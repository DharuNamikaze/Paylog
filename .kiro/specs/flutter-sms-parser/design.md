# Design Document: Flutter SMS Transaction Parser

## Overview

The Flutter SMS Transaction Parser is an Android mobile application that monitors incoming SMS messages, identifies financial transactions, parses transaction details, and persists them to Firebase Firestore. The system leverages Flutter's platform channels for native SMS access on Android and uses a clean architecture pattern with proper state management.

The architecture follows Flutter best practices with clear separation between presentation, business logic, and data layers, utilizing the BLoC pattern for state management and dependency injection for testability.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│              (Flutter Widgets, Screens, BLoCs)              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Dashboard    │  │ Transaction  │  │ Settings     │       │
│  │ Screen       │  │ Detail       │  │ Screen       │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                      │
│                        (BLoCs/Cubits)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ SMS BLoC     │  │ Transaction  │  │ Settings     │       │
│  │              │  │ BLoC         │  │ BLoC         │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer                              │
│                   (Use Cases, Entities)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Parse SMS    │  │ Save         │  │ Get          │       │
│  │ Use Case     │  │ Transaction  │  │ Transactions │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ SMS Service  │  │ Firestore    │  │ Local        │       │
│  │ (Platform    │  │ Repository   │  │ Storage      │       │
│  │ Channels)    │  │              │  │ (Hive)       │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Native Platform Layer                           │
│              (Android SMS Receiver)                          │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. SMS Service (Platform Channel)
**Responsibility:** Handle SMS monitoring through Flutter platform channels

**Key Methods:**
- `startListening()`: Initialize SMS monitoring
- `stopListening()`: Stop SMS monitoring
- `requestPermissions()`: Request SMS permissions
- `Stream<SmsMessage> get smsStream`: Stream of incoming SMS messages

**Platform Implementation:**
- **Android:** Native BroadcastReceiver for SMS interception

**Dependencies:**
- Flutter MethodChannel for platform communication
- Android: SMS permissions (READ_SMS, RECEIVE_SMS)

### 2. Financial Context Detector
**Responsibility:** Classify SMS messages as financial or non-financial

**Key Methods:**
- `bool isFinancialMessage(String content)`: Determine if message is financial
- `double getConfidenceScore(String content)`: Return confidence score (0.0-1.0)
- `List<String> extractFinancialKeywords(String content)`: Extract matched keywords

**Financial Keywords:**
- Credit indicators: "credited", "received", "deposited", "transferred in", "added"
- Debit indicators: "debited", "withdrawn", "transferred", "paid", "deducted"
- Amount indicators: "rupees", "rs", "₹", "amount", "inr"
- Account indicators: "account", "ac no", "a/c", "account number"

### 3. SMS Parser Service
**Responsibility:** Extract structured transaction data from SMS content

**Key Methods:**
- `ParsedTransaction? parseTransaction(SmsMessage sms)`
- `double? extractAmount(String content)`
- `TransactionType extractTransactionType(String content)`
- `String? extractAccountNumber(String content)`
- `DateTime? extractDateTime(String content)`

**Parsing Strategy:**
- Regex patterns for common Indian bank formats
- Fallback to flexible pattern matching
- Support multiple date/time formats
- Word-to-number conversion using custom parser

### 4. Firestore Repository
**Responsibility:** Persist and retrieve transaction data from Firebase Firestore

**Key Methods:**
- `Future<String> saveTransaction(Transaction transaction)`: Returns document ID
- `Stream<List<Transaction>> getTransactions(String userId)`: Real-time stream
- `Future<void> deleteTransaction(String transactionId)`
- `Future<void> syncOfflineQueue()`: Sync queued transactions

**Firestore Structure:**
```
users/{userId}/
  transactions/{transactionId}/
    amount: double
    transactionType: String ('debit'|'credit'|'unknown')
    accountNumber: String?
    date: String (ISO 8601)
    time: String (HH:MM:SS)
    smsContent: String
    senderPhoneNumber: String
    timestamp: int (milliseconds)
    createdAt: Timestamp
    isManualEntry: bool
```

### 5. Local Storage Service (Hive)
**Responsibility:** Manage offline transaction queue and local caching

**Key Methods:**
- `Future<void> queueTransaction(Transaction transaction)`
- `Future<List<Transaction>> getQueuedTransactions()`
- `Future<void> removeFromQueue(String transactionId)`
- `Future<void> cacheTransactions(List<Transaction> transactions)`

**Storage:**
- Hive database for offline queue and caching
- Encrypted box for sensitive transaction data
- SharedPreferences for app settings

### 6. Transaction Validator
**Responsibility:** Validate parsed transaction data before persistence

