import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/core/utils/account_number_extractor.dart';

void main() {
  group('AccountNumberExtractor', () {
    group('extractAccountNumber', () {
      test('should extract masked account number with x', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Debited from account xxxxxx2323'
        );
        expect(account, 'xxxxxx2323');
      });

      test('should extract masked account number with X', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Credited to A/c XXXX1234'
        );
        expect(account, 'xxxx1234');
      });

      test('should extract masked account number with asterisks', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Transaction from ******5678'
        );
        expect(account, 'xxxxxx5678');
      });

      test('should extract full account number', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'A/c 1234567890 debited'
        );
        expect(account, '1234567890');
      });

      test('should extract account with context keyword', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Account No: 9876543210 credited'
        );
        expect(account, '9876543210');
      });

      test('should extract account with A/c notation', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Your A/c xxxxxx4567 has been debited'
        );
        expect(account, 'xxxxxx4567');
      });

      test('should return null for empty content', () {
        final account = AccountNumberExtractor.extractAccountNumber('');
        expect(account, null);
      });

      test('should return null when no account number found', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Hello this is a test message'
        );
        expect(account, null);
      });

      test('should handle account with hyphens', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'A/c xxxx-xx-1234 debited'
        );
        expect(account, 'xxxxxx1234');
      });

      test('should handle account with spaces', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Account number xxxx xx 5678'
        );
        expect(account, 'xxxxxx5678');
      });
    });

    group('extractAllAccountNumbers', () {
      test('should extract multiple account numbers', () {
        final accounts = AccountNumberExtractor.extractAllAccountNumbers(
          'Transferred from A/c xxxxxx1234 to A/c xxxxxx5678'
        );
        expect(accounts.length, 2);
        expect(accounts, containsAll(['xxxxxx1234', 'xxxxxx5678']));
      });

      test('should return empty list when no accounts found', () {
        final accounts = AccountNumberExtractor.extractAllAccountNumbers(
          'No accounts here'
        );
        expect(accounts, isEmpty);
      });

      test('should not return duplicate accounts', () {
        final accounts = AccountNumberExtractor.extractAllAccountNumbers(
          'A/c xxxxxx1234 debited. Your A/c xxxxxx1234 balance is low'
        );
        expect(accounts.length, 1);
        expect(accounts.first, 'xxxxxx1234');
      });
    });

    group('hasAccountNumber', () {
      test('should return true when account number present', () {
        final hasAccount = AccountNumberExtractor.hasAccountNumber(
          'A/c xxxxxx1234 debited'
        );
        expect(hasAccount, true);
      });

      test('should return false when no account number', () {
        final hasAccount = AccountNumberExtractor.hasAccountNumber(
          'Hello world'
        );
        expect(hasAccount, false);
      });

      test('should return false for empty content', () {
        final hasAccount = AccountNumberExtractor.hasAccountNumber('');
        expect(hasAccount, false);
      });
    });

    group('Multiple account references', () {
      test('should identify primary account near "debited from"', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Debited from A/c xxxxxx1234. Transferred to A/c xxxxxx5678'
        );
        expect(account, 'xxxxxx1234');
      });

      test('should identify primary account near "credited to"', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Transferred from A/c xxxxxx1234 Credited to A/c xxxxxx5678'
        );
        expect(account, 'xxxxxx5678');
      });

      test('should prefer masked account when multiple present', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Transaction details: 1234567890 and xxxxxx5678'
        );
        expect(account, 'xxxxxx5678');
      });
    });

    group('Real-world SMS examples', () {
      test('should parse HDFC Bank SMS', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024'
        );
        expect(account, 'xxxxxx1234');
      });

      test('should parse ICICI Bank SMS', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Your A/c XX1234 is credited with INR 25000.00 on 17-Dec-24'
        );
        expect(account, 'xx1234');
      });

      test('should parse SBI SMS', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Rs 3500 debited from A/c **5678 on 17-DEC-24'
        );
        expect(account, 'xx5678');
      });

      test('should parse Axis Bank SMS', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'INR 12,345.50 credited to your account ending 9012'
        );
        expect(account, '9012');
      });

      test('should parse full account number format', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Account No: 1234567890123 debited with Rs.500'
        );
        expect(account, '1234567890123');
      });

      test('should handle account with no context', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Transaction successful. xxxxxx7890 updated.'
        );
        expect(account, 'xxxxxx7890');
      });
    });

    group('Edge cases', () {
      test('should not extract card numbers (16 digits)', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Card 1234-5678-9012-3456 used for payment'
        );
        // Should not extract card numbers
        expect(account, null);
      });

      test('should handle very short masked accounts', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'A/c xx12 debited'
        );
        expect(account, 'xx12');
      });

      test('should handle long account numbers', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Account 123456789012345678 credited'
        );
        expect(account, '123456789012345678');
      });

      test('should return null for invalid short numbers', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'Code 123 received'
        );
        expect(account, null);
      });

      test('should handle special characters in SMS', () {
        final account = AccountNumberExtractor.extractAccountNumber(
          'A/c: xxxxxx1234 - debited successfully!'
        );
        expect(account, 'xxxxxx1234');
      });
    });

    group('getAccountMatches', () {
      test('should return account matches with positions', () {
        final matches = AccountNumberExtractor.getAccountMatches(
          'Your A/c xxxxxx1234 has been debited'
        );
        expect(matches.length, 1);
        expect(matches.first.account, 'xxxxxx1234');
        expect(matches.first.hasContext, true);
      });

      test('should return empty list when no matches', () {
        final matches = AccountNumberExtractor.getAccountMatches(
          'No account numbers here'
        );
        expect(matches, isEmpty);
      });
    });
  });
}
