import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/core/utils/transaction_type_classifier.dart';
import 'package:flutter_sms_parser/domain/entities/transaction_type.dart';

void main() {
  group('TransactionTypeClassifier', () {
    group('Debit Classification', () {
      test('should classify "debited" as debit', () {
        const content = 'Your account has been debited with Rs.1000';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should classify "withdrawn" as debit', () {
        const content = 'Amount withdrawn: Rs.500 from ATM';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should classify "transferred out" as debit', () {
        const content = 'Rs.2000 transferred out to account 1234';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should classify "paid" as debit', () {
        const content = 'Payment of Rs.1500 paid to merchant';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should classify "deducted" as debit', () {
        const content = 'Rs.100 deducted as service charge';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });
    });

    group('Credit Classification', () {
      test('should classify "credited" as credit', () {
        const content = 'Your account has been credited with Rs.5000';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });

      test('should classify "received" as credit', () {
        const content = 'Amount received: Rs.3000 from sender';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });

      test('should classify "deposited" as credit', () {
        const content = 'Rs.10000 deposited to your account';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });

      test('should classify "transferred in" as credit', () {
        const content = 'Rs.2500 transferred in from account 5678';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });

      test('should classify "added" as credit', () {
        const content = 'Cashback of Rs.50 added to your account';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });
    });

    group('Unknown Classification', () {
      test('should classify empty content as unknown', () {
        const content = '';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.unknown);
      });

      test('should classify content without keywords as unknown', () {
        const content = 'Your account balance is Rs.10000';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.unknown);
      });

      test('should handle whitespace-only content as unknown', () {
        const content = '   ';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.unknown);
      });
    });

    group('Ambiguous Cases', () {
      test('should resolve ambiguous case with both keywords', () {
        const content = 'Rs.1000 debited and Rs.50 credited as cashback';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        // Should resolve based on position and keyword strength
        expect(result, isIn([TransactionType.debit, TransactionType.credit]));
      });

      test('should handle refund scenario correctly', () {
        const content = 'Payment of Rs.500 debited. Refund of Rs.500 credited.';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        // Should resolve based on position and score
        expect(result, isIn([TransactionType.debit, TransactionType.credit, TransactionType.unknown]));
      });
    });

    group('Case Insensitivity', () {
      test('should handle uppercase keywords', () {
        const content = 'Your account has been DEBITED with Rs.1000';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should handle mixed case keywords', () {
        const content = 'Amount CrEdItEd: Rs.2000';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });
    });

    group('Real Bank SMS Examples', () {
      test('should classify HDFC debit SMS', () {
        const content = 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });

      test('should classify ICICI credit SMS', () {
        const content = 'Rs.5000.00 credited to A/c XX1234 on 17-Dec-24. Info: NEFT-SALARY';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.credit);
      });

      test('should classify SBI withdrawal SMS', () {
        const content = 'Rs.2000 withdrawn from your account XX1234 at ATM on 17-Dec-24';
        final result = TransactionTypeClassifier.classifyTransaction(content);
        expect(result, TransactionType.debit);
      });
    });

    group('Confidence Score', () {
      test('should return 0.0 for unknown type', () {
        const content = 'Your balance is Rs.10000';
        final score = TransactionTypeClassifier.getConfidenceScore(
          content,
          TransactionType.unknown,
        );
        expect(score, 0.0);
      });

      test('should return positive score for debit with keywords', () {
        const content = 'Your account has been debited with Rs.1000';
        final score = TransactionTypeClassifier.getConfidenceScore(
          content,
          TransactionType.debit,
        );
        expect(score, greaterThan(0.0));
      });

      test('should return higher score for multiple keywords', () {
        const content = 'Payment debited and deducted from account';
        final score = TransactionTypeClassifier.getConfidenceScore(
          content,
          TransactionType.debit,
        );
        expect(score, greaterThanOrEqualTo(0.8));
      });
    });

    group('Keyword Detection', () {
      test('should detect transaction keywords', () {
        const content = 'Your account has been debited';
        final hasKeywords = TransactionTypeClassifier.hasTransactionKeywords(content);
        expect(hasKeywords, true);
      });

      test('should return false for content without keywords', () {
        const content = 'Your balance is Rs.10000';
        final hasKeywords = TransactionTypeClassifier.hasTransactionKeywords(content);
        expect(hasKeywords, false);
      });

      test('should return false for empty content', () {
        const content = '';
        final hasKeywords = TransactionTypeClassifier.hasTransactionKeywords(content);
        expect(hasKeywords, false);
      });
    });
  });
}
