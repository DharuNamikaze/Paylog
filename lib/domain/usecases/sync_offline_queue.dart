import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/local_storage_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../entities/transaction.dart';

/// Use case for syncing offline queued transactions to Firestore
/// 
/// This use case monitors network connectivity and automatically syncs
/// queued transactions when connection is restored. It handles sync failures
/// by re-queuing transactions and clearing the local queue after successful sync.
class SyncOfflineQueue {
  final LocalStorageDataSource _localStorage;
  final TransactionRepositoryImpl _repository;
  final Connectivity _connectivity;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  
  SyncOfflineQueue({
    required LocalStorageDataSource localStorage,
    required TransactionRepositoryImpl repository,
    Connectivity? connectivity,
  })  : _localStorage = localStorage,
        _repository = repository,
        _connectivity = connectivity ?? Connectivity();
  
  /// Start monitoring network connectivity changes
  /// 
  /// When connection is restored, automatically syncs queued transactions
  void startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        // Check if we have any connectivity
        final hasConnection = result != ConnectivityResult.none;
        
        if (hasConnection && !_isSyncing) {
          await syncQueue();
        }
      },
    );
  }
  
  /// Stop monitoring network connectivity changes
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  /// Manually trigger sync of queued transactions
  /// 
  /// Returns the number of successfully synced transactions
  Future<int> syncQueue() async {
    // Prevent concurrent sync operations
    if (_isSyncing) {
      return 0;
    }
    
    _isSyncing = true;
    int syncedCount = 0;
    
    try {
      // Get all queued transactions
      final queuedTransactions = await _localStorage.getQueuedTransactions();
      
      if (queuedTransactions.isEmpty) {
        return 0;
      }
      
      // Track failed transactions to re-queue
      final List<Transaction> failedTransactions = [];
      
      // Attempt to sync each transaction
      for (final transaction in queuedTransactions) {
        try {
          // Save to Firestore
          await _repository.saveTransaction(transaction);
          
          // Remove from local queue on success
          await _localStorage.removeFromQueue(transaction.id);
          
          syncedCount++;
        } catch (e) {
          // Log error and add to failed list
          print('Failed to sync transaction ${transaction.id}: $e');
          failedTransactions.add(transaction);
        }
      }
      
      // Re-queue failed transactions
      for (final transaction in failedTransactions) {
        try {
          // Ensure it's still in the queue (it should be since we only remove on success)
          final isInQueue = await _localStorage.isInQueue(transaction.id);
          if (!isInQueue) {
            await _localStorage.queueTransaction(transaction);
          }
        } catch (e) {
          print('Failed to re-queue transaction ${transaction.id}: $e');
        }
      }
      
      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;
  
  /// Get the current connectivity status
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  /// Get the number of transactions waiting to be synced
  Future<int> getQueueSize() async {
    return await _localStorage.getQueueSize();
  }
  
  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
