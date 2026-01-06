package com.paylog.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Background service for persistent SMS monitoring.
 * 
 * IMPORTANT: This service does NOT process SMS messages.
 * Its responsibilities are limited to:
 * 1. Process survival - Keeps the app process alive so BroadcastReceiver works
 * 2. Queue maintenance - Periodic cleanup of old/processed messages
 * 3. User visibility - Shows notification that monitoring is active
 * 
 * All SMS processing happens in Flutter when it reads from the SQLite queue.
 */
class SmsMonitoringService : Service() {
    
    companion object {
        private const val TAG = "PayLog_SmsService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "sms_monitoring_channel"
        
        // Service actions
        const val ACTION_START_MONITORING = "com.paylog.app.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.paylog.app.STOP_MONITORING"
        
        // Cleanup interval: 6 hours
        private const val CLEANUP_INTERVAL_MS = 6 * 60 * 60 * 1000L
    }
    
    private var isMonitoring = false
    private var queueManager: SmsQueueManager? = null
    private var cleanupHandler: Handler? = null
    private var cleanupRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "SMS Monitoring Service created")
        createNotificationChannel()
        
        // Initialize queue manager for cleanup operations
        queueManager = SmsQueueManager(applicationContext)
        
        // Perform initial cleanup
        performQueueCleanup()
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
                // If service is restarted by system, start monitoring
                if (!isMonitoring) {
                    startMonitoring()
                }
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
        stopCleanupScheduler()
        stopMonitoring()
        super.onDestroy()
    }
    
    /**
     * Start SMS monitoring in foreground mode.
     * 
     * NOTE: This service does NOT process SMS.
     * It only keeps the process alive and performs queue maintenance.
     */
    private fun startMonitoring() {
        if (isMonitoring) {
            Log.d(TAG, "SMS monitoring already active")
            return
        }
        
        Log.i(TAG, "Starting SMS monitoring service (process keeper + queue maintenance)")
        
        // Start foreground service with notification
        val notification = createMonitoringNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        isMonitoring = true
        
        // Start periodic cleanup scheduler
        startCleanupScheduler()
        
        Log.i(TAG, "SMS monitoring service is now active")
        Log.i(TAG, "NOTE: SMS processing happens in Flutter, this service only keeps process alive")
    }
    
    /**
     * Stop SMS monitoring.
     */
    private fun stopMonitoring() {
        if (!isMonitoring) {
            Log.d(TAG, "SMS monitoring already stopped")
            return
        }
        
        Log.i(TAG, "Stopping SMS monitoring service")
        
        stopCleanupScheduler()
        isMonitoring = false
        stopForeground(true)
        stopSelf()
        
        Log.i(TAG, "SMS monitoring service stopped")
    }
    
    /**
     * Start periodic cleanup scheduler.
     * Runs every 6 hours to clean up old and processed messages.
     */
    private fun startCleanupScheduler() {
        cleanupHandler = Handler(Looper.getMainLooper())
        cleanupRunnable = object : Runnable {
            override fun run() {
                performQueueCleanup()
                cleanupHandler?.postDelayed(this, CLEANUP_INTERVAL_MS)
            }
        }
        
        // Schedule first cleanup after 6 hours
        cleanupHandler?.postDelayed(cleanupRunnable!!, CLEANUP_INTERVAL_MS)
        Log.d(TAG, "Queue cleanup scheduler started (interval: ${CLEANUP_INTERVAL_MS / 1000 / 60 / 60} hours)")
    }
    
    /**
     * Stop periodic cleanup scheduler.
     */
    private fun stopCleanupScheduler() {
        cleanupRunnable?.let { runnable ->
            cleanupHandler?.removeCallbacks(runnable)
        }
        cleanupHandler = null
        cleanupRunnable = null
        Log.d(TAG, "Queue cleanup scheduler stopped")
    }
    
    /**
     * Perform queue cleanup operations.
     */
    private fun performQueueCleanup() {
        try {
            Log.d(TAG, "Performing queue cleanup")
            
            val oldDeleted = queueManager?.cleanupOldMessages() ?: 0
            val processedDeleted = queueManager?.cleanupProcessed() ?: 0
            val limitDeleted = queueManager?.enforceQueueLimit() ?: 0
            
            val totalDeleted = oldDeleted + processedDeleted + limitDeleted
            
            if (totalDeleted > 0) {
                Log.i(TAG, "Queue cleanup complete: old=$oldDeleted, processed=$processedDeleted, limit=$limitDeleted")
            } else {
                Log.d(TAG, "Queue cleanup complete: no messages removed")
            }
            
            // Log queue stats
            val stats = queueManager?.getQueueStats()
            if (stats != null) {
                Log.d(TAG, "Queue stats: unprocessed=${stats.unprocessedCount}, total=${stats.totalQueued}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during queue cleanup: ${e.message}", e)
        }
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