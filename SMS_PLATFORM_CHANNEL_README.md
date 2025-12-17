# SMS Platform Channel Implementation

This document explains the SMS platform channel implementation for the Flutter SMS Transaction Parser.

## Overview

The SMS platform channel enables the Flutter app to intercept and process incoming SMS messages on Android devices. It consists of three main components:

1. **Android Native Code** - BroadcastReceiver and Plugin for SMS interception
2. **Flutter Platform Channel** - Dart code for communication with native Android
3. **SMS Message Processing** - Data structures and stream handling

## Components Implemented

### 1. Android Native Components

#### SmsReceiver.kt
- **Location**: `android/app/src/main/kotlin/com/example/flutter_sms_parser/SmsReceiver.kt`
- **Purpose**: BroadcastReceiver that intercepts SMS messages using Android's SMS_RECEIVED_ACTION
- **Key Features**:
  - Extracts sender phone number, message content, and timestamp
  - Handles multiple SMS parts (for long messages)
  - Sends SMS data to Flutter via EventChannel
  - Error handling and logging

#### SmsPlugin.kt
- **Location**: `android/app/src/main/kotlin/com/example/flutter_sms_parser/SmsPlugin.kt`
- **Purpose**: Flutter plugin that manages SMS permissions and platform communication
- **Key Features**:
  - Permission management (READ_SMS, RECEIVE_SMS)
  - Method channel for Flutter-to-Android communication
  - Event channel for Android-to-Flutter SMS streaming
  - Activity lifecycle management

#### MainActivity.kt
- **Location**: `android/app/src/main/kotlin/com/example/flutter_sms_parser/MainActivity.kt`
- **Purpose**: Registers the SMS plugin with Flutter engine
- **Key Features**:
  - Plugin registration in configureFlutterEngine()

### 2. Flutter Platform Channel

#### SmsPlatformChannel
- **Location**: `lib/data/datasources/sms_platform_channel.dart`
- **Purpose**: Dart interface for SMS operations
- **Key Features**:
  - Permission checking and requesting
  - SMS listening start/stop
  - Stream-based SMS message delivery
  - Error handling with custom SmsException
  - Resource management and disposal

#### SmsMessage Data Class
- **Purpose**: Represents an SMS message with all required fields
- **Fields**:
  - `sender`: Phone number of SMS sender
  - `content`: Full SMS text content
  - `timestamp`: When SMS was received
  - `threadId`: Platform-specific thread identifier (optional)

## Requirements Satisfied

This implementation satisfies the following requirements from the specification:

### Requirement 1.1
✅ **SMS Interception**: The BroadcastReceiver intercepts SMS messages using Flutter platform channels

### Requirement 1.2
✅ **Data Extraction**: The system extracts sender phone number and complete message content
- Sender extracted via `message.originatingAddress`
- Content extracted via `message.messageBody`
- Timestamp extracted via `message.timestampMillis`

### Requirement 1.3
✅ **Processing Speed**: Messages are passed to Flutter within 500ms
- Direct EventChannel streaming ensures minimal latency
- No blocking operations in the BroadcastReceiver

## How It Works

### 1. SMS Reception Flow
```
Incoming SMS → Android BroadcastReceiver → SmsReceiver.kt → EventChannel → Flutter SmsPlatformChannel → SMS Stream
```

### 2. Permission Flow
```
Flutter App → MethodChannel → SmsPlugin.kt → Android Permission System → Result → Flutter App
```

### 3. Lifecycle Management
```
App Start → Request Permissions → Start Listening → Receive SMS Stream → Process Messages → Stop Listening → Cleanup
```

## Usage Example

```dart
// Initialize SMS platform channel
final smsPlatformChannel = SmsPlatformChannel();

// Check and request permissions
final hasPermissions = await smsPlatformChannel.checkPermissions();
if (!hasPermissions) {
  final granted = await smsPlatformChannel.requestPermissions();
  if (!granted) {
    throw Exception('SMS permissions required');
  }
}

// Start listening for SMS messages
await smsPlatformChannel.startListening();

// Subscribe to SMS stream
final subscription = smsPlatformChannel.smsStream.listen(
  (SmsMessage sms) {
    print('SMS from ${sms.sender}: ${sms.content}');
    // Pass to Financial Context Detector (next task)
  },
  onError: (error) {
    print('SMS error: $error');
  },
);

// Cleanup when done
await subscription.cancel();
await smsPlatformChannel.stopListening();
smsPlatformChannel.dispose();
```

## Testing

### Unit Tests
- **Location**: `test/data/datasources/sms_platform_channel_test.dart`
- **Coverage**: 
  - SmsMessage serialization/deserialization
  - Permission management
  - SMS listening lifecycle
  - Error handling
  - Stream processing

### Integration Tests
- **Location**: `test/integration/sms_integration_test.dart`
- **Coverage**:
  - End-to-end SMS processing
  - Multiple bank SMS formats
  - Edge cases (empty content, special characters)
  - Performance requirements (500ms processing)

### Demo Implementation
- **Location**: `lib/data/datasources/sms_platform_demo.dart`
- **Purpose**: Shows how to use the SMS platform channel
- **Features**:
  - Complete initialization flow
  - SMS message handling
  - Error management
  - Resource cleanup
  - Example SMS messages from different banks

## Android Manifest Configuration

The following permissions and receiver are already configured in `AndroidManifest.xml`:

```xml
<!-- SMS permissions -->
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />

<!-- SMS Broadcast Receiver -->
<receiver android:name=".SmsReceiver"
    android:exported="true"
    android:enabled="true">
    <intent-filter android:priority="1000">
        <action android:name="android.provider.Telephony.SMS_RECEIVED" />
    </intent-filter>
</receiver>
```

## Next Steps

This SMS platform channel implementation provides the foundation for:

1. **Task 4**: Financial Context Detector - Will use the SMS stream to identify financial messages
2. **Task 5**: Amount Parser - Will extract transaction amounts from SMS content
3. **Task 6**: Transaction Type Classifier - Will determine debit/credit from SMS content
4. **Task 7**: Account Number Extractor - Will extract account numbers from SMS content
5. **Task 8**: Date-Time Parser - Will extract transaction dates/times from SMS content

## Error Handling

The implementation includes comprehensive error handling:

- **Permission Errors**: Graceful handling of denied permissions
- **Platform Errors**: Proper exception wrapping and logging
- **Stream Errors**: Error propagation through SMS stream
- **Resource Cleanup**: Proper disposal of resources and subscriptions

## Performance Considerations

- **Non-blocking**: BroadcastReceiver operations are non-blocking
- **Stream-based**: Uses Dart streams for efficient message delivery
- **Memory Management**: Proper resource disposal prevents memory leaks
- **Error Recovery**: Robust error handling ensures app stability

## Security Considerations

- **Permission-based**: Requires explicit user permission for SMS access
- **Data Validation**: Input validation for SMS message data
- **Error Logging**: Secure logging without exposing sensitive data
- **Resource Limits**: Proper resource management prevents abuse