package com.paylog.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.security.MessageDigest
import java.util.UUID

/**
 * Manager class for SMS queue operations.
 * 
 * Handles all queue operations including:
 * - Queueing SMS messages with deduplication
 * - Retrieving unprocessed messages
 * - Marking messages as processed
 * - Cleanup of old/processed messages
 * - Enforcing queue size limits
 */
class SmsQueueManager(context: Context) {
    
    companion object {
        private const val TAG = "SmsQueueManager"
    }
    
    private val dbHelper: SmsQueueDatabase = SmsQueueDatabase(context)
    
    /**
     * Data class representing a queued SMS message
     */
    data class QueuedSms(
        val id: String,
        val hash: String,
        val sender: String,
        val content: String,
        val timestamp: Long,
        val queuedAt: Long,
        val processed: Boolean
    )
    
    /**
     * Data class for queue statistics
     */
    data class QueueStats(
        val totalQueued: Int,
        val unprocessedCount: Int,
        val processedCount: Int,
        val oldestUnprocessedAge: Long?,
        val newestUnprocessedAge: Long?
    )

    
    /**
     * Generate SHA-256 hash for deduplication.
     * Hash is based on sender, timestamp, and content.
     */
    fun generateHash(sender: String, content: String, timestamp: Long): String {
        val input = "$sender|$timestamp|$content"
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }
    
