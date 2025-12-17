package com.example.flutter_sms_parser

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
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) {
                Log.w(TAG, "No SMS messages found in intent")
                return
            }

            for (message in messages) {
                val smsData = mapOf(
                    "sender" to (message.originatingAddress ?: "Unknown"),
                    "content" to (message.messageBody ?: ""),
                    "timestamp" to message.timestampMillis,
                    "threadId" to null // Android doesn't provide thread ID in broadcast
                )

                Log.d(TAG, "SMS received from: ${smsData["sender"]}")
                Log.d(TAG, "SMS content: ${smsData["content"]}")

                // Send to Flutter via EventChannel
                eventSink?.success(smsData)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing SMS: ${e.message}", e)
            eventSink?.error("SMS_PROCESSING_ERROR", e.message, null)
        }
    }
}