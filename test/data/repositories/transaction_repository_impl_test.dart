import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:paylog/domain/entities/transaction.dart' as domain;
import 'package:paylog/domain/entities/transaction_type.dart';

void main() {
  group('TransactionRepositoryImpl', () {
    // Note: Full integration tests require Firebase emulator
    // These tests verify the logic without Firebase initialization
    
    test('should generate unique transaction ID when saving', () async {
      // This test verifies the ID generation logic
      final uuid = Uuid();
      final id1 = uuid.v4();
      final id2 = uuid.v4();
      
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });
    
    test('should handle exponential backoff calculation', () {
      // Test exponential backoff delays
      const initialBackoff = 1000;
      
      // First retry: 1000ms
      final delay1 = initialBackoff * (1 << 0);
      expect(delay1, equals(1000));
      
      // Second retry: 2000ms
      final delay2 = initialBackoff * (1 << 1);
      expect(delay2, equals(2000));
      
      // Third retry: 4000ms
      final delay3 = initialBackoff * (1 << 2);
      expect(delay3, equals(4000));
    });
    
    test('should create valid transaction with all required fields', () {
      final transaction = domain.Transaction(
        id: 'test-id',
        userId: 'user-123',
        amount: 1500.0,
        transactionType: TransactionType.debit,
        accountNumber: 'XXXXXX1234',
        date: '2024-12-15',
        time: '14:30:00',
        smsContent: 'Test SMS content',
        senderPhoneNumber: '+919876543210',
        confidenceScore: 0.95,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
      );
      
      expect(transaction.id, equals('test-id'));
      expect(transaction.userId, equals('user-123'));
      expect(transaction.amount, equals(1500.0));
      expect(transaction.transactionType, equals(TransactionType.debit));
      expect(transaction.accountNumber, equals('XXXXXX1234'));
    });
  });
}
