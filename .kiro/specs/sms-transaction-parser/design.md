# Design Document: SMS Transaction Parser

## Overview

The SMS Transaction Parser is an Android mobile application built with React Native and Expo that continuously monitors incoming SMS messages, identifies financial transaction notifications, parses transaction details, and persists them to Firebase. The system uses native Android SMS interception capabilities combined with pattern-based parsing to extract structured transaction data from unstructured SMS text.

The architecture follows a layered approach with clear separation between SMS listening, message classification, parsing, and data persistence layers.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    React Native UI Layer                     │
│              (Dashboard, Settings, Transaction List)         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Service Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ SMS Service  │  │ Parser       │  │ Firebase     │       │
│  │ (Listening)  │  │ Service      │  │ Service      │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Data Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Local Storage│  │ Firebase DB  │  │ Queue Manager│       │
│  │ (SQLite)     │  │ (Realtime)   │  │ (Offline)    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Native Android Layer                            │
│         (SMS Broadcast Receiver, Permissions)                │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. SMS Listener Service
**Responsibility:** Intercept incoming SMS messages at the Android OS level

**Key Methods:**
- `startListening()`: Initialize SMS broadcast receiver
- `stopListening()`: Unregister broadcast receiver
- `onSmsReceived(sender: string, content: string)`: Handle incoming SMS

**Dependencies:**
- Android BroadcastReceiver
- Android SMS Manager
- Permissions: READ_SMS, RECEIVE_SMS

### 2. Financial Context Detector
**Responsibility:** Classify whether an SMS contains financial transaction information

**Key Methods:**
- `isFinancialMessage(content: string): boolean`: Determine if message is financial
- `getConfidenceScore(content: string): number`: Return confidence score (0-1)

**Financial Keywords:**
- Credit indicators: "credited", "received", "deposited", "transferred in", "added"
- Debit indicators: "debited", "withdrawn", "transferred", "paid", "deducted"
- Amount indicators: "rupees", "rs", "₹", "amount", "inr"
- Account indicators: "account", "ac no", "a/c", "account number"

### 3. SMS Parser Service
**Responsibility:** Extract structured transaction data from SMS content

**Key Methods:**
- `parseTransaction(sms: RawSMS): ParsedTransaction | null`
- `extractAmount(content: string): number | null`
- `extractTransactionType(content: string): 'debit' | 'credit' | 'unknown'`
- `extractAccountNumber(content: string): string | null`
- `extractDateTime(content: string): { date: string; time: string } | null`

**Parsing Strategy:**
- Use regex patterns for common bank formats
- Fallback to flexible pattern matching
- Support multiple date/time formats
- Handle word-to-number conversion (e.g., "One Thousand" → 1000)

### 4. Firebase Service
**Responsibility:** Persist and retrieve transaction data from Firebase

**Key Methods:**
- `saveTransaction(transaction: Transaction): Promise<string>` (returns transaction ID)
- `getTransactions(userId: string): Promise<Transaction[]>`
- `deleteTransaction(transactionId: string): Promise<void>`
- `syncOfflineQueue(): Promise<void>`

**Firebase Structure:**
```
users/
  {userId}/
    transactions/
      {transactionId}/
        amount: number
        transactionType: 'debit' | 'credit'
        accountNumber: string
        date: string (ISO 8601)
        time: string (HH:MM:SS)
        smsContent: string
        senderPhoneNumber: string
        timestamp: number (milliseconds)
        createdAt: number
```

### 5. Local Storage Service
**Responsibility:** Manage offline transaction queue and local caching

**Key Methods:**
- `queueTransaction(transaction: Transaction): Promise<void>`
- `getQueuedTransactions(): Promise<Transaction[]>`
- `removeFromQueue(transactionId: string): Promise<void>`
- `cacheTransactions(transactions: Transaction[]): Promise<void>`

**Storage:**
- SQLite database for offline queue
- Async storage for app settings and cache

### 6. Transaction Validator
**Responsibility:** Validate parsed transaction data before persistence

**Key Methods:**
- `validateTransaction(transaction: Transaction): ValidationResult`
- `isValidAmount(amount: number): boolean`
- `isValidAccountNumber(accountNumber: string): boolean`
- `isValidDate(date: string): boolean`

## Data Models

### RawSMS
```typescript
interface RawSMS {
  sender: string;           // Phone number of sender
  content: string;          // Full SMS text
  timestamp: number;        // Milliseconds since epoch
  threadId: number;         // Android SMS thread ID
}
```

