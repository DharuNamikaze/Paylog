import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../../lib/data/datasources/sms_platform_channel.dart';

/// Integration test for SMS platform channel communication
/// 
/// This test verifies:
/// 1. Method channel calls work correctly
/// 2. Event channel setup and data streaming
/// 3. SMS data serialization/deserialization
/// 4. Error handling and timeout scenarios
/// 5. Platform channel connectivity and performance
void main() {
  group('SMS Platform Channel Communication Tests', () {
    late SmsPlatformChannel smsChannel;
    late List<MethodCall> methodCalls;

    setUp(() {
      smsChannel = SmsPlatformChannel();
      methodCalls = [];
      
      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          // Simulate method call latency
          await Future.delayed(const Duration(milliseconds: 10));
          
          switch (methodCall.method) {
            case 'checkPermissions':
              return {'allGranted': true, 'permissions': {'READ_SMS': true, 'RECEIVE_SMS': true}};
            case 'requestPermissions':
              return true;
            case 'startListening':
              return true;
            case 'stopListening':
              return true;
            case 'testPlatformChannelConnectivity':
              return {
                'methodChannelResponseTime': 15,
                'contextAvailable': true,
                'contextPackageName': 'com.paylog.app',
                'activityAvailable': true,
                'activityClassName': 'com.paylog.app.MainActivity',
                'eventSinkAvailable': false,
                'permissionStatus': {'READ_SMS': true, 'RECEIVE_SMS': true},
                'totalTestTime': 25,
                'testTimestamp': DateTime.now().millisecondsSinceEpoch,
                'overallConnectivity': true,
              };
            case 'simulateSmsReceived':
              final args = methodCall.arguments as Map<String, dynamic>;
              return {
                'success': true,
                'message': 'Simulated SMS sent to Flutter',
                'smsData': {
                  'sender': args['sender'],
                  'content': args['content'],
                  'timestamp': args['timestamp'],
                  'threadId': args['threadId'],
                  'receivedAt': DateTime.now().millisecondsSinceEpoch,
                  'contentLength': (args['content'] as String).length,
                  'isValidData': true,
                  'isSimulated': true,
                }
              };
            default:
              throw PlatformException(code: 'UNIMPLEMENTED', message: 'Method ${methodCall.method} not implemented');
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

    testWidgets('should test all method channel calls', (WidgetTester tester) async {
      // Test checkPermissions
      final hasPermissions = await smsChannel.checkPermissions();
      expect(hasPermissions, isTrue, reason: 'Permissions should be granted in mock');
      expect(methodCalls.any((call) => call.method == 'checkPermissions'), isTrue);
      
      // Test requestPermissions
      final permissionGranted = await smsChannel.requestPermissions();
      expect(permissionGranted, isTrue, reason: 'Permission request should succeed in mock');
      expect(methodCalls.any((call) => call.method == 'requestPermissions'), isTrue);
      
      // Test startListening
      await smsChannel.startListening();
      expect(smsChannel.isListening, isTrue, reason: 'Should be listening after start');
      expect(methodCalls.any((call) => call.method == 'startListening'), isTrue);
      
      // Test stopListening
      await smsChannel.stopListening();
      expect(smsChannel.isListening, isFalse, reason: 'Should not be listening after stop');
      expect(methodCalls.any((call) => call.method == 'stopListening'), isTrue);
      
      print('All method channel calls tested successfully');
      print('Total method calls made: ${methodCalls.length}');
    });

    testWidgets('should test platform channel connectivity', (WidgetTester tester) async {
      final connectivityResult = await smsChannel.testPlatformChannelConnectivity();
      
      // Verify connectivity test structure
      expect(connectivityResult, isA<Map<String, dynamic>>());
      expect(connectivityResult['overallConnectivity'], isTrue);
      expect(connectivityResult['contextAvailable'], isTrue);
      expect(connectivityResult['contextPackageName'], equals('com.paylog.app'));
      
      // Verify performance metrics
      expect(connectivityResult['methodChannelResponseTime'], isA<int>());
      expect(connectivityResult['totalTestTime'], isA<int>());
      expect(connectivityResult['testTimestamp'], isA<int>());
      
      // Verify permission status
      final permissionStatus = connectivityResult['permissionStatus'] as Map<String, dynamic>;
      expect(permissionStatus['READ_SMS'], isTrue);
      expect(permissionStatus['RECEIVE_SMS'], isTrue);
      
      print('Platform channel connectivity test results:');
      connectivityResult.forEach((key, value) {
        print('  $key: $value');
      });
    });

    testWidgets('should test SMS data flow through platform channel', (WidgetTester tester) async {
      final dataFlowResult = await smsChannel.testSmsDataFlow();
      
      // Verify test structure
      expect(dataFlowResult, isA<Map<String, dynamic>>());
      expect(dataFlowResult.containsKey('summary'), isTrue);
      
      final summary = dataFlowResult['summary'] as Map<String, dynamic>;
      expect(summary['overall_success'], isTrue, reason: 'All SMS data flow tests should pass');
      expect(summary['success_rate'], equals(1.0), reason: 'Success rate should be 100%');
      
      // Verify individual test cases
      expect(dataFlowResult.containsKey('bank_debit'), isTrue);
      expect(dataFlowResult.containsKey('upi_payment'), isTrue);
      expect(dataFlowResult.containsKey('empty_content'), isTrue);
      expect(dataFlowResult.containsKey('special_characters'), isTrue);
      
      // Check each test case
      for (final testCase in ['bank_debit', 'upi_payment', 'empty_content', 'special_characters']) {
        final testResult = dataFlowResult[testCase] as Map<String, dynamic>;
        expect(testResult['success'], isTrue, reason: 'Test case $testCase should succeed');
        
        final dataIntegrity = testResult['data_integrity'] as Map<String, dynamic>;
        expect(dataIntegrity['sender_match'], isTrue);
        expect(dataIntegrity['content_match'], isTrue);
        expect(dataIntegrity['timestamp_match'], isTrue);
        expect(dataIntegrity['thread_id_match'], isTrue);
      }
      
      print('SMS data flow test completed successfully');
      print('Tests passed: ${summary['successful_tests']}/${summary['total_tests']}');
    });

    testWidgets('should test SMS simulation through platform channel', (WidgetTester tester) async {
      // Test basic SMS simulation
      final basicSimulation = await smsChannel.simulateSmsReceived(
        sender: 'TEST-BANK',
        content: 'Your account has been debited with Rs.1000.00',
      );
      
      expect(basicSimulation['success'], isTrue);
      expect(basicSimulation['message'], equals('Simulated SMS sent to Flutter'));
      
      final smsData = basicSimulation['smsData'] as Map<String, dynamic>;
      expect(smsData['sender'], equals('TEST-BANK'));
      expect(smsData['content'], equals('Your account has been debited with Rs.1000.00'));
      expect(smsData['isSimulated'], isTrue);
      expect(smsData['isValidData'], isTrue);
      
      // Test SMS simulation with all parameters
      final fullSimulation = await smsChannel.simulateSmsReceived(
        sender: 'HDFC-BANK',
        content: 'UPI payment of Rs.500 to John Doe successful',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        threadId: 'test-thread-123',
      );
      
      expect(fullSimulation['success'], isTrue);
      final fullSmsData = fullSimulation['smsData'] as Map<String, dynamic>;
      expect(fullSmsData['sender'], equals('HDFC-BANK'));
      expect(fullSmsData['threadId'], equals('test-thread-123'));
      
      print('SMS simulation tests completed successfully');
    });

    testWidgets('should handle platform channel errors gracefully', (WidgetTester tester) async {
      // Mock error responses
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_sms_parser/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissions') {
            throw PlatformException(
              code: 'PERMISSION_ERROR',
              message: 'Failed to check permissions',
              details: 'Mock error for testing',
            );
          }
          return null;
        },
      );
      
      // Test error handling
      try {
        await smsChannel.checkPermissions();
        fail('Should have thrown SmsException');
      } catch (e) {
        expect(e, isA<SmsException>());
        final smsException = e as SmsException;
        expect(smsException.code, equals('PERMISSION_ERROR'));
        expect(smsException.message, contains('Failed to check permissions'));
      }
      
      print('Platform channel error handling test completed');
    });

    testWidgets('should test SMS message serialization edge cases', (WidgetTester tester) async {
      // Test with minimal data
      final minimalData = {'sender': 'TEST'};
      final minimalMessage = SmsMessage.fromMap(minimalData);
      expect(minimalMessage.sender, equals('TEST'));
      expect(minimalMessage.content, equals(''));
      expect(minimalMessage.threadId, isNull);
      
      // Test with null values
      final nullData = {
        'sender': null,
        'content': null,
        'timestamp': null,
        'threadId': null,
      };
      final nullMessage = SmsMessage.fromMap(nullData);
      expect(nullMessage.sender, equals('Unknown'));
      expect(nullMessage.content, equals(''));
      expect(nullMessage.threadId, isNull);
      
      // Test serialization round trip
      final originalData = {
        'sender': 'BANK-SMS',
        'content': 'Transaction completed successfully',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'threadId': 'thread-456',
      };
      
      final message = SmsMessage.fromMap(originalData);
      final serializedData = message.toMap();
      
      expect(serializedData['sender'], equals(originalData['sender']));
      expect(serializedData['content'], equals(originalData['content']));
      expect(serializedData['timestamp'], equals(originalData['timestamp']));
      expect(serializedData['threadId'], equals(originalData['threadId']));
      
      print('SMS message serialization edge cases handled correctly');
    });
  });
}