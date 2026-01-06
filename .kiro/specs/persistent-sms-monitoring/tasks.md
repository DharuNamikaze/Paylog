# Implementation Plan: Persistent Background SMS Monitoring

## Overview

This implementation plan addresses the critical issue where SMS messages are lost when the Flutter app is not running. The solution uses a queue-first design with SQLite storage, ensuring all SMS are persisted before any processing occurs.

## Tasks

- [x] 1. Create SmsQueueDatabase SQLite implementation
  - Create new Kotlin file for SQLite database helper
  - Define table schema with id, hash, sender, content, timestamp, queued_at, processed columns
  - Add UNIQUE constraint on hash column for deduplication
  - Create indexes on processed and queued_at columns
  - Enable WAL mode for better concurrent performance
  - _Requirements: 1.1, 1.3_

- [x] 1.1 Implement SmsQueueDatabase class
  - Create SQLiteOpenHelper subclass
  - Implement onCreate with table creation SQL
  - Implement onUpgrade for future schema migrations
  - Add companion object with constants (DB_NAME, DB_VERSION, TABLE_NAME)
  - _Requirements: 1.1_

- [x] 1.2 Implement hash generation function
  - Create generateHash function using SHA-256
  - Hash input: "$sender|$timestamp|$content"
  - Return hex string representation
  - _Requirements: 1.1 (deduplication)_

- [ ]* 1.3 Write property test for deduplication
  - **Property 2: Deduplication via Hash**
  - **Validates: Requirements 1.1**

- [x] 2. Create SmsQueueManager with queue operations
  - Implement queueSms method that returns false for duplicates
  - Implement getUnprocessedSms with ORDER BY timestamp
  - Implement markAsProcessed to update processed flag
  - Implement cleanup methods for old and processed messages
  - Implement enforceQueueLimit to maintain max 100 unprocessed
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 6.1, 6.2_

- [x] 2.1 Implement queueSms method
  - Generate UUID for id
  - Generate hash from sender, content, timestamp
  - Insert with INSERT OR IGNORE for duplicate handling
  - Return true if inserted, false if duplicate
  - _Requirements: 1.1_

- [x] 2.2 Implement getUnprocessedSms method
  - SELECT WHERE processed = 0 ORDER BY timestamp ASC
  - Map cursor to QueuedSms data class
  - Return empty list on error
  - _Requirements: 1.2, 1.3_

- [x] 2.3 Implement markAsProcessed method
  - UPDATE SET processed = 1 WHERE id = ?
  - Return true if row updated
  - _Requirements: 1.4_

- [x] 2.4 Implement cleanup methods
  - cleanupOldMessages: DELETE WHERE queued_at < (now - 7 days) AND processed = 0
  - cleanupProcessed: DELETE WHERE processed = 1 AND queued_at < (now - 1 hour)
  - enforceQueueLimit: DELETE oldest when count > 100
  - _Requirements: 6.1, 6.2_

- [ ]* 2.5 Write property test for queue ordering
  - **Property 4: Queue Ordering Preservation**
  - **Validates: Requirements 1.3**

- [ ]* 2.6 Write property test for timestamp preservation
  - **Property 5: Timestamp Preservation Through Queue**
  - **Validates: Requirements 5.3**

- [ ]* 2.7 Write property test for queue size limit
  - **Property 6: Queue Size Limit Enforcement**
  - **Validates: Requirements 6.1**

- [ ]* 2.8 Write property test for age-based cleanup
  - **Property 7: Age-Based Queue Cleanup**
  - **Validates: Requirements 6.2**

- [x] 3. Update SmsReceiver to use queue-first design
  - ALWAYS queue SMS to SQLite first
  - Check for duplicates via queueSms return value
  - Notify Flutter via eventSink only after successful queue
  - Send notification type "new_sms_queued" instead of full SMS data
  - _Requirements: 1.1, 1.2_

- [x] 3.1 Modify onReceive to queue first
  - Instantiate SmsQueueManager with context
  - Call queueSms before any eventSink operations
  - Skip processing if queueSms returns false (duplicate)
  - Log queue operation result
  - _Requirements: 1.1_

- [x] 3.2 Update eventSink notification
  - Change from sending full SMS data to notification
  - Send map with type: "new_sms_queued", sender, timestamp
  - Flutter will read from queue when notified
  - _Requirements: 1.2_

- [ ]* 3.3 Write property test for queue-first behavior
  - **Property 1: SMS Always Queued First**
  - **Validates: Requirements 1.1**

- [ ]* 3.4 Write property test for round trip processing
  - **Property 3: Queue Round Trip Processing**
  - **Validates: Requirements 1.2, 1.4, 5.2, 5.4**

