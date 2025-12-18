# Requirements Document: SMS Monitoring Fix

## Introduction

The SMS Transaction Parser app has been successfully built and deployed, but SMS monitoring functionality is not working. Users report that when they perform real transactions and receive SMS notifications, the app does not detect or display these transactions in the UI. This critical issue prevents the core functionality of automatic transaction detection from working.

## Glossary

- **SMS Monitoring**: The process of intercepting and processing incoming SMS messages in real-time
- **Package Name**: The unique identifier for an Android application (e.g., com.paylog.app)
- **BroadcastReceiver**: Android component that listens for system-wide broadcast messages
- **Platform Channel**: Flutter mechanism for communication between Dart and native Android code
- **Native Implementation**: Android-specific code written in Kotlin/Java
- **Manifest Registration**: Declaration of components and permissions in AndroidManifest.xml
- **Permission Grant**: User authorization for the app to access SMS functionality
- **Event Stream**: Real-time data flow from native Android to Flutter Dart code

## Requirements

### Requirement 1

**User Story:** As a user, I want the app to properly register SMS broadcast receivers, so that incoming SMS messages are intercepted by the application.

#### Acceptance Criteria

1. WHEN the app is installed THEN the SMS BroadcastReceiver SHALL be registered with the correct package name in AndroidManifest.xml
2. WHEN an SMS message arrives THEN the Android system SHALL route it to the app's BroadcastReceiver
3. WHEN the BroadcastReceiver is triggered THEN it SHALL successfully extract SMS content and sender information
4. WHEN SMS data is extracted THEN it SHALL be passed to the Flutter layer via the platform channel

### Requirement 2

**User Story:** As a developer, I want the Android native code to use the correct package name, so that all components are properly registered and accessible.

#### Acceptance Criteria

1. WHEN the MainActivity is defined THEN it SHALL use the package name "com.paylog.app" to match the applicationId
2. WHEN the SmsPlugin is defined THEN it SHALL use the package name "com.paylog.app" to match the applicationId  
3. WHEN the SmsReceiver is defined THEN it SHALL use the package name "com.paylog.app" to match the applicationId
4. WHEN the AndroidManifest.xml references native components THEN it SHALL use the correct package-relative paths

### Requirement 3

**User Story:** As a user, I want SMS permissions to be properly requested and granted, so that the app can access incoming SMS messages.

#### Acceptance Criteria

1. WHEN the app requests SMS permissions THEN the system SHALL present the permission dialog to the user
2. WHEN SMS permissions are granted THEN the app SHALL be able to receive SMS broadcast intents
3. WHEN SMS permissions are denied THEN the app SHALL display appropriate error messages and fallback options
4. WHEN permission status changes THEN the app SHALL update its SMS monitoring state accordingly

### Requirement 4

**User Story:** As a user, I want the SMS monitoring service to properly initialize and start listening, so that transaction SMS messages are processed automatically.

#### Acceptance Criteria

1. WHEN the user starts SMS monitoring THEN the SmsListenerService SHALL successfully initialize all dependencies
2. WHEN SMS monitoring is active THEN the platform channel SHALL establish a connection between native and Dart code
3. WHEN an SMS message is received THEN it SHALL flow through the complete processing pipeline: BroadcastReceiver → Platform Channel → SmsListenerService → Transaction Processing
4. WHEN SMS processing completes THEN the transaction SHALL appear in the UI transaction list

### Requirement 5

**User Story:** As a developer, I want comprehensive logging and error handling, so that SMS monitoring issues can be diagnosed and resolved.

#### Acceptance Criteria

1. WHEN SMS monitoring starts THEN the system SHALL log the initialization status and any errors
2. WHEN an SMS message is received THEN the system SHALL log the sender, content preview, and processing status
3. WHEN SMS processing fails THEN the system SHALL log detailed error information including stack traces
4. WHEN permissions are missing THEN the system SHALL log clear error messages indicating the specific permissions needed

### Requirement 6

**User Story:** As a user, I want the SMS monitoring to work with real bank SMS messages, so that I can automatically track my financial transactions.

#### Acceptance Criteria

1. WHEN a real bank SMS is received THEN the system SHALL detect it as a financial message
2. WHEN a financial SMS is processed THEN the system SHALL successfully parse transaction details (amount, type, account)
3. WHEN transaction parsing succeeds THEN the system SHALL save the transaction to the database
4. WHEN a transaction is saved THEN it SHALL immediately appear in the dashboard UI

### Requirement 7

**User Story:** As a user, I want the SMS monitoring to handle edge cases gracefully, so that the system remains stable during various scenarios.

#### Acceptance Criteria

1. WHEN the app is in the background THEN SMS monitoring SHALL continue to function normally
2. WHEN the device receives non-financial SMS messages THEN they SHALL be properly filtered out without errors
3. WHEN network connectivity is poor THEN SMS processing SHALL continue locally and sync when connection improves
4. WHEN the app is restarted THEN SMS monitoring SHALL resume its previous state automatically

### Requirement 8

**User Story:** As a developer, I want the platform channel communication to be robust and reliable, so that SMS data flows correctly between native and Dart code.

#### Acceptance Criteria

1. WHEN the platform channel is established THEN it SHALL use the correct channel names for method and event channels
2. WHEN SMS data is sent via the platform channel THEN it SHALL be properly serialized and deserialized
3. WHEN platform channel errors occur THEN they SHALL be caught and handled gracefully with appropriate error messages
4. WHEN the Flutter engine is restarted THEN the platform channel SHALL re-establish connection automatically

### Requirement 9

**User Story:** As a user, I want visual feedback about SMS monitoring status, so that I know whether the feature is working correctly.

#### Acceptance Criteria

1. WHEN SMS monitoring is active THEN the dashboard SHALL display a green "listening" indicator
2. WHEN SMS permissions are missing THEN the dashboard SHALL display a clear permission request button
3. WHEN SMS monitoring encounters errors THEN the dashboard SHALL display specific error messages with suggested actions
4. WHEN an SMS is successfully processed THEN the dashboard SHALL show a brief confirmation or update the transaction count

### Requirement 10

**User Story:** As a developer, I want the SMS monitoring fix to be thoroughly tested, so that the functionality works reliably in production.

#### Acceptance Criteria

1. WHEN the fix is implemented THEN it SHALL be tested with real SMS messages from multiple banks
2. WHEN testing SMS monitoring THEN it SHALL be verified on different Android versions and devices
3. WHEN SMS processing is tested THEN it SHALL handle various message formats and edge cases correctly
4. WHEN the fix is complete THEN it SHALL include automated tests to prevent regression of SMS monitoring functionality