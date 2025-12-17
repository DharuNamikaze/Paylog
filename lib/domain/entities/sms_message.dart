import 'package:json_annotation/json_annotation.dart';

part 'sms_message.g.dart';

/// Represents an SMS message received on the device
@JsonSerializable()
class SmsMessage {
  /// Phone number of the sender
  final String sender;
  
  /// Full SMS text content
  final String content;
  
  /// When the SMS was received
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime timestamp;
  
  /// Platform-specific thread ID (optional)
  final String? threadId;
  
  const SmsMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.threadId,
  });
  
  /// JSON serialization
  factory SmsMessage.fromJson(Map<String, dynamic> json) =>
      _$SmsMessageFromJson(json);
  
  /// JSON deserialization
  Map<String, dynamic> toJson() => _$SmsMessageToJson(this);
  
  /// Helper method to convert DateTime to JSON
  static String _dateTimeToJson(DateTime dateTime) =>
      dateTime.millisecondsSinceEpoch.toString();
  
  /// Helper method to convert JSON to DateTime
  static DateTime _dateTimeFromJson(dynamic json) {
    if (json is String) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(json));
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    throw ArgumentError('Invalid timestamp format: $json');
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsMessage &&
          runtimeType == other.runtimeType &&
          sender == other.sender &&
          content == other.content &&
          timestamp == other.timestamp &&
          threadId == other.threadId;
  
  @override
  int get hashCode =>
      sender.hashCode ^
      content.hashCode ^
      timestamp.hashCode ^
      threadId.hashCode;
  
  @override
  String toString() {
    return 'SmsMessage{sender: $sender, content: $content, timestamp: $timestamp, threadId: $threadId}';
  }
  
  /// Create a copy of this SMS message with updated fields
  SmsMessage copyWith({
    String? sender,
    String? content,
    DateTime? timestamp,
    String? threadId,
  }) {
    return SmsMessage(
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      threadId: threadId ?? this.threadId,
    );
  }
}