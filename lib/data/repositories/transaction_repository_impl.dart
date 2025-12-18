import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/transaction.dart' as domain;
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_storage_datasource.dart';

/// Implementation of TransactionRepository using Firebase Firestore
class TransactionRepositoryImpl implements TransactionRepository {
  final FirebaseFirestore? _firestore;
  final LocalStorageDataSource? _localDataSource;
  final Uuid _uuid;
  
  /// Maximum number of retry attempts for failed operations
  static const int maxRetries = 3;
  
  /// Initial delay for exponential backoff (in milliseconds)
  static const int initialBackoffMs = 1000;
  
  TransactionRepositoryImpl({
    FirebaseFirestore? firestore,
    LocalStorageDataSource? localDataSource,
    Uuid? uuid,
  })  : _firestore = firestore,
        _localDataSource = localDataSource,
        _uuid = uuid ?? const Uuid();
  
  @override
  Future<String> saveTransaction(domain.Transaction transaction) async {
    // Generate unique ID if not provided
    final transactionId = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    
    // Create transaction with ID
    final transactionWithId = transaction.copyWith(
      id: transactionId,
    );
    
    try {
      // Try to save to Firestore if available
      if (_firestore != null) {
        final data = _transactionToFirestoreMap(transactionWithId.copyWith(syncedToFirestore: true));
        
        await _executeWithRetry(() async {
          await _firestore!
              .collection('users')
              .doc(transaction.userId)
              .collection('transactions')
              .doc(transactionId)
              .set(data);
        });
        
        developer.log('Transaction saved to Firestore: $transactionId', name: 'TransactionRepository');
      } else {
        developer.log('Firestore not available, saving locally only', name: 'TransactionRepository');
      }
      
      // Always save to local storage as backup
      if (_localDataSource != null) {
        await _localDataSource!.saveTransaction(transactionWithId.copyWith(
          syncedToFirestore: _firestore != null,
        ));
        developer.log('Transaction saved to local storage: $transactionId', name: 'TransactionRepository');
      }
      
    } catch (e) {
      developer.log('Error saving to Firestore, falling back to local storage: $e', name: 'TransactionRepository', error: e);
      
      // Fallback to local storage only
      if (_localDataSource != null) {
        await _localDataSource!.saveTransaction(transactionWithId.copyWith(syncedToFirestore: false));
        // Queue for later sync
        await _localDataSource!.queueTransaction(transactionWithId);
        developer.log('Transaction queued for sync: $transactionId', name: 'TransactionRepository');
      } else {
        rethrow; // If no local storage, we can't save anywhere
      }
    }
    
    return transactionId;
  }
  
