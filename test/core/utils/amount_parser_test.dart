import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/core/utils/amount_parser.dart';

void main() {
  group('AmountParser', () {
    group('extractAmount', () {
      test('should extract numeric amount with rupee symbol', () {
        final amount = AmountParser.extractAmount('Debited ₹1,234.56 from account');
        expect(amount, 1234.56);
      });

      test('should extract numeric amount with Rs. prefix', () {
        final amount = AmountParser.extractAmount('Credited Rs.5000 to your account');
        expect(amount, 5000.0);
      });

      test('should extract numeric amount with INR prefix', () {
        final amount = AmountParser.extractAmount('Amount INR 2500.50 received');
        expect(amount, 2500.50);
      });

      test('should extract amount with currency suffix', () {
        final amount = AmountParser.extractAmount('Paid 1500 rupees successfully');
        expect(amount, 1500.0);
      });

      test('should handle word-based amounts', () {
        final amount = AmountParser.extractAmount('One Thousand Rupees debited');
        expect(amount, 1000.0);
      });

      test('should handle complex word amounts', () {
        final amount = AmountParser.extractAmount('Five Thousand Five Hundred rupees');
        expect(amount, 5500.0);
      });

      test('should handle lakh denomination', () {
        final amount = AmountParser.extractAmount('Two Lakh rupees credited');
        expect(amount, 200000.0);
      });

      test('should return null for empty content', () {
        final amount = AmountParser.extractAmount('');
        expect(amount, null);
      });

      test('should return null when no amount found', () {
        final amount = AmountParser.extractAmount('Hello this is a test message');
        expect(amount, null);
      });

      test('should handle multiple amounts and return primary', () {
        final amount = AmountParser.extractAmount(
          'Debited Rs.1500 from account. Available balance Rs.25000'
        );
        expect(amount, 1500.0); // Primary amount near "debited"
      });
    });

    group('extractAllAmounts', () {
      test('should extract all numeric amounts', () {
        final amounts = AmountParser.extractAllAmounts(
          'Debited Rs.1500. Balance Rs.25000'
        );
        expect(amounts.length, 2);
        expect(amounts, containsAll([1500.0, 25000.0]));
      });

      test('should return empty list when no amounts found', () {
        final amounts = AmountParser.extractAllAmounts('No amounts here');
        expect(amounts, isEmpty);
      });
    });

    group('normalizeAmount', () {
      test('should remove currency symbols', () {
        final amount = AmountParser.normalizeAmount('₹1,234.56');
        expect(amount, 1234.56);
      });

      test('should handle Rs. prefix', () {
        final amount = AmountParser.normalizeAmount('Rs.5000');
        expect(amount, 5000.0);
      });

      test('should handle INR prefix', () {
        final amount = AmountParser.normalizeAmount('INR 2500.50');
        expect(amount, 2500.50);
      });
    });

    group('Real-world SMS examples', () {
      test('should parse HDFC Bank SMS', () {
        final amount = AmountParser.extractAmount(
          'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024'
        );
        expect(amount, 1500.0);
      });

      test('should parse ICICI Bank SMS', () {
        final amount = AmountParser.extractAmount(
          'Your A/c XX1234 is credited with INR 25000.00 on 17-Dec-24'
        );
        expect(amount, 25000.0);
      });

      test('should parse SBI SMS', () {
        final amount = AmountParser.extractAmount(
          'Rs 3500 debited from A/c **5678 on 17-DEC-24'
        );
        expect(amount, 3500.0);
      });

      test('should parse Axis Bank SMS', () {
        final amount = AmountParser.extractAmount(
          'INR 12,345.50 credited to your account ending 9012'
        );
        expect(amount, 12345.50);
      });
    });
  });
}
