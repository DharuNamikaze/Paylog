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
    _smsController ??= StreamController<SmsMessage>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
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

  /// Internal method to start the event stream
  void _startListening() {
    if (_smsSubscription != null) return;

    developer.log('Starting SMS event stream', name: 'SmsPlatformChannel');

    _smsSubscription = _eventChannel
        .receiveBroadcastStream()
        .map<SmsMessage>((dynamic event) {
      try {
        if (event is Map<String, dynamic>) {
          return SmsMessage.fromMap(event);
        } else {
          developer.log(
            'Received invalid SMS event format: $event',
            name: 'SmsPlatformChannel',
          );
          throw const SmsException('Invalid SMS event format');
        }
      } catch (e) {
        developer.log(
          'Error parsing SMS event: $e',
          name: 'SmsPlatformChannel',
          error: e,
        );
        rethrow;
      }
    }).listen(
      (SmsMessage sms) {
        developer.log(
          'SMS received: ${sms.sender} - ${sms.content.substring(0, sms.content.length > 50 ? 50 : sms.content.length)}...',
          name: 'SmsPlatformChannel',
        );
        _smsController?.add(sms);
      },
      onError: (error) {
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
    developer.log('Stopping SMS event stream', name: 'SmsPlatformChannel');
    _smsSubscription?.cancel();
    _smsSubscription = null;
  }

  /// Dispose resources
  void dispose() {
    _smsSubscription?.cancel();
    _smsController?.close();
    _smsController = null;
    _smsSubscription = null;
    _isListening = false;
  }
}