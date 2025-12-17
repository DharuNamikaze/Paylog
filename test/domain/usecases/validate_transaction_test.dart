import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/domain/entities/transaction.dart';
import 'package:flutter_sms_parser/domain/entities/transaction_type.dart';
import 'package:flutter_sms_parser/domain/usecases/validate_transaction.dart';

void main() {
  late ValidateTransaction validator;

  setUp(() {
    validator = ValidateTransaction();
  });

  group('ValidateTransaction', () {
    // Helper to create a valid transaction
    Transaction createValidTransaction() {
      final now = DateTime.now();
      return Transaction(
        id: 'test-id-123',
        userId: 'user-123',
        createdAt: now,
        syncedToFirestore: false,
        duplicateCheckHash: 'hash123',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxx1234',
        date: now.toIso8601String().split('T')[0], // YYYY-MM-DD
        time: '14:30:00',
        smsContent: 'Your account has been debited with Rs.1000',
        senderPhoneNumber: 'HDFC-BANK',
        confidenceScore: 0.9,
      );
    }

    group('Amount Validation', () {
      test('should pass for valid positive amount', () {
        final transaction = createValidTransaction();
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail for negative amount', () {
        final transaction = createValidTransaction().copyWith(amount: -100.0);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Amount must be positive')));
      });

      test('should fail for zero amount', () {
        final transaction = createValidTransaction().copyWith(amount: 0.0);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Amount must be positive')));
      });

      test('should fail for amount exceeding threshold', () {
        final transaction = createValidTransaction().copyWith(amount: 10000001.0);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('exceeds maximum threshold')));
      });

      test('should warn for very small amounts', () {
        final transaction = createValidTransaction().copyWith(amount: 0.5);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings, contains(contains('less than ₹1')));
      });

      test('isValidAmount should return true for valid amounts', () {
        expect(validator.isValidAmount(100.0), true);
        expect(validator.isValidAmount(10000000.0), true);
      });

      test('isValidAmount should return false for invalid amounts', () {
        expect(validator.isValidAmount(0.0), false);
        expect(validator.isValidAmount(-100.0), false);
        expect(validator.isValidAmount(10000001.0), false);
      });
    });

    group('Date Validation', () {
      test('should pass for today\'s date', () {
        final transaction = createValidTransaction();
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail for future date', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final transaction = createValidTransaction().copyWith(
          date: futureDate.toIso8601String().split('T')[0],
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('cannot be in the future')));
      });

      test('should fail for date more than 90 days in past', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 91));
        final transaction = createValidTransaction().copyWith(
          date: oldDate.toIso8601String().split('T')[0],
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('more than 90 days in the past')));
      });

      test('should pass for date exactly 90 days in past', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 90));
        final transaction = createValidTransaction().copyWith(
          date: oldDate.toIso8601String().split('T')[0],
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
      });

      test('should warn for date close to 90 day limit', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 85));
        final transaction = createValidTransaction().copyWith(
          date: oldDate.toIso8601String().split('T')[0],
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings, contains(contains('close to the 90 day limit')));
      });

      test('should fail for invalid date format', () {
        final transaction = createValidTransaction().copyWith(date: '31/12/2023');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid date format')));
      });

      test('isValidDate should return true for valid dates', () {
        final today = DateTime.now().toIso8601String().split('T')[0];
        expect(validator.isValidDate(today), true);
        
        final pastDate = DateTime.now().subtract(const Duration(days: 30))
            .toIso8601String().split('T')[0];
        expect(validator.isValidDate(pastDate), true);
      });

      test('isValidDate should return false for invalid dates', () {
        final futureDate = DateTime.now().add(const Duration(days: 1))
            .toIso8601String().split('T')[0];
        expect(validator.isValidDate(futureDate), false);
        
        final oldDate = DateTime.now().subtract(const Duration(days: 91))
            .toIso8601String().split('T')[0];
        expect(validator.isValidDate(oldDate), false);
        
        expect(validator.isValidDate('invalid-date'), false);
      });
    });

    group('Account Number Validation', () {
      test('should pass for valid masked account number', () {
        final transaction = createValidTransaction();
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
      });

      test('should pass for null account number', () {
        final transaction = createValidTransaction().copyWith(accountNumber: null);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
      });

      test('should warn for very short account number', () {
        final transaction = createValidTransaction().copyWith(accountNumber: 'x12');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings, contains(contains('seems too short')));
      });

      test('should warn for account number without digits or mask', () {
        final transaction = createValidTransaction().copyWith(accountNumber: 'ABCD');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings, contains(contains('does not contain expected digits')));
      });

      test('isValidAccountNumber should return true for valid formats', () {
        expect(validator.isValidAccountNumber('xxxx1234'), true);
        expect(validator.isValidAccountNumber('1234567890'), true);
        expect(validator.isValidAccountNumber(null), true);
        expect(validator.isValidAccountNumber(''), true);
      });

      test('isValidAccountNumber should return false for invalid formats', () {
        expect(validator.isValidAccountNumber('x12'), false);
        expect(validator.isValidAccountNumber('ABC'), false);
      });
    });

    group('Required Fields Validation', () {
      test('should fail for empty transaction ID', () {
        final transaction = createValidTransaction().copyWith(id: '');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Transaction ID is required')));
      });

      test('should fail for empty user ID', () {
        final transaction = createValidTransaction().copyWith(userId: '');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('User ID is required')));
      });

      test('should fail for empty SMS content', () {
        final transaction = createValidTransaction().copyWith(smsContent: '');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('SMS content is required')));
      });

      test('should fail for empty sender phone number', () {
        final transaction = createValidTransaction().copyWith(senderPhoneNumber: '');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Sender phone number is required')));
      });

      test('should fail for invalid time format', () {
        final transaction = createValidTransaction().copyWith(time: '2:30 PM');
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors, contains(contains('Invalid time format')));
      });

      test('should pass for valid time formats', () {
        final validTimes = ['00:00:00', '14:30:45', '23:59:59'];
        
        for (final time in validTimes) {
          final transaction = createValidTransaction().copyWith(time: time);
          final result = validator.validateTransaction(transaction);
          
          expect(result.isValid, true, reason: 'Time $time should be valid');
        }
      });

      test('should fail for confidence score out of range', () {
        final transaction1 = createValidTransaction().copyWith(confidenceScore: -0.1);
        final result1 = validator.validateTransaction(transaction1);
        
        expect(result1.isValid, false);
        expect(result1.errors, contains(contains('Confidence score must be between')));
        
        final transaction2 = createValidTransaction().copyWith(confidenceScore: 1.1);
        final result2 = validator.validateTransaction(transaction2);
        
        expect(result2.isValid, false);
        expect(result2.errors, contains(contains('Confidence score must be between')));
      });

      test('should warn for low confidence score', () {
        final transaction = createValidTransaction().copyWith(confidenceScore: 0.3);
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings, contains(contains('Low confidence score')));
      });
    });

    group('Multiple Validation Errors', () {
      test('should collect multiple errors', () {
        final transaction = createValidTransaction().copyWith(
          amount: -100.0,
          id: '',
          userId: '',
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, false);
        expect(result.errors.length, greaterThanOrEqualTo(3));
      });

      test('should collect both errors and warnings', () {
        final transaction = createValidTransaction().copyWith(
          amount: 0.5, // Warning: less than ₹1
          confidenceScore: 0.3, // Warning: low confidence
        );
        final result = validator.validateTransaction(transaction);
        
        expect(result.isValid, true);
        expect(result.warnings.length, 2);
      });
    });
  });
}