**Key Methods:**
- `ValidationResult validateTransaction(Transaction transaction)`
- `bool isValidAmount(double amount)`
- `bool isValidAccountNumber(String? accountNumber)`
- `bool isValidDate(String date)`

### 7. BLoC State Management

#### SMS BLoC
**States:**
- `SmsInitial`: Initial state
- `SmsListening`: Actively monitoring SMS
- `SmsPermissionDenied`: SMS permissions not granted
- `SmsError`: Error in SMS monitoring

**Events:**
- `StartSmsListening`: Begin SMS monitoring
- `StopSmsListening`: Stop SMS monitoring
- `SmsReceived`: New SMS message received
- `RequestSmsPermissions`: Request SMS permissions

#### Transaction BLoC
**States:**
- `TransactionInitial`: Initial state
- `TransactionLoading`: Loading transactions
- `TransactionLoaded`: Transactions loaded successfully
- `TransactionError`: Error loading transactions

**Events:**
- `LoadTransactions`: Load user transactions
- `AddTransaction`: Add new transaction
- `DeleteTransaction`: Delete transaction
- `RefreshTransactions`: Refresh transaction list

## Data Models

### SmsMessage
```dart
class SmsMessage {
  final String sender;           // Phone number of sender
  final String content;          // Full SMS text
  final DateTime timestamp;      // When SMS was received
  final String? threadId;        // Platform-specific thread ID
  
  const SmsMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.threadId,
  });
}
```

### ParsedTransaction
```dart
class ParsedTransaction {
  final double amount;                    // Transaction amount in Rupees
  final TransactionType transactionType;  // debit, credit, or unknown
  final String? accountNumber;            // Masked account number
  final String date;                      // ISO 8601 format (YYYY-MM-DD)
  final String time;                      // 24-hour format (HH:MM:SS)
  final String smsContent;                // Original SMS text
  final String senderPhoneNumber;         // Bank's phone number
  final double confidenceScore;           // 0.0-1.0 confidence in parsing
  
  const ParsedTransaction({
    required this.amount,
    required this.transactionType,
    this.accountNumber,
    required this.date,
    required this.time,
    required this.smsContent,
    required this.senderPhoneNumber,
    required this.confidenceScore,
  });
}
```

### Transaction (Persisted)
```dart
class Transaction extends ParsedTransaction {
  final String id;                        // Unique transaction ID
  final String userId;                    // User who owns this transaction
  final DateTime createdAt;               // When record was created
  final bool syncedToFirestore;           // Whether synced to cloud
  final String duplicateCheckHash;        // Hash for duplicate detection
  final bool isManualEntry;               // Whether manually entered
  
  const Transaction({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.syncedToFirestore,
    required this.duplicateCheckHash,
    required this.isManualEntry,
    required super.amount,
    required super.transactionType,
    super.accountNumber,
    required super.date,
    required super.time,
    required super.smsContent,
    required super.senderPhoneNumber,
    required super.confidenceScore,
  });
}
```

### TransactionType
```dart
enum TransactionType {
  debit,
  credit,
  unknown;
}
```

