package com.paylog.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Background service for persistent SMS monitoring
 * 
 * This service runs as a foreground service to ensure Android doesn't kill it.
 * It maintains SMS monitoring even when the app is not in the foreground.
 */
class SmsMonitoringService : Service() {
    
    companion object {
        private const val TAG = "PayLog_SmsService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "sms_monitoring_channel"
        
        // Service actions
        const val ACTION_START_MONITORING = "com.paylog.app.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.paylog.app.STOP_MONITORING"
    }
    
    private var isMonitoring = false
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "SMS Monitoring Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service start command received: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_MONITORING -> {
                startMonitoring()
            }
            ACTION_STOP_MONITORING -> {
                stopMonitoring()
            }
            else -> {
                Log.w(TAG, "Unknown action received: ${intent?.action}")
            }
        }
        
        // Return START_STICKY to restart service if killed by system
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null // This is not a bound service
    }
    
    override fun onDestroy() {
        Log.d(TAG, "SMS Monitoring Service destroyed")
        stopMonitoring()
        super.onDestroy()
    }
    
    /**
     * Start SMS monitoring in foreground mode
     */
    private fun startMonitoring() {
        if (isMonitoring) {
            Log.d(TAG, "SMS monitoring already active")
            return
        }
        
        Log.i(TAG, "Starting SMS monitoring service")
        
        // Start foreground service with notification
        val notification = createMonitoringNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        isMonitoring = true
        
        // The actual SMS monitoring is handled by SmsReceiver
        // This service just ensures the process stays alive
        Log.i(TAG, "SMS monitoring service is now active")
    }
    
    /**
     * Stop SMS monitoring
     */
    private fun stopMonitoring() {
        if (!isMonitoring) {
            Log.d(TAG, "SMS monitoring already stopped")
            return
        }
        
        Log.i(TAG, "Stopping SMS monitoring service")
        
        isMonitoring = false
        stopForeground(true)
        stopSelf()
        
        Log.i(TAG, "SMS monitoring service stopped")
    }
    
    /**
     * Create notification channel for Android 8.0+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors SMS messages for financial transactions"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "Notification channel created")
        }
    }
    
    /**
     * Create notification for foreground service
     */
    private fun createMonitoringNotification(): Notification {
        // Intent to open the app when notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent to stop monitoring
        val stopIntent = Intent(this, SmsMonitoringService::class.java).apply {
            action = ACTION_STOP_MONITORING
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PayLog SMS Monitoring")
            .setContentText("Monitoring SMS messages for financial transactions")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Use built-in icon for now
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}