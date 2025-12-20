# PayLog - API & Backend Documentation

## Overview

PayLog's backend architecture consists of three main layers: **Data Sources**, **Repositories**, and **Use Cases**. The system is designed with clean architecture principles, ensuring separation of concerns and testability.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Presentation  │    │     Domain      │    │      Data       │
│                 │    │                 │    │                 │
│ • BLoCs         │◄──►│ • Entities      │◄──►│ • Repositories  │
│ • Pages         │    │ • Use Cases     │    │ • Data Sources  │
│ • Widgets       │    │ • Repositories  │    │ • Platform APIs │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Core Entities

### Transaction Entity

The `Transaction` class represents a complete financial transaction record with metadata.

```dart
class Transaction {
  final String id;                    // Unique identifier
  final String userId;                // Owner of the transaction
  final DateTime createdAt;           // When record was created
  final bool syncedToFirestore;       // Cloud sync status
  final String duplicateCheckHash;    // For duplicate detection
  final bool isManualEntry;          // Manual vs automatic entry
  
  // Transaction details (inherited from ParsedTransaction)
  final double amount;                // Transaction amount in Rupees
  final TransactionType transactionType; // DEBIT, CREDIT, UNKNOWN
  final String? accountNumber;        // Masked account number
  final String date;                  // Transaction date (YYYY-MM-DD)
  final String time;                  // Transaction time (HH:MM:SS)
  final String smsContent;           // Original SMS text
  final String senderPhoneNumber;    // Bank's phone number
  final double confidenceScore;      // Parsing accuracy (0.0-1.0)
}
```

### SMS Message Entity

```dart
class SmsMessage {
  final String sender;        // Phone number of sender
  final String content;       // Full SMS text content
  final DateTime timestamp;   // When SMS was received
  final String? threadId;     // Platform-specific thread ID
}
```

### Transaction Types

```dart
enum TransactionType {
  DEBIT,    // Money withdrawn/sent
  CREDIT,   // Money received/deposited
  UNKNOWN   // Could not determine type
}
```

## Data Sources

### SMS Platform Channel

Handles communication with native Android SMS APIs.

#### Key Methods

```dart
class SmsPlatformChannel {
  // Permission management
  Future<bool> checkPermissions()
  Future<bool> requestPermissions()
  
  // SMS monitoring
  Future<void> startListening()
  Future<void> stopListening()
  Stream<SmsMessage> get smsStream
  
  // Testing utilities
  Future<Map<String, dynamic>> simulateSmsReceived({
    String? sender,
    String? content,
    int? timestamp,
    String? threadId,
  })
}
```

#### Usage Example

```dart
final smsChannel = SmsPlatformChannel();

// Check and request permissions
if (!await smsChannel.checkPermissions()) {
  await smsChannel.requestPermissions();
}

// Start monitoring SMS
await smsChannel.startListening();

// Listen to incoming SMS
smsChannel.smsStream.listen((SmsMessage sms) {
  print('Received SMS from ${sms.sender}: ${sms.content}');
});
```

### Local Storage Data Source

Manages local persistence using Hive database.

#### Key Methods

```dart
class LocalStorageDataSource {
  // Transaction operations
  Future<void> saveTransaction(Transaction transaction)
  Future<List<Transaction>> getAllTransactions()
  Future<Transaction?> getTransactionById(String id)
  Future<void> deleteTransaction(String id)
  
  // Offline queue operations
  Future<void> addToOfflineQueue(Transaction transaction)
  Future<List<Transaction>> getOfflineQueue()
  Future<void> removeFromOfflineQueue(String transactionId)
  Future<void> clearOfflineQueue()
}
```

## Repositories

### Transaction Repository

Provides a unified interface for transaction data operations, abstracting away the underlying storage mechanism.

#### Interface

```dart
abstract class TransactionRepository {
  // CRUD operations
  Future<void> saveTransaction(Transaction transaction);
  Future<List<Transaction>> getAllTransactions();
  Future<Transaction?> getTransactionById(String id);
  Future<void> deleteTransaction(String id);
  
  // Real-time updates
  Stream<List<Transaction>> watchTransactions();
  
  // Sync operations
  Future<void> syncPendingTransactions();
}
```

#### Implementations

**1. TransactionRepositoryImpl** (Firebase + Local)
- Primary storage: Firebase Firestore
- Offline support: Local Hive database
- Automatic sync when online

