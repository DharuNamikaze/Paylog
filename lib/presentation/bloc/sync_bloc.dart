import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/connectivity_monitor.dart';

// ============================================================
// Events
// ============================================================

/// Base class for all sync events
abstract class SyncEvent {}

/// Event to initialize sync monitoring
/// 
/// Should be dispatched when the app starts to begin
/// listening to sync status and connectivity changes.
class SyncStarted extends SyncEvent {}

/// Event for user-triggered manual sync
/// 
/// Dispatched when user taps the sync button.
/// Requirements: 4.1
class SyncRequested extends SyncEvent {}

/// Internal event for sync status changes from CloudSyncService
/// 
/// Requirements: 3.1, 3.2, 3.3, 3.4
class SyncStatusChanged extends SyncEvent {
  final SyncStatus status;

  SyncStatusChanged(this.status);
}

/// Internal event for connectivity state changes
/// 
/// Requirements: 5.1
class ConnectivityChanged extends SyncEvent {
  final ConnectivityState state;

  ConnectivityChanged(this.state);
}

/// Internal event for sync result after manual sync
class _SyncResultReceived extends SyncEvent {
  final SyncResult result;

  _SyncResultReceived(this.result);
}

// ============================================================
// States
// ============================================================

/// Base class for all sync states
abstract class SyncBlocState {
  /// Number of transactions pending sync
  int get pendingCount;
}

/// Initial state before sync monitoring starts
class SyncInitial extends SyncBlocState {
  @override
  int get pendingCount => 0;
}

/// Sync operation is currently in progress
/// 
/// Requirements: 3.3
class SyncInProgress extends SyncBlocState {
  @override
  final int pendingCount;
  
  /// Number of transactions synced so far in this operation
  final int syncedCount;

  SyncInProgress({
    required this.pendingCount,
    this.syncedCount = 0,
  });
}

/// All transactions have been synced successfully
/// 
/// Requirements: 3.4
class SyncComplete extends SyncBlocState {
  /// Number of transactions synced in the last operation
  final int syncedCount;
  
  /// Timestamp of the last successful sync
  final DateTime lastSyncTime;

  SyncComplete({
    required this.syncedCount,
    required this.lastSyncTime,
  });

  @override
  int get pendingCount => 0;
}

/// Transactions are pending sync but no sync is in progress
/// 
/// Requirements: 3.2
class SyncPending extends SyncBlocState {
  @override
  final int pendingCount;
  
  /// Timestamp of the last sync attempt (if any)
  final DateTime? lastSyncTime;

  SyncPending({
    required this.pendingCount,
    this.lastSyncTime,
  });
}

/// Sync encountered an error
/// 
/// Requirements: 3.1
class SyncError extends SyncBlocState {
  /// Error message describing what went wrong
  final String message;
  
  @override
  final int pendingCount;
  
  /// Number of transactions that failed to sync
  final int failedCount;

  SyncError({
    required this.message,
    required this.pendingCount,
    this.failedCount = 0,
  });
}

/// Device is offline, sync is not possible
/// 
/// Requirements: 5.1
class SyncOffline extends SyncBlocState {
  @override
  final int pendingCount;

  SyncOffline({
    required this.pendingCount,
  });
}

// ============================================================
// BLoC
// ============================================================

/// BLoC for managing sync state in the UI layer
/// 
/// This BLoC subscribes to CloudSyncService status stream and
/// ConnectivityMonitor to provide UI-friendly sync states.
/// 
/// Requirements: 3.1, 3.2, 3.3, 3.4
class SyncBloc extends Bloc<SyncEvent, SyncBlocState> {
  final CloudSyncService _cloudSyncService;
  final ConnectivityMonitor _connectivityMonitor;
  
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<ConnectivityState>? _connectivitySubscription;

  SyncBloc({
    required CloudSyncService cloudSyncService,
    required ConnectivityMonitor connectivityMonitor,
  })  : _cloudSyncService = cloudSyncService,
        _connectivityMonitor = connectivityMonitor,
        super(SyncInitial()) {
    on<SyncStarted>(_onSyncStarted);
    on<SyncRequested>(_onSyncRequested);
    on<SyncStatusChanged>(_onSyncStatusChanged);
    on<ConnectivityChanged>(_onConnectivityChanged);
    on<_SyncResultReceived>(_onSyncResultReceived);
  }