- [x] 4. Update SmsPlugin with queue management methods
  - Add getUnprocessedSms method channel handler
  - Add markAsProcessed method channel handler
  - Add getQueueStats method channel handler
  - Add cleanupQueue method channel handler
  - _Requirements: 5.1, 5.2_

- [x] 4.1 Implement getUnprocessedSms handler
  - Call SmsQueueManager.getUnprocessedSms()
  - Convert List<QueuedSms> to List<Map> for platform channel
  - Return serialized list to Flutter
  - _Requirements: 5.1, 5.2_

- [x] 4.2 Implement markAsProcessed handler
  - Accept id parameter from Flutter
  - Call SmsQueueManager.markAsProcessed(id)
  - Return success boolean
  - _Requirements: 1.4_

- [x] 4.3 Implement getQueueStats handler
  - Call SmsQueueManager.getQueueStats()
  - Return map with queue statistics
  - _Requirements: 5.1_

- [x] 5. Update Flutter SmsListenerService for queue processing
  - Add processQueuedMessages method
  - Call on service initialization
  - Listen for "new_sms_queued" notifications
  - Process each message through existing pipeline
  - Mark as processed after successful processing
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 5.1 Add platform channel methods for queue
  - Add _getUnprocessedSms() method
  - Add _markAsProcessed(String id) method
  - Add _getQueueStats() method
  - _Requirements: 5.1_

- [x] 5.2 Implement processQueuedMessages
  - Get unprocessed messages from native queue
  - Loop through each message
  - Process through existing SMS processing pipeline
  - Mark as processed on success
  - Log errors but continue processing remaining
  - _Requirements: 5.2, 5.3_

- [x] 5.3 Update initialize to process queue
  - Call processQueuedMessages after existing initialization
  - Update stream listener to handle "new_sms_queued" type
  - Trigger processQueuedMessages when notification received
  - _Requirements: 5.1, 5.2_

- [x] 6. Update SmsMonitoringService for cleanup
  - Add periodic cleanup scheduling (every 6 hours)
  - Call cleanupOldMessages, cleanupProcessed, enforceQueueLimit
  - Ensure service does NOT process SMS (only cleanup)
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 6.1 Add cleanup scheduling
  - Create Handler for periodic execution
  - Schedule cleanup every 6 hours
  - Call all cleanup methods in sequence
  - Log cleanup results
  - _Requirements: 6.1, 6.2_

- [x] 6.2 Update service documentation
  - Add clear comments that service does NOT process SMS
  - Document service responsibilities (process survival, cleanup, notification)
  - _Requirements: 6.3_

- [x] 7. Checkpoint - Test queue functionality
  - ✅ Build compiles successfully
  - Test SMS queueing when app is closed
  - Test queue processing when app opens
  - Ask the user if questions arise

- [x] 8. Add battery optimization exemption UI
  - Add button in settings to request exemption
  - Show warning if exemption not granted
  - Store exemption status
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 8.1 Add exemption request in Flutter
  - Create method to call requestBatteryOptimizationExemption
  - Create method to check isBatteryOptimizationIgnored
  - Add UI button in settings page
  - _Requirements: 3.1, 3.4_

- [x] 8.2 Add exemption status warning
  - Check exemption status on app start
  - Show warning dialog if not exempted
  - Provide button to request exemption from warning
  - _Requirements: 3.3_

- [x] 9. Add device-specific guidance
  - Detect device manufacturer via Build.MANUFACTURER
  - Show manufacturer-specific instructions for battery optimization
  - Support Samsung, Xiaomi, Huawei, OnePlus, Oppo, Vivo
  - _Requirements: 7.2_

- [x] 9.1 Create manufacturer detection
  - Add method to detect manufacturer in SmsPlugin
  - Return manufacturer name to Flutter
  - _Requirements: 7.2_

- [x] 9.2 Create guidance UI
  - Create dialog with manufacturer-specific instructions
  - Include step-by-step settings navigation
  - Show when battery optimization warning is displayed
  - _Requirements: 7.2_

- [x] 10. Final checkpoint - End-to-end testing
  - Test complete flow: close app → receive SMS → open app → see transaction
  - Test device reboot and auto-restart
  - Test battery optimization exemption flow
  - Test with multiple SMS while app closed
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Tasks marked with `*` are optional property-based tests
- SQLite is used instead of SharedPreferences for reliability
- Queue-first design ensures no SMS is lost
- Foreground service only handles cleanup, not SMS processing
- All SMS processing happens in Flutter layer
