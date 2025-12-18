package com.paylog.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot receiver that starts SMS monitoring service when device boots up
 * 
 * This ensures PayLog automatically starts monitoring SMS messages
 * even after device restart, providing seamless transaction tracking.
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "PayLog_BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Boot receiver triggered with action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "Device boot completed - starting PayLog SMS monitoring")
                startSmsMonitoringService(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                Log.i(TAG, "PayLog app updated - restarting SMS monitoring")
                startSmsMonitoringService(context)
            }
            else -> {
                Log.w(TAG, "Received unexpected action: ${intent.action}")
            }
        }
    }
    
    /**
     * Start the SMS monitoring background service
     */
    private fun startSmsMonitoringService(context: Context) {
        try {
            val serviceIntent = Intent(context, SmsMonitoringService::class.java)
            serviceIntent.action = SmsMonitoringService.ACTION_START_MONITORING
            
            // Start as foreground service for Android 8.0+ compatibility
            context.startForegroundService(serviceIntent)
            
            Log.i(TAG, "SMS monitoring service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start SMS monitoring service", e)
        }
    }
}