  /// Handle SyncStarted event - initialize monitoring
  Future<void> _onSyncStarted(
    SyncStarted event,
    Emitter<SyncBlocState> emit,
  ) async {
    // Cancel any existing subscriptions
    await _statusSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    // Subscribe to CloudSyncService status stream
    _statusSubscription = _cloudSyncService.statusStream.listen(
      (status) {
        if (!isClosed) {
          add(SyncStatusChanged(status));
        }
      },
      onError: (error) {
        if (!isClosed) {
          add(SyncStatusChanged(SyncStatus(
            state: SyncState.error,
            errorMessage: error.toString(),
          )));
        }
      },
    );

    // Subscribe to connectivity changes
    _connectivitySubscription = _connectivityMonitor.connectivityStream.listen(
      (connectivityState) {
        if (!isClosed) {
          add(ConnectivityChanged(connectivityState));
        }
      },
      onError: (error) {
        // Ignore connectivity errors, assume offline
      },
    );

    // Get initial state from CloudSyncService
    final currentStatus = _cloudSyncService.currentStatus;
    final isOnline = await _connectivityMonitor.isOnline;

    // Emit initial state based on current status and connectivity
    emit(_mapStatusToState(currentStatus, isOnline));
  }

  /// Handle SyncRequested event - user-triggered manual sync
  /// 
  /// Requirements: 4.1, 4.2, 4.3
  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncBlocState> emit,
  ) async {
    // Check if already syncing (Requirements: 4.3)
    if (state is SyncInProgress) {
      // Already syncing, don't start another sync
      return;
    }

    // Check connectivity
    final isOnline = await _connectivityMonitor.isOnline;
    if (!isOnline) {
      final pendingCount = await _cloudSyncService.getPendingCount();
      emit(SyncOffline(pendingCount: pendingCount));
      return;
    }

    // Emit in-progress state
    final pendingCount = await _cloudSyncService.getPendingCount();
    emit(SyncInProgress(pendingCount: pendingCount));

    // Trigger manual sync
    try {
      final result = await _cloudSyncService.manualSync();
      
      // Use internal event to handle result (avoid emit after async gap)
      if (!isClosed) {
        add(_SyncResultReceived(result));
      }
    } catch (e) {
      if (!isClosed) {
        final currentPendingCount = await _cloudSyncService.getPendingCount();
        emit(SyncError(
          message: 'Sync failed: ${e.toString()}',
          pendingCount: currentPendingCount,
        ));
      }
    }
  }

  /// Handle sync result after manual sync
  Future<void> _onSyncResultReceived(
    _SyncResultReceived event,
    Emitter<SyncBlocState> emit,
  ) async {
    final result = event.result;
    final pendingCount = await _cloudSyncService.getPendingCount();

    if (result.errors.isNotEmpty && result.successCount == 0) {
      // All failed
      emit(SyncError(
        message: result.errors.first.errorMessage,
        pendingCount: pendingCount,
        failedCount: result.failureCount,
      ));
    } else if (pendingCount > 0) {
      // Some pending
      emit(SyncPending(
        pendingCount: pendingCount,
        lastSyncTime: DateTime.now(),
      ));
    } else {
      // All synced
      emit(SyncComplete(
        syncedCount: result.successCount,
        lastSyncTime: DateTime.now(),
      ));
    }
  }

  /// Handle SyncStatusChanged event from CloudSyncService
  /// 
  /// Requirements: 3.1, 3.2, 3.3, 3.4
  Future<void> _onSyncStatusChanged(
    SyncStatusChanged event,
    Emitter<SyncBlocState> emit,
  ) async {
    final isOnline = await _connectivityMonitor.isOnline;
    emit(_mapStatusToState(event.status, isOnline));
  }

  /// Handle ConnectivityChanged event
  /// 
  /// Requirements: 5.1
  Future<void> _onConnectivityChanged(
    ConnectivityChanged event,
    Emitter<SyncBlocState> emit,
  ) async {
    final isOnline = event.state != ConnectivityState.offline;
    final currentStatus = _cloudSyncService.currentStatus;

    if (!isOnline) {
      // Device went offline
      emit(SyncOffline(pendingCount: currentStatus.pendingCount));
    } else {
      // Device came online - map current status to state
      emit(_mapStatusToState(currentStatus, true));
    }
  }

  /// Map CloudSyncService SyncStatus to SyncBlocState
  SyncBlocState _mapStatusToState(SyncStatus status, bool isOnline) {
    // If offline, always show offline state
    if (!isOnline) {
      return SyncOffline(pendingCount: status.pendingCount);
    }

    switch (status.state) {
      case SyncState.idle:
        if (status.pendingCount > 0) {
          return SyncPending(
            pendingCount: status.pendingCount,
            lastSyncTime: status.lastSyncTime,
          );
        } else {
          return SyncComplete(
            syncedCount: status.syncedCount,
            lastSyncTime: status.lastSyncTime ?? DateTime.now(),
          );
        }

      case SyncState.syncing:
        return SyncInProgress(
          pendingCount: status.pendingCount,
          syncedCount: status.syncedCount,
        );

      case SyncState.paused:
        return SyncPending(
          pendingCount: status.pendingCount,
          lastSyncTime: status.lastSyncTime,
        );

      case SyncState.error:
        return SyncError(
          message: status.errorMessage ?? 'Unknown sync error',
          pendingCount: status.pendingCount,
          failedCount: status.failedCount,
        );
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