### ParsedTransaction
```typescript
interface ParsedTransaction {
  amount: number;                    // Transaction amount in Rupees
  transactionType: 'debit' | 'credit' | 'unknown';
  accountNumber: string | null;      // Masked account number (e.g., "xxxxxx2323")
  date: string;                      // ISO 8601 format (YYYY-MM-DD)
  time: string;                      // 24-hour format (HH:MM:SS)
  smsContent: string;                // Original SMS text
  senderPhoneNumber: string;         // Bank's phone number
  confidenceScore: number;           // 0-1 confidence in parsing accuracy
}
```

### Transaction (Persisted)
```typescript
interface Transaction extends ParsedTransaction {
  id: string;                        // Unique transaction ID
  userId: string;                    // User who owns this transaction
  createdAt: number;                 // Timestamp when record was created
  syncedToFirebase: boolean;         // Whether synced to cloud
  duplicateCheckHash: string;        // Hash for duplicate detection
}
```

### ValidationResult
```typescript
interface ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}
```

## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: SMS Extraction Completeness
*For any* incoming SMS message, the system should extract both the sender's phone number and the complete message content without loss or truncation.

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
*For any* successfully parsed transaction, the resulting transaction record should contain all required fields (id, amount, transactionType, accountNumber, date, time, smsContent, senderPhoneNumber, timestamp) with consistent field types and valid data before persistence to Firebase.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4**

### Property 8: Transaction Persistence Round Trip
*For any* successfully parsed transaction, after persisting it to Firebase and retrieving it, the retrieved transaction should contain identical values for all fields (amount, transactionType, accountNumber, date, time, smsContent, senderPhoneNumber) as the original parsed transaction.

**Validates: Requirements 7.1, 7.2, 7.4**

### Property 9: Retry Logic with Exponential Backoff
*For any* failed Firebase write operation, the system should automatically retry up to 3 times with exponential backoff delays, and only after all retries are exhausted should the transaction be queued for later sync.

**Validates: Requirements 7.3**

### Property 10: Multi-Bank Format Flexibility
*For any* SMS message from different banks with varying formats, the system should attempt to parse and extract transaction details using flexible pattern matching, and for unrecognized formats, should attempt fallback patterns before logging for manual review.

**Validates: Requirements 9.1, 9.2, 9.3**

### Property 11: Duplicate Detection and Prevention
*For any* two identical SMS messages (same sender, content, and timestamp) received at different times, the system should detect them as duplicates using a hash-based mechanism and prevent creating duplicate transaction records in the database.

**Validates: Requirements 10.4**

### Property 12: Offline Queue Sync Consistency
*For any* transaction queued during offline mode (when Firebase connection is unavailable), after the device reconnects and the queue is synced, the transaction should appear in Firebase with identical field values as when it was queued, and the local queue should be cleared.

**Validates: Requirements 10.3**

## Error Handling

### SMS Listening Errors
- **Permission Denied:** Gracefully handle missing SMS permissions; prompt user to grant permissions
- **Broadcast Receiver Failure:** Log error and attempt to restart listener
- **Message Parsing Timeout:** Set 5-second timeout; discard message if parsing exceeds limit

### Parsing Errors
- **Unrecognized Format:** Log message for manual review; store in "unparsed" collection
- **Invalid Amount:** Mark as unknown; log for review
- **Missing Required Fields:** Store with null values; flag for manual verification

### Firebase Errors
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
- Use **fast-check** library for JavaScript/TypeScript property-based testing
- Configure each property test to run minimum 100 iterations
- Generate random SMS messages with financial keywords
- Generate random transaction data and verify round-trip persistence
- Generate duplicate messages and verify duplicate detection
- Test with various character encodings and special characters

### Test Coverage Requirements
- **Parser Functions:** 100% coverage of parsing logic
- **Classification Logic:** All financial keyword combinations
- **Validation Logic:** All validation rules and edge cases
- **Firebase Integration:** Mock Firebase for unit tests; use emulator for integration tests
- **Offline Queue:** Test queue operations and sync logic

### Testing Framework
- **Unit Tests:** Jest with React Native testing utilities
- **Property-Based Tests:** fast-check library
- **Integration Tests:** Firebase Emulator Suite for local testing
- **Mock Data:** Generate realistic SMS examples from major Indian banks (HDFC, ICICI, SBI, Axis, etc.)

