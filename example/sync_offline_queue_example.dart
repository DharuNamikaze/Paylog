import 'package:paylog/data/datasources/local_storage_datasource.dart';
import 'package:paylog/data/repositories/transaction_repository_impl.dart';
import 'package:paylog/domain/usecases/sync_offline_queue.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';

/// Example demonstrating the Offline Queue Sync Service
/// 
/// This example shows how to:
/// 1. Initialize the sync service
/// 2. Monitor network connectivity
/// 3. Queue transactions when offline
/// 4. Automatically sync when connection is restored
void main() async {
  // Initialize local storage
  final localStorage = LocalStorageDataSource();
  await localStorage.initialize();
  
  // Initialize repository
  final repository = TransactionRepositoryImpl();
  
  // Create sync service
  final syncService = SyncOfflineQueue(
    localStorage: localStorage,
    repository: repository,
  );
  
  // Start monitoring network connectivity
  // This will automatically sync queued transactions when connection is restored
  syncService.startMonitoring();
  
  print('Sync service started. Monitoring network connectivity...');
  
  // Example: Queue a transaction when offline
  final transaction = Transaction(
    id: 'txn_001',
    userId: 'user_123',
    amount: 1500.0,
    transactionType: TransactionType.debit,
    accountNumber: 'XXXXXX1234',
    date: '2024-12-15',
    time: '14:30:00',
    smsContent: 'Your account has been debited with Rs.1,500.00',
    senderPhoneNumber: 'HDFC-BANK',
    confidenceScore: 0.95,
    createdAt: DateTime.now(),
    syncedToFirestore: false,
    duplicateCheckHash: 'hash_001',
    isManualEntry: false,
  );
  
  // Queue transaction for later sync
  await localStorage.queueTransaction(transaction);
  print('Transaction queued for sync');
  
  // Check queue size
  final queueSize = await syncService.getQueueSize();
  print('Queue size: $queueSize');
  
  // Check connectivity status
  final hasConnection = await syncService.hasConnection();
  print('Has connection: $hasConnection');
  
  // Manually trigger sync (if needed)
  if (hasConnection) {
    print('Syncing queued transactions...');
    final syncedCount = await syncService.syncQueue();
    print('Synced $syncedCount transactions');
  }
  
  // Stop monitoring when done
  syncService.stopMonitoring();
  
  // Clean up
  await localStorage.close();
  
  print('Example completed');
}
