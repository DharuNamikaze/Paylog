import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Data class representing an SMS message received from the platform
class SmsMessage {
  final String sender;
  final String content;
  final DateTime timestamp;
  final String? threadId;

  const SmsMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.threadId,
  });

  factory SmsMessage.fromMap(Map<String, dynamic> map) {
    print('🟦 [SmsMessage] Creating from map with keys: ${map.keys.join(', ')}');
    
    return SmsMessage(
      sender: map['sender'] as String? ?? 'Unknown',
      content: map['content'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      threadId: map['threadId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'threadId': threadId,
    };
  }

  @override
  String toString() {
    return 'SmsMessage(sender: $sender, content: $content, timestamp: $timestamp, threadId: $threadId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmsMessage &&
        other.sender == sender &&
        other.content == content &&
        other.timestamp == timestamp &&
        other.threadId == threadId;
  }

  @override
  int get hashCode {
    return sender.hashCode ^
        content.hashCode ^
        timestamp.hashCode ^
        threadId.hashCode;
  }
}

/// Exception thrown when SMS platform operations fail
class SmsException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const SmsException(this.message, {this.code, this.details});

  @override
  String toString() {
    return 'SmsException: $message${code != null ? ' (code: $code)' : ''}';
  }
}

/// Platform channel for SMS operations on Android
class SmsPlatformChannel {
  static const String _methodChannelName = 'flutter_sms_parser/methods';
  static const String _eventChannelName = 'flutter_sms_parser/sms_stream';

  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);

  StreamSubscription<SmsMessage>? _smsSubscription;
  StreamController<SmsMessage>? _smsController;
  bool _isListening = false;

  /// Stream of incoming SMS messages
  Stream<SmsMessage> get smsStream {
    if (_smsController == null) {
      print('🟦 [SmsPlatformChannel] Creating new SMS stream controller');
      _smsController = StreamController<SmsMessage>.broadcast(
        onListen: () {
          print('🟦 [SmsPlatformChannel] Stream listener attached - starting EventChannel');
          _startListening();
        },
        onCancel: () {
          print('🟦 [SmsPlatformChannel] Stream listener cancelled - but keeping EventChannel alive');
          // Don't stop listening to keep receiving SMS in background
          // _stopListening();
        },
      );
      
      // Immediately start listening to ensure we don't miss any SMS
      _startListening();
    }
    return _smsController!.stream;
  }

  /// Check if SMS permissions are granted
  Future<bool> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('checkPermissions');
      if (result is Map) {
        return result['allGranted'] as bool? ?? false;
      }
      return false;
    } on PlatformException catch (e) {
      developer.log(
        'Error checking SMS permissions: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to check SMS permissions: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Request SMS permissions from the user
  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('requestPermissions');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error requesting SMS permissions: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to request SMS permissions: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Start listening for SMS messages
  Future<void> startListening() async {
    if (_isListening) {
      developer.log('SMS listening already started', name: 'SmsPlatformChannel');
      return;
    }

    try {
      // Check permissions first
      final hasPermissions = await checkPermissions();
      if (!hasPermissions) {
        throw const SmsException('SMS permissions not granted');
      }

      // Start listening on the platform side
      await _methodChannel.invokeMethod('startListening');
      _isListening = true;

      developer.log('SMS listening started successfully', name: 'SmsPlatformChannel');
    } on PlatformException catch (e) {
      developer.log(
        'Error starting SMS listening: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to start SMS listening: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Stop listening for SMS messages
  Future<void> stopListening() async {
    if (!_isListening) {
      developer.log('SMS listening already stopped', name: 'SmsPlatformChannel');
      return;
    }

    try {
      await _methodChannel.invokeMethod('stopListening');
      _isListening = false;
      await _smsSubscription?.cancel();
      _smsSubscription = null;

      developer.log('SMS listening stopped successfully', name: 'SmsPlatformChannel');
    } on PlatformException catch (e) {
      developer.log(
        'Error stopping SMS listening: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to stop SMS listening: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Check if currently listening for SMS messages
  bool get isListening => _isListening;

  /// Get debug information about the SMS receiver (Android only)
  Future<Map<String, dynamic>> getReceiverDebugInfo() async {
    try {
      final result = await _methodChannel.invokeMethod('getReceiverDebugInfo');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      developer.log(
        'Error getting receiver debug info: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to get receiver debug info: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Test SMS receiver registration (Android only)
  Future<Map<String, dynamic>> testReceiverRegistration() async {
    try {
      final result = await _methodChannel.invokeMethod('testReceiverRegistration');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      developer.log(
        'Error testing receiver registration: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to test receiver registration: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Test platform channel connectivity (Android only)
  Future<Map<String, dynamic>> testPlatformChannelConnectivity() async {
    try {
      final result = await _methodChannel.invokeMethod('testPlatformChannelConnectivity');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      developer.log(
        'Error testing platform channel connectivity: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to test platform channel connectivity: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Simulate SMS received for testing (Android only)
  Future<Map<String, dynamic>> simulateSmsReceived({
    String? sender,
    String? content,
    int? timestamp,
    String? threadId,
  }) async {
    try {
      final arguments = <String, dynamic>{
        'sender': sender ?? 'TEST-BANK',
        'content': content ?? 'Test SMS: Your account has been debited with Rs.100.00',
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
        'threadId': threadId,
      };
      
      final result = await _methodChannel.invokeMethod('simulateSmsReceived', arguments);
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      developer.log(
        'Error simulating SMS received: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to simulate SMS received: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }

  /// Test SMS data flow through platform channel
  Future<Map<String, dynamic>> testSmsDataFlow() async {
    final testResults = <String, dynamic>{};
    
    try {
      developer.log('Testing SMS data flow through platform channel', name: 'SmsPlatformChannel');
      
      // Test different SMS message formats
      final testMessages = [
        {
          'name': 'bank_debit',
          'data': {
            'sender': 'HDFC-BANK',
            'content': 'Your account XXXXXX1234 has been debited with Rs.500.00 on 17-Dec-25. Available balance: Rs.10,500.00',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'threadId': 'bank-thread-1',
          }
        },
        {
          'name': 'upi_payment',
          'data': {
            'sender': 'PAYTM',
            'content': 'Rs.250 paid to John Doe via UPI. UPI Ref: 123456789. Balance: Rs.9,750',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'threadId': 'upi-thread-1',
          }
        },
        {
          'name': 'empty_content',
          'data': {
            'sender': 'TEST-SENDER',
            'content': '',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'threadId': null,
          }
        },
        {
          'name': 'special_characters',
          'data': {
            'sender': 'SPECIAL-BANK',
            'content': 'Transaction: ₹1,000.50 • Account: ****1234 • Date: 17/12/2025 • Balance: ₹15,000.75',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'threadId': 'special-thread-1',
          }
        },
      ];
      
      for (final testMessage in testMessages) {
        final messageName = testMessage['name'] as String;
        final messageData = testMessage['data'] as Map<String, dynamic>;
        
        try {
          // Test SMS message creation and serialization
          final smsMessage = SmsMessage.fromMap(messageData);
          final serializedData = smsMessage.toMap();
          
          // Verify data integrity
          final dataIntegrityCheck = {
            'sender_match': smsMessage.sender == messageData['sender'],
            'content_match': smsMessage.content == messageData['content'],
            'timestamp_match': smsMessage.timestamp.millisecondsSinceEpoch == messageData['timestamp'],
            'thread_id_match': smsMessage.threadId == messageData['threadId'],
          };
          
          final allFieldsMatch = dataIntegrityCheck.values.every((match) => match);
          
          testResults[messageName] = {
            'success': allFieldsMatch,
            'data_integrity': dataIntegrityCheck,
            'original_data': messageData,
            'parsed_message': {
              'sender': smsMessage.sender,
              'content': smsMessage.content,
              'timestamp': smsMessage.timestamp.millisecondsSinceEpoch,
              'threadId': smsMessage.threadId,
            },
            'serialized_data': serializedData,
          };
          
        } catch (e) {
          testResults[messageName] = {
            'success': false,
            'error': e.toString(),
            'original_data': messageData,
          };
        }
      }
      
      // Calculate overall success rate
      final successfulTests = testResults.values
          .where((result) => result is Map && result['success'] == true)
          .length;
      final totalTests = testMessages.length;
      
      testResults['summary'] = {
        'total_tests': totalTests,
        'successful_tests': successfulTests,
        'success_rate': successfulTests / totalTests,
        'overall_success': successfulTests == totalTests,
      };
      
      developer.log('SMS data flow test completed: $successfulTests/$totalTests tests passed', name: 'SmsPlatformChannel');
      return testResults;
      
    } catch (e) {
      developer.log('SMS data flow test failed: $e', name: 'SmsPlatformChannel', error: e);
      testResults['fatal_error'] = e.toString();
      testResults['overall_success'] = false;
      return testResults;
    }
  }

  /// Internal method to start the event stream
  void _startListening() {
    if (_smsSubscription != null) return;

    print('🟦 [SmsPlatformChannel] Starting SMS event stream');
    developer.log('Starting SMS event stream', name: 'SmsPlatformChannel');

    _smsSubscription = _eventChannel
        .receiveBroadcastStream()
        .map<SmsMessage>((dynamic event) {
      try {
        print('🟦 [SmsPlatformChannel] Received SMS event from native: $event');
        if (event is Map) {
          // Convert to Map<String, dynamic> to handle any map type
          final eventMap = Map<String, dynamic>.from(event);
          print('🟦 [SmsPlatformChannel] Converting map with keys: ${eventMap.keys.join(', ')}');
          
          final smsMessage = SmsMessage.fromMap(eventMap);
          print('🟦 [SmsPlatformChannel] Parsed SMS: ${smsMessage.sender}, amount check: ${smsMessage.content.contains('Rs.')}');
          return smsMessage;
        } else {
          print('❌ [SmsPlatformChannel] Invalid SMS event format (not a map): $event (type: ${event.runtimeType})');
          developer.log(
            'Received invalid SMS event format: $event',
            name: 'SmsPlatformChannel',
          );
          throw const SmsException('Invalid SMS event format');
        }
      } catch (e) {
        print('❌ [SmsPlatformChannel] Error parsing SMS event: $e');
        developer.log(
          'Error parsing SMS event: $e',
          name: 'SmsPlatformChannel',
          error: e,
        );
        rethrow;
      }
    }).listen(
      (SmsMessage sms) {
        print('✅ [SmsPlatformChannel] SMS successfully received and parsed: ${sms.sender}');
        developer.log(
          'SMS received: ${sms.sender} - ${sms.content.substring(0, sms.content.length > 50 ? 50 : sms.content.length)}...',
          name: 'SmsPlatformChannel',
        );
        _smsController?.add(sms);
        print('✅ [SmsPlatformChannel] SMS added to controller stream');
      },
      onError: (error) {
        print('❌ [SmsPlatformChannel] SMS stream error: $error');
        developer.log(
          'SMS stream error: $error',
          name: 'SmsPlatformChannel',
          error: error,
        );
        _smsController?.addError(
          error is PlatformException
              ? SmsException(
                  'SMS stream error: ${error.message}',
                  code: error.code,
                  details: error.details,
                )
              : SmsException('SMS stream error: $error'),
        );
      },
    );
  }

  /// Internal method to stop the event stream
  void _stopListening() {
    print('🟦 [SmsPlatformChannel] _stopListening called - but keeping connection alive for background SMS');
    developer.log('Stopping SMS event stream', name: 'SmsPlatformChannel');
    
    // DON'T cancel the subscription to keep receiving SMS in background
    // _smsSubscription?.cancel();
    // _smsSubscription = null;
    
    print('🟦 [SmsPlatformChannel] EventChannel subscription kept alive for background operation');
  }

  /// Dispose resources
  void dispose() {
    _smsSubscription?.cancel();
    _smsController?.close();
    _smsController = null;
    _smsSubscription = null;
    _isListening = false;
  }
  
  // ========================================
  // Queue Management Methods
  // ========================================
  
  /// Get all unprocessed SMS messages from the native queue.
  /// Called to process messages that were received while Flutter was not running.
  Future<List<QueuedSmsMessage>> getUnprocessedSms() async {
    try {
      developer.log('Getting unprocessed SMS from native queue', name: 'SmsPlatformChannel');
      
      final result = await _methodChannel.invokeMethod('getUnprocessedSms');
      
      if (result is List) {
        final messages = result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return QueuedSmsMessage.fromMap(map);
        }).toList();
        
        developer.log('Retrieved ${messages.length} unprocessed SMS messages', name: 'SmsPlatformChannel');
        return messages;
      }
      
      return [];
    } on PlatformException catch (e) {
      developer.log(
        'Error getting unprocessed SMS: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to get unprocessed SMS: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }
  
  /// Mark an SMS message as processed in the native queue.
  /// Called after successfully processing a queued message.
  Future<bool> markSmsAsProcessed(String id) async {
    try {
      developer.log('Marking SMS as processed: $id', name: 'SmsPlatformChannel');
      
      final result = await _methodChannel.invokeMethod('markSmsAsProcessed', {'id': id});
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error marking SMS as processed: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to mark SMS as processed: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }
  
  /// Get queue statistics for monitoring.
  Future<QueueStats> getQueueStats() async {
    try {
      developer.log('Getting queue statistics', name: 'SmsPlatformChannel');
      
      final result = await _methodChannel.invokeMethod('getQueueStats');
      
      if (result is Map) {
        return QueueStats.fromMap(Map<String, dynamic>.from(result));
      }
      
      return QueueStats.empty();
    } on PlatformException catch (e) {
      developer.log(
        'Error getting queue stats: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to get queue stats: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }
  
  /// Perform queue cleanup operations.
  Future<Map<String, int>> cleanupQueue() async {
    try {
      developer.log('Performing queue cleanup', name: 'SmsPlatformChannel');
      
      final result = await _methodChannel.invokeMethod('cleanupQueue');
      
      if (result is Map) {
        return Map<String, int>.from(result.map((k, v) => MapEntry(k.toString(), v as int)));
      }
      
      return {};
    } on PlatformException catch (e) {
      developer.log(
        'Error cleaning up queue: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      throw SmsException(
        'Failed to cleanup queue: ${e.message}',
        code: e.code,
        details: e.details,
      );
    }
  }
  
  /// Get device manufacturer for battery optimization guidance.
  Future<DeviceInfo> getDeviceManufacturer() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceManufacturer');
      
      if (result is Map) {
        return DeviceInfo.fromMap(Map<String, dynamic>.from(result));
      }
      
      return DeviceInfo.unknown();
    } on PlatformException catch (e) {
      developer.log(
        'Error getting device manufacturer: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return DeviceInfo.unknown();
    }
  }
  
  /// Request battery optimization exemption.
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await _methodChannel.invokeMethod('requestBatteryOptimizationExemption');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error requesting battery optimization exemption: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return false;
    }
  }
  
  /// Check if battery optimization is ignored.
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final result = await _methodChannel.invokeMethod('isBatteryOptimizationIgnored');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error checking battery optimization status: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return false;
    }
  }
  
  /// Start background SMS monitoring service.
  Future<bool> startBackgroundService() async {
    try {
      final result = await _methodChannel.invokeMethod('startBackgroundService');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error starting background service: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return false;
    }
  }
  
  /// Stop background SMS monitoring service.
  Future<bool> stopBackgroundService() async {
    try {
      final result = await _methodChannel.invokeMethod('stopBackgroundService');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error stopping background service: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return false;
    }
  }
  
  /// Check if background service is running.
  Future<bool> isBackgroundServiceRunning() async {
    try {
      final result = await _methodChannel.invokeMethod('isBackgroundServiceRunning');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'Error checking background service status: ${e.message}',
        name: 'SmsPlatformChannel',
        error: e,
      );
      return false;
    }
  }
}

/// Data class representing a queued SMS message from native storage.
class QueuedSmsMessage {
  final String id;
  final String hash;
  final String sender;
  final String content;
  final DateTime timestamp;
  final DateTime queuedAt;
  final bool processed;

  const QueuedSmsMessage({
    required this.id,
    required this.hash,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.queuedAt,
    required this.processed,
  });

  factory QueuedSmsMessage.fromMap(Map<String, dynamic> map) {
    return QueuedSmsMessage(
      id: map['id'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      sender: map['sender'] as String? ?? 'Unknown',
      content: map['content'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      queuedAt: DateTime.fromMillisecondsSinceEpoch(
        map['queuedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      processed: map['processed'] as bool? ?? false,
    );
  }

  /// Convert to SmsMessage for processing.
  SmsMessage toSmsMessage() {
    return SmsMessage(
      sender: sender,
      content: content,
      timestamp: timestamp,
      threadId: null,
    );
  }

  @override
  String toString() {
    return 'QueuedSmsMessage(id: $id, sender: $sender, processed: $processed)';
  }
}

/// Data class for queue statistics.
class QueueStats {
  final int totalQueued;
  final int unprocessedCount;
  final int processedCount;
  final Duration? oldestUnprocessedAge;
  final Duration? newestUnprocessedAge;

  const QueueStats({
    required this.totalQueued,
    required this.unprocessedCount,
    required this.processedCount,
    this.oldestUnprocessedAge,
    this.newestUnprocessedAge,
  });

  factory QueueStats.fromMap(Map<String, dynamic> map) {
    return QueueStats(
      totalQueued: map['totalQueued'] as int? ?? 0,
      unprocessedCount: map['unprocessedCount'] as int? ?? 0,
      processedCount: map['processedCount'] as int? ?? 0,
      oldestUnprocessedAge: map['oldestUnprocessedAge'] != null
          ? Duration(milliseconds: map['oldestUnprocessedAge'] as int)
          : null,
      newestUnprocessedAge: map['newestUnprocessedAge'] != null
          ? Duration(milliseconds: map['newestUnprocessedAge'] as int)
          : null,
    );
  }

  factory QueueStats.empty() {
    return const QueueStats(
      totalQueued: 0,
      unprocessedCount: 0,
      processedCount: 0,
    );
  }

  @override
  String toString() {
    return 'QueueStats(total: $totalQueued, unprocessed: $unprocessedCount, processed: $processedCount)';
  }
}

/// Data class for device information.
class DeviceInfo {
  final String manufacturer;
  final String model;
  final String brand;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      manufacturer: map['manufacturer'] as String? ?? 'Unknown',
      model: map['model'] as String? ?? 'Unknown',
      brand: map['brand'] as String? ?? 'Unknown',
    );
  }

  factory DeviceInfo.unknown() {
    return const DeviceInfo(
      manufacturer: 'Unknown',
      model: 'Unknown',
      brand: 'Unknown',
    );
  }

  /// Check if device is from a manufacturer known for aggressive battery optimization.
  bool get hasAggressiveBatteryOptimization {
    final lowerManufacturer = manufacturer.toLowerCase();
    return lowerManufacturer.contains('xiaomi') ||
        lowerManufacturer.contains('huawei') ||
        lowerManufacturer.contains('oppo') ||
        lowerManufacturer.contains('vivo') ||
        lowerManufacturer.contains('oneplus') ||
        lowerManufacturer.contains('realme') ||
        lowerManufacturer.contains('samsung');
  }

  @override
  String toString() {
    return 'DeviceInfo(manufacturer: $manufacturer, model: $model, brand: $brand)';
  }
}
