import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/datasources/local_storage_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart' as domain;
import '../utils/transaction_hash.dart';
import 'auth_service.dart';
import 'connectivity_monitor.dart';

/// Sync state enum representing the current state of the sync engine
/// 
/// State Machine Transitions:
/// | From     | To       | Condition                    |
/// |----------|----------|------------------------------|
/// | idle     | syncing  | triggerSync & online         |
/// | syncing  | idle     | queue empty (success)        |
/// | syncing  | paused   | connectivity lost            |
/// | syncing  | error    | fatal error (auth/quota)     |
/// | paused   | syncing  | connectivity restored        |
/// | paused   | idle     | manual cancel                |
/// | error    | idle     | manual retry or app resume   |
enum SyncState {
  /// No sync operation in progress
  idle,
  /// Sync operation is currently running
  syncing,
  /// Sync was paused due to connectivity loss
  paused,
  /// Sync encountered a fatal error
  error,
}

/// Status information for sync operations
class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncStatus({
    required this.state,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncStatus copyWith({
    SyncState? state,
    int? pendingCount,
    int? syncedCount,
    int? failedCount,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      failedCount: failedCount ?? this.failedCount,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  String toString() {
    return 'SyncStatus(state: $state, pending: $pendingCount, synced: $syncedCount, failed: $failedCount)';
  }
}

/// Result of a sync operation
class SyncResult {
  final int successCount;
  final int failureCount;
  final List<SyncError> errors;
  final bool wasInterrupted;

  const SyncResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    this.wasInterrupted = false,
  });

  @override
  String toString() {
    return 'SyncResult(success: $successCount, failed: $failureCount, interrupted: $wasInterrupted)';
  }
}

/// Error information for a failed sync operation
class SyncError {
  final String transactionId;
  final String errorMessage;
  final bool isRetryable;

  const SyncError({
    required this.transactionId,
    required this.errorMessage,
    required this.isRetryable,
  });

  @override
  String toString() {
    return 'SyncError(id: $transactionId, retryable: $isRetryable, message: $errorMessage)';
  }
}

/// Error type classification for sync errors
/// 
/// Requirements: 6.1, 6.4
enum SyncErrorType {
  /// Network timeout or connection error - retryable with backoff
  network,
  /// Firestore unavailable - retryable with backoff
  unavailable,
  /// Permission denied - not retryable, requires re-auth
  permissionDenied,
  /// Unauthenticated - not retryable, requires re-auth
  unauthenticated,
  /// Invalid data - not retryable, skip transaction
  invalidData,
  /// Quota exceeded - hard pause required
  quotaExceeded,
  /// Unknown error - default to retryable
  unknown,
}


/// Queued transaction with retry metadata
class QueuedTransaction {
  final domain.Transaction transaction;
  final int retryCount;
  final DateTime queuedAt;
  final DateTime? lastAttemptAt;
  final String? lastError;

  const QueuedTransaction({
    required this.transaction,
    this.retryCount = 0,
    required this.queuedAt,
    this.lastAttemptAt,
    this.lastError,
  });

  bool get canRetry => retryCount < CloudSyncService.maxRetries;

  Duration get backoffDuration {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, capped at 32s
    final seconds = min(1 << retryCount, 32);
    // Add jitter to prevent thundering herd
    final jitter = Random().nextInt(1000);
    return Duration(seconds: seconds, milliseconds: jitter);
  }

  QueuedTransaction copyWith({
    domain.Transaction? transaction,
    int? retryCount,
    DateTime? queuedAt,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return QueuedTransaction(
      transaction: transaction ?? this.transaction,
      retryCount: retryCount ?? this.retryCount,
      queuedAt: queuedAt ?? this.queuedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Service responsible for coordinating transaction sync between local storage and Firestore
/// 
/// This service manages the sync lifecycle including:
/// - Event-driven sync triggers (app start, resume, connectivity change)
/// - Queue management with deduplication
/// - Retry logic with exponential backoff
/// - State machine for sync status
/// 
/// Requirements: 1.1, 1.4, 2.1, 2.3, 2.4, 4.1, 4.3, 6.1, 6.2, 6.3, 6.4
class CloudSyncService {
  final LocalStorageDataSource localStorage;
  final TransactionRepositoryImpl? firestoreRepo;
  final AuthService authService;
  final ConnectivityMonitor connectivityMonitor;
  final FirebaseFirestore? firestore;

  /// Maximum retry attempts per transaction
  static const int maxRetries = 5;

  /// Current sync state
  SyncState _syncState = SyncState.idle;

  /// Stream controller for sync status updates
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  /// Current sync status
  SyncStatus _currentStatus = const SyncStatus(state: SyncState.idle);

  /// Subscription to connectivity changes
  StreamSubscription<ConnectivityState>? _connectivitySubscription;

  /// Whether the service has been initialized
  bool _isInitialized = false;

  /// Track the previous connectivity state for offline→online detection
  ConnectivityState _previousConnectivityState = ConnectivityState.offline;

  /// Whether sync is hard paused (quota exceeded)
  /// Requires manual trigger or app resume to restart
  bool _isHardPaused = false;

  /// Index of the next transaction to process (for resume after pause)
  int _nextTransactionIndex = 0;

  /// Creates a CloudSyncService instance
  CloudSyncService({
    required this.localStorage,
    this.firestoreRepo,
    required this.authService,
    required this.connectivityMonitor,
    this.firestore,
  });


  /// Initialize and start monitoring for sync triggers
  /// 
  /// Requirements: 1.2, 1.4
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔄 CloudSyncService: Initializing...');

    // Get initial connectivity state
    _previousConnectivityState = await connectivityMonitor.currentState;

    // Subscribe to connectivity changes for auto-trigger
    _connectivitySubscription = connectivityMonitor.connectivityStream.listen(
      _handleConnectivityChange,
      onError: (error) {
        debugPrint('❌ CloudSyncService: Connectivity stream error: $error');
      },
    );

    // Update initial pending count
    final pendingCount = await getPendingCount();
    _updateStatus(_currentStatus.copyWith(pendingCount: pendingCount));

    _isInitialized = true;
    debugPrint('✅ CloudSyncService: Initialized with $pendingCount pending transactions');

    // Trigger initial sync if online
    if (await connectivityMonitor.isOnline) {
      debugPrint('🔄 CloudSyncService: Online at startup, triggering initial sync');
      triggerSync();
    }
  }

  /// Handle connectivity state changes
  /// 
  /// Requirements: 1.4, 5.2, 5.3
  void _handleConnectivityChange(ConnectivityState newState) {
    debugPrint('🔄 CloudSyncService: Connectivity changed from $_previousConnectivityState to $newState');

    final wasOffline = _previousConnectivityState == ConnectivityState.offline;
    final isNowOnline = newState != ConnectivityState.offline;

    // Check for offline → online transition
    if (wasOffline && isNowOnline) {
      debugPrint('🔄 CloudSyncService: Connectivity restored, triggering sync');
      
      // If we were paused (not hard paused), resume syncing
      if (_syncState == SyncState.paused && !_isHardPaused) {
        _transitionTo(SyncState.syncing);
        triggerSync();
      } else if (_syncState == SyncState.idle && !_isHardPaused) {
        triggerSync();
      }
    }

    // Check for online → offline transition
    if (!wasOffline && !isNowOnline) {
      debugPrint('⚠️ CloudSyncService: Connectivity lost');
      
      // If we were syncing, pause (Requirements: 5.3)
      if (_syncState == SyncState.syncing) {
        _transitionTo(SyncState.paused);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.paused,
          errorMessage: 'Sync paused: No network connection',
        ));
      }
    }

    _previousConnectivityState = newState;
  }

  /// Validate and perform state transition
  /// 
  /// Returns true if transition is valid and was performed
  /// Requirements: 4.3
  bool _transitionTo(SyncState newState) {
    if (!_validateStateTransition(_syncState, newState)) {
      debugPrint('⚠️ CloudSyncService: Invalid state transition from $_syncState to $newState');
      return false;
    }

    debugPrint('🔄 CloudSyncService: State transition: $_syncState → $newState');
    _syncState = newState;
    return true;
  }

  /// Validate if a state transition is allowed
  /// 
  /// State Machine Rules:
  /// | From     | To       | Condition                    |
  /// |----------|----------|------------------------------|
  /// | idle     | syncing  | triggerSync & online         |
  /// | syncing  | idle     | queue empty (success)        |
  /// | syncing  | paused   | connectivity lost            |
  /// | syncing  | error    | fatal error (auth/quota)     |
  /// | paused   | syncing  | connectivity restored        |
  /// | paused   | idle     | manual cancel                |
  /// | error    | idle     | manual retry or app resume   |
  bool _validateStateTransition(SyncState from, SyncState to) {
    // Same state is always valid (no-op)
    if (from == to) return true;

    switch (from) {
      case SyncState.idle:
        // idle can only go to syncing
        return to == SyncState.syncing;
      
      case SyncState.syncing:
        // syncing can go to idle, paused, or error
        return to == SyncState.idle || 
               to == SyncState.paused || 
               to == SyncState.error;
      
      case SyncState.paused:
        // paused can go to syncing or idle
        return to == SyncState.syncing || to == SyncState.idle;
      
      case SyncState.error:
        // error can only go to idle (must reset before syncing again)
        return to == SyncState.idle;
    }
  }

  /// Update and broadcast sync status
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    debugPrint('📊 CloudSyncService: Status updated: $status');
  }

  /// Get current sync status stream for UI updates
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Get current sync status
  SyncStatus get currentStatus => _currentStatus;

  /// Get current sync state
  SyncState get syncState => _syncState;


  // ============================================================
  // Queue Management Methods (Requirements: 2.1, 2.3, 2.4)
  // ============================================================

  /// Queue a transaction for sync
  /// 
  /// Performs deduplication check to prevent duplicate entries.
  /// Requirements: 2.1, 2.4
  Future<void> queueForSync(domain.Transaction transaction) async {
    // Check if already in queue (deduplication)
    final isAlreadyQueued = await localStorage.isInQueue(transaction.id);
    
    if (isAlreadyQueued) {
      debugPrint('⚠️ CloudSyncService: Transaction ${transaction.id} already in queue, skipping');
      return;
    }

    // Add to queue
    await localStorage.queueTransaction(transaction);
    debugPrint('✅ CloudSyncService: Transaction ${transaction.id} queued for sync');

    // Update pending count
    final pendingCount = await getPendingCount();
    _updateStatus(_currentStatus.copyWith(pendingCount: pendingCount));
  }

  /// Get the number of transactions pending sync
  /// 
  /// Requirements: 2.3
  Future<int> getPendingCount() async {
    return await localStorage.getQueueSize();
  }

  /// Get all queued transactions sorted by createdAt (oldest first)
  /// 
  /// Requirements: 1.7
  Future<List<domain.Transaction>> _getQueuedTransactionsSorted() async {
    final transactions = await localStorage.getQueuedTransactions();
    
    // Sort by createdAt ascending (oldest first)
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    return transactions;
  }

  // ============================================================
  // Sync Trigger Logic (Requirements: 1.2, 1.3, 1.4, 4.1)
  // ============================================================

  /// Trigger sync operation (called on app start, resume, connectivity change)
  /// 
  /// Guards:
  /// - Must be online
  /// - Must not already be syncing
  /// 
  /// Requirements: 1.2, 1.3, 1.4
  Future<SyncResult> triggerSync() async {
    debugPrint('🔄 CloudSyncService: triggerSync() called');

    // Guard: Check if online
    final isOnline = await connectivityMonitor.isOnline;
    if (!isOnline) {
      debugPrint('⚠️ CloudSyncService: Cannot sync - offline');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    // Guard: Check if already syncing (prevent concurrent syncs)
    if (_syncState == SyncState.syncing) {
      debugPrint('⚠️ CloudSyncService: Cannot sync - already syncing');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    // Guard: Check if Firestore is available (must check before auth)
    // If Firestore is not available, we're in local-only mode - silently skip
    if (firestore == null) {
      debugPrint('ℹ️ CloudSyncService: Sync skipped - running in local-only mode (no Firestore)');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    // Guard: Check if authenticated
    // If auth is in local-only mode, silently skip (not an error)
    if (authService.isLocalOnlyMode) {
      debugPrint('ℹ️ CloudSyncService: Sync skipped - auth is in local-only mode');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    if (!authService.isAuthenticated) {
      debugPrint('⚠️ CloudSyncService: Cannot sync - not authenticated');
      _updateStatus(_currentStatus.copyWith(
        state: SyncState.error,
        errorMessage: 'Not authenticated',
      ));
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [SyncError(
          transactionId: '',
          errorMessage: 'Not authenticated',
          isRetryable: false,
        )],
        wasInterrupted: false,
      );
    }

    // Guard: Check if Firestore repo is available
    if (firestoreRepo == null) {
      debugPrint('⚠️ CloudSyncService: Cannot sync - Firestore repo not available (local-only mode)');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    // Transition to syncing state
    if (!_transitionTo(SyncState.syncing)) {
      debugPrint('⚠️ CloudSyncService: Cannot transition to syncing state');
      return const SyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
        wasInterrupted: false,
      );
    }

    // Perform sync
    return await _performSync();
  }

  /// Manual sync triggered by user
  /// 
  /// Requirements: 4.1, 6.1 (quota handling - resume on manual trigger)
  Future<SyncResult> manualSync() async {
    debugPrint('🔄 CloudSyncService: manualSync() called by user');

    // Reset hard pause on manual sync (Requirements: 6.1 - quota handling)
    if (_isHardPaused) {
      debugPrint('🔄 CloudSyncService: Resetting hard pause on manual sync');
      _isHardPaused = false;
      _nextTransactionIndex = 0;
    }

    // If in error state, reset to idle first
    if (_syncState == SyncState.error) {
      _transitionTo(SyncState.idle);
    }

    return await triggerSync();
  }

  /// Called when app resumes from background
  /// 
  /// Resets hard pause and triggers sync if online
  /// Requirements: 1.3, 6.1 (quota handling - resume on app resume)
  Future<SyncResult> onAppResume() async {
    debugPrint('🔄 CloudSyncService: onAppResume() called');

    // Reset hard pause on app resume (Requirements: 6.1 - quota handling)
    if (_isHardPaused) {
      debugPrint('🔄 CloudSyncService: Resetting hard pause on app resume');
      _isHardPaused = false;
      _nextTransactionIndex = 0;
    }

    // If in error state, reset to idle first
    if (_syncState == SyncState.error) {
      _transitionTo(SyncState.idle);
    }

    return await triggerSync();
  }

  /// Check if sync is hard paused (quota exceeded)
  bool get isHardPaused => _isHardPaused;


  /// Perform the actual sync operation
  /// 
  /// This is the core sync logic that processes queued transactions.
  /// - Uploads transactions to Firestore using transaction hash as document ID
  /// - Uses path `/users/{uid}/transactions/{hash}`
  /// - Uses `set(..., SetOptions(merge: true))` for upserts
  /// - Processes transactions in chronological order (oldest first)
  /// - Updates local syncedToFirestore flag on success
  /// - Removes transaction from queue on success
  /// - Implements exponential backoff retry on retryable errors
  /// - Marks transactions as permanently failed after max retries
  /// - Handles permission errors without retry
  /// - Hard pauses on quota exceeded
  /// 
  /// Requirements: 1.5, 1.6, 1.7, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 7.4
  Future<SyncResult> _performSync() async {
    debugPrint('🔄 CloudSyncService: Starting sync operation');

    int successCount = 0;
    int failureCount = 0;
    final List<SyncError> errors = [];
    bool wasInterrupted = false;

    try {
      // Get queued transactions sorted by createdAt (oldest first)
      // Only get retryable transactions (not permanently failed)
      // Requirements: 1.7 - Chronological processing order
      final transactions = await _getQueuedTransactionsSorted();
      
      if (transactions.isEmpty) {
        debugPrint('✅ CloudSyncService: No transactions to sync');
        _transitionTo(SyncState.idle);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.idle,
          pendingCount: 0,
          lastSyncTime: DateTime.now(),
        ));
        return const SyncResult(
          successCount: 0,
          failureCount: 0,
          errors: [],
          wasInterrupted: false,
        );
      }

      // Filter out permanently failed transactions
      final retryableTransactions = <domain.Transaction>[];
      for (final transaction in transactions) {
        final isPermanentFailed = await localStorage.isPermanentlyFailed(transaction.id);
        if (!isPermanentFailed) {
          retryableTransactions.add(transaction);
        }
      }

      if (retryableTransactions.isEmpty) {
        debugPrint('✅ CloudSyncService: No retryable transactions to sync');
        _transitionTo(SyncState.idle);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.idle,
          pendingCount: await getPendingCount(),
          lastSyncTime: DateTime.now(),
        ));
        return const SyncResult(
          successCount: 0,
          failureCount: 0,
          errors: [],
          wasInterrupted: false,
        );
      }

      debugPrint('🔄 CloudSyncService: Processing ${retryableTransactions.length} transactions');

      _updateStatus(_currentStatus.copyWith(
        state: SyncState.syncing,
        pendingCount: retryableTransactions.length,
      ));

      // Get the current user ID for Firestore path
      final uid = authService.currentUid;
      if (uid == null) {
        debugPrint('❌ CloudSyncService: Cannot sync - no authenticated user');
        _transitionTo(SyncState.error);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.error,
          errorMessage: 'Not authenticated',
        ));
        return const SyncResult(
          successCount: 0,
          failureCount: 0,
          errors: [SyncError(
            transactionId: '',
            errorMessage: 'Not authenticated',
            isRetryable: false,
          )],
          wasInterrupted: false,
        );
      }

      // Resume from the next transaction index if we were paused
      final startIndex = _nextTransactionIndex;
      _nextTransactionIndex = 0;

      // Process each transaction in chronological order (oldest first)
      for (int i = startIndex; i < retryableTransactions.length; i++) {
        final transaction = retryableTransactions[i];

        // Check if we should stop (connectivity lost or state changed)
        if (_syncState != SyncState.syncing) {
          debugPrint('⚠️ CloudSyncService: Sync interrupted - state changed to $_syncState');
          _nextTransactionIndex = i; // Save position for resume
          wasInterrupted = true;
          break;
        }

        // Check connectivity (Requirements: 5.3)
        final isOnline = await connectivityMonitor.isOnline;
        if (!isOnline) {
          debugPrint('⚠️ CloudSyncService: Sync interrupted - connectivity lost');
          _transitionTo(SyncState.paused);
          _nextTransactionIndex = i; // Save position for resume
          wasInterrupted = true;
          _updateStatus(_currentStatus.copyWith(
            state: SyncState.paused,
            errorMessage: 'Sync paused: No network connection',
          ));
          break;
        }

        // Check if hard paused (quota exceeded)
        if (_isHardPaused) {
          debugPrint('⚠️ CloudSyncService: Sync hard paused - quota exceeded');
          _nextTransactionIndex = i; // Save position for resume
          wasInterrupted = true;
          break;
        }

        // Check retry count and apply backoff if needed
        final retryCount = await localStorage.getRetryCount(transaction.id);
        if (retryCount > 0) {
          // Calculate backoff duration
          final backoffDuration = _calculateBackoff(retryCount);
          debugPrint('⏳ CloudSyncService: Waiting ${backoffDuration.inSeconds}s backoff for transaction ${transaction.id} (retry $retryCount)');
          await Future.delayed(backoffDuration);
        }

        try {
          // Upload transaction to Firestore
          await _uploadTransactionToFirestore(transaction, uid);
          
          // Success: Update local flag, remove from queue, clear retry metadata
          // Requirements: 1.5 - Successful upload handling
          await localStorage.updateSyncedFlag(transaction.id, true);
          await localStorage.removeFromQueue(transaction.id);
          await localStorage.clearRetryMetadata(transaction.id);
          
          successCount++;
          debugPrint('✅ CloudSyncService: Uploaded transaction ${transaction.id}');

        } catch (e) {
          // Classify the error
          final errorType = _classifyError(e);
          debugPrint('❌ CloudSyncService: Failed to upload transaction ${transaction.id}: $e (type: $errorType)');

          // Handle based on error type
          final handleResult = await _handleSyncError(transaction, e, errorType);
          
          if (handleResult.shouldStop) {
            wasInterrupted = true;
            _nextTransactionIndex = i + 1; // Resume from next transaction
            
            errors.add(SyncError(
              transactionId: transaction.id,
              errorMessage: e.toString(),
              isRetryable: handleResult.isRetryable,
            ));
            
            if (handleResult.isPermanentlyFailed) {
              failureCount++;
            }
            
            break;
          }
          
          if (handleResult.isPermanentlyFailed) {
            failureCount++;
          }
          
          errors.add(SyncError(
            transactionId: transaction.id,
            errorMessage: e.toString(),
            isRetryable: handleResult.isRetryable,
          ));
        }

        // Update status
        final remainingCount = await getPendingCount();
        _updateStatus(_currentStatus.copyWith(
          pendingCount: remainingCount,
          syncedCount: successCount,
          failedCount: failureCount,
        ));
      }

      // Sync completed
      if (!wasInterrupted) {
        _transitionTo(SyncState.idle);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.idle,
          pendingCount: await getPendingCount(),
          syncedCount: successCount,
          failedCount: failureCount,
          lastSyncTime: DateTime.now(),
        ));
        debugPrint('✅ CloudSyncService: Sync completed - $successCount success, $failureCount failed');
      }

    } catch (e) {
      debugPrint('❌ CloudSyncService: Sync error: $e');
      _transitionTo(SyncState.error);
      _updateStatus(_currentStatus.copyWith(
        state: SyncState.error,
        errorMessage: e.toString(),
      ));
      errors.add(SyncError(
        transactionId: '',
        errorMessage: e.toString(),
        isRetryable: true,
      ));
    }

    return SyncResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      wasInterrupted: wasInterrupted,
    );
  }

  /// Calculate exponential backoff duration
  /// 
  /// Formula: min(2^retryCount, 32) seconds with jitter
  /// Requirements: 6.1
  Duration _calculateBackoff(int retryCount) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, capped at 32s
    final seconds = min(1 << retryCount, 32);
    // Add jitter to prevent thundering herd (0-1000ms)
    final jitter = Random().nextInt(1000);
    return Duration(seconds: seconds, milliseconds: jitter);
  }

  /// Classify an error into a SyncErrorType
  /// 
  /// Requirements: 6.1, 6.4
  SyncErrorType _classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Check for permission denied
    if (errorString.contains('permission-denied') ||
        errorString.contains('permission denied') ||
        errorString.contains('forbidden')) {
      return SyncErrorType.permissionDenied;
    }
    
    // Check for unauthenticated
    if (errorString.contains('unauthenticated') ||
        errorString.contains('not authenticated') ||
        errorString.contains('unauthorized')) {
      return SyncErrorType.unauthenticated;
    }
    
    // Check for quota exceeded
    if (errorString.contains('quota') ||
        errorString.contains('resource-exhausted') ||
        errorString.contains('rate limit')) {
      return SyncErrorType.quotaExceeded;
    }
    
    // Check for invalid data
    if (errorString.contains('invalid') ||
        errorString.contains('malformed') ||
        errorString.contains('bad request')) {
      return SyncErrorType.invalidData;
    }
    
    // Check for unavailable
    if (errorString.contains('unavailable') ||
        errorString.contains('service unavailable')) {
      return SyncErrorType.unavailable;
    }
    
    // Check for network errors
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('deadline') ||
        errorString.contains('connection')) {
      return SyncErrorType.network;
    }
    
    // Default to unknown
    return SyncErrorType.unknown;
  }

  /// Handle a sync error based on its type
  /// 
  /// Returns a result indicating how to proceed
  /// Requirements: 6.1, 6.2, 6.3, 6.4
  Future<_ErrorHandleResult> _handleSyncError(
    domain.Transaction transaction,
    dynamic error,
    SyncErrorType errorType,
  ) async {
    switch (errorType) {
      case SyncErrorType.permissionDenied:
        // Requirements: 6.4 - No retry on permission denied
        debugPrint('🚫 CloudSyncService: Permission denied for ${transaction.id} - not retrying');
        await localStorage.markAsPermanentlyFailed(transaction.id, error.toString());
        _transitionTo(SyncState.error);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.error,
          errorMessage: 'Permission denied - please check authentication',
        ));
        return _ErrorHandleResult(
          shouldStop: true,
          isRetryable: false,
          isPermanentlyFailed: true,
        );

      case SyncErrorType.unauthenticated:
        // Requirements: 6.4 - No retry on auth errors
        debugPrint('🚫 CloudSyncService: Unauthenticated for ${transaction.id} - not retrying');
        await localStorage.markAsPermanentlyFailed(transaction.id, error.toString());
        _transitionTo(SyncState.error);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.error,
          errorMessage: 'Authentication error - please sign in again',
        ));
        return _ErrorHandleResult(
          shouldStop: true,
          isRetryable: false,
          isPermanentlyFailed: true,
        );

      case SyncErrorType.quotaExceeded:
        // Requirements: 6.1 - Hard pause on quota exceeded
        debugPrint('⏸️ CloudSyncService: Quota exceeded - hard pausing sync');
        _isHardPaused = true;
        _transitionTo(SyncState.error);
        _updateStatus(_currentStatus.copyWith(
          state: SyncState.error,
          errorMessage: 'Quota exceeded - sync paused. Try again later.',
        ));
        return _ErrorHandleResult(
          shouldStop: true,
          isRetryable: true,
          isPermanentlyFailed: false,
        );

      case SyncErrorType.invalidData:
        // Invalid data - skip transaction, don't retry
        debugPrint('🚫 CloudSyncService: Invalid data for ${transaction.id} - skipping');
        await localStorage.markAsPermanentlyFailed(transaction.id, error.toString());
        return _ErrorHandleResult(
          shouldStop: false,
          isRetryable: false,
          isPermanentlyFailed: true,
        );

      case SyncErrorType.network:
      case SyncErrorType.unavailable:
      case SyncErrorType.unknown:
        // Requirements: 6.1, 6.2, 6.3 - Retry with exponential backoff
        final newRetryCount = await localStorage.incrementRetryCount(
          transaction.id,
          error.toString(),
        );
        
        debugPrint('🔄 CloudSyncService: Retryable error for ${transaction.id} - retry count: $newRetryCount');
        
        // Check if max retries exceeded
        // Requirements: 6.2, 6.3 - Max retry limit
        if (newRetryCount >= maxRetries) {
          debugPrint('🚫 CloudSyncService: Max retries exceeded for ${transaction.id} - marking as failed');
          await localStorage.markAsPermanentlyFailed(
            transaction.id,
            'Max retries ($maxRetries) exceeded: ${error.toString()}',
          );
          return _ErrorHandleResult(
            shouldStop: false,
            isRetryable: false,
            isPermanentlyFailed: true,
          );
        }
        
        // Keep in queue for retry (Requirements: 1.6)
        return _ErrorHandleResult(
          shouldStop: false,
          isRetryable: true,
          isPermanentlyFailed: false,
        );
    }
  }

  /// Upload a single transaction to Firestore
  /// 
  /// - Uses transaction hash as document ID for cloud-side deduplication
  /// - Uses path `/users/{uid}/transactions/{hash}`
  /// - Uses `set(..., SetOptions(merge: true))` for upserts
  /// - Includes all transaction fields
  /// 
  /// Requirements: 7.1, 7.2, 7.3, 7.4
  Future<void> _uploadTransactionToFirestore(domain.Transaction transaction, String uid) async {
    // Compute transaction hash for document ID
    // Requirements: 7.1 - Use transaction hash as document ID
    final transactionHash = computeTransactionHash(transaction);
    
    // Build document path: /users/{uid}/transactions/{hash}
    // Requirements: 7.2 - Use path /users/{uid}/transactions/{transactionHash}
    final docPath = 'users/$uid/transactions/$transactionHash';
    debugPrint('📤 CloudSyncService: Uploading to $docPath');

    // Prepare transaction data with all fields
    // Requirements: 7.4 - Include all transaction fields
    final data = _transactionToFirestoreMap(transaction, uid);

    // Use Firestore instance if available, otherwise use firestoreRepo's firestore
    final firestoreInstance = firestore;
    if (firestoreInstance == null) {
      throw Exception('Firestore not available');
    }

    // Upload using set with merge option for upsert behavior
    // Requirements: 7.3 - Use set(..., SetOptions(merge: true)) for upserts
    await firestoreInstance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionHash)
        .set(data, SetOptions(merge: true));
  }

  /// Convert Transaction to Firestore map with all fields
  /// 
  /// Requirements: 7.4 - Include all transaction fields without data loss
  Map<String, dynamic> _transactionToFirestoreMap(domain.Transaction transaction, String uid) {
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
      'syncedToFirestore': true,
      'duplicateCheckHash': transaction.duplicateCheckHash,
      'isManualEntry': transaction.isManualEntry,
      'localId': transaction.id,
      'syncedAt': FieldValue.serverTimestamp(),
      'userId': uid,
    };
  }

  /// Check if an error is retryable
  /// 
  /// Network errors and temporary failures are retryable.
  /// Permission errors and invalid data errors are not retryable.
  bool _isRetryableError(dynamic error) {
    final errorType = _classifyError(error);
    return errorType == SyncErrorType.network ||
           errorType == SyncErrorType.unavailable ||
           errorType == SyncErrorType.unknown ||
           errorType == SyncErrorType.quotaExceeded;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _isInitialized = false;
    debugPrint('✅ CloudSyncService: Disposed');
  }
}

/// Result of handling a sync error
class _ErrorHandleResult {
  /// Whether to stop processing more transactions
  final bool shouldStop;
  
  /// Whether the error is retryable
  final bool isRetryable;
  
  /// Whether the transaction is permanently failed
  final bool isPermanentlyFailed;

  const _ErrorHandleResult({
    required this.shouldStop,
    required this.isRetryable,
    required this.isPermanentlyFailed,
  });
}
