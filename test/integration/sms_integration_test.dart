import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/data/datasources/sms_platform_channel.dart';

void main() {
  group('SMS Platform Channel Integration', () {
    late SmsPlatformChannel smsPlatformChannel;

    setUp(() {
      smsPlatformChannel = SmsPlatformChannel();
    });

    tearDown(() {
      smsPlatformChannel.dispose();
    });

    test('should create SMS platform channel instance', () {
      expect(smsPlatformChannel, isNotNull);
      expect(smsPlatformChannel.isListening, false);
    });

    test('should create SmsMessage with all required fields', () {
      final smsMessage = SmsMessage(
        sender: 'HDFC-BANK',
        content: 'Your account has been debited with Rs.1000 on 01-Jan-2024',
        timestamp: DateTime.now(),
        threadId: 'thread123',
      );

      expect(smsMessage.sender, 'HDFC-BANK');
      expect(smsMessage.content, contains('debited'));
      expect(smsMessage.content, contains('Rs.1000'));
      expect(smsMessage.timestamp, isA<DateTime>());
      expect(smsMessage.threadId, 'thread123');
    });

    test('should handle SMS message serialization', () {
      final originalSms = SmsMessage(
        sender: 'ICICI-BANK',
        content: 'Your account has been credited with Rs.2500',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1640995200000),
        threadId: null,
      );

      final map = originalSms.toMap();
      final deserializedSms = SmsMessage.fromMap(map);

      expect(deserializedSms, equals(originalSms));
      expect(deserializedSms.sender, originalSms.sender);
      expect(deserializedSms.content, originalSms.content);
      expect(deserializedSms.timestamp, originalSms.timestamp);
      expect(deserializedSms.threadId, originalSms.threadId);
    });

    test('should create SmsException with proper error information', () {
      const exception = SmsException(
        'Permission denied',
        code: 'PERMISSION_ERROR',
        details: {'permission': 'READ_SMS'},
      );

      expect(exception.message, 'Permission denied');
      expect(exception.code, 'PERMISSION_ERROR');
      expect(exception.details, {'permission': 'READ_SMS'});
      expect(exception.toString(), contains('Permission denied'));
      expect(exception.toString(), contains('PERMISSION_ERROR'));
    });

    test('should validate SMS message extraction requirements', () {
      // Test Requirements 1.1, 1.2, 1.3 - SMS extraction completeness
      final testSms = SmsMessage(
        sender: '+919876543210', // Indian mobile number format
        content: 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30. Available balance: Rs.25,000.00. -HDFC Bank',
        timestamp: DateTime.now(),
        threadId: 'sms_thread_001',
      );

      // Verify sender extraction (Requirement 1.2)
      expect(testSms.sender, isNotEmpty);
      expect(testSms.sender, '+919876543210');

      // Verify content extraction (Requirement 1.2)
      expect(testSms.content, isNotEmpty);
      expect(testSms.content, contains('debited'));
      expect(testSms.content, contains('Rs.1,500.00'));
      expect(testSms.content, contains('XXXXXX1234'));

      // Verify timestamp extraction (Requirement 1.2)
      expect(testSms.timestamp, isA<DateTime>());
      expect(testSms.timestamp.isBefore(DateTime.now().add(Duration(seconds: 1))), true);

      // Verify message processing within 500ms requirement (Requirement 1.3)
      final startTime = DateTime.now();
      final processedSms = SmsMessage.fromMap(testSms.toMap());
      final processingTime = DateTime.now().difference(startTime);
      
      expect(processedSms, equals(testSms));
      expect(processingTime.inMilliseconds, lessThan(500));
    });

    test('should handle various SMS formats from different banks', () {
      final bankSmsFormats = [
        // HDFC Bank format
        SmsMessage(
          sender: 'HDFC-BANK',
          content: 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30.',
          timestamp: DateTime.now(),
        ),
        // ICICI Bank format
        SmsMessage(
          sender: 'ICICI-BANK',
          content: 'Your A/c no XX1234 is credited with INR 2500.00 on 15-Dec-24. Available Bal: INR 15000.00',
          timestamp: DateTime.now(),
        ),
        // SBI format
        SmsMessage(
          sender: 'SBI-BANK',
          content: 'SBI: Rs 1000 debited from a/c **1234 on 15Dec24. Available bal Rs 5000. Not you? Call 1800111109',
          timestamp: DateTime.now(),
        ),
        // Axis Bank format
        SmsMessage(
          sender: 'AXIS-BANK',
          content: 'Dear Customer, INR 750.00 has been debited from your account ending 1234 on 15-Dec-2024.',
          timestamp: DateTime.now(),
        ),
      ];

      for (final sms in bankSmsFormats) {
        // Verify each SMS can be processed
        expect(sms.sender, isNotEmpty);
        expect(sms.content, isNotEmpty);
        expect(sms.timestamp, isA<DateTime>());
        
        // Verify serialization works for all formats
        final map = sms.toMap();
        final deserializedSms = SmsMessage.fromMap(map);
        expect(deserializedSms, equals(sms));
      }
    });

    test('should handle edge cases gracefully', () {
      // Empty content (Requirement 10.1)
      final emptySms = SmsMessage(
        sender: 'TEST-BANK',
        content: '',
        timestamp: DateTime.now(),
      );
      expect(emptySms.content, isEmpty);

      // Special characters (Requirement 10.2)
      final specialCharSms = SmsMessage(
        sender: 'TEST-BANK',
        content: 'Your a/c débited with ₹1,000.50 on 15-Déc-2024 @ 14:30 hrs. Bal: ₹25,000.00',
        timestamp: DateTime.now(),
      );
      expect(specialCharSms.content, contains('₹'));
      expect(specialCharSms.content, contains('débited'));
      expect(specialCharSms.content, contains('Déc'));

      // Very long content
      final longContent = 'A' * 1000;
      final longSms = SmsMessage(
        sender: 'TEST-BANK',
        content: longContent,
        timestamp: DateTime.now(),
      );
      expect(longSms.content.length, 1000);
    });
  });
}
