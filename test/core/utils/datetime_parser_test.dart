import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/core/utils/datetime_parser.dart';

void main() {
  group('DateTimeParser', () {
    // Reference timestamp for testing
    final referenceDate = DateTime(2024, 12, 18, 14, 30, 45);

    group('extractDate', () {
      test('should extract date in DD-MM-YYYY format', () {
        final date = DateTimeParser.extractDate(
          'Transaction on 15-12-2024 was successful',
          referenceDate,
        );
        expect(date, '2024-12-15');
      });

      test('should extract date in DD/MM/YYYY format', () {
        final date = DateTimeParser.extractDate(
          'Payment made on 25/11/2024',
          referenceDate,
        );
        expect(date, '2024-11-25');
      });

      test('should extract date in YYYY-MM-DD format', () {
        final date = DateTimeParser.extractDate(
          'Transaction date: 2024-10-05',
          referenceDate,
        );
        expect(date, '2024-10-05');
      });

      test('should extract date in DD-MM-YY format', () {
        final date = DateTimeParser.extractDate(
          'Debited on 15-12-24',
          referenceDate,
        );
        expect(date, '2024-12-15');
      });

      test('should handle "today" text', () {
        final date = DateTimeParser.extractDate(
          'Transaction completed today',
          referenceDate,
        );
        expect(date, '2024-12-18');
      });

      test('should handle "yesterday" text', () {
        final date = DateTimeParser.extractDate(
          'Payment made yesterday',
          referenceDate,
        );
        expect(date, '2024-12-17');
      });

      test('should handle "tomorrow" text', () {
        final date = DateTimeParser.extractDate(
          'Scheduled for tomorrow',
          referenceDate,
        );
        expect(date, '2024-12-19');
      });

      test('should extract date with month name (short)', () {
        final date = DateTimeParser.extractDate(
          'Transaction on 15th Dec',
          referenceDate,
        );
        expect(date, '2024-12-15');
      });

      test('should extract date with month name (full)', () {
        final date = DateTimeParser.extractDate(
          'Payment on 25 December',
          referenceDate,
        );
        expect(date, '2024-12-25');
      });

      test('should fallback to SMS timestamp when no date found', () {
        final date = DateTimeParser.extractDate(
          'No date in this message',
          referenceDate,
        );
        expect(date, '2024-12-18');
      });

      test('should return SMS timestamp for empty content', () {
        final date = DateTimeParser.extractDate('', referenceDate);
        expect(date, '2024-12-18');
      });

      test('should handle leap year dates', () {
        final date = DateTimeParser.extractDate(
          'Transaction on 29-02-2024',
          referenceDate,
        );
        expect(date, '2024-02-29');
      });

      test('should reject invalid dates', () {
        final date = DateTimeParser.extractDate(
          'Invalid date 32-13-2024',
          referenceDate,
        );
        // Should fallback to reference date
        expect(date, '2024-12-18');
      });
    });

    group('extractTime', () {
      test('should extract time in HH:MM format', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 14:30',
          referenceDate,
        );
        expect(time, '14:30:00');
      });

      test('should extract time in HH:MM:SS format', () {
        final time = DateTimeParser.extractTime(
          'Completed at 09:15:30',
          referenceDate,
        );
        expect(time, '09:15:30');
      });

      test('should extract time with AM', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 09:30 AM',
          referenceDate,
        );
        expect(time, '09:30:00');
      });

      test('should extract time with PM', () {
        final time = DateTimeParser.extractTime(
          'Payment at 02:45 PM',
          referenceDate,
        );
        expect(time, '14:45:00');
      });

      test('should handle 12:00 PM (noon)', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 12:00 PM',
          referenceDate,
        );
        expect(time, '12:00:00');
      });

      test('should handle 12:00 AM (midnight)', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 12:00 AM',
          referenceDate,
        );
        expect(time, '00:00:00');
      });

      test('should handle time with seconds and AM/PM', () {
        final time = DateTimeParser.extractTime(
          'Completed at 11:45:30 PM',
          referenceDate,
        );
        expect(time, '23:45:30');
      });

      test('should fallback to SMS timestamp when no time found', () {
        final time = DateTimeParser.extractTime(
          'No time in this message',
          referenceDate,
        );
        expect(time, '14:30:45');
      });

      test('should return SMS timestamp for empty content', () {
        final time = DateTimeParser.extractTime('', referenceDate);
        expect(time, '14:30:45');
      });

      test('should handle lowercase am/pm', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 03:20 pm',
          referenceDate,
        );
        expect(time, '15:20:00');
      });
    });

    group('extractDateTime', () {
      test('should extract both date and time', () {
        final result = DateTimeParser.extractDateTime(
          'Transaction on 15-12-2024 at 14:30',
          referenceDate,
        );
        expect(result['date'], '2024-12-15');
        expect(result['time'], '14:30:00');
      });

      test('should handle date and time in different formats', () {
        final result = DateTimeParser.extractDateTime(
          'Payment on 25/11/2024 at 09:45 AM',
          referenceDate,
        );
        expect(result['date'], '2024-11-25');
        expect(result['time'], '09:45:00');
      });

      test('should fallback to SMS timestamp for missing values', () {
        final result = DateTimeParser.extractDateTime(
          'No date or time here',
          referenceDate,
        );
        expect(result['date'], '2024-12-18');
        expect(result['time'], '14:30:45');
      });
    });

    group('parseDateTime', () {
      test('should parse complete DateTime from content', () {
        final dateTime = DateTimeParser.parseDateTime(
          'Transaction on 15-12-2024 at 14:30:45',
          referenceDate,
        );
        expect(dateTime.year, 2024);
        expect(dateTime.month, 12);
        expect(dateTime.day, 15);
        expect(dateTime.hour, 14);
        expect(dateTime.minute, 30);
        expect(dateTime.second, 45);
      });

      test('should use SMS timestamp for missing components', () {
        final dateTime = DateTimeParser.parseDateTime(
          'No date or time',
          referenceDate,
        );
        expect(dateTime.year, 2024);
        expect(dateTime.month, 12);
        expect(dateTime.day, 18);
        expect(dateTime.hour, 14);
        expect(dateTime.minute, 30);
        expect(dateTime.second, 45);
      });
    });

    group('normalizeDateString', () {
      test('should normalize DD-MM-YYYY to ISO 8601', () {
        final normalized = DateTimeParser.normalizeDateString(
          '15-12-2024',
          referenceDate,
        );
        expect(normalized, '2024-12-15');
      });

      test('should normalize DD/MM/YYYY to ISO 8601', () {
        final normalized = DateTimeParser.normalizeDateString(
          '25/11/2024',
          referenceDate,
        );
        expect(normalized, '2024-11-25');
      });

      test('should keep ISO 8601 format unchanged', () {
        final normalized = DateTimeParser.normalizeDateString(
          '2024-10-05',
          referenceDate,
        );
        expect(normalized, '2024-10-05');
      });

      test('should return null for empty string', () {
        final normalized = DateTimeParser.normalizeDateString('', referenceDate);
        expect(normalized, null);
      });
    });

    group('normalizeTimeString', () {
      test('should normalize time to HH:MM:SS', () {
        final normalized = DateTimeParser.normalizeTimeString(
          '14:30',
          referenceDate,
        );
        expect(normalized, '14:30:00');
      });

      test('should normalize AM/PM time to 24-hour format', () {
        final normalized = DateTimeParser.normalizeTimeString(
          '02:45 PM',
          referenceDate,
        );
        expect(normalized, '14:45:00');
      });

      test('should return null for empty string', () {
        final normalized = DateTimeParser.normalizeTimeString('', referenceDate);
        expect(normalized, null);
      });
    });

    group('Real-world SMS examples', () {
      test('should parse HDFC Bank SMS', () {
        final content = 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30:45';
        final result = DateTimeParser.extractDateTime(content, referenceDate);
        expect(result['date'], '2024-12-15');
        expect(result['time'], '14:30:45');
      });

      test('should parse ICICI Bank SMS', () {
        final content = 'Your A/c XX1234 is credited with INR 25000.00 on 17-12-24 at 09:15 AM';
        final result = DateTimeParser.extractDateTime(content, referenceDate);
        expect(result['date'], '2024-12-17');
        expect(result['time'], '09:15:00');
      });

      test('should parse SBI SMS', () {
        final content = 'Rs 3500 debited from A/c **5678 on 17-DEC-24 at 11:45 PM';
        final result = DateTimeParser.extractDateTime(content, referenceDate);
        expect(result['date'], '2024-12-17');
        expect(result['time'], '23:45:00');
      });

      test('should parse Axis Bank SMS with date only', () {
        final content = 'INR 12,345.50 credited to your account ending 9012 on 15/12/2024';
        final date = DateTimeParser.extractDate(content, referenceDate);
        expect(date, '2024-12-15');
      });

      test('should handle SMS with "today"', () {
        final content = 'Transaction of Rs.5000 completed today at 10:30 AM';
        final result = DateTimeParser.extractDateTime(content, referenceDate);
        expect(result['date'], '2024-12-18');
        expect(result['time'], '10:30:00');
      });

      test('should handle SMS with "yesterday"', () {
        final content = 'Payment of Rs.2500 was processed yesterday';
        final date = DateTimeParser.extractDate(content, referenceDate);
        expect(date, '2024-12-17');
      });

      test('should fallback to SMS timestamp when date/time not in message', () {
        final content = 'Your transaction was successful';
        final result = DateTimeParser.extractDateTime(content, referenceDate);
        expect(result['date'], '2024-12-18');
        expect(result['time'], '14:30:45');
      });
    });

    group('Edge cases', () {
      test('should handle single-digit day and month', () {
        final date = DateTimeParser.extractDate(
          'Transaction on 5-3-2024',
          referenceDate,
        );
        expect(date, '2024-03-05');
      });

      test('should handle various month name formats', () {
        final dates = [
          DateTimeParser.extractDate('5th Jan', referenceDate),
          DateTimeParser.extractDate('5 January', referenceDate),
          DateTimeParser.extractDate('5th jan', referenceDate),
        ];
        
        for (final date in dates) {
          expect(date, '2024-01-05');
        }
      });

      test('should handle time without seconds', () {
        final time = DateTimeParser.extractTime(
          'Transaction at 14:30',
          referenceDate,
        );
        expect(time, '14:30:00');
      });

      test('should handle 2-digit year conversion', () {
        final date1 = DateTimeParser.extractDate('15-12-24', referenceDate);
        expect(date1, '2024-12-15');
        
        final date2 = DateTimeParser.extractDate('15-12-99', referenceDate);
        expect(date2, '1999-12-15');
      });

      test('should validate date ranges', () {
        // Invalid month
        final invalidMonth = DateTimeParser.extractDate(
          '15-13-2024',
          referenceDate,
        );
        expect(invalidMonth, '2024-12-18'); // Fallback
        
        // Invalid day
        final invalidDay = DateTimeParser.extractDate(
          '32-12-2024',
          referenceDate,
        );
        expect(invalidDay, '2024-12-18'); // Fallback
      });

      test('should handle February 29 in non-leap year', () {
        final date = DateTimeParser.extractDate(
          '29-02-2023',
          referenceDate,
        );
        // Should fallback as 2023 is not a leap year
        expect(date, '2024-12-18');
      });
    });
  });
}
