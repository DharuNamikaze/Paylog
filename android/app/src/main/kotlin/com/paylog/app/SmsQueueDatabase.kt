package com.paylog.app

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import java.security.MessageDigest
import java.util.UUID

/**
 * SQLite database for persistent SMS queue storage.
 * 
 * This database stores SMS messages when Flutter is not available,
 * ensuring no messages are lost even when the app is killed.
 * 
 * Key features:
 * - Atomic writes (no corruption on process death)
 * - UNIQUE constraint on hash for deduplication
 * - WAL mode for better concurrent performance
 * - Efficient cleanup with indexed columns
 */
class SmsQueueDatabase(context: Context) : SQLiteOpenHelper(
    context.applicationContext,
    DB_NAME,
    null,
    DB_VERSION
) {
    
    companion object {
        private const val TAG = "SmsQueueDatabase"
        
        // Database configuration
        private const val DB_NAME = "sms_queue.db"
        private const val DB_VERSION = 1
        
        // Table and column names
        const val TABLE_NAME = "sms_queue"
        const val COLUMN_ID = "id"
        const val COLUMN_HASH = "hash"
        const val COLUMN_SENDER = "sender"
        const val COLUMN_CONTENT = "content"
        const val COLUMN_TIMESTAMP = "timestamp"
        const val COLUMN_QUEUED_AT = "queued_at"
        const val COLUMN_PROCESSED = "processed"
        
        // Queue limits
        const val MAX_QUEUE_SIZE = 100
        const val MAX_AGE_DAYS = 7
        const val PROCESSED_RETENTION_HOURS = 1
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        Log.d(TAG, "Creating SMS queue database")
        
        // Create main table with UNIQUE constraint on hash for deduplication
        db.execSQL("""
            CREATE TABLE $TABLE_NAME (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_HASH TEXT UNIQUE NOT NULL,
                $COLUMN_SENDER TEXT NOT NULL,
                $COLUMN_CONTENT TEXT NOT NULL,
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_QUEUED_AT INTEGER NOT NULL,
                $COLUMN_PROCESSED INTEGER DEFAULT 0
            )
        """.trimIndent())
        
        // Create indexes for efficient queries
        db.execSQL("CREATE INDEX idx_processed ON $TABLE_NAME($COLUMN_PROCESSED)")
        db.execSQL("CREATE INDEX idx_queued_at ON $TABLE_NAME($COLUMN_QUEUED_AT)")
        db.execSQL("CREATE INDEX idx_timestamp ON $TABLE_NAME($COLUMN_TIMESTAMP)")
        
        Log.d(TAG, "SMS queue database created successfully")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        Log.d(TAG, "Upgrading database from version $oldVersion to $newVersion")
        // For now, just recreate the table on upgrade
        // In production, implement proper migration logic
        db.execSQL("DROP TABLE IF EXISTS $TABLE_NAME")
        onCreate(db)
    }
    
    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        // Enable WAL mode for better concurrent read/write performance
        db.enableWriteAheadLogging()
        Log.d(TAG, "WAL mode enabled for SMS queue database")
    }
    
    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        Log.d(TAG, "SMS queue database opened")
    }
    
    /**
     * Generates a SHA-256 hash for SMS deduplication.
     * 
     * The hash is computed from the combination of sender, timestamp, and content,
     * ensuring that identical SMS messages are detected and rejected.
     * 
     * @param sender The SMS sender address
     * @param timestamp The original SMS timestamp in milliseconds
     * @param content The SMS message content
     * @return A hex string representation of the SHA-256 hash
     */
    fun generateHash(sender: String, timestamp: Long, content: String): String {
        val input = "$sender|$timestamp|$content"
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }
}
