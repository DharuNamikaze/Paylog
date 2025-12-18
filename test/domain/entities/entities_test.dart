import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/domain/entities/sms_message.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';
import 'package:paylog/domain/entities/validation_result.dart';

void main() {
  group('Entity Tests', () {
    test('TransactionType enum should work correctly', () {
      expect(TransactionType.debit.toJson(), 'debit');
      expect(TransactionType.credit.toJson(), 'credit');
      expect(TransactionType.unknown.toJson(), 'unknown');
      
      expect(TransactionType.fromJson('debit'), TransactionType.debit);
      expect(TransactionType.fromJson('credit'), TransactionType.credit);
      expect(TransactionType.fromJson('unknown'), TransactionType.unknown);
      expect(TransactionType.fromJson('invalid'), TransactionType.unknown);
    });

    test('ValidationResult should create correctly', () {
      final success = ValidationResult.success();
      expect(success.isValid, true);
      expect(success.errors, isEmpty);
      expect(success.warnings, isEmpty);

      final failure = ValidationResult.failure(['Error 1', 'Error 2']);
      expect(failure.isValid, false);
      expect(failure.errors, ['Error 1', 'Error 2']);
      expect(failure.warnings, isEmpty);

      final withWarnings = ValidationResult.withWarnings(['Warning 1']);
      expect(withWarnings.isValid, true);
      expect(withWarnings.errors, isEmpty);
      expect(withWarnings.warnings, ['Warning 1']);
    });

    test('SmsMessage should serialize/deserialize correctly', () {
      final timestamp = DateTime.now();
      final sms = SmsMessage(
        sender: '+1234567890',
        content: 'Test SMS content',
        timestamp: timestamp,
        threadId: 'thread123',
      );

      final json = sms.toJson();
      final restored = SmsMessage.fromJson(json);

      expect(restored.sender, sms.sender);
      expect(restored.content, sms.content);
      expect(restored.timestamp, sms.timestamp);
      expect(restored.threadId, sms.threadId);
    });

    test('ParsedTransaction should serialize/deserialize correctly', () {
      final parsed = ParsedTransaction(
        amount: 1000.50,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxxxx1234',
        date: '2023-12-17',
        time: '14:30:00',
        smsContent: 'Your account has been debited with Rs. 1000.50',
        senderPhoneNumber: 'HDFC-BANK',
        confidenceScore: 0.95,
      );

      final json = parsed.toJson();
      final restored = ParsedTransaction.fromJson(json);

      expect(restored.amount, parsed.amount);
      expect(restored.transactionType, parsed.transactionType);
      expect(restored.accountNumber, parsed.accountNumber);
      expect(restored.date, parsed.date);
      expect(restored.time, parsed.time);
      expect(restored.smsContent, parsed.smsContent);
      expect(restored.senderPhoneNumber, parsed.senderPhoneNumber);
      expect(restored.confidenceScore, parsed.confidenceScore);
    });

    test('Transaction should serialize/deserialize correctly', () {
      final createdAt = DateTime.now();
      final transaction = Transaction(
        id: 'txn123',
        userId: 'user456',
        createdAt: createdAt,
        syncedToFirestore: true,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        amount: 1000.50,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxxxx1234',
        date: '2023-12-17',
        time: '14:30:00',
        smsContent: 'Your account has been debited with Rs. 1000.50',
        senderPhoneNumber: 'HDFC-BANK',
        confidenceScore: 0.95,
      );

      final json = transaction.toJson();
      final restored = Transaction.fromJson(json);

      expect(restored.id, transaction.id);
      expect(restored.userId, transaction.userId);
      expect(restored.createdAt, transaction.createdAt);
      expect(restored.syncedToFirestore, transaction.syncedToFirestore);
      expect(restored.duplicateCheckHash, transaction.duplicateCheckHash);
      expect(restored.isManualEntry, transaction.isManualEntry);
      expect(restored.amount, transaction.amount);
      expect(restored.transactionType, transaction.transactionType);
      expect(restored.accountNumber, transaction.accountNumber);
      expect(restored.date, transaction.date);
      expect(restored.time, transaction.time);
      expect(restored.smsContent, transaction.smsContent);
      expect(restored.senderPhoneNumber, transaction.senderPhoneNumber);
      expect(restored.confidenceScore, transaction.confidenceScore);
    });

    test('Transaction.fromParsedTransaction should work correctly', () {
      final parsed = ParsedTransaction(
        amount: 1000.50,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxxxx1234',
        date: '2023-12-17',
        time: '14:30:00',
        smsContent: 'Your account has been debited with Rs. 1000.50',
        senderPhoneNumber: 'HDFC-BANK',
        confidenceScore: 0.95,
      );

      final createdAt = DateTime.now();
      final transaction = Transaction.fromParsedTransaction(
        id: 'txn123',
        userId: 'user456',
        createdAt: createdAt,
        syncedToFirestore: true,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        parsedTransaction: parsed,
      );

      expect(transaction.id, 'txn123');
      expect(transaction.userId, 'user456');
      expect(transaction.createdAt, createdAt);
      expect(transaction.syncedToFirestore, true);
      expect(transaction.duplicateCheckHash, 'hash123');
      expect(transaction.isManualEntry, false);
      expect(transaction.amount, parsed.amount);
      expect(transaction.transactionType, parsed.transactionType);
      expect(transaction.accountNumber, parsed.accountNumber);
      expect(transaction.date, parsed.date);
      expect(transaction.time, parsed.time);
      expect(transaction.smsContent, parsed.smsContent);
      expect(transaction.senderPhoneNumber, parsed.senderPhoneNumber);
      expect(transaction.confidenceScore, parsed.confidenceScore);
    });
  });
}
