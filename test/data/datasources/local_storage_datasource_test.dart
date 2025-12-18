import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paylog/data/datasources/local_storage_datasource.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';

void main() {
  late LocalStorageDataSource dataSource;
  late Directory testDirectory;

  setUpAll(() async {
    // Create a temporary directory for testing
    testDirectory = Directory.systemTemp.createTempSync('hive_test_');
    // Initialize Hive with the test directory
    Hive.init(testDirectory.path);
  });

  setUp(() async {
    dataSource = LocalStorageDataSource();
    await dataSource.initialize(path: testDirectory.path);
  });

  tearDown(() async {
    try {
      await dataSource.clearQueue();
      await dataSource.clearCache();
      await dataSource.close();
    } catch (e) {
      // Ignore errors during teardown
    }
  });

  tearDownAll(() async {
    await Hive.close();
    // Clean up test directory
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  group('LocalStorageDataSource - Queue Operations', () {
    test('should queue a transaction', () async {
      // Arrange
      final transaction = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS content',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      // Act
      await dataSource.queueTransaction(transaction);

      // Assert
      final queuedTransactions = await dataSource.getQueuedTransactions();
      expect(queuedTransactions.length, 1);
      expect(queuedTransactions.first.id, 'test-1');
      expect(queuedTransactions.first.amount, 1000.0);
    });

    test('should get all queued transactions', () async {
      // Arrange
      final transaction1 = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS 1',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      final transaction2 = Transaction(
        id: 'test-2',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-2',
        isManualEntry: false,
        amount: 2000.0,
        transactionType: TransactionType.credit,
        accountNumber: 'xxxx5678',
        date: '2024-01-16',
        time: '15:45:00',
        smsContent: 'Test SMS 2',
        senderPhoneNumber: 'BANK-456',
        confidenceScore: 0.90,
      );

      // Act
      await dataSource.queueTransaction(transaction1);
      await dataSource.queueTransaction(transaction2);

      // Assert
      final queuedTransactions = await dataSource.getQueuedTransactions();
      expect(queuedTransactions.length, 2);
    });

    test('should remove transaction from queue', () async {
      // Arrange
      final transaction = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      await dataSource.queueTransaction(transaction);

      // Act
      await dataSource.removeFromQueue('test-1');

      // Assert
      final queuedTransactions = await dataSource.getQueuedTransactions();
      expect(queuedTransactions.length, 0);
    });

    test('should check if transaction is in queue', () async {
      // Arrange
      final transaction = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      await dataSource.queueTransaction(transaction);

      // Act & Assert
      expect(await dataSource.isInQueue('test-1'), true);
      expect(await dataSource.isInQueue('non-existent'), false);
    });

    test('should get queue size', () async {
      // Arrange
      final transaction1 = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS 1',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      final transaction2 = Transaction(
        id: 'test-2',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-2',
        isManualEntry: false,
        amount: 2000.0,
        transactionType: TransactionType.credit,
        accountNumber: 'xxxx5678',
        date: '2024-01-16',
        time: '15:45:00',
        smsContent: 'Test SMS 2',
        senderPhoneNumber: 'BANK-456',
        confidenceScore: 0.90,
      );

      // Act
      await dataSource.queueTransaction(transaction1);
      await dataSource.queueTransaction(transaction2);

      // Assert
      expect(await dataSource.getQueueSize(), 2);
    });

    test('should clear queue', () async {
      // Arrange
      final transaction = Transaction(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'hash-1',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: '2024-01-15',
        time: '14:30:00',
        smsContent: 'Test SMS',
        senderPhoneNumber: 'BANK-123',
        confidenceScore: 0.95,
      );

      await dataSource.queueTransaction(transaction);

      // Act
      await dataSource.clearQueue();

      // Assert
      expect(await dataSource.getQueueSize(), 0);
    });
  });

  group('LocalStorageDataSource - Cache Operations', () {
    test('should cache transactions', () async {
      // Arrange
      final transactions = [
        Transaction(
          id: 'test-1',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-1',
          isManualEntry: false,
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2024-01-15',
          time: '14:30:00',
          smsContent: 'Test SMS 1',
          senderPhoneNumber: 'BANK-123',
          confidenceScore: 0.95,
        ),
        Transaction(
          id: 'test-2',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-2',
          isManualEntry: false,
          amount: 2000.0,
          transactionType: TransactionType.credit,
          accountNumber: 'xxxx5678',
          date: '2024-01-16',
          time: '15:45:00',
          smsContent: 'Test SMS 2',
          senderPhoneNumber: 'BANK-456',
          confidenceScore: 0.90,
        ),
      ];

      // Act
      await dataSource.cacheTransactions(transactions);

      // Assert
      final cachedTransactions = await dataSource.getCachedTransactions();
      expect(cachedTransactions.length, 2);
    });

    test('should get cached transactions sorted by createdAt', () async {
      // Arrange
      final now = DateTime.now();
      final transactions = [
        Transaction(
          id: 'test-1',
          userId: 'user-1',
          createdAt: now.subtract(Duration(hours: 2)),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-1',
          isManualEntry: false,
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2024-01-15',
          time: '14:30:00',
          smsContent: 'Test SMS 1',
          senderPhoneNumber: 'BANK-123',
          confidenceScore: 0.95,
        ),
        Transaction(
          id: 'test-2',
          userId: 'user-1',
          createdAt: now,
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-2',
          isManualEntry: false,
          amount: 2000.0,
          transactionType: TransactionType.credit,
          accountNumber: 'xxxx5678',
          date: '2024-01-16',
          time: '15:45:00',
          smsContent: 'Test SMS 2',
          senderPhoneNumber: 'BANK-456',
          confidenceScore: 0.90,
        ),
      ];

      // Act
      await dataSource.cacheTransactions(transactions);

      // Assert
      final cachedTransactions = await dataSource.getCachedTransactions();
      expect(cachedTransactions.length, 2);
      expect(cachedTransactions.first.id, 'test-2'); // Most recent first
      expect(cachedTransactions.last.id, 'test-1');
    });

    test('should update cache timestamp', () async {
      // Arrange
      final transactions = [
        Transaction(
          id: 'test-1',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-1',
          isManualEntry: false,
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2024-01-15',
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK-123',
          confidenceScore: 0.95,
        ),
      ];

      // Act
      await dataSource.cacheTransactions(transactions);

      // Assert
      final lastUpdate = await dataSource.getLastCacheUpdate();
      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.isBefore(DateTime.now().add(Duration(seconds: 1))), true);
    });

    test('should clear cache', () async {
      // Arrange
      final transactions = [
        Transaction(
          id: 'test-1',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-1',
          isManualEntry: false,
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2024-01-15',
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK-123',
          confidenceScore: 0.95,
        ),
      ];

      await dataSource.cacheTransactions(transactions);

      // Act
      await dataSource.clearCache();

      // Assert
      final cachedTransactions = await dataSource.getCachedTransactions();
      expect(cachedTransactions.length, 0);
      final lastUpdate = await dataSource.getLastCacheUpdate();
      expect(lastUpdate, isNull);
    });

    test('should replace existing cache when caching new transactions', () async {
      // Arrange
      final oldTransactions = [
        Transaction(
          id: 'old-1',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-old',
          isManualEntry: false,
          amount: 500.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx9999',
          date: '2024-01-10',
          time: '10:00:00',
          smsContent: 'Old SMS',
          senderPhoneNumber: 'BANK-OLD',
          confidenceScore: 0.80,
        ),
      ];

      final newTransactions = [
        Transaction(
          id: 'new-1',
          userId: 'user-1',
          createdAt: DateTime.now(),
          syncedToFirestore: true,
          duplicateCheckHash: 'hash-new',
          isManualEntry: false,
          amount: 1000.0,
          transactionType: TransactionType.credit,
          accountNumber: 'xxxx1234',
          date: '2024-01-15',
          time: '14:30:00',
          smsContent: 'New SMS',
          senderPhoneNumber: 'BANK-NEW',
          confidenceScore: 0.95,
        ),
      ];

      // Act
      await dataSource.cacheTransactions(oldTransactions);
      await dataSource.cacheTransactions(newTransactions);

      // Assert
      final cachedTransactions = await dataSource.getCachedTransactions();
      expect(cachedTransactions.length, 1);
      expect(cachedTransactions.first.id, 'new-1');
    });
  });

  group('LocalStorageDataSource - Initialization', () {
    test('should throw StateError when not initialized', () async {
      // Arrange
      final uninitializedDataSource = LocalStorageDataSource();

      // Act & Assert
      expect(
        () => uninitializedDataSource.getQueuedTransactions(),
        throwsStateError,
      );
    });
  });
}
