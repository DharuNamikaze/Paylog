# Design Document: Persistent Background SMS Monitoring

## Overview

This design addresses the critical gap in PayLog's SMS monitoring where messages are lost when the Flutter app is not running. The solution implements a native Android SMS queue that stores messages when Flutter is unavailable, combined with a robust foreground service that survives device restarts and battery optimization.

The key insight is that the `SmsReceiver` BroadcastReceiver already receives SMS messages even when the app is closed (it's registered in the manifest), but currently discards them when `eventSink` is null. The fix involves adding a native storage layer that queues messages for later processing.

## Architecture

### Current Broken Flow
```
SMS Arrives → SmsReceiver → eventSink (NULL when app closed) → Message Lost
```

### Fixed Architecture (Queue-First Design)
```
SMS Arrives → SmsReceiver → ALWAYS Queue to SQLite (with dedup hash)
                                      ↓
                              Check eventSink
                                      ↓
              ┌───────────────────────┴───────────────────────┐
              ↓                                               ↓
        eventSink EXISTS                              eventSink NULL
              ↓                                               ↓
        Notify Flutter "new SMS queued"              Wait for App Open
              ↓                                               ↓
        Flutter reads from queue                     App Opens → Read Queue
              ↓                                               ↓
        Process & mark as processed                  Process & mark as processed
```

**Key Design Principle: Queue-First, Single Source of Truth**
- ALL SMS messages are ALWAYS written to SQLite first
- Flutter reads from the queue, never directly from the receiver
- This eliminates race conditions and ensures crash-safety
- Deduplication happens at the database level using hash constraint

### Component Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                        Android Native Layer                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐ │
│  │ SmsReceiver │───▶│ SmsQueueManager  │───▶│ SharedPrefs/   │ │
│  │ (Broadcast) │    │ (Queue Logic)    │    │ SQLite Storage │ │
│  └─────────────┘    └──────────────────┘    └────────────────┘ │
│         │                    │                                  │
│         ▼                    ▼                                  │
│  ┌─────────────┐    ┌──────────────────┐                       │
│  │ SmsMonitor- │    │ BootReceiver     │                       │
│  │ ingService  │◀───│ (Auto-start)     │                       │
│  │ (Foreground)│    └──────────────────┘                       │
│  └─────────────┘                                                │
├─────────────────────────────────────────────────────────────────┤
│                      Platform Channel                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐ │
│  │ SmsPlugin   │───▶│ SmsListenerSvc   │───▶│ Transaction    │ │
│  │ (Methods)   │    │ (Dart)           │    │ Processing     │ │
│  └─────────────┘    └──────────────────┘    └────────────────┘ │
│                        Flutter Layer                             │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. SmsQueueDatabase (New Component - SQLite)

Native Android SQLite database for reliable SMS queue storage.

**Why SQLite over SharedPreferences:**
- Atomic writes - no corruption on process death
- UNIQUE constraint for deduplication
- Efficient age-based cleanup with SQL
- Thread-safe by design
- Handles concurrent writes properly

```kotlin
class SmsQueueDatabase(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
    
    companion object {
        private const val DB_NAME = "sms_queue.db"
        private const val DB_VERSION = 1
        private const val TABLE_NAME = "sms_queue"
        private const val MAX_QUEUE_SIZE = 100
        private const val MAX_AGE_DAYS = 7
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE $TABLE_NAME (
                id TEXT PRIMARY KEY,
                hash TEXT UNIQUE NOT NULL,
                sender TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                queued_at INTEGER NOT NULL,
                processed INTEGER DEFAULT 0
            )
        """)
        db.execSQL("CREATE INDEX idx_processed ON $TABLE_NAME(processed)")
        db.execSQL("CREATE INDEX idx_queued_at ON $TABLE_NAME(queued_at)")
    }
}

class SmsQueueManager(private val context: Context) {
    
    private val db: SmsQueueDatabase = SmsQueueDatabase(context)
    
    // Queue an SMS message - ALWAYS called, even when Flutter is running
    // Returns false if duplicate (hash already exists)
    fun queueSms(sender: String, content: String, timestamp: Long): Boolean
    
    // Get all unprocessed SMS messages (ordered by timestamp)
    fun getUnprocessedSms(): List<QueuedSms>
    
    // Mark a message as processed (don't delete immediately for debugging)
    fun markAsProcessed(id: String): Boolean
    
    // Delete processed messages older than 1 hour
    fun cleanupProcessed()
    
    // Delete unprocessed messages older than MAX_AGE_DAYS
    fun cleanupOldMessages()
    
    // Enforce MAX_QUEUE_SIZE by removing oldest unprocessed
    fun enforceQueueLimit()
    
    // Get queue statistics
    fun getQueueStats(): QueueStats
    
    // Generate dedup hash: SHA256(sender + timestamp + content)
    private fun generateHash(sender: String, content: String, timestamp: Long): String
}

data class QueuedSms(
    val id: String,           // UUID for tracking
    val hash: String,         // Dedup hash
    val sender: String,
    val content: String,
    val timestamp: Long,      // Original SMS timestamp
    val queuedAt: Long,       // When it was queued
    val processed: Boolean    // Whether Flutter has processed it
)

data class QueueStats(
    val totalQueued: Int,
    val unprocessedCount: Int,
    val processedCount: Int,
    val oldestUnprocessedAge: Long?,
    val newestUnprocessedAge: Long?
)
```

### 2. Updated SmsReceiver (Queue-First Design)

Modified to ALWAYS queue messages first, then notify Flutter if available.

```kotlin
class SmsReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        // ... existing SMS extraction logic ...
        
        // ALWAYS queue first - single source of truth
        val queueManager = SmsQueueManager(context)
        val wasQueued = queueManager.queueSms(sender, content, timestamp)
        
        if (!wasQueued) {
            // Duplicate detected via hash - skip
            Log.d(TAG, "Duplicate SMS detected, skipping: $sender")
            return
        }
        
        Log.i(TAG, "SMS queued: $sender")
        
        // Notify Flutter if available (it will read from queue)
        val sink = eventSink
        if (sink != null) {
            // Send notification that new SMS is available
            sink.success(mapOf(
                "type" to "new_sms_queued",
                "sender" to sender,
                "timestamp" to timestamp
            ))
            Log.d(TAG, "Flutter notified of new queued SMS")
        } else {
            Log.d(TAG, "Flutter not available, SMS will be processed on app open")
        }
    }
}
```

### 3. Updated SmsPlugin

New methods for queue management.

```kotlin
// New method channel methods
"getQueuedSmsCount" -> getQueuedSmsCount(result)
"processQueuedSms" -> processQueuedSms(result)
"clearSmsQueue" -> clearSmsQueue(result)
"getQueueStatus" -> getQueueStatus(result)
```

### 4. Updated SmsMonitoringService

**Important: The foreground service does NOT process SMS.**

Its responsibilities are limited to:
1. **Process survival** - Keeps the app process alive so BroadcastReceiver works
2. **Queue maintenance** - Periodic cleanup of old/processed messages
3. **User visibility** - Shows notification that monitoring is active

```kotlin
class SmsMonitoringService : Service() {
    
    private var queueManager: SmsQueueManager? = null
    private var cleanupHandler: Handler? = null
    
    override fun onCreate() {
        super.onCreate()
        queueManager = SmsQueueManager(applicationContext)
        
        // Schedule periodic cleanup (every 6 hours)
        schedulePeriodicCleanup()
    }
    
    private fun schedulePeriodicCleanup() {
        cleanupHandler = Handler(Looper.getMainLooper())
        cleanupHandler?.postDelayed(object : Runnable {
            override fun run() {
                queueManager?.cleanupOldMessages()
                queueManager?.cleanupProcessed()
                queueManager?.enforceQueueLimit()
                cleanupHandler?.postDelayed(this, 6 * 60 * 60 * 1000) // 6 hours
            }
        }, 6 * 60 * 60 * 1000)
    }
    
    // NOTE: This service does NOT process SMS
    // SMS processing happens in Flutter when it reads from the queue
}
```

### 5. Flutter SmsListenerService Updates

```dart
class SmsListenerService {
    
    // Process queued SMS on initialization and when notified
    Future<void> processQueuedMessages() async {
        final messages = await _getUnprocessedSms();
        if (messages.isEmpty) return;
        
        debugPrint('Processing ${messages.length} queued SMS messages');
        
        for (final msg in messages) {
            try {
                // Process through normal pipeline
                await _processSmsMessage(msg);
                // Mark as processed in native queue
                await _markAsProcessed(msg.id);
            } catch (e) {
                debugPrint('Failed to process queued SMS ${msg.id}: $e');
                // Don't mark as processed - will retry next time
            }
        }
    }
    
    // Called during service initialization
    Future<void> initialize() async {
        // ... existing initialization ...
        
        // Process any queued messages from when app was closed
        await processQueuedMessages();
        
        // Listen for "new_sms_queued" notifications
        _smsStream.listen((event) {
            if (event['type'] == 'new_sms_queued') {
                // New SMS queued - process it
                processQueuedMessages();
            }
        });
    }
}
```

## Data Models

### Native Queue Storage (SQLite Schema)

```sql
CREATE TABLE sms_queue (
    id TEXT PRIMARY KEY,                    -- UUID
    hash TEXT UNIQUE NOT NULL,              -- SHA256(sender + timestamp + content)
    sender TEXT NOT NULL,
    content TEXT NOT NULL,
    timestamp INTEGER NOT NULL,             -- Original SMS timestamp
    queued_at INTEGER NOT NULL,             -- When queued
    processed INTEGER DEFAULT 0             -- 0 = unprocessed, 1 = processed
);

CREATE INDEX idx_processed ON sms_queue(processed);
CREATE INDEX idx_queued_at ON sms_queue(queued_at);
```

**Deduplication Hash:**
```kotlin
fun generateHash(sender: String, content: String, timestamp: Long): String {
    val input = "$sender|$timestamp|$content"
    val digest = MessageDigest.getInstance("SHA-256")
    return digest.digest(input.toByteArray()).joinToString("") { "%02x".format(it) }
}
```

### Platform Channel Data Transfer

```dart
// Method: getQueueStatus
Map<String, dynamic> {
  "queueSize": int,
  "oldestMessageAge": int,  // milliseconds
  "newestMessageAge": int,
  "lastCleanupAt": int,
  "totalQueued": int,
  "totalProcessed": int
}

// Method: processQueuedSms
List<Map<String, dynamic>> [
  {
    "id": String,
    "sender": String,
    "content": String,
    "timestamp": int,
    "queuedAt": int
  }
]
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: SMS Always Queued First

*For any* SMS message received by SmsReceiver, the message SHALL be written to SQLite queue BEFORE any notification is sent to Flutter, ensuring single source of truth.

**Validates: Requirements 1.1**

### Property 2: Deduplication via Hash

*For any* SMS message with the same sender, content, and timestamp as an existing queued message, the duplicate SHALL be rejected (UNIQUE constraint on hash) and not added to the queue.

**Validates: Requirements 1.1 (implicit dedup requirement)**

### Property 3: Queue Round Trip Processing

*For any* set of SMS messages queued in SQLite, when Flutter connects and processes the queue, ALL unprocessed messages SHALL be delivered to the Flutter layer and marked as processed.

**Validates: Requirements 1.2, 1.4, 5.2, 5.4**

### Property 4: Queue Ordering Preservation

*For any* sequence of SMS messages queued while Flutter is unavailable, the messages SHALL be returned in the same order they were received (ordered by original timestamp).

**Validates: Requirements 1.3**

### Property 5: Timestamp Preservation Through Queue

*For any* SMS message that passes through the SQLite queue, the original SMS timestamp SHALL be preserved and match the timestamp when the message is processed by Flutter.

**Validates: Requirements 5.3**

### Property 6: Queue Size Limit Enforcement

*For any* queue state where adding a new message would exceed 100 unprocessed messages, the oldest unprocessed message(s) SHALL be removed to maintain the queue size at or below 100.

**Validates: Requirements 6.1**

### Property 7: Age-Based Queue Cleanup

*For any* unprocessed message in the queue that is older than 7 days (based on queued_at timestamp), the message SHALL be removed during cleanup operations.

**Validates: Requirements 6.2**

## Error Handling

### Native Layer Error Handling

1. **SQLite Write Errors**
   - Use transactions for atomic writes
   - On UNIQUE constraint violation (duplicate), return false gracefully
   - Log database errors but don't crash the receiver

2. **Queue Read Errors**
   - If database is corrupted, attempt to recreate it
   - Return empty list rather than throwing exception
   - Log errors for debugging

3. **Service Lifecycle Errors**
   - If foreground service fails to start, log error and notify Flutter
   - If notification creation fails, continue service without notification
   - Handle SecurityException for missing permissions gracefully

4. **Concurrent Access**
   - SQLite handles concurrent access natively
   - Use WAL mode for better concurrent read/write performance

### Flutter Layer Error Handling

1. **Queue Processing Errors**
   - If processing a queued message fails, mark it for retry
   - After 3 failed attempts, discard message and log error
   - Continue processing remaining messages even if one fails

2. **Platform Channel Errors**
   - Implement timeout for queue operations (5 seconds)
   - Retry failed operations up to 3 times
   - Provide user feedback if queue processing fails

## Testing Strategy

### Unit Testing

Unit tests will verify individual component behavior:

1. **SmsQueueDatabase Tests**
   - Test table creation and schema
   - Test UNIQUE constraint on hash
   - Test index creation

2. **SmsQueueManager Tests**
   - Test queueSms adds message correctly
   - Test queueSms returns false for duplicates
   - Test getUnprocessedSms returns only unprocessed messages
   - Test markAsProcessed updates processed flag
   - Test cleanupOldMessages removes old entries
   - Test cleanupProcessed removes processed entries
   - Test enforceQueueLimit removes oldest when over limit
   - Test generateHash produces consistent results

3. **SmsReceiver Queue Integration Tests**
   - Test message is ALWAYS queued first
   - Test Flutter is notified when eventSink exists
   - Test duplicate SMS is rejected

### Property-Based Testing

Property-based tests will use **fast_check** library for Dart/Flutter to verify correctness properties with randomly generated inputs.

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with: **Feature: persistent-sms-monitoring, Property {number}: {property_text}**

**Test Implementation:**
1. Generate random SMS messages (sender, content, timestamp)
2. Simulate various queue states (empty, partial, full)
3. Verify properties hold across all generated scenarios

### Integration Testing

1. **End-to-End Queue Flow**
   - Queue messages with Flutter stopped
   - Start Flutter and verify all messages processed
   - Verify queue is empty after processing

2. **Service Lifecycle Testing**
   - Test service survives app kill
   - Test service restarts after device reboot
   - Test queue persists across service restarts

### Manual Testing Checklist

1. Install app and enable SMS monitoring
2. Force close the app completely
3. Send test SMS to device
4. Reopen app and verify SMS appears
5. Test with multiple SMS while app closed
6. Test device reboot and verify monitoring resumes
7. Test battery optimization exemption flow

## Implementation Notes

### Why SQLite over SharedPreferences

SQLite is the correct choice because:
- **Atomic writes** - No corruption on process death mid-write
- **UNIQUE constraint** - Database-level deduplication via hash
- **Efficient cleanup** - SQL DELETE with WHERE clause
- **Thread-safe** - Built-in concurrency handling
- **Handles concurrent writes** - Multiple SMS arriving simultaneously

### Queue-First Design Rationale

Always queueing first (even when Flutter is running) provides:
- **Single source of truth** - All SMS go through the same path
- **No race conditions** - No branching logic based on Flutter state
- **Crash-safe** - If app crashes after queue, message is still there
- **Simpler debugging** - One code path to trace

### Foreground Service Responsibilities (IMPORTANT)

The foreground service does NOT process SMS. Its only jobs are:
1. **Keep process alive** - So BroadcastReceiver can receive SMS
2. **Periodic cleanup** - Remove old/processed messages
3. **Show notification** - User knows monitoring is active

All SMS processing happens in Flutter when it reads from the queue.

### Thread Safety

SQLite handles thread safety natively. Additional considerations:
- Use WAL (Write-Ahead Logging) mode for better concurrent performance
- SmsReceiver runs on main thread, cleanup runs on background
- No explicit synchronization needed with SQLite

### Battery Optimization Guidance

Different manufacturers have different battery optimization behaviors:
- **Samsung**: Settings → Apps → PayLog → Battery → Unrestricted
- **Xiaomi**: Settings → Apps → PayLog → Autostart + No battery restrictions
- **Huawei**: Settings → Apps → PayLog → Battery → Launch manually
- **OnePlus**: Settings → Battery → Battery optimization → PayLog → Don't optimize

Consider adding in-app guidance for specific manufacturers detected via `Build.MANUFACTURER`.