### ValidationResult
```dart
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: SMS Extraction Completeness
*For any* incoming SMS message on Android, the system should extract both the sender's phone number and the complete message content without loss or truncation.

**Validates: Requirements 1.2**

### Property 2: Financial Message Classification Accuracy
*For any* SMS message containing financial keywords (credited, debited, transferred, payment, rupees, amount, etc.), the financial context detector should classify it as a financial message, and for any message without such keywords, it should classify it as non-financial.

**Validates: Requirements 2.1, 2.2, 2.3**

### Property 3: Amount Extraction and Normalization
*For any* financial SMS message containing a transaction amount in any format (numeric, words like "One Thousand", or with currency symbols ₹/Rs./INR), the parser should extract and normalize it to a numeric value that represents the same monetary amount.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 4: Transaction Type Classification
*For any* financial SMS message, the parser should correctly classify the transaction type as either debit (for keywords: debited, withdrawn, transferred out, paid, deducted) or credit (for keywords: credited, received, deposited, transferred in, added), and the classification should match the message semantics.

**Validates: Requirements 4.1, 4.2, 4.3**

### Property 5: Account Number Extraction and Preservation
*For any* financial SMS message containing an account number or identifier, the parser should extract it exactly as it appears in the message, preserving any masking format (e.g., "xxxxxx2323"), and for messages without an account number, the field should be null.

**Validates: Requirements 5.1, 5.2, 5.4**

### Property 6: Date-Time Extraction and Normalization
*For any* financial SMS message containing a date and/or time in any format (DD-MM-YYYY, DD/MM/YYYY, text like "today"/"yesterday", or various time formats), the parser should extract and normalize them to ISO 8601 format for dates (YYYY-MM-DD) and 24-hour format for times (HH:MM:SS), representing the same point in time as the original.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4**

### Property 7: Transaction Record Schema Compliance
*For any* successfully parsed transaction, the resulting transaction record should contain all required fields (id, amount, transactionType, accountNumber, date, time, smsContent, senderPhoneNumber, timestamp) with consistent field types and valid data before persistence to Firestore.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4**

### Property 8: Transaction Persistence Round Trip
*For any* successfully parsed transaction, after persisting it to Firestore and retrieving it, the retrieved transaction should contain identical values for all fields (amount, transactionType, accountNumber, date, time, smsContent, senderPhoneNumber) as the original parsed transaction.

**Validates: Requirements 7.1, 7.2, 7.4**

### Property 9: Retry Logic with Exponential Backoff
*For any* failed Firestore write operation, the system should automatically retry up to 3 times with exponential backoff delays, and only after all retries are exhausted should the transaction be queued for later sync.

**Validates: Requirements 7.3**

### Property 10: Multi-Bank Format Flexibility
*For any* SMS message from different banks with varying formats, the system should attempt to parse and extract transaction details using flexible pattern matching, and for unrecognized formats, should attempt fallback patterns before logging for manual review.

**Validates: Requirements 9.1, 9.2, 9.3**

### Property 11: Duplicate Detection and Prevention
*For any* two identical SMS messages (same sender, content, and timestamp) received at different times, the system should detect them as duplicates using a hash-based mechanism and prevent creating duplicate transaction records in the database.

**Validates: Requirements 10.4**

### Property 12: Offline Queue Sync Consistency
*For any* transaction queued during offline mode (when Firestore connection is unavailable), after the device reconnects and the queue is synced, the transaction should appear in Firestore with identical field values as when it was queued, and the local queue should be cleared.

**Validates: Requirements 10.3**

### Property 13: Manual Entry Parsing Consistency
*For any* SMS message entered manually, the parsing logic should produce identical results to the same message received automatically, ensuring consistent transaction extraction regardless of input method.

**Validates: Requirements 12.2**

## Error Handling

### SMS Listening Errors
- **Permission Denied:** Gracefully handle missing SMS permissions; prompt user to grant permissions
- **Broadcast Receiver Failure:** Log error and attempt to restart listener
- **Message Parsing Timeout:** Set 5-second timeout; discard message if parsing exceeds limit

### Parsing Errors
- **Unrecognized Format:** Log message for manual review; store in "unparsed" collection
- **Invalid Amount:** Mark as unknown; log for review
- **Missing Required Fields:** Store with null values; flag for manual verification

### Firestore Errors
- **Network Unavailable:** Queue transaction locally; retry on connection restore
- **Authentication Failed:** Prompt user to re-authenticate
- **Write Quota Exceeded:** Implement exponential backoff; queue for retry
- **Duplicate Write:** Detect via transaction hash; skip duplicate

### Data Validation Errors
- **Invalid Amount:** Reject if negative or exceeds reasonable threshold (e.g., > ₹10,000,000)
- **Invalid Date:** Reject if date is in future or more than 90 days in past
- **Invalid Account Number:** Accept any non-empty string; validate format if possible

## Testing Strategy

### Unit Testing Approach
- Test individual parser functions with specific SMS examples from different banks
- Test amount extraction with various formats (numeric, words, symbols)
- Test date/time parsing with multiple formats
- Test transaction type classification with keyword variations
- Test validation functions with edge cases (empty strings, special characters, boundary values)

### Property-Based Testing Approach
- Use **test** package with custom property testing utilities for Dart/Flutter
- Configure each property test to run minimum 100 iterations
- Generate random SMS messages with financial keywords
- Generate random transaction data and verify round-trip persistence
- Generate duplicate messages and verify duplicate detection
- Test with various character encodings and special characters

### Test Coverage Requirements
- **Parser Functions:** 100% coverage of parsing logic
- **Classification Logic:** All financial keyword combinations
- **Validation Logic:** All validation rules and edge cases
- **Firestore Integration:** Mock Firestore for unit tests; use emulator for integration tests
- **Offline Queue:** Test queue operations and sync logic

### Testing Framework
- **Unit Tests:** Flutter test framework with mockito for mocking
- **Property-Based Tests:** Custom property testing utilities built on Flutter test
- **Integration Tests:** Firebase Emulator Suite for local testing
- **Mock Data:** Generate realistic SMS examples from major Indian banks (HDFC, ICICI, SBI, Axis, etc.)