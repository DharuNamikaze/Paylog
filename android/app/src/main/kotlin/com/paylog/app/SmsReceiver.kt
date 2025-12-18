package com.paylog.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

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
        
        /**
         * Static method to get receiver status without instantiation
         */
        fun getReceiverStatus(): Map<String, Any> {
            return mapOf<String, Any>(
                "receiverClass" to SmsReceiver::class.java.name,
                "receiverPackage" to (SmsReceiver::class.java.`package`?.name ?: "unknown"),
                "isReceiverRegistered" to isReceiverRegistered,
                "smsReceivedCount" to smsReceivedCount,
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
            Log.d(TAG, "=== SMS BROADCAST RECEIVER DEBUG ===")
            Log.d(TAG, "Receiver class: ${this.javaClass.name}")
            Log.d(TAG, "Receiver package: ${this.javaClass.`package`?.name}")
            Log.d(TAG, "SMS count: $smsReceivedCount")
            Log.d(TAG, "Intent action: ${intent?.action}")
            Log.d(TAG, "Intent extras: ${intent?.extras?.keySet()?.joinToString(", ")}")
            Log.d(TAG, "Context available: ${context != null}")
            Log.d(TAG, "Context package: ${context?.packageName}")
            Log.d(TAG, "EventSink available: ${eventSink != null}")
            Log.d(TAG, "Processing started at: $startTime")
        }
        
        Log.i(TAG, "SMS broadcast received (#$smsReceivedCount) with action: ${intent?.action} at $startTime")
        
        // Log background operation status
        val appContext = context?.applicationContext
        if (appContext != null) {
            Log.d(TAG, "SMS processing in background - app context available (package: ${appContext.packageName})")
        } else {
            Log.w(TAG, "SMS processing without app context - this may indicate registration issues")
        }
        
        // Verify SMS_RECEIVED intent filtering
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.w(TAG, "Received non-SMS intent action: ${intent?.action}")
            Log.w(TAG, "Expected action: ${Telephony.Sms.Intents.SMS_RECEIVED_ACTION}")
            if (DEBUG_ENABLED) {
                Log.d(TAG, "Intent categories: ${intent?.categories?.joinToString(", ") ?: "none"}")
                Log.d(TAG, "Intent data: ${intent?.data}")
                Log.d(TAG, "Intent type: ${intent?.type}")
            }
            return
        }
        
        Log.i(TAG, "SMS_RECEIVED intent confirmed - proceeding with SMS processing")

        try {
            // Enhanced SMS extraction debugging
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) {
                Log.w(TAG, "No SMS messages found in intent - this may indicate intent parsing issues")
                if (DEBUG_ENABLED) {
                    Log.d(TAG, "Intent extras for debugging:")
                    intent?.extras?.let { extras ->
                        for (key in extras.keySet()) {
                            Log.d(TAG, "  $key: ${extras.get(key)}")
                        }
                    }
                }
                return
            }

            Log.i(TAG, "Successfully extracted ${messages.size} SMS message(s) from intent")
            if (DEBUG_ENABLED) {
                Log.d(TAG, "Message extraction successful - SMS parsing working correctly")
            }

            for (message in messages) {
                val messageStartTime = System.currentTimeMillis()
                val smsData = createValidatedSmsData(message)
                
                if (smsData != null) {
                    Log.i(TAG, "SMS received from: ${smsData["sender"]}")
                    Log.i(TAG, "SMS content preview: ${truncateContent(smsData["content"] as String)}")
                    Log.d(TAG, "SMS timestamp: ${smsData["timestamp"]}")
                    
                    if (DEBUG_ENABLED) {
                        Log.d(TAG, "SMS data validation successful:")
                        Log.d(TAG, "  - Sender: ${smsData["sender"]}")
                        Log.d(TAG, "  - Content length: ${(smsData["content"] as String).length}")
                        Log.d(TAG, "  - Timestamp: ${smsData["timestamp"]}")
                        Log.d(TAG, "  - Thread ID: ${smsData["threadId"]}")
                        Log.d(TAG, "  - Received at: ${smsData["receivedAt"]}")
                    }

                    // Send to Flutter via EventChannel
                    val sink = eventSink
                    if (sink != null) {
                        try {
                            sink.success(smsData)
                            val processingTime = System.currentTimeMillis() - messageStartTime
                            Log.i(TAG, "SMS data sent to Flutter successfully in ${processingTime}ms")
                            
                            if (DEBUG_ENABLED) {
                                Log.d(TAG, "Platform channel communication successful")
                                Log.d(TAG, "EventSink.success() completed without errors")
                            }
                            
                            // Log performance warning if processing takes too long
                            if (processingTime > 500) {
                                Log.w(TAG, "SMS processing took longer than expected: ${processingTime}ms (target: <500ms)")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending SMS data to Flutter via EventChannel: ${e.message}", e)
                        }
                    } else {
                        Log.w(TAG, "EventChannel sink not available - SMS data cannot be sent to Flutter")
                        Log.w(TAG, "This indicates platform channel is not properly connected")
                        if (DEBUG_ENABLED) {
                            Log.d(TAG, "EventSink is null - check if Flutter EventChannel is listening")
                        }
                    }
                } else {
                    Log.w(TAG, "SMS data validation failed, skipping message")
                    if (DEBUG_ENABLED) {
                        Log.d(TAG, "SMS validation failed - check createValidatedSmsData() method")
                    }
                }
            }
            
            val totalTime = System.currentTimeMillis() - startTime
            Log.d(TAG, "Total SMS processing time: ${totalTime}ms for ${messages.size} message(s)")
        } catch (e: Exception) {
            val errorTime = System.currentTimeMillis() - startTime
            Log.e(TAG, "Error processing SMS after ${errorTime}ms: ${e.message}", e)
            eventSink?.error("SMS_PROCESSING_ERROR", 
                "Error processing SMS: ${e.message}", 
                mapOf("error" to e.toString(), "timestamp" to System.currentTimeMillis(), "processingTime" to errorTime))
        }
    }
    
    private fun createValidatedSmsData(message: SmsMessage): Map<String, Any>? {
        try {
            // Extract and validate sender
            val sender = message.originatingAddress?.trim()
            if (sender.isNullOrEmpty()) {
                Log.w(TAG, "SMS sender is null or empty")
                return null
            }

            // Extract and validate content
            val content = message.messageBody?.trim() ?: ""
            if (content.isEmpty()) {
                Log.w(TAG, "SMS content is empty")
                // Still process empty messages as they might be valid system messages
            }

            // Validate timestamp
            val timestamp = message.timestampMillis
            if (timestamp <= 0) {
                Log.w(TAG, "Invalid SMS timestamp: $timestamp")
                // Use current time as fallback
                return createSmsDataMap(sender, content, System.currentTimeMillis())
            }

            return createSmsDataMap(sender, content, timestamp)
        } catch (e: Exception) {
            Log.e(TAG, "Error validating SMS data: ${e.message}", e)
            return null
        }
    }
    
    private fun createSmsDataMap(sender: String, content: String, timestamp: Long): Map<String, Any> {
        val dataMap = mutableMapOf<String, Any>()
        dataMap["sender"] = sender
        dataMap["content"] = content
        dataMap["timestamp"] = timestamp
        dataMap["threadId"] = "null" // Use string "null" instead of null
        dataMap["receivedAt"] = System.currentTimeMillis()
        dataMap["contentLength"] = content.length
        dataMap["isValidData"] = true
        return dataMap
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
            "lastSmsProcessedAt" to lastSmsProcessedAt,
            "eventSinkAvailable" to (eventSink != null),
            "debugEnabled" to DEBUG_ENABLED
        )
    }
    
}