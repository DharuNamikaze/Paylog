# Requirements Document: Flutter SMS Transaction Parser

## Introduction

The Flutter SMS Transaction Parser is a cross-platform mobile application that continuously monitors incoming SMS messages from financial institutions, automatically detects transaction-related messages, parses transaction details, and persists them to a cloud database. The system extracts critical financial information including transaction amounts, account numbers, transaction types (debit/credit), and timestamps from unstructured SMS text using Flutter's native platform capabilities.

## Glossary

- **SMS Message**: Short Message Service text message received on the device
- **Financial Institution**: Banks, payment services, or financial entities that send transaction notifications
- **Transaction**: A financial event involving money transfer (debit or credit)
- **Debit**: Money withdrawn or sent from an account
- **Credit**: Money received or deposited into an account
- **Account Number**: Unique identifier for a bank account (typically partially masked)
- **Transaction Amount**: The monetary value involved in a transaction, typically in Rupees (₹)
- **Timestamp**: Date and time when the transaction occurred
- **SMS Parser**: Component that extracts structured data from unstructured SMS text
- **Cloud Database**: Firebase Firestore or similar NoSQL database for persisting transaction records
- **SMS Listener**: Flutter service that monitors incoming SMS messages using platform channels
- **Flutter App**: Cross-platform mobile application built with Flutter framework
- **Platform Channel**: Flutter mechanism for communicating with native Android/iOS code
- **Background Service**: Flutter service that continues running when app is not in foreground

## Requirements

### Requirement 1

**User Story:** As a user, I want the Flutter app to automatically capture all incoming SMS messages from financial institutions, so that I don't miss any transaction notifications on my Android device.

#### Acceptance Criteria

1. WHEN an SMS message arrives on the device THEN the SMS Listener SHALL intercept the message using Flutter platform channels
2. WHEN an SMS is received THEN the system SHALL extract the sender's phone number and message content
3. WHEN the SMS Listener receives a message THEN the system SHALL pass the message to the Financial Context Detector within 500 milliseconds
4. WHEN the app is running in the background THEN the system SHALL continue monitoring incoming SMS messages using Flutter background services

### Requirement 2

**User Story:** As a user, I want the app to identify which SMS messages contain financial transaction information, so that irrelevant messages are not processed.

#### Acceptance Criteria

1. WHEN an SMS message is received THEN the system SHALL analyze the message content to determine if it contains financial transaction context
2. WHEN a message contains keywords like "credited", "debited", "transferred", "payment", "rupees", "amount", or similar financial terms THEN the system SHALL classify it as a financial message
3. WHEN a message does not contain financial context THEN the system SHALL discard it without further processing
4. IF a message contains financial keywords but is not a valid transaction notification THEN the system SHALL log it for manual review

### Requirement 3

**User Story:** As a user, I want transaction amounts to be accurately extracted from SMS messages, so that I have a complete record of all financial movements.

#### Acceptance Criteria

1. WHEN a financial SMS message is parsed THEN the system SHALL extract the transaction amount in numeric format
2. WHEN an amount is specified in words (e.g., "One Thousand Rupees") THEN the system SHALL convert it to numeric format
3. WHEN an amount contains currency symbols or abbreviations (₹, Rs., INR) THEN the system SHALL normalize it to a numeric value
4. WHEN multiple amounts appear in a message THEN the system SHALL identify and extract the primary transaction amount

### Requirement 4

**User Story:** As a user, I want to know whether money was added to or removed from my account, so that I can track my account balance changes.

#### Acceptance Criteria

1. WHEN a financial message is parsed THEN the system SHALL determine if the transaction is a debit or credit
2. WHEN a message contains keywords indicating money received (e.g., "credited", "received", "deposited") THEN the system SHALL mark the transaction as a credit
3. WHEN a message contains keywords indicating money sent (e.g., "debited", "withdrawn", "transferred out") THEN the system SHALL mark the transaction as a debit
4. IF the transaction type cannot be determined from the message THEN the system SHALL mark it as unknown and log it for review

### Requirement 5

**User Story:** As a user, I want the account number associated with each transaction to be captured, so that I can track which of my accounts was affected.

#### Acceptance Criteria

1. WHEN a financial message is parsed THEN the system SHALL extract the account number or account identifier
2. WHEN an account number is partially masked (e.g., "xxxxxx2323") THEN the system SHALL preserve the masked format as provided in the message
3. WHEN a message contains multiple account references THEN the system SHALL identify and extract the primary account number
4. WHEN no account number is present in the message THEN the system SHALL record a null value for the account field