**2. LocalTransactionRepository** (Local Only)
- Storage: Hive database only
- No cloud sync
- Faster operations, no network dependency

## Use Cases

### Parse SMS Transaction

Converts raw SMS messages into structured transaction data.

```dart
class ParseSmsTransaction {
  ParsedTransaction? parseTransaction(SmsMessage sms);
  List<ParsedTransaction> parseTransactions(List<SmsMessage> messages);
  bool canParse(SmsMessage sms);
  Map<String, dynamic> getParsingStats(List<SmsMessage> messages);
}
```

#### Parsing Pipeline

1. **Financial Context Detection**: Check if SMS contains financial keywords
2. **Amount Extraction**: Extract transaction amount using regex patterns
3. **Transaction Type Classification**: Determine if debit or credit
4. **Account Number Extraction**: Extract masked account numbers
5. **Date/Time Parsing**: Parse transaction timestamp
6. **Confidence Scoring**: Calculate parsing accuracy score

#### Supported SMS Formats

The parser handles various bank SMS formats:

```
HDFC Bank: "Your account XXXXXX1234 has been debited with Rs.500.00 on 17-Dec-25"
ICICI Bank: "Rs.1000 debited from A/c **1234 on 17-Dec-25. Available Bal: Rs.5000"
SBI: "Dear Customer, Rs.250.00 is debited from your A/c **5678 on 17-Dec-25"
UPI: "Rs.100 paid to John Doe via UPI. UPI Ref: 123456789"
```

### Detect Financial Context

Determines if an SMS message contains financial transaction information.

```dart
class FinancialContextDetector {
  bool isFinancialMessage(String content);
  double getConfidenceScore(String content);
}
```

#### Detection Keywords

- **Transaction indicators**: credited, debited, transferred, payment, transaction
- **Currency indicators**: Rs, ₹, INR, rupees, amount
- **Banking terms**: account, balance, available, withdraw, deposit
- **Payment methods**: UPI, NEFT, RTGS, IMPS, card

### Validate Transaction

Ensures transaction data integrity and completeness.

```dart
class ValidateTransaction {
  ValidationResult validate(ParsedTransaction transaction);
}
```

#### Validation Rules

- Amount must be positive and non-zero
- Date must be valid and not in future
- Time must be in valid 24-hour format
- Account number format validation (if present)
- SMS content must not be empty
- Confidence score must be between 0.0 and 1.0

### Sync Offline Queue

Manages synchronization of locally stored transactions to Firebase.

```dart
class SyncOfflineQueue {
  Future<void> syncPendingTransactions();
  Future<void> addToQueue(Transaction transaction);
  Future<int> getPendingCount();
}
```

## Service Locator

Manages dependency injection and service lifecycle.

```dart
class ServiceLocator {
  // Initialization
  Future<void> initialize();                    // Full initialization with Firebase
  Future<void> initializeWithoutFirebase();    // Local-only mode
  
  // Service access
  T get<T>();                                   // Get service instance
  bool isRegistered<T>();                       // Check if service exists
  
  // BLoC creation
  SmsBloc createSmsBloc();
  TransactionBloc createTransactionBloc();
  
  // Cleanup
  Future<void> dispose();
  Future<void> reset();
}
```

## Error Handling

### Exception Types

```dart
// SMS-related errors
class SmsException implements Exception {
  final String message;
  final String? code;
  final dynamic details;
}

// Repository errors
class RepositoryException implements Exception {
  final String message;
  final Exception? cause;
}

// Validation errors
class ValidationException implements Exception {
  final String field;
  final String message;
}
```

### Error Recovery Strategies

1. **Network Failures**: Automatic retry with exponential backoff
2. **Permission Denied**: Graceful degradation to manual entry
3. **Parsing Failures**: Log for manual review, continue processing
4. **Storage Failures**: Fallback to alternative storage method

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Services initialized only when needed
2. **Stream Caching**: Transaction streams cached to avoid repeated queries
3. **Batch Operations**: Multiple transactions processed together
4. **Background Processing**: SMS parsing happens off main thread
5. **Efficient Queries**: Indexed database queries for fast retrieval

### Memory Management

- Automatic disposal of unused services
- Stream subscription cleanup
- Hive box closure on app termination
- BLoC state cleanup

