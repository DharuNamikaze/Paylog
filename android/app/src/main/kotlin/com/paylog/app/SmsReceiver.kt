package com.paylog.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * SMS BroadcastReceiver with Queue-First Design.
 * 
 * ALL SMS messages are ALWAYS queued to SQLite first, then Flutter is notified.
 * This ensures no messages are lost even when Flutter is not running.
 * 
 * Flow:
 * 1. SMS arrives → Extract data
 * 2. Queue to SQLite (with dedup hash)
 * 3. If Flutter available → Notify "new_sms_queued"
 * 4. Flutter reads from queue when ready
 */
class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        var eventSink: EventChannel.EventSink? = null
        
        // Debug flag to enable verbose logging
        private const val DEBUG_ENABLED = true
        
        // Track receiver registration status
        @Volatile
        var isReceiverRegistered = false
        
        // Track last SMS processing time for debugging
        @Volatile
        var lastSmsProcessedAt: Long = 0
        
        // Counter for received SMS messages
        @Volatile
        var smsReceivedCount = 0
        
        // Counter for queued SMS messages
        @Volatile
        var smsQueuedCount = 0
        
        // Counter for duplicate SMS messages (rejected)
        @Volatile
        var smsDuplicateCount = 0
        
        /**
         * Static method to get receiver status without instantiation
         */
        fun getReceiverStatus(): Map<String, Any> {
            return mapOf<String, Any>(
                "receiverClass" to SmsReceiver::class.java.name,
                "receiverPackage" to (SmsReceiver::class.java.`package`?.name ?: "unknown"),
                "isReceiverRegistered" to isReceiverRegistered,
                "smsReceivedCount" to smsReceivedCount,
                "smsQueuedCount" to smsQueuedCount,
                "smsDuplicateCount" to smsDuplicateCount,
                "lastSmsProcessedAt" to lastSmsProcessedAt,
                "eventSinkAvailable" to (eventSink != null),
                "debugEnabled" to DEBUG_ENABLED
            )
        }
    }
    
    init {
        // Log receiver instantiation
        if (DEBUG_ENABLED) {
            Log.d(TAG, "SmsReceiver instantiated - class: ${this.javaClass.name}")
            Log.d(TAG, "SmsReceiver package: ${this.javaClass.`package`?.name}")
            isReceiverRegistered = true
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val startTime = System.currentTimeMillis()
        smsReceivedCount++
        lastSmsProcessedAt = startTime
        
        // Enhanced debug logging for receiver registration verification
        if (DEBUG_ENABLED) {
            Log.d(TAG, "=== SMS BROADCAST RECEIVER DEBUG (Queue-First) ===")
            Log.d(TAG, "Receiver class: ${this.javaClass.name}")
            Log.d(TAG, "SMS count: $smsReceivedCount, Queued: $smsQueuedCount, Duplicates: $smsDuplicateCount")
            Log.d(TAG, "Intent action: ${intent?.action}")
            Log.d(TAG, "Context available: ${context != null}")
            Log.d(TAG, "EventSink available: ${eventSink != null}")
        }
        
        Log.i(TAG, "SMS broadcast received (#$smsReceivedCount) - using queue-first design")
        
        // Verify context is available
        if (context == null) {
            Log.e(TAG, "Context is null - cannot process SMS")
            return
        }
        
        // Verify SMS_RECEIVED intent filtering
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.w(TAG, "Received non-SMS intent action: ${intent?.action}")
            return
        }
        
        Log.i(TAG, "SMS_RECEIVED intent confirmed - proceeding with queue-first processing")

        try {
            // Extract SMS messages from intent
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) {
                Log.w(TAG, "No SMS messages found in intent")
                return
            }

            Log.i(TAG, "Extracted ${messages.size} SMS message(s) from intent")
            
            // Initialize queue manager
            val queueManager = SmsQueueManager(context)

            for (message in messages) {
                processAndQueueMessage(message, queueManager)
            }
            
            val totalTime = System.currentTimeMillis() - startTime
            Log.d(TAG, "Total SMS processing time: ${totalTime}ms for ${messages.size} message(s)")
        } catch (e: Exception) {
            val errorTime = System.currentTimeMillis() - startTime
            Log.e(TAG, "Error processing SMS after ${errorTime}ms: ${e.message}", e)
        }
    }
    
    /**
     * Process a single SMS message using queue-first design.
     * 
     * 1. Validate and extract SMS data
     * 2. ALWAYS queue to SQLite first
     * 3. Notify Flutter if available
     */
    private fun processAndQueueMessage(message: SmsMessage, queueManager: SmsQueueManager) {
        val messageStartTime = System.currentTimeMillis()
        
        try {
            // Extract and validate sender
            val sender = message.originatingAddress?.trim()
            if (sender.isNullOrEmpty()) {
                Log.w(TAG, "SMS sender is null or empty - skipping")
                return
            }
            
            // Extract content
            val content = message.messageBody?.trim() ?: ""
            
            // Get timestamp
            val timestamp = if (message.timestampMillis > 0) {
                message.timestampMillis
            } else {
                System.currentTimeMillis()
            }
            
            Log.i(TAG, "Processing SMS from: $sender")
            Log.d(TAG, "SMS content preview: ${truncateContent(content)}")
            
            // ========================================
            // QUEUE-FIRST: Always queue to SQLite first
            // ========================================
            val wasQueued = queueManager.queueSms(sender, content, timestamp)
            
            if (!wasQueued) {
                // Duplicate detected via hash - skip
                smsDuplicateCount++
                Log.d(TAG, "Duplicate SMS detected (hash exists) - skipping notification")
                return
            }
            
            smsQueuedCount++
            Log.i(TAG, "SMS queued successfully (#$smsQueuedCount)")
            
            // ========================================
            // Notify Flutter if available
            // ========================================
            val sink = eventSink
            if (sink != null) {
                try {
                    // Send notification that new SMS is queued (not the full SMS data)
                    // Flutter will read from the queue
                    val notification = mapOf(
                        "type" to "new_sms_queued",
                        "sender" to sender,
                        "timestamp" to timestamp,
                        "queuedAt" to System.currentTimeMillis()
                    )
                    
                    sink.success(notification)
                    
                    val processingTime = System.currentTimeMillis() - messageStartTime
                    Log.i(TAG, "Flutter notified of new queued SMS in ${processingTime}ms")
                    
                    if (processingTime > 500) {
                        Log.w(TAG, "SMS processing took longer than expected: ${processingTime}ms (target: <500ms)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error notifying Flutter: ${e.message}", e)
                    // Message is still queued - Flutter will get it when it reads the queue
                }
            } else {
                Log.d(TAG, "Flutter not available - SMS queued for later processing")
                if (DEBUG_ENABLED) {
                    Log.d(TAG, "EventSink is null - message will be processed when app opens")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing SMS message: ${e.message}", e)
        }
    }
    
    private fun truncateContent(content: String, maxLength: Int = 50): String {
        return if (content.length <= maxLength) {
            content
        } else {
            "${content.substring(0, maxLength)}..."
        }
    }
    
    /**
     * Get debug information about the SMS receiver status
     * This method can be called from SmsPlugin to verify receiver functionality
     */
    fun getDebugInfo(): Map<String, Any> {
        return mapOf<String, Any>(
            "receiverClass" to this.javaClass.name,
            "receiverPackage" to (this.javaClass.`package`?.name ?: "unknown"),
            "isReceiverRegistered" to isReceiverRegistered,
            "smsReceivedCount" to smsReceivedCount,
            "smsQueuedCount" to smsQueuedCount,
            "smsDuplicateCount" to smsDuplicateCount,
            "lastSmsProcessedAt" to lastSmsProcessedAt,
            "eventSinkAvailable" to (eventSink != null),
            "debugEnabled" to DEBUG_ENABLED
        )
    }
    
}