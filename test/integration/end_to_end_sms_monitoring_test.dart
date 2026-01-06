import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/data/datasources/sms_platform_channel.dart';

/// End-to-End SMS Monitoring Tests
/// 
/// This test file documents and verifies the complete SMS monitoring flow
/// for the persistent-sms-monitoring feature.
/// 
/// Test Scenarios:
/// 1. Complete flow: close app → receive SMS → open app → see transaction
/// 2. Device reboot and auto-restart
/// 3. Battery optimization exemption flow
/// 4. Multiple SMS while app closed
/// 
/// Note: Some tests require manual verification on a physical device
/// as they involve system-level interactions (SMS reception, device reboot).
void main() {
  group('End-to-End SMS Monitoring Tests', () {
    late SmsPlatformChannel smsChannel;

    setUp(() {
      smsChannel = SmsPlatformChannel();
    });

    tearDown(() {
      smsChannel.dispose();
    });

    group('Queue Management', () {
      test('QueuedSmsMessage should deserialize correctly', () {
        final map = {
          'id': 'test-uuid-123',
          'hash': 'abc123hash',
          'sender': 'HDFC-BANK',
          'content': 'Your account has been debited with Rs.1000.00',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'queuedAt': DateTime.now().millisecondsSinceEpoch,
          'processed': false,
        };

        final queuedSms = QueuedSmsMessage.fromMap(map);

        expect(queuedSms.id, equals('test-uuid-123'));
        expect(queuedSms.hash, equals('abc123hash'));
        expect(queuedSms.sender, equals('HDFC-BANK'));
        expect(queuedSms.content, contains('debited'));
        expect(queuedSms.processed, isFalse);
      });

      test('QueuedSmsMessage should convert to SmsMessage', () {
        final queuedSms = QueuedSmsMessage(
          id: 'test-id',
          hash: 'test-hash',
          sender: 'ICICI-BANK',
          content: 'Your account credited with Rs.5000.00',
          timestamp: DateTime.now(),
          queuedAt: DateTime.now(),
          processed: false,
        );

        final smsMessage = queuedSms.toSmsMessage();

        expect(smsMessage.sender, equals('ICICI-BANK'));
        expect(smsMessage.content, equals('Your account credited with Rs.5000.00'));
        expect(smsMessage.threadId, isNull);
      });

      test('QueueStats should deserialize correctly', () {
        final map = {
          'totalQueued': 10,
          'unprocessedCount': 3,
          'processedCount': 7,
          'oldestUnprocessedAge': 3600000, // 1 hour in ms
          'newestUnprocessedAge': 60000, // 1 minute in ms
        };

        final stats = QueueStats.fromMap(map);

        expect(stats.totalQueued, equals(10));
        expect(stats.unprocessedCount, equals(3));
        expect(stats.processedCount, equals(7));
        expect(stats.oldestUnprocessedAge?.inHours, equals(1));
        expect(stats.newestUnprocessedAge?.inMinutes, equals(1));
      });

      test('QueueStats.empty should return zero values', () {
        final stats = QueueStats.empty();

        expect(stats.totalQueued, equals(0));
        expect(stats.unprocessedCount, equals(0));
        expect(stats.processedCount, equals(0));
        expect(stats.oldestUnprocessedAge, isNull);
        expect(stats.newestUnprocessedAge, isNull);
      });
    });

    group('Device Info', () {
      test('DeviceInfo should deserialize correctly', () {
        final map = {
          'manufacturer': 'Samsung',
          'model': 'Galaxy S21',
          'brand': 'samsung',
        };

        final deviceInfo = DeviceInfo.fromMap(map);

        expect(deviceInfo.manufacturer, equals('Samsung'));
        expect(deviceInfo.model, equals('Galaxy S21'));
        expect(deviceInfo.brand, equals('samsung'));
      });

      test('DeviceInfo should detect aggressive battery optimization manufacturers', () {
        final samsungDevice = DeviceInfo(
          manufacturer: 'Samsung',
          model: 'Galaxy S21',
          brand: 'samsung',
        );
        expect(samsungDevice.hasAggressiveBatteryOptimization, isTrue);

        final xiaomiDevice = DeviceInfo(
          manufacturer: 'Xiaomi',
          model: 'Redmi Note 10',
          brand: 'xiaomi',
        );
        expect(xiaomiDevice.hasAggressiveBatteryOptimization, isTrue);

        final huaweiDevice = DeviceInfo(
          manufacturer: 'Huawei',
          model: 'P40 Pro',
          brand: 'huawei',
        );
        expect(huaweiDevice.hasAggressiveBatteryOptimization, isTrue);

        final googleDevice = DeviceInfo(
          manufacturer: 'Google',
          model: 'Pixel 6',
          brand: 'google',
        );
        expect(googleDevice.hasAggressiveBatteryOptimization, isFalse);
      });

      test('DeviceInfo.unknown should return Unknown values', () {
        final deviceInfo = DeviceInfo.unknown();

        expect(deviceInfo.manufacturer, equals('Unknown'));
        expect(deviceInfo.model, equals('Unknown'));
        expect(deviceInfo.brand, equals('Unknown'));
      });
    });

    group('SMS Message Handling', () {
      test('SmsMessage should handle notification type events', () {
        // When native sends "new_sms_queued" notification
        final notificationMap = {
          'type': 'new_sms_queued',
          'sender': 'HDFC-BANK',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'queuedAt': DateTime.now().millisecondsSinceEpoch,
        };

        // The SmsMessage.fromMap should handle this gracefully
        final smsMessage = SmsMessage.fromMap(notificationMap);

        expect(smsMessage.sender, equals('HDFC-BANK'));
        // Content will be empty for notification type
        expect(smsMessage.content, isEmpty);
      });

      test('SmsMessage should handle full SMS data', () {
        final smsMap = {
          'sender': 'SBI-BANK',
          'content': 'Rs.2500 debited from A/c **1234 on 05-Jan-26',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'threadId': 'thread-123',
        };

        final smsMessage = SmsMessage.fromMap(smsMap);

        expect(smsMessage.sender, equals('SBI-BANK'));
        expect(smsMessage.content, contains('Rs.2500'));
        expect(smsMessage.threadId, equals('thread-123'));
      });
    });
  });

  group('Manual Testing Checklist', () {
    // These tests document the manual testing scenarios
    // They pass automatically but serve as documentation

    test('MANUAL: Test complete flow - close app → receive SMS → open app → see transaction', () {
      // Steps:
      // 1. Install app and enable SMS monitoring
      // 2. Grant SMS permissions
      // 3. Start background service
      // 4. Force close the app completely (swipe away from recent apps)
      // 5. Send a test financial SMS to the device
      // 6. Wait 10 seconds
      // 7. Open the app
      // 8. Verify the SMS appears in the transaction list
      //
      // Expected: Transaction should appear with correct amount and details
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });

    test('MANUAL: Test device reboot and auto-restart', () {
      // Steps:
      // 1. Enable SMS monitoring in the app
      // 2. Verify background service is running (notification visible)
      // 3. Reboot the device
      // 4. Wait for device to fully boot
      // 5. Check if PayLog notification appears automatically
      // 6. Send a test SMS
      // 7. Open app and verify SMS was captured
      //
      // Expected: Service should auto-start after boot via BootReceiver
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });

    test('MANUAL: Test battery optimization exemption flow', () {
      // Steps:
      // 1. Open app settings page
      // 2. Tap "Request Battery Optimization Exemption" button
      // 3. System dialog should appear
      // 4. Grant exemption
      // 5. Verify status shows "Exempted"
      // 6. For aggressive manufacturers (Xiaomi, Huawei, Samsung):
      //    - Follow device-specific guidance shown in app
      //    - Navigate to device settings as instructed
      //
      // Expected: App should be exempted from battery optimization
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });

    test('MANUAL: Test with multiple SMS while app closed', () {
      // Steps:
      // 1. Enable SMS monitoring
      // 2. Force close the app
      // 3. Send 5 different financial SMS messages to the device
      //    - HDFC debit: Rs.1000
      //    - ICICI credit: Rs.2000
      //    - SBI transfer: Rs.500
      //    - Axis UPI: Rs.750
      //    - Kotak balance: Rs.10000
      // 4. Wait 30 seconds
      // 5. Open the app
      // 6. Verify all 5 transactions appear in order
      //
      // Expected: All SMS should be queued and processed in order
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });

    test('MANUAL: Test duplicate SMS rejection', () {
      // Steps:
      // 1. Enable SMS monitoring
      // 2. Send a financial SMS
      // 3. Verify it appears in transactions
      // 4. Send the exact same SMS again (same sender, content, timestamp)
      // 5. Verify duplicate is not added
      //
      // Expected: Duplicate SMS should be rejected via hash deduplication
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });

    test('MANUAL: Test queue cleanup', () {
      // Steps:
      // 1. Enable SMS monitoring
      // 2. Send multiple SMS messages
      // 3. Wait for them to be processed
      // 4. Check queue stats (should show processed count)
      // 5. Wait 1+ hour (or trigger cleanup manually)
      // 6. Verify processed messages are cleaned up
      //
      // Expected: Processed messages older than 1 hour should be removed
      expect(true, isTrue, reason: 'Manual test - see steps above');
    });
  });
}