  @override
  Stream<List<domain.Transaction>> getTransactions(String userId) {
    if (_firestore != null) {
      return _firestore!
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return _firestoreDocToTransaction(doc);
          } catch (e) {
            // Log error and skip malformed documents
            developer.log('Error parsing transaction ${doc.id}: $e', name: 'TransactionRepository', error: e);
            return null;
        }
      }).whereType<domain.Transaction>().toList();
    }).handleError((error) {
      // Handle stream errors
      developer.log('Error in transaction stream: $error', name: 'TransactionRepository', error: error);
      throw _handleFirestoreError(error);
    });
    } else {
      // Fallback to local storage if Firestore not available
      if (_localDataSource != null) {
        return _localDataSource!.getTransactionsStream(userId);
      } else {
        // Return empty stream if no data sources available
        return Stream.value(<domain.Transaction>[]);
      }
    }
  }
  
  @override
  Future<void> deleteTransaction(String transactionId) async {
    // Note: This requires knowing the userId, which should be passed
    // For now, this is a placeholder that would need userId context
    throw UnimplementedError(
      'deleteTransaction requires userId context. '
      'Consider adding userId parameter or using a different approach.',
    );
  }
  
  @override
  Future<void> syncOfflineQueue() async {
    try {
      // Check if we have network connectivity
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        developer.log('No network connectivity - skipping sync', name: 'TransactionRepository');
        return;
      }

      // Get queued transactions from local storage
      if (_localDataSource == null) {
        developer.log('Local data source not available for sync', name: 'TransactionRepository');
        return;
      }
      
      final queuedTransactions = await _localDataSource!.getQueuedTransactions();
      
      if (queuedTransactions.isEmpty) {
        developer.log('No transactions to sync', name: 'TransactionRepository');
        return;
      }

      developer.log('Syncing ${queuedTransactions.length} queued transactions', name: 'TransactionRepository');
      
      int syncedCount = 0;
      final List<domain.Transaction> failedTransactions = [];

      // Attempt to sync each transaction
      for (final transaction in queuedTransactions) {
        try {
          // Only sync to Firestore if available
          if (_firestore != null) {
            final data = _transactionToFirestoreMap(transaction.copyWith(syncedToFirestore: true));
            await _firestore!
                .collection('users')
                .doc(transaction.userId)
                .collection('transactions')
                .doc(transaction.id)
                .set(data);
            developer.log('Synced transaction ${transaction.id} to Firestore', name: 'TransactionRepository');
          }
          
          // Remove from local queue on success
          await _localDataSource!.removeFromQueue(transaction.id);
          syncedCount++;
          
        } catch (e) {
          developer.log('Failed to sync transaction ${transaction.id}: $e', name: 'TransactionRepository', error: e);
          failedTransactions.add(transaction);
        }
      }

      developer.log('Sync completed: $syncedCount synced, ${failedTransactions.length} failed', name: 'TransactionRepository');
      
    } catch (e, stackTrace) {
      developer.log('Error during sync: $e', name: 'TransactionRepository', error: e, stackTrace: stackTrace);
      // Don't throw - sync failures shouldn't crash the app
    }
  }
  
  /// Execute a function with exponential backoff retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;
    
    while (true) {
      try {
        return await operation();
      } catch (error) {
        attempt++;
        
        // If we've exhausted retries, throw the error
        if (attempt >= maxRetries) {
          throw _handleFirestoreError(error);
        }
        
        // Calculate exponential backoff delay
        final delayMs = initialBackoffMs * (1 << (attempt - 1));
        
        // Check if error is retryable
        if (!_isRetryableError(error)) {
          throw _handleFirestoreError(error);
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
  
  /// Check if an error is retryable
  bool _isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      // Retry on network errors, unavailable, deadline exceeded
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'resource-exhausted' ||
          error.message?.contains('network') == true;
    }
    return false;
  }
  
  /// Handle Firestore errors and convert to meaningful exceptions
  Exception _handleFirestoreError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return Exception(
            'Permission denied: User does not have access to this resource',
          );
        case 'unauthenticated':
          return Exception(
            'Authentication required: User must be signed in',
          );
        case 'not-found':
          return Exception('Resource not found');
        case 'already-exists':
          return Exception('Resource already exists');
        case 'resource-exhausted':
          return Exception(
            'Quota exceeded: Too many requests. Please try again later.',
          );
        case 'unavailable':
          return Exception(
            'Service unavailable: Please check your connection and try again',
          );
        default:
          return Exception('Firestore error: ${error.message}');
      }
    }
    return Exception('Unknown error: $error');
  }
  
  /// Convert Transaction to Firestore map
  Map<String, dynamic> _transactionToFirestoreMap(domain.Transaction transaction) {
    return {
      'amount': transaction.amount,
      'transactionType': transaction.transactionType.toJson(),
      'accountNumber': transaction.accountNumber,
      'date': transaction.date,
      'time': transaction.time,
      'smsContent': transaction.smsContent,
      'senderPhoneNumber': transaction.senderPhoneNumber,
      'confidenceScore': transaction.confidenceScore,
      'createdAt': Timestamp.fromDate(transaction.createdAt),
      'syncedToFirestore': transaction.syncedToFirestore,
      'duplicateCheckHash': transaction.duplicateCheckHash,
      'isManualEntry': transaction.isManualEntry,
      'timestamp': transaction.createdAt.millisecondsSinceEpoch,
    };
  }
  
  /// Convert Firestore document to Transaction
  domain.Transaction _firestoreDocToTransaction(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle createdAt conversion
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    } else {
      createdAt = DateTime.now();
    }
    
    return domain.Transaction(
      id: doc.id,
      userId: doc.reference.parent.parent!.id,
      amount: (data['amount'] as num).toDouble(),
      transactionType: TransactionType.fromJson(data['transactionType'] as String),
      accountNumber: data['accountNumber'] as String?,
      date: data['date'] as String,
      time: data['time'] as String,
      smsContent: data['smsContent'] as String,
      senderPhoneNumber: data['senderPhoneNumber'] as String,
      confidenceScore: (data['confidenceScore'] as num).toDouble(),
      createdAt: createdAt,
      syncedToFirestore: data['syncedToFirestore'] as bool? ?? true,
      duplicateCheckHash: data['duplicateCheckHash'] as String,
      isManualEntry: data['isManualEntry'] as bool? ?? false,
    );
  }
}
