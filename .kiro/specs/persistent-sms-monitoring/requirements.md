# Requirements Document: Persistent Background SMS Monitoring

## Introduction

The PayLog SMS Transaction Parser app currently loses SMS messages when the app is closed or killed by the system. Users report that transactions are only detected when the app is actively open, and SMS received during periods when the app is closed are never captured. This feature addresses the need for truly persistent SMS monitoring that works regardless of app state, device restarts, or battery optimization.

## Glossary

- **Persistent Monitoring**: SMS monitoring that continues to function even when the Flutter app is not running
- **SMS Queue**: A native Android storage mechanism that holds SMS messages until they can be processed by Flutter
- **Foreground Service**: An Android service that runs with a visible notification and is less likely to be killed
- **Battery Optimization**: Android's power-saving feature that can kill background processes
- **WorkManager**: Android's recommended solution for deferrable, guaranteed background work
- **EventSink**: Flutter's mechanism for streaming data from native code to Dart
- **Native Storage**: Android SharedPreferences or SQLite database for storing data without Flutter
- **Boot Receiver**: Android component that starts services when the device boots up

## Requirements

### Requirement 1

**User Story:** As a user, I want SMS messages to be captured even when the app is completely closed, so that I never miss tracking a financial transaction.

#### Acceptance Criteria

1. WHEN an SMS message arrives and the Flutter engine is not running THEN the SmsReceiver SHALL store the message in native Android storage
2. WHEN the Flutter app is opened after SMS messages were queued THEN the System SHALL process all queued messages and display them in the UI
3. WHEN multiple SMS messages arrive while the app is closed THEN the System SHALL queue all messages in order of receipt
4. WHEN a queued message is successfully processed by Flutter THEN the System SHALL remove it from the native queue

### Requirement 2

**User Story:** As a user, I want SMS monitoring to automatically restart after my device reboots, so that I don't have to manually open the app after every restart.

#### Acceptance Criteria

1. WHEN the device completes booting THEN the BootReceiver SHALL start the SMS monitoring foreground service
2. WHEN the foreground service starts after boot THEN it SHALL display a persistent notification indicating monitoring is active
3. WHEN the app is updated THEN the System SHALL restart SMS monitoring automatically
4. WHEN the foreground service is killed by the system THEN it SHALL restart automatically using START_STICKY

### Requirement 3

**User Story:** As a user, I want the app to request battery optimization exemption, so that Android doesn't kill the SMS monitoring service.

#### Acceptance Criteria

1. WHEN the user enables SMS monitoring for the first time THEN the System SHALL prompt for battery optimization exemption
2. WHEN battery optimization exemption is granted THEN the System SHALL store this status persistently
3. WHEN battery optimization exemption is denied THEN the System SHALL display a warning about potential missed messages
4. WHEN the user opens settings THEN the System SHALL provide a button to request battery optimization exemption

### Requirement 4

**User Story:** As a user, I want to see a persistent notification when SMS monitoring is active, so that I know the service is running.

#### Acceptance Criteria

1. WHEN SMS monitoring is active THEN the System SHALL display a low-priority persistent notification
2. WHEN the notification is tapped THEN the System SHALL open the PayLog app
3. WHEN the notification's stop button is tapped THEN the System SHALL stop SMS monitoring
4. WHEN SMS monitoring is stopped THEN the System SHALL remove the persistent notification

### Requirement 5

**User Story:** As a user, I want queued SMS messages to be processed as soon as I open the app, so that I see all my transactions immediately.

#### Acceptance Criteria

1. WHEN the Flutter app starts THEN the System SHALL check for queued SMS messages in native storage
2. WHEN queued messages exist THEN the System SHALL process them through the normal SMS processing pipeline
3. WHEN processing queued messages THEN the System SHALL maintain the original timestamp of each message
4. WHEN all queued messages are processed THEN the System SHALL clear the native queue

### Requirement 6

**User Story:** As a user, I want the SMS queue to have a reasonable size limit, so that it doesn't consume excessive storage.

#### Acceptance Criteria

1. WHEN the SMS queue reaches 100 messages THEN the System SHALL remove the oldest messages to make room for new ones
2. WHEN a message is older than 7 days in the queue THEN the System SHALL remove it during cleanup
3. WHEN the app starts THEN the System SHALL perform queue cleanup before processing
4. WHEN queue cleanup removes messages THEN the System SHALL log the number of removed messages

### Requirement 7

**User Story:** As a user, I want SMS monitoring to work reliably across different Android versions and manufacturers, so that the feature works on my specific device.

#### Acceptance Criteria

1. WHEN running on Android 8.0+ THEN the System SHALL use foreground service with notification channel
2. WHEN running on devices with aggressive battery optimization (Xiaomi, Huawei, Samsung) THEN the System SHALL provide device-specific guidance
3. WHEN the foreground service type is required (Android 14+) THEN the System SHALL declare dataSync foreground service type
4. WHEN WorkManager is available THEN the System SHALL use it for periodic queue processing as a backup

### Requirement 8

**User Story:** As a developer, I want comprehensive logging for background SMS operations, so that issues can be diagnosed.

#### Acceptance Criteria

1. WHEN an SMS is queued in native storage THEN the System SHALL log the queue operation with timestamp
2. WHEN the Flutter engine reconnects THEN the System SHALL log the number of queued messages found
3. WHEN queue processing fails THEN the System SHALL log detailed error information
4. WHEN the foreground service state changes THEN the System SHALL log the state transition
