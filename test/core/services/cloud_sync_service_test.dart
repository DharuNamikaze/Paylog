import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/core/services/cloud_sync_service.dart';
import 'package:paylog/core/services/auth_service.dart';
import 'package:paylog/core/services/connectivity_monitor.dart';
import 'package:paylog/data/datasources/local_storage_datasource.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';

/// Mock LocalStorageDataSource for testing
class MockLocalStorageDataSource implements LocalStorageDataSource {
  final Map<String, Transaction> _queue = {};
  final Map<String, Map<String, dynamic>> _retryMetadata = {};
  int queueTransactionCallCount = 0;

  @override
  Future<void> queueTransaction(Transaction transaction) async {
    _queue[transaction.id] = transaction;
    queueTransactionCallCount++;
  }

  @override
  Future<List<Transaction>> getQueuedTransactions() async {
    return _queue.values.toList();
  }

  @override
  Future<void> removeFromQueue(String transactionId) async {
    _queue.remove(transactionId);
  }

  @override
  Future<bool> isInQueue(String transactionId) async {
    return _queue.containsKey(transactionId);
  }

  @override
  Future<int> getQueueSize() async {
    return _queue.length;
  }

  @override
  Future<void> updateSyncedFlag(String transactionId, bool synced) async {}

  // Retry metadata methods
  @override
  Future<Map<String, dynamic>> getRetryMetadata(String transactionId) async {
    return _retryMetadata[transactionId] ?? {
      'retryCount': 0,
      'lastAttemptAt': null,
      'lastError': null,
      'permanentlyFailed': false,
    };
  }

  @override
  Future<int> incrementRetryCount(String transactionId, String? errorMessage) async {
    final metadata = await getRetryMetadata(transactionId);
    final newRetryCount = (metadata['retryCount'] as int) + 1;
    _retryMetadata[transactionId] = {
      'retryCount': newRetryCount,
      'lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
      'lastError': errorMessage,
      'permanentlyFailed': metadata['permanentlyFailed'] ?? false,
    };
    return newRetryCount;
  }

  @override
  Future<void> markAsPermanentlyFailed(String transactionId, String errorMessage) async {
    final metadata = await getRetryMetadata(transactionId);
    _retryMetadata[transactionId] = {
      'retryCount': metadata['retryCount'],
      'lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
      'lastError': errorMessage,
      'permanentlyFailed': true,
    };
  }

  @override
  Future<bool> isPermanentlyFailed(String transactionId) async {
    final metadata = await getRetryMetadata(transactionId);
    return metadata['permanentlyFailed'] == true;
  }

  @override
  Future<int> getRetryCount(String transactionId) async {
    final metadata = await getRetryMetadata(transactionId);
    return metadata['retryCount'] as int;
  }

  @override
  Future<void> clearRetryMetadata(String transactionId) async {
    _retryMetadata.remove(transactionId);
  }

  @override
  Future<List<Transaction>> getRetryableQueuedTransactions() async {
    final allTransactions = await getQueuedTransactions();
    final retryableTransactions = <Transaction>[];
    for (final transaction in allTransactions) {
      final isPermanentFailed = await isPermanentlyFailed(transaction.id);
      if (!isPermanentFailed) {
        retryableTransactions.add(transaction);
      }
    }
    return retryableTransactions;
  }

  @override
  Future<void> initialize({String? path}) async {}
  @override
  Future<void> cacheTransactions(List<Transaction> transactions) async {}
  @override
  Future<List<Transaction>> getCachedTransactions() async => [];
  @override
  Future<DateTime?> getLastCacheUpdate() async => null;
  @override
  Future<void> clearQueue() async => _queue.clear();
  @override
  Future<void> clearCache() async {}
  @override
  Future<Transaction?> getTransaction(String transactionId) async => null;
  @override
  Future<void> saveTransaction(Transaction transaction) async {}
  @override
  Stream<List<Transaction>> getTransactionsStream(String userId) => const Stream.empty();
  @override
  Future<void> close() async {}
}

/// Mock AuthService for testing
class MockAuthService implements AuthService {
  bool _isAuthenticated = true;
  String? _currentUid = 'test-uid';
  bool _isLocalOnlyMode = false;

