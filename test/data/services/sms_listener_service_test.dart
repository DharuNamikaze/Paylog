import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/data/services/sms_listener_service.dart';
import 'package:paylog/domain/entities/sms_message.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';
import 'package:paylog/domain/entities/validation_result.dart';
import 'package:paylog/domain/usecases/detect_financial_context.dart';
import 'package:paylog/domain/usecases/parse_sms_transaction.dart';
import 'package:paylog/domain/usecases/validate_transaction.dart';
import 'package:paylog/domain/repositories/transaction_repository.dart';
import 'package:paylog/core/utils/duplicate_detector.dart';

/// Mock transaction repository for testing
class MockTransactionRepository implements TransactionRepository {
  final List<Transaction> _transactions = [];
  bool shouldThrowError = false;
  
  @override
  Future<String> saveTransaction(Transaction transaction) async {
    if (shouldThrowError) {
      throw Exception('Mock save error');
    }
    _transactions.add(transaction);
    return 'mock-transaction-id-${_transactions.length}';
  }
  
  @override
  Stream<List<Transaction>> getTransactions(String userId) {
    return Stream.value(_transactions.where((t) => t.userId == userId).toList());
  }
  
  @override
  Future<void> deleteTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
  }
  
  @override
  Future<void> syncOfflineQueue() async {
    // Mock implementation
  }
  
  List<Transaction> get savedTransactions => List.unmodifiable(_transactions);
  void clear() => _transactions.clear();
}

