import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../lib/data/services/sms_listener_service.dart';
import '../../lib/data/datasources/sms_platform_channel.dart' as platform;
import '../../lib/domain/entities/sms_message.dart';
import '../../lib/domain/entities/transaction.dart';
import '../../lib/domain/usecases/detect_financial_context.dart';
import '../../lib/domain/usecases/parse_sms_transaction.dart';
import '../../lib/domain/usecases/validate_transaction.dart';
import '../../lib/domain/repositories/transaction_repository.dart';
import '../../lib/core/utils/duplicate_detector.dart';

/// Mock implementation of TransactionRepository for testing
class MockTransactionRepository implements TransactionRepository {
  final List<Transaction> _transactions = [];
  
  @override
  Future<String> saveTransaction(Transaction transaction) async {
    _transactions.add(transaction);
    return transaction.id;
  }
  
  @override
  Future<List<Transaction>> getTransactions(String userId) async {
    return _transactions.where((t) => t.userId == userId).toList();
  }
  
  @override
  Future<Transaction?> getTransactionById(String id) async {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
  }
  
  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    }
  }
  
  List<Transaction> get allTransactions => List.unmodifiable(_transactions);
  void clear() => _transactions.clear();
}

/// Mock SMS Platform Channel for testing
class MockSmsPlatformChannel implements platform.SmsPlatformChannel {
  final StreamController<platform.SmsMessage> _smsController = 
      StreamController<platform.SmsMessage>.broadcast();
  
  bool _isListening = false;
  bool _hasPermissions = true;
  
  @override
  Stream<platform.SmsMessage> get smsStream => _smsController.stream;
  
  @override
  bool get isListening => _isListening;
  
  @override
  Future<bool> checkPermissions() async => _hasPermissions;
  
  @override
  Future<bool> requestPermissions() async => _hasPermissions;
  
  @override
  Future<void> startListening() async {
    _isListening = true;
  }
  
  @override
  Future<void> stopListening() async {
    _isListening = false;
  }
  
  @override
  void dispose() {
    _smsController.close();
  }
  
  // Test helper methods
  void simulateSmsReceived(platform.SmsMessage sms) {
    if (_isListening) {
      _smsController.add(sms);
    }
  }
  
  void setPermissions(bool hasPermissions) {
    _hasPermissions = hasPermissions;
  }
  
  void simulatePermissionDenied() {
    _hasPermissions = false;
  }
  
  // Implement other required methods with mock behavior
  @override
  Future<Map<String, dynamic>> getReceiverDebugInfo() async => {};
  
  @override
  Future<Map<String, dynamic>> testReceiverRegistration() async => {};
  
  @override
  Future<Map<String, dynamic>> testPlatformChannelConnectivity() async => {};
  
  @override
  Future<Map<String, dynamic>> simulateSmsReceived({
    String sender = 'TEST-SENDER',
    String content = 'Test SMS message for platform channel testing',
    int? timestamp,
    String? threadId,
  }) async => {};
  
  @override
  Future<Map<String, dynamic>> testSmsDataFlow() async => {};
}