    /**
     * Queue an SMS message for later processing.
     * 
     * This method is called by SmsReceiver for EVERY SMS received.
     * Returns true if the message was queued, false if it's a duplicate.
     */
    fun queueSms(sender: String, content: String, timestamp: Long): Boolean {
        val startTime = System.currentTimeMillis()
        
        try {
            val id = UUID.randomUUID().toString()
            val hash = generateHash(sender, content, timestamp)
            val queuedAt = System.currentTimeMillis()
            
            Log.d(TAG, "Queueing SMS from $sender with hash: ${hash.take(16)}...")
            
            val db = dbHelper.writableDatabase
            val values = ContentValues().apply {
                put(SmsQueueDatabase.COLUMN_ID, id)
                put(SmsQueueDatabase.COLUMN_HASH, hash)
                put(SmsQueueDatabase.COLUMN_SENDER, sender)
                put(SmsQueueDatabase.COLUMN_CONTENT, content)
                put(SmsQueueDatabase.COLUMN_TIMESTAMP, timestamp)
                put(SmsQueueDatabase.COLUMN_QUEUED_AT, queuedAt)
                put(SmsQueueDatabase.COLUMN_PROCESSED, 0)
            }
            
            // INSERT OR IGNORE - returns -1 if duplicate (UNIQUE constraint on hash)
            val rowId = db.insertWithOnConflict(
                SmsQueueDatabase.TABLE_NAME,
                null,
                values,
                SQLiteDatabase.CONFLICT_IGNORE
            )
            
            val processingTime = System.currentTimeMillis() - startTime
            
            return if (rowId != -1L) {
                Log.i(TAG, "SMS queued successfully (id: $id) in ${processingTime}ms")
                true
            } else {
                Log.d(TAG, "Duplicate SMS detected (hash: ${hash.take(16)}...), skipping")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error queueing SMS: ${e.message}", e)
            return false
        }
    }

    
    /**
     * Get all unprocessed SMS messages ordered by timestamp.
     */
    fun getUnprocessedSms(): List<QueuedSms> {
        val messages = mutableListOf<QueuedSms>()
        
        try {
            val db = dbHelper.readableDatabase
            val cursor = db.query(
                SmsQueueDatabase.TABLE_NAME,
                null,
                "${SmsQueueDatabase.COLUMN_PROCESSED} = 0",
                null,
                null,
                null,
                "${SmsQueueDatabase.COLUMN_TIMESTAMP} ASC"
            )
            
            cursor.use {
                while (it.moveToNext()) {
                    messages.add(cursorToQueuedSms(it))
                }
            }
            
            Log.d(TAG, "Retrieved ${messages.size} unprocessed SMS messages")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting unprocessed SMS: ${e.message}", e)
        }
        
        return messages
    }
    
    /**
     * Mark a message as processed.
     */
    fun markAsProcessed(id: String): Boolean {
        try {
            val db = dbHelper.writableDatabase
            val values = ContentValues().apply {
                put(SmsQueueDatabase.COLUMN_PROCESSED, 1)
            }
            
            val rowsUpdated = db.update(
                SmsQueueDatabase.TABLE_NAME,
                values,
                "${SmsQueueDatabase.COLUMN_ID} = ?",
                arrayOf(id)
            )
            
            val success = rowsUpdated > 0
            if (success) {
                Log.d(TAG, "Marked SMS as processed: $id")
            } else {
                Log.w(TAG, "Failed to mark SMS as processed (not found): $id")
            }
            
            return success
        } catch (e: Exception) {
            Log.e(TAG, "Error marking SMS as processed: ${e.message}", e)
            return false
        }
    }

    
    /**
     * Delete unprocessed messages older than MAX_AGE_DAYS.
     */
    fun cleanupOldMessages(): Int {
        try {
            val db = dbHelper.writableDatabase
            val cutoffTime = System.currentTimeMillis() - 
                (SmsQueueDatabase.MAX_AGE_DAYS * 24 * 60 * 60 * 1000L)
            
            val deletedCount = db.delete(
                SmsQueueDatabase.TABLE_NAME,
                "${SmsQueueDatabase.COLUMN_QUEUED_AT} < ? AND ${SmsQueueDatabase.COLUMN_PROCESSED} = 0",
                arrayOf(cutoffTime.toString())
            )
            
            if (deletedCount > 0) {
                Log.i(TAG, "Cleaned up $deletedCount old unprocessed messages")
            }
            
            return deletedCount
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up old messages: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Delete processed messages older than PROCESSED_RETENTION_HOURS.
     */
    fun cleanupProcessed(): Int {
        try {
            val db = dbHelper.writableDatabase
            val cutoffTime = System.currentTimeMillis() - 
                (SmsQueueDatabase.PROCESSED_RETENTION_HOURS * 60 * 60 * 1000L)
            
            val deletedCount = db.delete(
                SmsQueueDatabase.TABLE_NAME,
                "${SmsQueueDatabase.COLUMN_QUEUED_AT} < ? AND ${SmsQueueDatabase.COLUMN_PROCESSED} = 1",
                arrayOf(cutoffTime.toString())
            )
            
            if (deletedCount > 0) {
                Log.d(TAG, "Cleaned up $deletedCount processed messages")
            }
            
            return deletedCount
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up processed messages: ${e.message}", e)
            return 0
        }
    }

    
    /**
     * Enforce queue size limit by removing oldest unprocessed messages.
     */
    fun enforceQueueLimit(): Int {
        try {
            val db = dbHelper.writableDatabase
            
            // Count unprocessed messages
            val countCursor = db.rawQuery(
                "SELECT COUNT(*) FROM ${SmsQueueDatabase.TABLE_NAME} WHERE ${SmsQueueDatabase.COLUMN_PROCESSED} = 0",
                null
            )
            
            val count = countCursor.use {
                if (it.moveToFirst()) it.getInt(0) else 0
            }
            
            if (count <= SmsQueueDatabase.MAX_QUEUE_SIZE) {
                return 0
            }
            
            val toDelete = count - SmsQueueDatabase.MAX_QUEUE_SIZE
            
            // Delete oldest unprocessed messages
            val deletedCount = db.delete(
                SmsQueueDatabase.TABLE_NAME,
                "${SmsQueueDatabase.COLUMN_ID} IN (SELECT ${SmsQueueDatabase.COLUMN_ID} FROM ${SmsQueueDatabase.TABLE_NAME} WHERE ${SmsQueueDatabase.COLUMN_PROCESSED} = 0 ORDER BY ${SmsQueueDatabase.COLUMN_TIMESTAMP} ASC LIMIT ?)",
                arrayOf(toDelete.toString())
            )
            
            if (deletedCount > 0) {
                Log.i(TAG, "Enforced queue limit: removed $deletedCount oldest messages")
            }
            
            return deletedCount
        } catch (e: Exception) {
            Log.e(TAG, "Error enforcing queue limit: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Get queue statistics.
     */
    fun getQueueStats(): QueueStats {
        try {
            val db = dbHelper.readableDatabase
            val now = System.currentTimeMillis()
            
            // Get counts
            val totalCursor = db.rawQuery(
                "SELECT COUNT(*) FROM ${SmsQueueDatabase.TABLE_NAME}",
                null
            )
            val total = totalCursor.use { if (it.moveToFirst()) it.getInt(0) else 0 }
            
            val unprocessedCursor = db.rawQuery(
                "SELECT COUNT(*) FROM ${SmsQueueDatabase.TABLE_NAME} WHERE ${SmsQueueDatabase.COLUMN_PROCESSED} = 0",
                null
            )
            val unprocessed = unprocessedCursor.use { if (it.moveToFirst()) it.getInt(0) else 0 }
            
            // Get oldest/newest unprocessed ages
            val ageCursor = db.rawQuery(
                "SELECT MIN(${SmsQueueDatabase.COLUMN_QUEUED_AT}), MAX(${SmsQueueDatabase.COLUMN_QUEUED_AT}) FROM ${SmsQueueDatabase.TABLE_NAME} WHERE ${SmsQueueDatabase.COLUMN_PROCESSED} = 0",
                null
            )
            
            var oldestAge: Long? = null
            var newestAge: Long? = null
            
            ageCursor.use {
                if (it.moveToFirst() && !it.isNull(0)) {
                    oldestAge = now - it.getLong(0)
                    newestAge = now - it.getLong(1)
                }
            }
            
            return QueueStats(
                totalQueued = total,
                unprocessedCount = unprocessed,
                processedCount = total - unprocessed,
                oldestUnprocessedAge = oldestAge,
                newestUnprocessedAge = newestAge
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting queue stats: ${e.message}", e)
            return QueueStats(0, 0, 0, null, null)
        }
    }

    
    /**
     * Convert cursor row to QueuedSms object.
     */
    private fun cursorToQueuedSms(cursor: android.database.Cursor): QueuedSms {
        return QueuedSms(
            id = cursor.getString(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_ID)),
            hash = cursor.getString(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_HASH)),
            sender = cursor.getString(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_SENDER)),
            content = cursor.getString(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_CONTENT)),
            timestamp = cursor.getLong(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_TIMESTAMP)),
            queuedAt = cursor.getLong(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_QUEUED_AT)),
            processed = cursor.getInt(cursor.getColumnIndexOrThrow(SmsQueueDatabase.COLUMN_PROCESSED)) == 1
        )
    }
    
    /**
     * Run all cleanup operations.
     */
    fun runCleanup() {
        Log.d(TAG, "Running queue cleanup...")
        val oldDeleted = cleanupOldMessages()
        val processedDeleted = cleanupProcessed()
        val limitDeleted = enforceQueueLimit()
        Log.d(TAG, "Cleanup complete: old=$oldDeleted, processed=$processedDeleted, limit=$limitDeleted")
    }
    
    /**
     * Close the database connection.
     */
    fun close() {
        dbHelper.close()
    }
}

/**
 * Extension function for QueuedSms to convert to Map for platform channel transfer.
 */
fun SmsQueueManager.QueuedSms.toMap(): Map<String, Any> {
    return mapOf(
        "id" to id,
        "hash" to hash,
        "sender" to sender,
        "content" to content,
        "timestamp" to timestamp,
        "queuedAt" to queuedAt,
        "processed" to processed
    )
}

/**
 * Extension function for QueueStats to convert to Map for platform channel transfer.
 */
fun SmsQueueManager.QueueStats.toMap(): Map<String, Any?> {
    return mapOf(
        "totalQueued" to totalQueued,
        "unprocessedCount" to unprocessedCount,
        "processedCount" to processedCount,
        "oldestUnprocessedAge" to oldestUnprocessedAge,
        "newestUnprocessedAge" to newestUnprocessedAge
    )
}