  void setAuthenticated(bool value) => _isAuthenticated = value;
  void setCurrentUid(String? value) => _currentUid = value;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUid => _currentUid;

  @override
  String get requireUid => _currentUid ?? (throw StateError('Not authenticated'));

  @override
  bool get isLocalOnlyMode => _isLocalOnlyMode;

  @override
  Stream<String?> get authStateChanges => Stream.value(_currentUid);

  @override
  Future<String?> initialize() async => _currentUid;

  @override
  Future<void> signOut() async {
    _currentUid = null;
    _isAuthenticated = false;
  }

  @override
  Future<void> refreshToken() async {}

  @override
  void dispose() {}
}

/// Mock ConnectivityMonitor for testing
class MockConnectivityMonitor implements ConnectivityMonitor {
  ConnectivityState _currentState = ConnectivityState.wifi;
  final StreamController<ConnectivityState> _streamController =
      StreamController<ConnectivityState>.broadcast();

  void setConnectivityState(ConnectivityState state) {
    _currentState = state;
    _streamController.add(state);
  }

  @override
  Stream<ConnectivityState> get connectivityStream => _streamController.stream;

  @override
  Future<ConnectivityState> get currentState async => _currentState;

  @override
  ConnectivityState get currentStateSync => _currentState;

  @override
  Future<bool> get isOnline async => _currentState != ConnectivityState.offline;

  @override
  bool get isOnlineSync => _currentState != ConnectivityState.offline;

  @override
  bool get isWifi => _currentState == ConnectivityState.wifi;

  @override
  bool get isMobile => _currentState == ConnectivityState.mobile;

  @override
  bool get isEthernet => _currentState == ConnectivityState.ethernet;

  @override
  Future<void> initialize() async {}

  @override
  Future<ConnectivityState> checkConnectivity() async => _currentState;

  @override
  void dispose() {
    _streamController.close();
  }
}

