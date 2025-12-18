import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:paylog/domain/entities/sms_message.dart';

/// Detects duplicate SMS messages using hash-based storage
/// 
/// This class generates hashes from SMS messages (sender + content + timestamp)
/// and stores them in Hive to prevent duplicate transaction records in Firestore.
class DuplicateDetector {
  static const String _boxName = 'duplicate_hashes';
  Box<int>? _hashBox;

  /// Initialize the duplicate detector with Hive storage
  /// 
  /// [path] is optional and used for testing. If not provided, uses default Hive path.
  Future<void> initialize({String? path}) async {
    if (path != null) {
      Hive.init(path);
    }
    _hashBox = await Hive.openBox<int>(_boxName);
  }

  /// Close the Hive box
  Future<void> close() async {
    await _hashBox?.close();
    _hashBox = null;
  }

  /// Generate a hash from an SMS message
  /// 
  /// Combines sender, content, and timestamp to create a unique hash
  String generateHash(SmsMessage sms) {
    return generateHashFromComponents(
      sender: sms.sender,
      content: sms.content,
      timestamp: sms.timestamp,
    );
  }

  /// Generate a hash from individual components
  /// 
  /// This allows hash generation without creating an SmsMessage object
  String generateHashFromComponents({
    required String sender,
    required String content,
    required DateTime timestamp,
  }) {
    // Combine sender, content, and timestamp (in milliseconds)
    final combined = '$sender|$content|${timestamp.millisecondsSinceEpoch}';
    
    // Generate SHA-256 hash
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Check if an SMS message is a duplicate
  /// 
  /// Returns true if the message has been processed before
  Future<bool> isSmsMessageDuplicate(SmsMessage sms) async {
    _ensureInitialized();
    final hash = generateHash(sms);
    return isDuplicate(hash);
  }

  /// Check if a hash exists in storage (is a duplicate)
  Future<bool> isDuplicate(String hash) async {
    _ensureInitialized();
    return _hashBox!.containsKey(hash);
  }

  /// Mark an SMS message as processed
  /// 
  /// Stores the hash with the current timestamp
  Future<void> markSmsAsProcessed(SmsMessage sms) async {
    _ensureInitialized();
    final hash = generateHash(sms);
    await markAsProcessed(hash);
  }

  /// Mark a hash as processed
  /// 
  /// Stores the hash with the current timestamp (in milliseconds)
  Future<void> markAsProcessed(String hash) async {
    _ensureInitialized();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _hashBox!.put(hash, timestamp);
  }

  /// Get the timestamp when a hash was processed
  /// 
  /// Returns null if the hash doesn't exist
  Future<DateTime?> getProcessedTimestamp(String hash) async {
    _ensureInitialized();
    final timestamp = _hashBox!.get(hash);
    if (timestamp == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Remove a hash from storage
  Future<void> removeHash(String hash) async {
    _ensureInitialized();
    await _hashBox!.delete(hash);
  }

  /// Clear all stored hashes
  Future<void> clearAllHashes() async {
    _ensureInitialized();
    await _hashBox!.clear();
  }

  /// Get the count of stored hashes
  Future<int> getHashCount() async {
    _ensureInitialized();
    return _hashBox!.length;
  }

  /// Cleanup old hashes beyond the specified max age
  /// 
  /// [maxAge] defaults to 90 days
  /// Returns the number of hashes removed
  Future<int> cleanupOldHashes({Duration maxAge = const Duration(days: 90)}) async {
    _ensureInitialized();
    
    final cutoffTime = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    final hashesToRemove = <String>[];
    
    // Find hashes older than cutoff time
    for (final key in _hashBox!.keys) {
      final timestamp = _hashBox!.get(key);
      if (timestamp != null && timestamp < cutoffTime) {
        hashesToRemove.add(key as String);
      }
    }
    
    // Remove old hashes
    for (final hash in hashesToRemove) {
      await _hashBox!.delete(hash);
    }
    
    return hashesToRemove.length;
  }

  /// Ensure the detector is initialized before use
  void _ensureInitialized() {
    if (_hashBox == null) {
      throw StateError('DuplicateDetector not initialized. Call initialize() first.');
    }
  }
}
