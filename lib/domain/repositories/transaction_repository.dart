import '../entities/transaction.dart';

/// Abstract repository interface for transaction persistence
abstract class TransactionRepository {
  /// Save a transaction to the database
  /// Returns the document ID of the saved transaction
  Future<String> saveTransaction(Transaction transaction);
  
  /// Get a stream of transactions for a specific user
  /// Returns a real-time stream that updates when transactions change
  Stream<List<Transaction>> getTransactions(String userId);
  
  /// Delete a transaction by ID
  Future<void> deleteTransaction(String transactionId);
  
  /// Sync offline queued transactions to Firestore
  Future<void> syncOfflineQueue();
}