### Requirement 6

**User Story:** As a user, I want the date and time of each transaction to be captured, so that I have a complete timeline of my financial activity.

#### Acceptance Criteria

1. WHEN a financial message is parsed THEN the system SHALL extract the transaction date and time
2. WHEN a date is specified in various formats (DD-MM-YYYY, DD/MM/YYYY, or text like "today", "yesterday") THEN the system SHALL normalize it to ISO 8601 format (YYYY-MM-DD)
3. WHEN a time is specified in the message THEN the system SHALL extract it and normalize to 24-hour format (HH:MM:SS)
4. WHEN no explicit time is provided in the message THEN the system SHALL use the SMS receipt timestamp as the transaction time

### Requirement 7

**User Story:** As a user, I want parsed transaction data to be automatically saved to a cloud database, so that I have a persistent record of all transactions accessible across devices.

#### Acceptance Criteria

1. WHEN a transaction is successfully parsed THEN the system SHALL create a transaction record with all extracted fields
2. WHEN a transaction record is created THEN the system SHALL persist it to Firebase Firestore immediately
3. WHEN a database write operation fails THEN the system SHALL retry the operation up to 3 times with exponential backoff
4. WHEN a transaction is persisted THEN the system SHALL generate a unique transaction ID for future reference

### Requirement 8

**User Story:** As a developer, I want a clear data structure for transaction records, so that the system maintains consistency and enables reliable querying across Flutter platforms.

#### Acceptance Criteria

1. THE Transaction Record Schema SHALL include fields: id, amount, transactionType (debit/credit), accountNumber, date, time, smsContent, senderPhoneNumber, timestamp
2. WHEN a transaction record is created THEN all required fields SHALL be populated with parsed or derived values
3. WHEN a transaction record is stored THEN the system SHALL validate that all required fields contain valid data before persistence
4. WHEN transaction records are queried THEN the system SHALL return records with consistent field types and formats

### Requirement 9

**User Story:** As a user, I want the Flutter app to handle various SMS message formats from different banks, so that I can track transactions from multiple financial institutions.

#### Acceptance Criteria

1. WHEN SMS messages from different banks are received THEN the system SHALL parse them using flexible pattern matching
2. WHEN a message format is not recognized THEN the system SHALL attempt to extract transaction details using fallback patterns
3. WHEN parsing fails for a message THEN the system SHALL log the message content and sender for manual review
4. WHEN new bank message formats are encountered THEN the system SHALL store them for pattern analysis and future improvement

### Requirement 10

**User Story:** As a user, I want the Flutter app to handle edge cases gracefully, so that the system remains stable and reliable on Android.

#### Acceptance Criteria

1. WHEN an SMS message is empty or contains only whitespace THEN the system SHALL discard it without processing
2. WHEN an SMS message contains special characters or encoding issues THEN the system SHALL handle them without crashing
3. WHEN the cloud database connection is unavailable THEN the system SHALL queue transactions locally using Flutter's local storage and sync when connection is restored
4. WHEN duplicate messages are received THEN the system SHALL detect and prevent duplicate transaction records in the database

### Requirement 11

**User Story:** As a user, I want a clean and intuitive Flutter UI to view my parsed transactions, so that I can easily review my financial activity.

#### Acceptance Criteria

1. WHEN the app launches THEN the system SHALL display a dashboard with recent transactions using Flutter widgets
2. WHEN transactions are displayed THEN the system SHALL show amount, type, account, date, and time in a clear format
3. WHEN a user taps on a transaction THEN the system SHALL show detailed information including the original SMS content
4. WHEN new transactions are parsed THEN the system SHALL update the UI in real-time using Flutter state management

### Requirement 12

**User Story:** As a user, I want to manually input SMS messages when automatic detection fails, so that I can still track transactions if needed.

#### Acceptance Criteria

1. WHEN SMS permissions are unavailable or automatic detection fails THEN the system SHALL provide a manual SMS input interface
2. WHEN a user manually enters an SMS message THEN the system SHALL parse it using the same logic as automatic messages
3. WHEN manual input is used THEN the system SHALL validate the input format and provide feedback to the user
4. WHEN a manually entered transaction is parsed THEN the system SHALL mark it as manually entered for tracking purposes