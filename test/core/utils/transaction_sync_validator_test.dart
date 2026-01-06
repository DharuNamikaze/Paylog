import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/core/utils/transaction_sync_validator.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';

void main() {
  late TransactionSyncValidator validator;

  setUp(() {
    validator = TransactionSyncValidator();
  });

  /// Helper to create a valid transaction for testing
  Transaction createValidTransaction({
    double amount = 1000.0,
    String date = '2026-01-06',
    String time = '14:30:00',
    String smsContent = 'Your account has been debited with Rs.1000',
    String senderPhoneNumber = 'HDFC-BANK',
  }) {
    return Transaction(
      id: 'test-id-123',
      userId: 'user-123',
      createdAt: DateTime.now(),
      syncedToFirestore: false,
      duplicateCheckHash: 'hash123',
      isManualEntry: false,
      amount: amount,
      transactionType: TransactionType.debit,
      accountNumber: 'xxxx1234',
      date: date,
      time: time,
      smsContent: smsContent,
      senderPhoneNumber: senderPhoneNumber,
      confidenceScore: 0.9,
    );
  }

  group('TransactionSyncValidator', () {
    group('validate - full transaction validation', () {
      test('should pass for valid transaction', () {
        final transaction = createValidTransaction();
        final result = validator.validate(transaction);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should collect multiple errors', () {
        final transaction = createValidTransaction(
          amount: -100.0,
          date: '',
          time: '',
          smsContent: '',
          senderPhoneNumber: '',
        );
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors.length, greaterThanOrEqualTo(5));
      });
    });

    group('Amount Validation', () {
      test('should pass for positive amount', () {
        final transaction = createValidTransaction(amount: 100.0);
        final result = validator.validate(transaction);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail for zero amount', () {
        final transaction = createValidTransaction(amount: 0.0);
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Amount must be positive')));
      });

      test('should fail for negative amount', () {
        final transaction = createValidTransaction(amount: -50.0);
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Amount must be positive')));
      });

      test('should warn for amount less than 1', () {
        final transaction = createValidTransaction(amount: 0.5);
        final result = validator.validate(transaction);

        expect(result.isValid, true);
        expect(result.warnings, contains(contains('Amount is less than 1')));
      });

      test('isValidAmount should return true for positive amounts', () {
        expect(validator.isValidAmount(1.0), true);
        expect(validator.isValidAmount(100.0), true);
        expect(validator.isValidAmount(0.01), true);
      });

      test('isValidAmount should return false for non-positive amounts', () {
        expect(validator.isValidAmount(0.0), false);
        expect(validator.isValidAmount(-1.0), false);
      });
    });

    group('Date Validation', () {
      test('should pass for valid date format YYYY-MM-DD', () {
        final transaction = createValidTransaction(date: '2026-01-06');
        final result = validator.validate(transaction);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail for empty date', () {
        final transaction = createValidTransaction(date: '');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Date is required')));
      });

      test('should fail for invalid date format DD/MM/YYYY', () {
        final transaction = createValidTransaction(date: '06/01/2026');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid date format')));
      });

      test('should fail for invalid date format MM-DD-YYYY', () {
        final transaction = createValidTransaction(date: '01-06-2026');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid date format')));
      });

      test('should fail for invalid date value like 2026-02-30', () {
        final transaction = createValidTransaction(date: '2026-02-30');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid date')));
      });

      test('should fail for invalid month', () {
        final transaction = createValidTransaction(date: '2026-13-01');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid date format')));
      });

      test('isValidDateFormat should return true for valid dates', () {
        expect(validator.isValidDateFormat('2026-01-06'), true);
        expect(validator.isValidDateFormat('2025-12-31'), true);
        expect(validator.isValidDateFormat('2024-02-29'), true); // Leap year
      });

      test('isValidDateFormat should return false for invalid dates', () {
        expect(validator.isValidDateFormat(''), false);
        expect(validator.isValidDateFormat('06/01/2026'), false);
        expect(validator.isValidDateFormat('2026-13-01'), false);
        expect(validator.isValidDateFormat('2026-02-30'), false);
      });
    });

    group('Time Validation', () {
      test('should pass for valid time format HH:MM:SS', () {
        final transaction = createValidTransaction(time: '14:30:00');
        final result = validator.validate(transaction);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should pass for midnight time', () {
        final transaction = createValidTransaction(time: '00:00:00');
        final result = validator.validate(transaction);

        expect(result.isValid, true);
      });

      test('should pass for end of day time', () {
        final transaction = createValidTransaction(time: '23:59:59');
        final result = validator.validate(transaction);

        expect(result.isValid, true);
      });

      test('should fail for empty time', () {
        final transaction = createValidTransaction(time: '');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Time is required')));
      });

      test('should fail for invalid time format HH:MM', () {
        final transaction = createValidTransaction(time: '14:30');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('should fail for 12-hour format', () {
        final transaction = createValidTransaction(time: '2:30 PM');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('should fail for invalid hour', () {
        final transaction = createValidTransaction(time: '25:00:00');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('should fail for invalid minute', () {
        final transaction = createValidTransaction(time: '14:60:00');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('should fail for invalid second', () {
        final transaction = createValidTransaction(time: '14:30:60');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('isValidTimeFormat should return true for valid times', () {
        expect(validator.isValidTimeFormat('00:00:00'), true);
        expect(validator.isValidTimeFormat('14:30:45'), true);
        expect(validator.isValidTimeFormat('23:59:59'), true);
      });

      test('isValidTimeFormat should return false for invalid times', () {
        expect(validator.isValidTimeFormat(''), false);
        expect(validator.isValidTimeFormat('14:30'), false);
        expect(validator.isValidTimeFormat('25:00:00'), false);
        expect(validator.isValidTimeFormat('2:30 PM'), false);
      });
    });

    group('SMS Content Validation', () {
      test('should pass for non-empty smsContent', () {
        final transaction = createValidTransaction(
          smsContent: 'Your account has been debited',
        );
        final result = validator.validate(transaction);

        expect(result.isValid, true);
      });

      test('should fail for empty smsContent', () {
        final transaction = createValidTransaction(smsContent: '');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('SMS content is required')));
      });

      test('should fail for whitespace-only smsContent', () {
        final transaction = createValidTransaction(smsContent: '   ');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('SMS content cannot be only whitespace')));
      });

      test('isValidSmsContent should return true for valid content', () {
        expect(validator.isValidSmsContent('Hello'), true);
        expect(validator.isValidSmsContent('  Hello  '), true);
      });

      test('isValidSmsContent should return false for invalid content', () {
        expect(validator.isValidSmsContent(''), false);
        expect(validator.isValidSmsContent('   '), false);
      });
    });

    group('Sender Phone Number Validation', () {
      test('should pass for non-empty senderPhoneNumber', () {
        final transaction = createValidTransaction(
          senderPhoneNumber: 'HDFC-BANK',
        );
        final result = validator.validate(transaction);

        expect(result.isValid, true);
      });

      test('should fail for empty senderPhoneNumber', () {
        final transaction = createValidTransaction(senderPhoneNumber: '');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Sender phone number is required')));
      });

      test('should fail for whitespace-only senderPhoneNumber', () {
        final transaction = createValidTransaction(senderPhoneNumber: '   ');
        final result = validator.validate(transaction);

        expect(result.isValid, false);
        expect(result.errors, contains(contains('Sender phone number cannot be only whitespace')));
      });

      test('isValidSenderPhoneNumber should return true for valid numbers', () {
        expect(validator.isValidSenderPhoneNumber('HDFC-BANK'), true);
        expect(validator.isValidSenderPhoneNumber('+919876543210'), true);
      });

      test('isValidSenderPhoneNumber should return false for invalid numbers', () {
        expect(validator.isValidSenderPhoneNumber(''), false);
        expect(validator.isValidSenderPhoneNumber('   '), false);
      });
    });

    group('validateParsed - ParsedTransaction validation', () {
      test('should pass for valid ParsedTransaction', () {
        final parsed = ParsedTransaction(
          amount: 1000.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: '2026-01-06',
          time: '14:30:00',
          smsContent: 'Your account has been debited',
          senderPhoneNumber: 'HDFC-BANK',
          confidenceScore: 0.9,
        );
        final result = validator.validateParsed(parsed);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail for invalid ParsedTransaction', () {
        final parsed = ParsedTransaction(
          amount: -100.0,
          transactionType: TransactionType.debit,
          accountNumber: 'xxxx1234',
          date: 'invalid',
          time: 'invalid',
          smsContent: '',
          senderPhoneNumber: '',
          confidenceScore: 0.9,
        );
        final result = validator.validateParsed(parsed);

        expect(result.isValid, false);
        expect(result.errors.length, greaterThanOrEqualTo(5));
      });
    });
  });
}