## Testing Support

### Mock Implementations

```dart
// Mock SMS channel for testing
class MockSmsPlatformChannel extends SmsPlatformChannel {
  @override
  Future<bool> checkPermissions() async => true;
  
  @override
  Stream<SmsMessage> get smsStream => Stream.fromIterable([
    SmsMessage(
      sender: 'TEST-BANK',
      content: 'Test transaction Rs.100',
      timestamp: DateTime.now(),
    ),
  ]);
}

// Mock repository for testing
class MockTransactionRepository extends TransactionRepository {
  final List<Transaction> _transactions = [];
  
  @override
  Future<void> saveTransaction(Transaction transaction) async {
    _transactions.add(transaction);
  }
  
  @override
  Future<List<Transaction>> getAllTransactions() async => _transactions;
}
```

### Test Utilities

```dart
// Create test transaction
Transaction createTestTransaction({
  String? id,
  double? amount,
  TransactionType? type,
}) {
  return Transaction(
    id: id ?? 'test-id',
    userId: 'test-user',
    amount: amount ?? 100.0,
    transactionType: type ?? TransactionType.DEBIT,
    // ... other required fields
  );
}

// Create test SMS
SmsMessage createTestSms({
  String? sender,
  String? content,
}) {
  return SmsMessage(
    sender: sender ?? 'TEST-BANK',
    content: content ?? 'Test SMS content',
    timestamp: DateTime.now(),
  );
}
```

## Configuration

### Environment Variables

```dart
// Firebase configuration
const String FIREBASE_PROJECT_ID = 'paylog-s5';
const String FIREBASE_COLLECTION = 'transactions';

// Local storage configuration
const String HIVE_BOX_TRANSACTIONS = 'transactions';
const String HIVE_BOX_QUEUE = 'queue';

// SMS configuration
const Duration SMS_TIMEOUT = Duration(seconds: 30);
const int MAX_RETRY_ATTEMPTS = 3;
```

### Feature Flags

```dart
class FeatureFlags {
  static const bool ENABLE_FIREBASE = true;
  static const bool ENABLE_SMS_MONITORING = true;
  static const bool ENABLE_OFFLINE_QUEUE = true;
  static const bool ENABLE_DUPLICATE_DETECTION = true;
}
```

## API Rate Limits

### Firebase Firestore

- **Reads**: 50,000 per day (free tier)
- **Writes**: 20,000 per day (free tier)
- **Deletes**: 20,000 per day (free tier)

### SMS Platform Channel

- **No explicit limits**: Depends on device SMS handling capacity
- **Recommended**: Process SMS in batches to avoid overwhelming the system

## Security Considerations

### Data Protection

1. **SMS Content**: Only financial SMS processed, others discarded
2. **Account Numbers**: Stored as received (already masked by banks)
3. **Local Storage**: Hive database encrypted on device
4. **Firebase**: Data encrypted in transit and at rest

### Permissions

- **Minimal Permissions**: Only SMS read/receive permissions requested
- **Runtime Permissions**: Requested only when needed
- **Graceful Degradation**: App works without SMS permissions (manual entry only)

## Monitoring and Logging

### Log Levels

```dart
enum LogLevel {
  DEBUG,    // Detailed debugging information
  INFO,     // General information
  WARNING,  // Potential issues
  ERROR,    // Error conditions
  CRITICAL  // Critical failures
}
```

### Metrics Tracked

- SMS parsing success rate
- Transaction sync success rate
- App crash frequency
- Performance metrics (parsing time, sync time)
- User engagement (transactions per day, manual vs automatic)

## Future Enhancements

### Planned Features

1. **Machine Learning**: Improve parsing accuracy with ML models
2. **Multi-language Support**: Support for regional language SMS
3. **Advanced Analytics**: Spending patterns and insights
4. **Export Features**: CSV/PDF export of transactions
5. **Backup/Restore**: Cloud backup of transaction data
6. **Multi-account Support**: Support for multiple bank accounts
7. **Category Classification**: Automatic transaction categorization
8. **Budget Tracking**: Set and track spending budgets

### API Extensibility

The current architecture supports easy extension:

- New data sources can be added by implementing repository interfaces
- New parsing algorithms can be plugged into the use case layer
- Additional storage backends can be integrated through the repository pattern
- New UI components can consume existing BLoCs without backend changes