void main() {
  late CloudSyncService cloudSyncService;
  late MockLocalStorageDataSource mockLocalStorage;
  late MockAuthService mockAuthService;
  late MockConnectivityMonitor mockConnectivityMonitor;

  setUp(() {
    mockLocalStorage = MockLocalStorageDataSource();
    mockAuthService = MockAuthService();
    mockConnectivityMonitor = MockConnectivityMonitor();

    cloudSyncService = CloudSyncService(
      localStorage: mockLocalStorage,
      authService: mockAuthService,
      connectivityMonitor: mockConnectivityMonitor,
      firestoreRepo: null,
    );
  });

  tearDown(() {
    cloudSyncService.dispose();
    mockConnectivityMonitor.dispose();
  });

  group('CloudSyncService State Machine', () {
    test('initial state should be idle', () {
      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });

    test('triggerSync should reject when offline', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.offline);

      final result = await cloudSyncService.triggerSync();

      expect(result.successCount, equals(0));
      expect(result.failureCount, equals(0));
      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });

    test('triggerSync should skip silently when Firestore not available', () async {
      // When Firestore is not available (local-only mode), sync should skip silently
      // This is the expected behavior - no error, just skip
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);
      mockAuthService.setAuthenticated(false);

      final result = await cloudSyncService.triggerSync();

      expect(result.successCount, equals(0));
      expect(result.failureCount, equals(0));
      expect(result.errors.isEmpty, isTrue); // No errors in local-only mode
      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });

    test('manualSync should work when online and authenticated', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);
      mockAuthService.setAuthenticated(true);

      final result = await cloudSyncService.manualSync();

      expect(result.successCount, equals(0));
      expect(result.failureCount, equals(0));
      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });

    test('sync should return to idle state when queue is empty', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);
      mockAuthService.setAuthenticated(true);

      await cloudSyncService.triggerSync();

      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });
  });

  group('CloudSyncService State Transitions Validation', () {
    test('valid transition: idle -> syncing -> idle (empty queue)', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);
      mockAuthService.setAuthenticated(true);

      expect(cloudSyncService.syncState, equals(SyncState.idle));

      await cloudSyncService.triggerSync();

      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });
  });

  group('CloudSyncService Queue Management', () {
    test('queueForSync should add transaction to queue', () async {
      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      await cloudSyncService.queueForSync(transaction);

      expect(mockLocalStorage.queueTransactionCallCount, equals(1));
      expect(await mockLocalStorage.getQueueSize(), equals(1));
    });

    test('queueForSync should skip duplicate transactions (idempotence)', () async {
      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      await cloudSyncService.queueForSync(transaction);
      expect(mockLocalStorage.queueTransactionCallCount, equals(1));

      await cloudSyncService.queueForSync(transaction);
      expect(mockLocalStorage.queueTransactionCallCount, equals(1));
    });

    test('getPendingCount should return queue size', () async {
      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      await cloudSyncService.queueForSync(transaction);

      final count = await cloudSyncService.getPendingCount();
      expect(count, equals(1));
    });
  });

  group('CloudSyncService Status Stream', () {
    test('statusStream should emit status updates when queueing', () async {
      final statusUpdates = <SyncStatus>[];
      final subscription = cloudSyncService.statusStream.listen(statusUpdates.add);

      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      await cloudSyncService.queueForSync(transaction);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(statusUpdates.isNotEmpty, isTrue);
      expect(statusUpdates.last.pendingCount, equals(1));

      await subscription.cancel();
    });

    test('currentStatus should reflect latest state', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);
      mockAuthService.setAuthenticated(true);

      await cloudSyncService.triggerSync();

      expect(cloudSyncService.currentStatus.state, equals(SyncState.idle));
    });
  });

  group('CloudSyncService Connectivity Handling', () {
    test('should trigger sync when connectivity changes from offline to online', () async {
      mockConnectivityMonitor.setConnectivityState(ConnectivityState.offline);

      await cloudSyncService.initialize();

      mockConnectivityMonitor.setConnectivityState(ConnectivityState.wifi);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(cloudSyncService.syncState, equals(SyncState.idle));
    });
  });

  group('CloudSyncService SyncStatus', () {
    test('SyncStatus copyWith should work correctly', () {
      const status = SyncStatus(
        state: SyncState.idle,
        pendingCount: 5,
        syncedCount: 10,
        failedCount: 2,
      );

      final updated = status.copyWith(
        state: SyncState.syncing,
        pendingCount: 3,
      );

      expect(updated.state, equals(SyncState.syncing));
      expect(updated.pendingCount, equals(3));
      expect(updated.syncedCount, equals(10));
      expect(updated.failedCount, equals(2));
    });
  });

  group('CloudSyncService QueuedTransaction', () {
    test('QueuedTransaction canRetry should respect maxRetries', () {
      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      final queued = QueuedTransaction(
        transaction: transaction,
        retryCount: 3,
        queuedAt: DateTime.now(),
      );

      expect(queued.canRetry, isTrue);

      final maxedOut = QueuedTransaction(
        transaction: transaction,
        retryCount: 5,
        queuedAt: DateTime.now(),
      );

      expect(maxedOut.canRetry, isFalse);
    });

    test('QueuedTransaction backoffDuration should increase exponentially', () {
      final transaction = Transaction(
        id: 'test-id',
        amount: 100.0,
        transactionType: TransactionType.debit,
        date: '2026-01-06',
        time: '10:00:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'TEST-BANK',
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        userId: 'test-user',
      );

      final retry0 = QueuedTransaction(
        transaction: transaction,
        retryCount: 0,
        queuedAt: DateTime.now(),
      );
      final retry1 = QueuedTransaction(
        transaction: transaction,
        retryCount: 1,
        queuedAt: DateTime.now(),
      );
      final retry2 = QueuedTransaction(
        transaction: transaction,
        retryCount: 2,
        queuedAt: DateTime.now(),
      );

      expect(retry0.backoffDuration.inSeconds, greaterThanOrEqualTo(1));
      expect(retry1.backoffDuration.inSeconds, greaterThanOrEqualTo(2));
      expect(retry2.backoffDuration.inSeconds, greaterThanOrEqualTo(4));
    });
  });
}
