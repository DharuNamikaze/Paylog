import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_storage_datasource.dart';

/// Local-only transaction repository that stores transactions in Hive
/// 
/// This repository provides the same interface as the Firebase repository
/// but stores all data locally using Hive. Perfect for offline-first usage
/// or when Firebase is not configured.
class LocalTransactionRepository implements TransactionRepository {
  final LocalStorageDataSource localStorage;
  final Uuid uuid;

  LocalTransactionRepository({
    required this.localStorage,
    required this.uuid,
  });

  @override
  Future<String> saveTransaction(Transaction transaction) async {
    try {
      // Generate ID if not provided
      final transactionId = transaction.id ?? uuid.v4();
      
      // Create transaction with correct constructor
      final transactionWithId = Transaction(
        id: transactionId,
        userId: transaction.userId,
        createdAt: transaction.createdAt,
        syncedToFirestore: false, // Local only, not synced
        duplicateCheckHash: transaction.duplicateCheckHash,
        isManualEntry: transaction.isManualEntry,
        amount: transaction.amount,
        transactionType: transaction.transactionType,
        accountNumber: transaction.accountNumber,
        date: transaction.date,
        time: transaction.time,
        smsContent: transaction.smsContent,
        senderPhoneNumber: transaction.senderPhoneNumber,
        confidenceScore: transaction.confidenceScore,
      );

      // Save to local storage using queue method
      await localStorage.queueTransaction(transactionWithId);
      
      return transactionId;
    } catch (e) {
      throw Exception('Failed to save transaction locally: $e');
    }
  }

  @override
  Stream<List<Transaction>> getTransactions(String userId) {
    try {
      // Convert Future to Stream for compatibility
      return Stream.fromFuture(localStorage.getCachedTransactions());
    } catch (e) {
      throw Exception('Failed to get transactions from local storage: $e');
    }
  }

  Future<List<Transaction>> getTransactionsList(String userId) async {
    try {
      return await localStorage.getCachedTransactions();
    } catch (e) {
      throw Exception('Failed to get transactions list from local storage: $e');
    }
  }

  Future<Transaction?> getTransaction(String transactionId) async {
    try {
      final transactions = await localStorage.getCachedTransactions();
      return transactions.firstWhere(
        (t) => t.id == transactionId,
        orElse: () => throw StateError('Transaction not found'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await localStorage.removeFromQueue(transactionId);
    } catch (e) {
      throw Exception('Failed to delete transaction from local storage: $e');
    }
  }

  @override
  Future<void> syncOfflineQueue() async {
    // For local-only repository, this is a no-op
    // In a real implementation, this would sync to a remote server
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      // For local storage, we'll delete and re-add
      await localStorage.removeFromQueue(transaction.id!);
      await localStorage.queueTransaction(transaction);
    } catch (e) {
      throw Exception('Failed to update transaction in local storage: $e');
    }
  }

  /// Get transactions count for a user
  Future<int> getTransactionCount(String userId) async {
    try {
      final transactions = await getTransactionsList(userId);
      return transactions.length;
    } catch (e) {
      throw Exception('Failed to get transaction count: $e');
    }
  }

  /// Clear all transactions for a user (useful for testing)
  Future<void> clearUserTransactions(String userId) async {
    try {
      final transactions = await getTransactionsList(userId);
      for (final transaction in transactions) {
        if (transaction.id != null) {
          await deleteTransaction(transaction.id!);
        }
      }
    } catch (e) {
      throw Exception('Failed to clear user transactions: $e');
    }
  }

  /// Get transactions within a date range
  Future<List<Transaction>> getTransactionsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allTransactions = await getTransactionsList(userId);
      
      return allTransactions.where((transaction) {
        try {
          final transactionDate = DateTime.parse(transaction.date);
          return transactionDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 transactionDate.isBefore(endDate.add(const Duration(days: 1)));
        } catch (e) {
          // If date parsing fails, exclude the transaction
          return false;
        }
      }).toList();
    } catch (e) {
      throw Exception('Failed to get transactions in date range: $e');
    }
  }

  /// Get recent transactions (last N transactions)
  Future<List<Transaction>> getRecentTransactions(String userId, {int limit = 10}) async {
    try {
      final allTransactions = await getTransactionsList(userId);
      
      // Sort by creation date (most recent first)
      allTransactions.sort((a, b) {
        try {
          return b.createdAt.compareTo(a.createdAt);
        } catch (e) {
          return 0;
        }
      });
      
      return allTransactions.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get recent transactions: $e');
    }
  }
}