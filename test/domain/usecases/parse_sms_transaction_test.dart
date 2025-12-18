import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/domain/entities/sms_message.dart';
import 'package:paylog/domain/entities/transaction_type.dart';
import 'package:paylog/domain/usecases/parse_sms_transaction.dart';

void main() {
  group('ParseSmsTransaction', () {
    late ParseSmsTransaction parser;

    setUp(() {
      parser = ParseSmsTransaction();
    });

    group('parseTransaction', () {
      test('should parse a valid debit transaction SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'HDFC-BANK',
          content: 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30.',
          timestamp: DateTime(2024, 12, 15, 14, 30),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.amount, 1500.00);
        expect(result.transactionType, TransactionType.debit);
        expect(result.accountNumber, isNotNull);
        expect(result.accountNumber, contains('1234'));
        expect(result.date, '2024-12-15');
        expect(result.time, '14:30:00');
        expect(result.senderPhoneNumber, 'HDFC-BANK');
        expect(result.smsContent, sms.content);
        expect(result.confidenceScore, greaterThan(0.5));
      });

      test('should parse a valid credit transaction SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'ICICI-BANK',
          content: 'Your account xxxxxx5678 has been credited with Rs.2,500.00 on 16-Dec-2024.',
          timestamp: DateTime(2024, 12, 16, 10, 15),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.amount, 2500.00);
        expect(result.transactionType, TransactionType.credit);
        expect(result.accountNumber, isNotNull);
        expect(result.accountNumber, contains('5678'));
        expect(result.date, '2024-12-16');
        expect(result.confidenceScore, greaterThan(0.5));
      });

      test('should return null for non-financial SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: '+919876543210',
          content: 'Hey, how are you doing today?',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNull);
      });

      test('should return null when amount cannot be extracted', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Your account has been debited. Please check your balance.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNull);
      });

      test('should handle SMS with word-based amounts', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'SBI',
          content: 'Your account has been credited with One Thousand Rupees on today.',
          timestamp: DateTime(2024, 12, 18, 12, 0),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.amount, 1000.0);
        expect(result.transactionType, TransactionType.credit);
      });

      test('should fallback to SMS timestamp when date/time not in content', () {
        // Arrange
        final timestamp = DateTime(2024, 12, 18, 15, 45, 30);
        final sms = SmsMessage(
          sender: 'AXIS-BANK',
          content: 'Your account has been debited with Rs.500.',
          timestamp: timestamp,
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.date, '2024-12-18');
        expect(result.time, '15:45:30');
      });

      test('should handle unknown transaction type', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Transaction of Rs.1000 processed for your account.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.transactionType, TransactionType.unknown);
      });

      test('should extract masked account numbers correctly', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'HDFC',
          content: 'A/c xxxxxx9012 debited with Rs.750 on 17-Dec-24.',
          timestamp: DateTime(2024, 12, 17),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.accountNumber, contains('9012'));
      });

      test('should handle multiple amounts and extract primary', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Your account has been debited with Rs.1,500.00. Available balance: Rs.25,000.00.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.amount, 1500.00); // Should extract the transaction amount, not balance
      });
    });

    group('parseTransactions', () {
      test('should parse multiple SMS messages', () {
        // Arrange
        final messages = [
          SmsMessage(
            sender: 'HDFC',
            content: 'Debited Rs.500 from account xxxxxx1234.',
            timestamp: DateTime.now(),
          ),
          SmsMessage(
            sender: 'ICICI',
            content: 'Credited Rs.1000 to account xxxxxx5678.',
            timestamp: DateTime.now(),
          ),
          SmsMessage(
            sender: 'Friend',
            content: 'Hey, let\'s meet tomorrow!',
            timestamp: DateTime.now(),
          ),
        ];

        // Act
        final results = parser.parseTransactions(messages);

        // Assert
        expect(results.length, 2); // Only 2 financial messages
        expect(results[0].amount, 500.0);
        expect(results[1].amount, 1000.0);
      });
    });

    group('canParse', () {
      test('should return true for parseable financial SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Your account has been debited with Rs.500.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.canParse(sms);

        // Assert
        expect(result, isTrue);
      });

      test('should return false for non-financial SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'Friend',
          content: 'Hello, how are you?',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.canParse(sms);

        // Assert
        expect(result, isFalse);
      });

      test('should return false for financial SMS without amount', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Your account has been debited. Please check.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.canParse(sms);

        // Assert
        expect(result, isFalse);
      });
    });

    group('getParsingStats', () {
      test('should return correct statistics', () {
        // Arrange
        final messages = [
          SmsMessage(
            sender: 'HDFC',
            content: 'Debited Rs.500 from account.',
            timestamp: DateTime.now(),
          ),
          SmsMessage(
            sender: 'ICICI',
            content: 'Credited Rs.1000 to account.',
            timestamp: DateTime.now(),
          ),
          SmsMessage(
            sender: 'Friend',
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
          SmsMessage(
            sender: 'BANK',
            content: 'Your account has been debited.',
            timestamp: DateTime.now(),
          ),
        ];

        // Act
        final stats = parser.getParsingStats(messages);

        // Assert
        expect(stats['total'], 4);
        expect(stats['parsed'], 2);
        expect(stats['failed'], 1);
        expect(stats['notFinancial'], 1);
        expect(stats['successRate'], '50.00%');
      });
    });

    group('confidence score calculation', () {
      test('should have high confidence for complete transaction SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'HDFC-BANK',
          content: 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30.',
          timestamp: DateTime(2024, 12, 15, 14, 30),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.confidenceScore, greaterThan(0.7));
      });

      test('should have lower confidence for minimal transaction SMS', () {
        // Arrange
        final sms = SmsMessage(
          sender: 'BANK',
          content: 'Transaction of 500 processed.',
          timestamp: DateTime.now(),
        );

        // Act
        final result = parser.parseTransaction(sms);

        // Assert
        expect(result, isNotNull);
        expect(result!.confidenceScore, lessThan(0.7));
      });
    });
  });
}