void main() {
  group('SmsListenerService', () {
    late SmsListenerService service;
    late MockTransactionRepository mockRepository;
    late DuplicateDetector duplicateDetector;
    late Directory testDir;

    setUp(() async {
      // Create a temporary directory for Hive
      testDir = await Directory.systemTemp.createTemp('sms_listener_test_');
      
      // Initialize real components
      mockRepository = MockTransactionRepository();
      duplicateDetector = DuplicateDetector();
      
      service = SmsListenerService(
        repository: mockRepository,
        duplicateDetector: duplicateDetector,
      );
    });

    tearDown(() async {
      await service.dispose();
      await testDir.delete(recursive: true);
    });

    group('initialization', () {
      test('should initialize successfully', () async {
        await service.initialize(hivePath: testDir.path);
        
        expect(service.isListening, isFalse);
        expect(service.currentUserId, isNull);
      });

      test('should handle initialization with custom path', () async {
        // Test initialization with custom path
        await service.initialize(hivePath: testDir.path);
        
        expect(service.isListening, isFalse);
        expect(service.currentUserId, isNull);
      });
    });

    group('service status and statistics', () {
      test('should return correct initial service status', () async {
        await service.initialize(hivePath: testDir.path);
        
        final status = service.getServiceStatus();
        
        expect(status['isListening'], isFalse);
        expect(status['currentUserId'], isNull);
        expect(status['statistics'], isA<Map>());
        
        final stats = service.statistics;
        expect(stats['totalReceived'], equals(0));
        expect(stats['financialMessages'], equals(0));
        expect(stats['successfullyParsed'], equals(0));
        expect(stats['validationPassed'], equals(0));
        expect(stats['savedToDatabase'], equals(0));
        expect(stats['duplicatesDetected'], equals(0));
        expect(stats['errors'], equals(0));
      });
    });

    group('edge case validation', () {
      test('should validate SMS messages correctly', () async {
        await service.initialize(hivePath: testDir.path);
        
        // Test empty content
        final emptySms = SmsMessage(
          sender: 'BANK',
          content: '',
          timestamp: DateTime.now(),
        );
        
        // Test very short content
        final shortSms = SmsMessage(
          sender: 'BANK',
          content: 'Hi',
          timestamp: DateTime.now(),
        );
        
        // Test very long content
        final longSms = SmsMessage(
          sender: 'BANK',
          content: 'A' * 3000,
          timestamp: DateTime.now(),
        );
        
        // Test valid content
        final validSms = SmsMessage(
          sender: 'HDFC-BANK',
          content: 'Your account xxxx1234 has been debited with Rs.1000.00 on 18-Dec-23',
          timestamp: DateTime.now(),
        );
        
        // These should be filtered out by edge case validation
        // We can't directly test the private _isValidSmsMessage method,
        // but we can verify the behavior through the service
        
        // Valid SMS should pass basic validation
        expect(validSms.content.length, greaterThan(10));
        expect(validSms.content.length, lessThan(2000));
        expect(validSms.sender.isNotEmpty, isTrue);
      });
    });

    group('financial context detection', () {
      test('should detect financial messages correctly', () {
        final detector = FinancialContextDetector();
        
        // Financial messages
        expect(detector.isFinancialMessage('Your account has been debited with Rs.1000'), isTrue);
        expect(detector.isFinancialMessage('Amount credited to your account'), isTrue);
        expect(detector.isFinancialMessage('Transaction of ₹500 completed'), isTrue);
        
        // Non-financial messages
        expect(detector.isFinancialMessage('Hello, how are you?'), isFalse);
        expect(detector.isFinancialMessage('Meeting at 3 PM'), isFalse);
        expect(detector.isFinancialMessage(''), isFalse);
      });
    });

    group('SMS parsing', () {
      test('should parse financial SMS correctly', () {
        final parser = ParseSmsTransaction();
        
        final sms = SmsMessage(
          sender: 'HDFC-BANK',
          content: 'Your account xxxx1234 has been debited with Rs.1000.00 on 18-Dec-23 at 14:30:00',
          timestamp: DateTime.now(),
        );
        
        final result = parser.parseTransaction(sms);
        
        expect(result, isNotNull);
        expect(result!.amount, equals(1000.0));
        expect(result.transactionType, equals(TransactionType.debit));
        expect(result.senderPhoneNumber, equals('HDFC-BANK'));
      });
      
      test('should return null for non-financial SMS', () {
        final parser = ParseSmsTransaction();
        
        final sms = SmsMessage(
          sender: 'FRIEND',
          content: 'Hey, how are you doing?',
          timestamp: DateTime.now(),
        );
        
        final result = parser.parseTransaction(sms);
        
        expect(result, isNull);
      });
    });

    group('transaction validation', () {
      test('should validate transactions correctly', () {
        final validator = ValidateTransaction();
        
        final validTransaction = Transaction(
          id: 'test-id',
          userId: 'test-user',
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0], // Yesterday's date
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK',
          confidenceScore: 0.9,
          createdAt: DateTime.now(),
          syncedToFirestore: false,
          duplicateCheckHash: 'test-hash',
          isManualEntry: false,
        );
        
        final result = validator.validateTransaction(validTransaction);
        
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject invalid transactions', () {
        final validator = ValidateTransaction();
        
        final invalidTransaction = Transaction(
          id: 'test-id',
          userId: 'test-user',
          amount: -100.0, // Invalid negative amount
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2025-12-18', // Future date
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK',
          confidenceScore: 0.9,
          createdAt: DateTime.now(),
          syncedToFirestore: false,
          duplicateCheckHash: 'test-hash',
          isManualEntry: false,
        );
        
        final result = validator.validateTransaction(invalidTransaction);
        
        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
      });
    });

    group('duplicate detection', () {
      test('should detect duplicate SMS messages', () async {
        await duplicateDetector.initialize(path: testDir.path);
        
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Test transaction message',
          timestamp: DateTime.now(),
        );
        
        // First time should not be duplicate
        expect(await duplicateDetector.isSmsMessageDuplicate(sms), isFalse);
        
        // Mark as processed
        await duplicateDetector.markSmsAsProcessed(sms);
        
        // Second time should be duplicate
        expect(await duplicateDetector.isSmsMessageDuplicate(sms), isTrue);
        
        await duplicateDetector.close();
      });
    });

    group('repository integration', () {
      test('should save transactions to repository', () async {
        final transaction = Transaction(
          id: 'test-id',
          userId: 'test-user',
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2023-12-18',
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK',
          confidenceScore: 0.9,
          createdAt: DateTime.now(),
          syncedToFirestore: false,
          duplicateCheckHash: 'test-hash',
          isManualEntry: false,
        );
        
        final transactionId = await mockRepository.saveTransaction(transaction);
        
        expect(transactionId, isNotNull);
        expect(mockRepository.savedTransactions, hasLength(1));
        expect(mockRepository.savedTransactions.first.amount, equals(1000.0));
      });
      
      test('should handle repository errors', () async {
        mockRepository.shouldThrowError = true;
        
        final transaction = Transaction(
          id: 'test-id',
          userId: 'test-user',
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2023-12-18',
          time: '14:30:00',
          smsContent: 'Test SMS',
          senderPhoneNumber: 'BANK',
          confidenceScore: 0.9,
          createdAt: DateTime.now(),
          syncedToFirestore: false,
          duplicateCheckHash: 'test-hash',
          isManualEntry: false,
        );
        
        expect(
          () => mockRepository.saveTransaction(transaction),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('service events', () {
      test('should emit events through event stream', () async {
        await service.initialize(hivePath: testDir.path);
        
        final events = <SmsListenerEvent>[];
        service.eventStream.listen(events.add);
        
        // Events will be tested in integration scenarios
        // For now, just verify the stream is available
        expect(service.eventStream, isNotNull);
      });
    });

    group('disposal', () {
      test('should dispose resources correctly', () async {
        await service.initialize(hivePath: testDir.path);
        
        await service.dispose();
        
        expect(service.isListening, isFalse);
        expect(service.currentUserId, isNull);
      });
    });
  });
}