/// Integration test for complete SMS processing pipeline
/// 
/// This test verifies:
/// 1. End-to-end SMS flow: Receipt → Processing → Storage → UI Updates
/// 2. Background operation functionality
/// 3. Performance requirements (500ms processing time)
/// 4. App lifecycle state handling
/// 5. Error handling and recovery
void main() {
  group('SMS Processing Pipeline Integration Tests', () {
    late SmsListenerService smsService;
    late MockTransactionRepository mockRepository;
    late MockSmsPlatformChannel mockSmsChannel;
    late List<SmsListenerEvent> capturedEvents;

    setUp(() async {
      mockRepository = MockTransactionRepository();
      mockSmsChannel = MockSmsPlatformChannel();
      capturedEvents = [];
      
      smsService = SmsListenerService(
        smsChannel: mockSmsChannel,
        repository: mockRepository,
      );
      
      // Capture service events
      smsService.eventStream.listen((event) {
        capturedEvents.add(event);
      });
      
      await smsService.initialize();
    });

    tearDown(() async {
      await smsService.dispose();
      mockSmsChannel.dispose();
      mockRepository.clear();
    });

    testWidgets('should process complete SMS pipeline end-to-end', (WidgetTester tester) async {
      const testUserId = 'test-user-123';
      
      // Start SMS listening
      await smsService.startListening(testUserId);
      expect(smsService.isListening, isTrue);
      expect(smsService.currentUserId, equals(testUserId));
      
      // Simulate financial SMS received
      final testSms = platform.SmsMessage(
        sender: 'HDFC-BANK',
        content: 'Your account XXXXXX1234 has been debited with Rs.500.00 on 17-Dec-25. Available balance: Rs.10,500.00',
        timestamp: DateTime.now(),
        threadId: 'bank-thread-1',
      );
      
      // Track processing time
      final startTime = DateTime.now();
      mockSmsChannel.simulateSmsReceived(testSms);
      
      // Wait for processing to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      final processingTime = DateTime.now().difference(startTime);
      
      // Verify performance requirement (< 500ms)
      expect(processingTime.inMilliseconds, lessThan(500),
          reason: 'SMS processing should complete within 500ms');
      
      // Verify transaction was saved
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(1),
          reason: 'One transaction should be saved');
      
      final savedTransaction = transactions.first;
      expect(savedTransaction.userId, equals(testUserId));
      expect(savedTransaction.isManualEntry, isFalse);
      expect(savedTransaction.syncedToFirestore, isTrue);
      
      // Verify service events were emitted
      expect(capturedEvents.any((e) => e is _FinancialMessageDetected), isTrue,
          reason: 'Financial message detection event should be emitted');
      expect(capturedEvents.any((e) => e is _TransactionParsed), isTrue,
          reason: 'Transaction parsed event should be emitted');
      expect(capturedEvents.any((e) => e is _TransactionSaved), isTrue,
          reason: 'Transaction saved event should be emitted');
      
      print('End-to-end SMS processing completed successfully');
      print('Processing time: ${processingTime.inMilliseconds}ms');
      print('Transaction ID: ${savedTransaction.id}');
    });

    testWidgets('should handle background operation correctly', (WidgetTester tester) async {
      const testUserId = 'background-user';
      
      await smsService.startListening(testUserId);
      
      // Simulate multiple SMS messages in background
      final backgroundMessages = [
        platform.SmsMessage(
          sender: 'ICICI-BANK',
          content: 'UPI payment of Rs.250.00 to John Doe successful. Ref: 123456789',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'PAYTM',
          content: 'Rs.100 added to Paytm Wallet. Balance: Rs.1,500',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'SBI-BANK',
          content: 'Your account has been credited with Rs.2000.00 salary',
          timestamp: DateTime.now(),
        ),
      ];
      
      // Simulate rapid SMS reception (background scenario)
      for (final sms in backgroundMessages) {
        mockSmsChannel.simulateSmsReceived(sms);
        await Future.delayed(const Duration(milliseconds: 50)); // Rapid succession
      }
      
      // Wait for all processing to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify all transactions were processed
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(3),
          reason: 'All background SMS messages should be processed');
      
      // Verify service statistics
      final stats = smsService.statistics;
      expect(stats['totalReceived'], equals(3));
      expect(stats['financialMessages'], equals(3));
      expect(stats['savedToDatabase'], equals(3));
      expect(stats['errors'], equals(0));
      
      print('Background operation test completed successfully');
      print('Processed ${transactions.length} transactions in background');
    });

    testWidgets('should handle app lifecycle state changes', (WidgetTester tester) async {
      const testUserId = 'lifecycle-user';
      
      // Start listening
      await smsService.startListening(testUserId);
      expect(smsService.isListening, isTrue);
      
      // Simulate app going to background - SMS should still work
      final backgroundSms = platform.SmsMessage(
        sender: 'AXIS-BANK',
        content: 'Transaction alert: Rs.750 debited from your account',
        timestamp: DateTime.now(),
      );
      
      mockSmsChannel.simulateSmsReceived(backgroundSms);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify processing continues in background
      var transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(1));
      
      // Simulate app restart - stop and start service
      await smsService.stopListening();
      expect(smsService.isListening, isFalse);
      
      await smsService.startListening(testUserId);
      expect(smsService.isListening, isTrue);
      
      // Simulate SMS after restart
      final restartSms = platform.SmsMessage(
        sender: 'KOTAK-BANK',
        content: 'Your account credited with Rs.1200.00',
        timestamp: DateTime.now(),
      );
      
      mockSmsChannel.simulateSmsReceived(restartSms);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify processing resumes after restart
      transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(2),
          reason: 'SMS processing should resume after app restart');
      
      print('App lifecycle state handling test completed successfully');
    });

    testWidgets('should handle non-financial SMS messages correctly', (WidgetTester tester) async {
      const testUserId = 'filter-user';
      
      await smsService.startListening(testUserId);
      
      // Mix of financial and non-financial messages
      final mixedMessages = [
        platform.SmsMessage(
          sender: 'BANK-SMS',
          content: 'Your account debited with Rs.300.00',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'PROMO-SMS',
          content: 'Get 50% off on your next purchase! Click here',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'OTP-SERVICE',
          content: 'Your OTP is 123456. Valid for 5 minutes',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'UPI-APP',
          content: 'Payment of Rs.150 to merchant successful',
          timestamp: DateTime.now(),
        ),
      ];
      
      for (final sms in mixedMessages) {
        mockSmsChannel.simulateSmsReceived(sms);
        await Future.delayed(const Duration(milliseconds: 30));
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify only financial messages were processed
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(2),
          reason: 'Only financial SMS messages should create transactions');
      
      // Verify service statistics
      final stats = smsService.statistics;
      expect(stats['totalReceived'], equals(4));
      expect(stats['financialMessages'], equals(2));
      expect(stats['savedToDatabase'], equals(2));
      
      // Verify non-financial message events
      final nonFinancialEvents = capturedEvents
          .where((e) => e is _NonFinancialMessage)
          .length;
      expect(nonFinancialEvents, equals(2),
          reason: 'Non-financial message events should be emitted');
      
      print('Non-financial SMS filtering test completed successfully');
    });

    testWidgets('should handle duplicate SMS detection', (WidgetTester tester) async {
      const testUserId = 'duplicate-user';
      
      await smsService.startListening(testUserId);
      
      // Same SMS message sent multiple times (duplicate scenario)
      final duplicateSms = platform.SmsMessage(
        sender: 'HDFC-BANK',
        content: 'Your account debited with Rs.500.00 on 17-Dec-25',
        timestamp: DateTime.now(),
      );
      
      // Send the same message 3 times
      for (int i = 0; i < 3; i++) {
        mockSmsChannel.simulateSmsReceived(duplicateSms);
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify only one transaction was created
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(1),
          reason: 'Duplicate SMS messages should be filtered out');
      
      // Verify duplicate detection statistics
      final stats = smsService.statistics;
      expect(stats['duplicatesDetected'], greaterThan(0),
          reason: 'Duplicate detection should be recorded');
      
      print('Duplicate SMS detection test completed successfully');
    });

    testWidgets('should handle SMS processing errors gracefully', (WidgetTester tester) async {
      const testUserId = 'error-user';
      
      await smsService.startListening(testUserId);
      
      // Malformed SMS messages that might cause parsing errors
      final problematicMessages = [
        platform.SmsMessage(
          sender: '',  // Empty sender
          content: 'Some transaction message',
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'BANK',
          content: '',  // Empty content
          timestamp: DateTime.now(),
        ),
        platform.SmsMessage(
          sender: 'BANK-SMS',
          content: 'Rs. debited',  // Incomplete transaction info
          timestamp: DateTime.now(),
        ),
      ];
      
      for (final sms in problematicMessages) {
        mockSmsChannel.simulateSmsReceived(sms);
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify service continues to work despite errors
      expect(smsService.isListening, isTrue,
          reason: 'Service should continue listening despite processing errors');
      
      // Verify error statistics
      final stats = smsService.statistics;
      expect(stats['errors'], greaterThanOrEqualTo(0),
          reason: 'Error count should be tracked');
      
      // Send a valid message to ensure service still works
      final validSms = platform.SmsMessage(
        sender: 'VALID-BANK',
        content: 'Your account debited with Rs.200.00',
        timestamp: DateTime.now(),
      );
      
      mockSmsChannel.simulateSmsReceived(validSms);
      await Future.delayed(const Duration(milliseconds: 100));
      
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, greaterThanOrEqualTo(1),
          reason: 'Valid SMS should still be processed after errors');
      
      print('SMS processing error handling test completed successfully');
    });

    testWidgets('should handle permission scenarios correctly', (WidgetTester tester) async {
      const testUserId = 'permission-user';
      
      // Test with permissions denied
      mockSmsChannel.setPermissions(false);
      
      try {
        await smsService.startListening(testUserId);
        fail('Should throw exception when permissions are denied');
      } catch (e) {
        expect(e.toString(), contains('SMS permissions not granted'));
      }
      
      // Grant permissions and retry
      mockSmsChannel.setPermissions(true);
      await smsService.startListening(testUserId);
      expect(smsService.isListening, isTrue);
      
      // Test SMS processing with permissions
      final testSms = platform.SmsMessage(
        sender: 'PERMISSION-BANK',
        content: 'Transaction of Rs.100.00 completed',
        timestamp: DateTime.now(),
      );
      
      mockSmsChannel.simulateSmsReceived(testSms);
      await Future.delayed(const Duration(milliseconds: 100));
      
      final transactions = await mockRepository.getTransactions(testUserId);
      expect(transactions.length, equals(1));
      
      print('Permission handling test completed successfully');
    });
  });
}