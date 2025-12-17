import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/data/datasources/sms_platform_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsPlatformChannel', () {
    late SmsPlatformChannel smsPlatformChannel;
    late List<MethodCall> methodCalls;
    late List<dynamic> eventStreamData;

    setUp(() {
      smsPlatformChannel = SmsPlatformChannel();
      methodCalls = [];
      eventStreamData = [];

      // Mock method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'checkPermissions':
              return {
                'allGranted': true,
                'permissions': {
                  'android.permission.READ_SMS': true,
                  'android.permission.RECEIVE_SMS': true,
                }
              };
            case 'requestPermissions':
              return true;
            case 'startListening':
              return true;
            case 'stopListening':
              return true;
            default:
              return null;
          }
        },
      );

      // Mock event channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('flutter_sms_parser/sms_stream'),
        MockStreamHandler(eventStreamData),
      );
    });

    tearDown(() {
      smsPlatformChannel.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('flutter_sms_parser/sms_stream'),
        null,
      );
    });

    group('SmsMessage', () {
      test('should create SmsMessage from map correctly', () {
        final map = {
          'sender': '+1234567890',
          'content': 'Test SMS message',
          'timestamp': 1640995200000, // 2022-01-01 00:00:00 UTC
          'threadId': 'thread123',
        };

        final smsMessage = SmsMessage.fromMap(map);

        expect(smsMessage.sender, '+1234567890');
        expect(smsMessage.content, 'Test SMS message');
        expect(smsMessage.timestamp, DateTime.fromMillisecondsSinceEpoch(1640995200000));
        expect(smsMessage.threadId, 'thread123');
      });

      test('should handle missing fields gracefully', () {
        final map = <String, dynamic>{};

        final smsMessage = SmsMessage.fromMap(map);

        expect(smsMessage.sender, 'Unknown');
        expect(smsMessage.content, '');
        expect(smsMessage.threadId, null);
        // timestamp should be close to now
        expect(
          smsMessage.timestamp.difference(DateTime.now()).abs().inSeconds,
          lessThan(5),
        );
      });

      test('should convert to map correctly', () {
        final smsMessage = SmsMessage(
          sender: '+1234567890',
          content: 'Test SMS message',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1640995200000),
          threadId: 'thread123',
        );

        final map = smsMessage.toMap();

        expect(map['sender'], '+1234567890');
        expect(map['content'], 'Test SMS message');
        expect(map['timestamp'], 1640995200000);
        expect(map['threadId'], 'thread123');
      });

      test('should implement equality correctly', () {
        final sms1 = SmsMessage(
          sender: '+1234567890',
          content: 'Test message',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1640995200000),
          threadId: 'thread123',
        );

        final sms2 = SmsMessage(
          sender: '+1234567890',
          content: 'Test message',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1640995200000),
          threadId: 'thread123',
        );

        final sms3 = SmsMessage(
          sender: '+0987654321',
          content: 'Different message',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1640995200000),
          threadId: 'thread123',
        );

        expect(sms1, equals(sms2));
        expect(sms1, isNot(equals(sms3)));
        expect(sms1.hashCode, equals(sms2.hashCode));
      });
    });

    group('Permission Management', () {
      test('should check permissions correctly', () async {
        final hasPermissions = await smsPlatformChannel.checkPermissions();

        expect(hasPermissions, true);
        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'checkPermissions');
      });

      test('should request permissions correctly', () async {
        final granted = await smsPlatformChannel.requestPermissions();

        expect(granted, true);
        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'requestPermissions');
      });

      test('should handle permission check errors', () async {
        // Mock error response
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_sms_parser/methods'),
          (MethodCall methodCall) async {
            throw PlatformException(
              code: 'PERMISSION_ERROR',
              message: 'Permission check failed',
            );
          },
        );

        expect(
          () => smsPlatformChannel.checkPermissions(),
          throwsA(isA<SmsException>()),
        );
      });
    });

    group('SMS Listening', () {
      test('should start listening successfully', () async {
        await smsPlatformChannel.startListening();

        expect(smsPlatformChannel.isListening, true);
        expect(methodCalls.length, 2); // checkPermissions + startListening
        expect(methodCalls[0].method, 'checkPermissions');
        expect(methodCalls[1].method, 'startListening');
      });

      test('should stop listening successfully', () async {
        await smsPlatformChannel.startListening();
        await smsPlatformChannel.stopListening();

        expect(smsPlatformChannel.isListening, false);
        expect(methodCalls.any((call) => call.method == 'stopListening'), true);
      });

      test('should not start listening without permissions', () async {
        // Mock no permissions
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter_sms_parser/methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'checkPermissions') {
              return {'allGranted': false};
            }
            return null;
          },
        );

        expect(
          () => smsPlatformChannel.startListening(),
          throwsA(isA<SmsException>()),
        );
      });

      test('should receive SMS messages through stream', () async {
        final smsData = {
          'sender': 'HDFC-BANK',
          'content': 'Your account has been debited with Rs.1000',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'threadId': null,
        };

        // Add test data to event stream
        eventStreamData.add(smsData);

        final smsStream = smsPlatformChannel.smsStream;
        final receivedSms = await smsStream.first;

        expect(receivedSms.sender, 'HDFC-BANK');
        expect(receivedSms.content, 'Your account has been debited with Rs.1000');
        expect(receivedSms.threadId, null);
      });

      test('should handle invalid SMS event format', () async {
        // Add invalid data to event stream
        eventStreamData.add('invalid_data');

        final smsStream = smsPlatformChannel.smsStream;

        expect(
          smsStream.first,
          throwsA(isA<SmsException>()),
        );
      });
    });

    group('Resource Management', () {
      test('should dispose resources correctly', () {
        smsPlatformChannel.dispose();

        expect(smsPlatformChannel.isListening, false);
        // Stream should be closed after dispose
        expect(() => smsPlatformChannel.smsStream, returnsNormally);
      });
    });
  });
}

class MockStreamHandler implements StreamHandler {
  final List<dynamic> data;
  StreamSink<dynamic>? _sink;

  MockStreamHandler(this.data);

  @override
  void onListen(Object? arguments, StreamSink<dynamic> events) {
    _sink = events;
    // Simulate receiving data
    for (final item in data) {
      events.add(item);
    }
  }

  @override
  void onCancel(Object? arguments) {
    _sink = null;
  }
}