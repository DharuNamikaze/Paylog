import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../../lib/data/datasources/sms_platform_channel.dart';

/// Integration test for SMS BroadcastReceiver registration and functionality
/// 
/// This test verifies:
/// 1. Platform channel method calls are properly structured
/// 2. SMS data serialization/deserialization works correctly
/// 3. Error handling for platform channel failures
/// 4. SMS message parsing and validation
void main() {
  group('SMS BroadcastReceiver Debug Tests', () {
    late SmsPlatformChannel smsChannel;
    late List<MethodCall> methodCalls;

    setUp(() {
      smsChannel = SmsPlatformChannel();
      methodCalls = [];
      
      // Mock the method channel to avoid actual platform calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          // Return mock responses based on method name
          switch (methodCall.method) {
            case 'testReceiverRegistration':
              return {
                'receiverClassExists': true,
                'receiverClassName': 'com.paylog.app.SmsReceiver',
                'receiverPackage': 'com.paylog.app',
                'manifestRegistrationFound': true,
                'contextPackageName': 'com.paylog.app',
                'totalReceiversInManifest': 1,
              };
            case 'getReceiverDebugInfo':
              return {
                'receiverClass': 'com.paylog.app.SmsReceiver',
                'receiverPackage': 'com.paylog.app',
                'isReceiverRegistered': true,
                'smsReceivedCount': 0,
                'lastSmsProcessedAt': 0,
                'eventSinkAvailable': false,
                'debugEnabled': true,
              };
            case 'checkPermissions':
              return {'allGranted': true, 'permissions': {'READ_SMS': true, 'RECEIVE_SMS': true}};
            case 'startListening':
              return true;
            case 'stopListening':
              return true;
            default:
              throw PlatformException(code: 'UNIMPLEMENTED', message: 'Method not implemented');
          }
        },
      );
    });

    tearDown(() {
      smsChannel.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        null,
      );
    });

    testWidgets('should verify SMS receiver registration in manifest', (WidgetTester tester) async {
      // Test receiver registration
      final registrationResult = await smsChannel.testReceiverRegistration();
      
      // Verify method was called
      expect(methodCalls.any((call) => call.method == 'testReceiverRegistration'), isTrue,
          reason: 'testReceiverRegistration method should be called');
      
      // Verify receiver class exists
      expect(registrationResult['receiverClassExists'], isTrue,
          reason: 'SMS receiver class should exist');
      
      // Verify receiver is registered in manifest
      expect(registrationResult['manifestRegistrationFound'], isTrue,
          reason: 'SMS receiver should be registered in AndroidManifest.xml');
      
      // Verify correct package name
      expect(registrationResult['receiverPackage'], equals('com.paylog.app'),
          reason: 'SMS receiver should use correct package name');
      
      // Verify context package name matches
      expect(registrationResult['contextPackageName'], equals('com.paylog.app'),
          reason: 'Context package name should match application package');
      
      // Log debug information
      print('SMS Receiver Registration Test Results:');
      registrationResult.forEach((key, value) {
        print('  $key: $value');
      });
    });

    testWidgets('should get SMS receiver debug information', (WidgetTester tester) async {
      // Get receiver debug info
      final debugInfo = await smsChannel.getReceiverDebugInfo();
      
      // Verify method was called
      expect(methodCalls.any((call) => call.method == 'getReceiverDebugInfo'), isTrue,
          reason: 'getReceiverDebugInfo method should be called');
      
      // Verify debug info structure
      expect(debugInfo, isA<Map<String, dynamic>>(),
          reason: 'Debug info should be a map');
      
      // Verify required fields exist
      expect(debugInfo.containsKey('receiverClass'), isTrue,
          reason: 'Debug info should contain receiver class');
      expect(debugInfo.containsKey('receiverPackage'), isTrue,
          reason: 'Debug info should contain receiver package');
      expect(debugInfo.containsKey('smsReceivedCount'), isTrue,
          reason: 'Debug info should contain SMS received count');
      expect(debugInfo.containsKey('eventSinkAvailable'), isTrue,
          reason: 'Debug info should contain event sink status');
      
      // Verify correct package
      expect(debugInfo['receiverPackage'], equals('com.paylog.app'),
          reason: 'Receiver should use correct package name');
      
      // Log debug information
      print('SMS Receiver Debug Information:');
      debugInfo.forEach((key, value) {
        print('  $key: $value');
      });
    });

    testWidgets('should verify platform channel method calls work', (WidgetTester tester) async {
      // Test permission check method call
      final hasPermissions = await smsChannel.checkPermissions();
      expect(hasPermissions, isA<bool>(),
          reason: 'Permission check should return boolean');
      
      // Verify method was called
      expect(methodCalls.any((call) => call.method == 'checkPermissions'), isTrue,
          reason: 'checkPermissions method should be called');
      
      print('SMS permissions granted: $hasPermissions');
      
      // Test start listening
      await smsChannel.startListening();
      expect(smsChannel.isListening, isTrue,
          reason: 'SMS listening should be active after start');
      
      // Verify method was called
      expect(methodCalls.any((call) => call.method == 'startListening'), isTrue,
          reason: 'startListening method should be called');
      
      // Test stop listening
      await smsChannel.stopListening();
      expect(smsChannel.isListening, isFalse,
          reason: 'SMS listening should be inactive after stop');
      
      // Verify method was called
      expect(methodCalls.any((call) => call.method == 'stopListening'), isTrue,
          reason: 'stopListening method should be called');
      
      print('SMS start/stop listening methods work correctly');
    });

    testWidgets('should verify SMS message data serialization', (WidgetTester tester) async {
      // Test SMS message creation from map
      final testSmsData = {
        'sender': 'TESTBANK',
        'content': 'Your account has been debited with Rs.500.00',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'threadId': 'thread123',
      };
      
      final smsMessage = SmsMessage.fromMap(testSmsData);
      
      // Verify SMS message fields
      expect(smsMessage.sender, equals('TESTBANK'),
          reason: 'SMS sender should be correctly parsed');
      expect(smsMessage.content, equals('Your account has been debited with Rs.500.00'),
          reason: 'SMS content should be correctly parsed');
      expect(smsMessage.threadId, equals('thread123'),
          reason: 'SMS thread ID should be correctly parsed');
      
      // Test SMS message serialization back to map
      final serializedMap = smsMessage.toMap();
      expect(serializedMap['sender'], equals(testSmsData['sender']),
          reason: 'Serialized sender should match original');
      expect(serializedMap['content'], equals(testSmsData['content']),
          reason: 'Serialized content should match original');
      expect(serializedMap['threadId'], equals(testSmsData['threadId']),
          reason: 'Serialized thread ID should match original');
      
      print('SMS message serialization test passed');
    });

    testWidgets('should handle SMS message parsing edge cases', (WidgetTester tester) async {
      // Test with missing fields
      final incompleteData = {
        'sender': 'TESTBANK',
        // Missing content and timestamp
      };
      
      final smsMessage = SmsMessage.fromMap(incompleteData);
      
      // Verify default values are used
      expect(smsMessage.sender, equals('TESTBANK'),
          reason: 'SMS sender should be parsed correctly');
      expect(smsMessage.content, equals(''),
          reason: 'Missing content should default to empty string');
      expect(smsMessage.threadId, isNull,
          reason: 'Missing thread ID should be null');
      
      // Test with null sender
      final nullSenderData = {
        'sender': null,
        'content': 'Test message',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final nullSenderMessage = SmsMessage.fromMap(nullSenderData);
      expect(nullSenderMessage.sender, equals('Unknown'),
          reason: 'Null sender should default to "Unknown"');
      
      print('SMS message edge case handling test passed');
    });
  });
}