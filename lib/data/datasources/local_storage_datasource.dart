import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/transaction.dart';

/// Local storage datasource using Hive for offline queue and caching
class LocalStorageDataSource {
  static const String _queueBoxName = 'transaction_queue';
  static const String _cacheBoxName = 'transaction_cache';
  static const String _metadataBoxName = 'metadata';
  
  Box<Map>? _queueBox;
  Box<Map>? _cacheBox;
  Box<dynamic>? _metadataBox;
  
  /// Initialize Hive and open boxes
  /// If [path] is provided, Hive will be initialized with that path (useful for testing)
  Future<void> initialize({String? path}) async {
    // Initialize Hive (skip if already initialized)
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }
    
    // Open boxes (encryption can be added here if needed)
    _queueBox = await Hive.openBox<Map>(_queueBoxName);
    _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
    _metadataBox = await Hive.openBox(_metadataBoxName);
  }
  
  /// Queue a transaction for later sync to Firestore
  Future<void> queueTransaction(Transaction transaction) async {
    _ensureInitialized();
    
    final transactionJson = transaction.toJson();
    await _queueBox!.put(transaction.id, transactionJson);
  }
  
  /// Get all queued transactions waiting to be synced
  Future<List<Transaction>> getQueuedTransactions() async {
    _ensureInitialized();
    
    final transactions = <Transaction>[];
    
    for (var key in _queueBox!.keys) {
      try {
        final json = _queueBox!.get(key);
        if (json != null) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final jsonMap = Map<String, dynamic>.from(json);
          transactions.add(Transaction.fromJson(jsonMap));
        }
      } catch (e) {
        // Log error but continue processing other transactions
        print('Error deserializing queued transaction: $e');
      }
    }
    
    return transactions;
  }
  
  /// Remove a transaction from the queue after successful sync
  Future<void> removeFromQueue(String transactionId) async {
    _ensureInitialized();
    
    await _queueBox!.delete(transactionId);
  }
  
  /// Cache transactions for local access
  Future<void> cacheTransactions(List<Transaction> transactions) async {
    _ensureInitialized();
    
    // Clear existing cache
    await _cacheBox!.clear();
    
    // Add new transactions to cache
    for (var transaction in transactions) {
      final transactionJson = transaction.toJson();
      await _cacheBox!.put(transaction.id, transactionJson);
    }
    
    // Update cache timestamp
    await _metadataBox!.put('last_cache_update', DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Get cached transactions
  Future<List<Transaction>> getCachedTransactions() async {
    _ensureInitialized();
    
    final transactions = <Transaction>[];
    
    for (var key in _cacheBox!.keys) {
      try {
        final json = _cacheBox!.get(key);
        if (json != null) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final jsonMap = Map<String, dynamic>.from(json);
          transactions.add(Transaction.fromJson(jsonMap));
        }
      } catch (e) {
        // Log error but continue processing other transactions
        print('Error deserializing cached transaction: $e');
      }
    }
    
    // Sort by createdAt descending (most recent first)
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return transactions;
  }
  
  /// Get the timestamp of the last cache update
  Future<DateTime?> getLastCacheUpdate() async {
    _ensureInitialized();
    
    final timestamp = _metadataBox!.get('last_cache_update');
    if (timestamp != null && timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }
  
  /// Check if a transaction exists in the queue
  Future<bool> isInQueue(String transactionId) async {
    _ensureInitialized();
    
    return _queueBox!.containsKey(transactionId);
  }
  
  /// Get the number of transactions in the queue
  Future<int> getQueueSize() async {
    _ensureInitialized();
    
    return _queueBox!.length;
  }
  
  /// Clear all queued transactions (use with caution)
  Future<void> clearQueue() async {
    _ensureInitialized();
    
    await _queueBox!.clear();
  }
  
  /// Clear all cached transactions
  Future<void> clearCache() async {
    _ensureInitialized();
    
    await _cacheBox!.clear();
    await _metadataBox!.delete('last_cache_update');
  }
  
  /// Close all Hive boxes
  Future<void> close() async {
    await _queueBox?.close();
    await _cacheBox?.close();
    await _metadataBox?.close();
  }
  
  /// Ensure Hive is initialized before operations
  void _ensureInitialized() {
    if (_queueBox == null || _cacheBox == null || _metadataBox == null) {
      throw StateError(
        'LocalStorageDataSource not initialized. Call initialize() first.',
      );
    }
  }
}
