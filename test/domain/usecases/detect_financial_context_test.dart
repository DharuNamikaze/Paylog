import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/domain/usecases/detect_financial_context.dart';

void main() {
  group('FinancialContextDetector Tests', () {
    late FinancialContextDetector detector;

    setUp(() {
      detector = FinancialContextDetector();
    });

    group('isFinancialMessage', () {
      test('should return true for messages with credit keywords', () {
        expect(detector.isFinancialMessage('Your account has been credited with Rs. 1000'), true);
        expect(detector.isFinancialMessage('Amount received: 500 rupees'), true);
        expect(detector.isFinancialMessage('Deposit of ₹2000 successful'), true);
      });

      test('should return true for messages with debit keywords', () {
        expect(detector.isFinancialMessage('Your account has been debited with Rs. 1000'), true);
        expect(detector.isFinancialMessage('Amount withdrawn: 500 rupees'), true);
        expect(detector.isFinancialMessage('Payment of ₹2000 successful'), true);
      });

      test('should return false for non-financial messages', () {
        expect(detector.isFinancialMessage('Hello, how are you?'), false);
        expect(detector.isFinancialMessage('Meeting at 3 PM today'), false);
        expect(detector.isFinancialMessage('Happy birthday!'), false);
      });

      test('should return false for empty or whitespace messages', () {
        expect(detector.isFinancialMessage(''), false);
        expect(detector.isFinancialMessage('   '), false);
        expect(detector.isFinancialMessage('\n\t'), false);
      });

      test('should handle case insensitive matching', () {
        expect(detector.isFinancialMessage('CREDITED with Rs. 1000'), true);
        expect(detector.isFinancialMessage('debited WITH rupees 500'), true);
        expect(detector.isFinancialMessage('Account BALANCE updated'), true);
      });
    });

    group('getConfidenceScore', () {
      test('should return 0.0 for empty messages', () {
        expect(detector.getConfidenceScore(''), 0.0);
        expect(detector.getConfidenceScore('   '), 0.0);
      });

      test('should return low score for non-financial messages', () {
        expect(detector.getConfidenceScore('Hello world'), 0.0);
        expect(detector.getConfidenceScore('Meeting today'), 0.0);
      });

      test('should return high score for complete transaction messages', () {
        final score = detector.getConfidenceScore(
          'Your account xxxxxx1234 has been debited with Rs. 1000 on 17-Dec-2023'
        );
        expect(score, greaterThan(0.8));
      });

      test('should return medium score for partial financial messages', () {
        final score = detector.getConfidenceScore('Payment successful');
        expect(score, greaterThan(0.0));
        expect(score, lessThan(0.8));
      });

      test('should cap score at 1.0', () {
        final score = detector.getConfidenceScore(
          'Your account xxxxxx1234 has been debited credited with Rs. amount 1000 rupees payment transaction'
        );
        expect(score, lessThanOrEqualTo(1.0));
      });
    });

    group('extractFinancialKeywords', () {
      test('should extract credit keywords', () {
        final keywords = detector.extractFinancialKeywords('Your account has been credited with amount');
        expect(keywords, contains('credited'));
        expect(keywords, contains('account'));
        expect(keywords, contains('amount'));
      });

      test('should extract debit keywords', () {
        final keywords = detector.extractFinancialKeywords('Amount debited from your account');
        expect(keywords, contains('debited'));
        expect(keywords, contains('account'));
        expect(keywords, contains('amount'));
      });

      test('should return empty list for non-financial messages', () {
        final keywords = detector.extractFinancialKeywords('Hello, how are you?');
        expect(keywords, isEmpty);
      });

      test('should handle case insensitive matching', () {
        final keywords = detector.extractFinancialKeywords('CREDITED with RUPEES');
        expect(keywords, contains('credited'));
        expect(keywords, contains('rupees'));
      });

      test('should remove duplicates', () {
        final keywords = detector.extractFinancialKeywords('credited credited amount amount');
        expect(keywords.where((k) => k == 'credited').length, 1);
        expect(keywords.where((k) => k == 'amount').length, 1);
      });
    });

    group('static keyword getters', () {
      test('should return immutable lists', () {
        final creditKeywords = FinancialContextDetector.getCreditKeywords();
        expect(creditKeywords, contains('credited'));
        expect(creditKeywords, contains('received'));
        
        // Should not be able to modify the returned list
        expect(() => creditKeywords.add('test'), throwsUnsupportedError);
      });

      test('should return debit keywords', () {
        final debitKeywords = FinancialContextDetector.getDebitKeywords();
        expect(debitKeywords, contains('debited'));
        expect(debitKeywords, contains('withdrawn'));
      });

      test('should return amount keywords', () {
        final amountKeywords = FinancialContextDetector.getAmountKeywords();
        expect(amountKeywords, contains('rupees'));
        expect(amountKeywords, contains('₹'));
      });

      test('should return account keywords', () {
        final accountKeywords = FinancialContextDetector.getAccountKeywords();
        expect(accountKeywords, contains('account'));
        expect(accountKeywords, contains('a/c'));
      });

      test('should return all financial keywords', () {
        final allKeywords = FinancialContextDetector.getAllFinancialKeywords();
        expect(allKeywords, contains('credited'));
        expect(allKeywords, contains('debited'));
        expect(allKeywords, contains('rupees'));
        expect(allKeywords, contains('account'));
        expect(allKeywords, contains('transaction'));
      });
    });

    group('real-world SMS examples', () {
      test('should correctly identify HDFC bank SMS', () {
        final sms = 'Dear Customer, your A/c xxxxxx1234 is debited by Rs.1,000.00 on 17-Dec-23. Available balance: Rs.5,000.00. HDFC Bank';
        
        expect(detector.isFinancialMessage(sms), true);
        expect(detector.getConfidenceScore(sms), greaterThan(0.8));
        
        final keywords = detector.extractFinancialKeywords(sms);
        expect(keywords, contains('a/c'));
        expect(keywords, contains('debited'));
        expect(keywords, contains('rs'));
        expect(keywords, contains('balance'));
        expect(keywords, contains('bank'));
      });

      test('should correctly identify ICICI bank SMS', () {
        final sms = 'ICICI Bank: Rs.2,500.00 credited to A/c xxxxxx5678 on 17-Dec-23. Available Bal: Rs.10,000.00';
        
        expect(detector.isFinancialMessage(sms), true);
        expect(detector.getConfidenceScore(sms), greaterThan(0.8));
        
        final keywords = detector.extractFinancialKeywords(sms);
        expect(keywords, contains('bank'));
        expect(keywords, contains('rs'));
        expect(keywords, contains('credited'));
        expect(keywords, contains('a/c'));
      });

      test('should correctly identify UPI transaction SMS', () {
        final sms = 'UPI transaction successful. Rs.500 debited from your account. UPI ID: user@paytm';
        
        expect(detector.isFinancialMessage(sms), true);
        expect(detector.getConfidenceScore(sms), greaterThan(0.7));
        
        final keywords = detector.extractFinancialKeywords(sms);
        expect(keywords, contains('upi'));
        expect(keywords, contains('transaction'));
        expect(keywords, contains('rs'));
        expect(keywords, contains('debited'));
        expect(keywords, contains('account'));
        expect(keywords, contains('paytm'));
      });

      test('should reject promotional messages', () {
        final sms = 'Get 50% off on your next shopping! Visit our store today.';
        
        expect(detector.isFinancialMessage(sms), false);
        expect(detector.getConfidenceScore(sms), lessThanOrEqualTo(0.3));
      });

      test('should reject OTP messages', () {
        final sms = 'Your OTP for login is 123456. Do not share with anyone.';
        
        expect(detector.isFinancialMessage(sms), false);
        expect(detector.getConfidenceScore(sms), lessThanOrEqualTo(0.3));
      });
    });
  });
}