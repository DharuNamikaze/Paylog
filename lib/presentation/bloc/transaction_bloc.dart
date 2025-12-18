import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

// Events
abstract class TransactionEvent {}

class LoadTransactions extends TransactionEvent {
  final String userId;

  LoadTransactions(this.userId);
}

class AddTransaction extends TransactionEvent {
  final Transaction transaction;

  AddTransaction(this.transaction);
}

class DeleteTransaction extends TransactionEvent {
  final String transactionId;

  DeleteTransaction(this.transactionId);
}

class RefreshTransactions extends TransactionEvent {
  final String userId;

  RefreshTransactions(this.userId);
}

// Internal events for stream updates
class _TransactionStreamUpdate extends TransactionEvent {
  final List<Transaction> transactions;

  _TransactionStreamUpdate(this.transactions);
}

class _TransactionStreamError extends TransactionEvent {
  final String error;
  final List<Transaction>? cachedTransactions;

  _TransactionStreamError({
    required this.error,
    this.cachedTransactions,
  });
}

// States
abstract class TransactionState {}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final DateTime lastUpdated;

  TransactionLoaded({
    required this.transactions,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  TransactionLoaded copyWith({
    List<Transaction>? transactions,
    DateTime? lastUpdated,
  }) {
    return TransactionLoaded(
      transactions: transactions ?? this.transactions,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class TransactionError extends TransactionState {
  final String error;
  final List<Transaction>? cachedTransactions;

  TransactionError({
    required this.error,
    this.cachedTransactions,
  });
}

// BLoC
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _transactionRepository;
  StreamSubscription<List<Transaction>>? _transactionSubscription;
  String? _currentUserId;

  TransactionBloc({
    required TransactionRepository transactionRepository,
  })  : _transactionRepository = transactionRepository,
        super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransaction>(_onAddTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
    on<RefreshTransactions>(_onRefreshTransactions);
    on<_TransactionStreamUpdate>(_onTransactionStreamUpdate);
    on<_TransactionStreamError>(_onTransactionStreamError);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      print('🔴 [TransactionBloc] LoadTransactions called for user: ${event.userId}');
      emit(TransactionLoading());
      _currentUserId = event.userId;

      // Cancel any existing subscription
      await _transactionSubscription?.cancel();
      print('🔴 [TransactionBloc] Previous subscription cancelled');

      // Subscribe to transaction stream
      print('🔴 [TransactionBloc] Subscribing to transaction stream...');
      _transactionSubscription = _transactionRepository
          .getTransactions(event.userId)
          .listen(
            (transactions) {
              print('🔴 [TransactionBloc] Received ${transactions.length} transactions from repository');
              
              if (transactions.isNotEmpty) {
                print('🔴 [TransactionBloc] Sample transaction: ${transactions.first.id}, amount: ${transactions.first.amount}');
              }
              
              // Sort transactions by date and time (most recent first)
              final sortedTransactions = List<Transaction>.from(transactions)
                ..sort((a, b) {
                  final dateComparison = b.date.compareTo(a.date);
                  if (dateComparison != 0) return dateComparison;
                  return b.time.compareTo(a.time);
                });

              print('🔴 [TransactionBloc] Sorted ${sortedTransactions.length} transactions');

              // Use add instead of emit to avoid the completion issue
              if (!isClosed) {
                print('🔴 [TransactionBloc] Emitting TransactionStreamUpdate with ${sortedTransactions.length} transactions');
                add(_TransactionStreamUpdate(sortedTransactions));
              } else {
                print('⚠️ [TransactionBloc] Bloc is closed, not emitting update');
              }
            },
            onError: (error) {
              print('❌ [TransactionBloc] Stream error: $error');
              if (!isClosed) {
                final currentTransactions = state is TransactionLoaded
                    ? (state as TransactionLoaded).transactions
                    : null;
                add(_TransactionStreamError(
                  error: 'Failed to load transactions: ${error.toString()}',
                  cachedTransactions: currentTransactions,
                ));
              }
            },
          );
      print('✅ [TransactionBloc] Stream subscription established');
    } catch (e) {
      print('❌ [TransactionBloc] LoadTransactions failed: $e');
      emit(TransactionError(
        error: 'Failed to load transactions: ${e.toString()}',
      ));
    }
  }

  Future<void> _onAddTransaction(
    AddTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Save transaction to repository
      await _transactionRepository.saveTransaction(event.transaction);

      // The stream subscription will automatically update the state
      // when the transaction is added to Firestore
    } catch (e) {
      final currentTransactions = state is TransactionLoaded
          ? (state as TransactionLoaded).transactions
          : null;
      emit(TransactionError(
        error: 'Failed to add transaction: ${e.toString()}',
        cachedTransactions: currentTransactions,
      ));
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Delete transaction from repository
      await _transactionRepository.deleteTransaction(event.transactionId);

      // The stream subscription will automatically update the state
      // when the transaction is removed from Firestore
    } catch (e) {
      final currentTransactions = state is TransactionLoaded
          ? (state as TransactionLoaded).transactions
          : null;
      emit(TransactionError(
        error: 'Failed to delete transaction: ${e.toString()}',
        cachedTransactions: currentTransactions,
      ));
    }
  }

  Future<void> _onRefreshTransactions(
    RefreshTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Sync offline queue first
      await _transactionRepository.syncOfflineQueue();

      // If we're already listening to the correct user, the stream will update automatically
      // Otherwise, reload transactions
      if (_currentUserId != event.userId) {
        add(LoadTransactions(event.userId));
      }
    } catch (e) {
      final currentTransactions = state is TransactionLoaded
          ? (state as TransactionLoaded).transactions
          : null;
      emit(TransactionError(
        error: 'Failed to refresh transactions: ${e.toString()}',
        cachedTransactions: currentTransactions,
      ));
    }
  }

  Future<void> _onTransactionStreamUpdate(
    _TransactionStreamUpdate event,
    Emitter<TransactionState> emit,
  ) async {
    print('🔴 [TransactionBloc] _onTransactionStreamUpdate called with ${event.transactions.length} transactions');
    
    if (event.transactions.isNotEmpty) {
      print('🔴 [TransactionBloc] First transaction: ${event.transactions.first.id}, amount: ${event.transactions.first.amount}');
    }
    
    emit(TransactionLoaded(transactions: event.transactions));
    print('✅ [TransactionBloc] Emitted TransactionLoaded state with ${event.transactions.length} transactions');
  }

  Future<void> _onTransactionStreamError(
    _TransactionStreamError event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionError(
      error: event.error,
      cachedTransactions: event.cachedTransactions,
    ));
  }

  @override
  Future<void> close() {
    _transactionSubscription?.cancel();
    return super.close();
  }
}
