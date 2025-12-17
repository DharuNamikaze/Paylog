# Implementation Plan: SMS Transaction Parser

## Overview
This implementation plan converts the SMS Transaction Parser design into a series of incremental coding tasks. Each task builds on previous ones, with core functionality implemented first, followed by optional testing tasks.

---

## Core Implementation Tasks

- [x] 1. Set up project structure and dependencies


  - Install required packages: `react-native-sms-user-consent`, `firebase`, `fast-check`, `jest`
  - Create directory structure: `services/`, `utils/`, `types/`, `tests/`
  - Configure Firebase project and initialize Firebase in the app
  - Set up TypeScript configuration for strict type checking
  - _Requirements: 1.1, 7.2, 8.1_




- [ ] 2. Define data models and types
  - Create `types/Transaction.ts` with Transaction, ParsedTransaction, RawSMS interfaces

  - Create `types/ValidationResult.ts` for validation responses
  - Implement type guards and validators for each interface
  - _Requirements: 8.1, 8.2_

- [x] 3. Implement SMS Listener Service


  - Create `services/SmsListenerService.ts` with BroadcastReceiver integration
  - Implement `startListening()` and `stopListening()` methods
  - Handle Android SMS permissions (READ_SMS, RECEIVE_SMS)
  - Implement `onSmsReceived(sender, content)` callback
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 3.1 Write property test for SMS extraction
  - **Feature: sms-transaction-parser, Property 1: SMS Extraction Completeness**
  - **Validates: Requirements 1.2**



- [ ] 4. Implement Financial Context Detector
  - Create `services/FinancialContextDetector.ts`
  - Implement `isFinancialMessage(content: string): boolean`
  - Implement `getConfidenceScore(content: string): number`
  - Define financial keywords for credit, debit, amount, and account indicators
  - _Requirements: 2.1, 2.2, 2.3_

- [x]* 4.1 Write property test for financial message classification


  - **Feature: sms-transaction-parser, Property 2: Financial Message Classification Accuracy**
  - **Validates: Requirements 2.1, 2.2, 2.3**

- [ ] 5. Implement Amount Extraction and Normalization
  - Create `utils/AmountParser.ts` with amount extraction logic
  - Implement numeric amount extraction (e.g., "1000", "₹1000", "Rs. 1000")
  - Implement word-to-number conversion (e.g., "One Thousand" → 1000)
  - Handle currency symbols and abbreviations (₹, Rs., INR)
  - _Requirements: 3.1, 3.2, 3.3_


- [ ]* 5.1 Write property test for amount extraction
  - **Feature: sms-transaction-parser, Property 3: Amount Extraction and Normalization**
  - **Validates: Requirements 3.1, 3.2, 3.3**

- [x] 6. Implement Transaction Type Classification

  - Create `utils/TransactionTypeClassifier.ts`
  - Implement debit keyword detection (debited, withdrawn, transferred out, paid, deducted)
  - Implement credit keyword detection (credited, received, deposited, transferred in, added)
  - Handle ambiguous cases and mark as "unknown"
  - _Requirements: 4.1, 4.2, 4.3_

- [ ]* 6.1 Write property test for transaction type classification
  - **Feature: sms-transaction-parser, Property 4: Transaction Type Classification**
  - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 7. Implement Account Number Extraction



  - Create `utils/AccountNumberExtractor.ts`
  - Extract account numbers in various formats (full, masked like "xxxxxx2323")
  - Handle multiple account references and identify primary account
  - Return null when no account number is present
  - _Requirements: 5.1, 5.2, 5.4_

- [ ]* 7.1 Write property test for account number extraction
  - **Feature: sms-transaction-parser, Property 5: Account Number Extraction and Preservation**
  - **Validates: Requirements 5.1, 5.2, 5.4**

- [x] 8. Implement Date-Time Extraction and Normalization


  - Create `utils/DateTimeParser.ts`
  - Parse dates in formats: DD-MM-YYYY, DD/MM/YYYY, text formats (today, yesterday)
  - Normalize dates to ISO 8601 format (YYYY-MM-DD)
  - Parse times in various formats and normalize to HH:MM:SS
  - Fallback to SMS receipt timestamp when time is not provided
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ]* 8.1 Write property test for date-time extraction
  - **Feature: sms-transaction-parser, Property 6: Date-Time Extraction and Normalization**
  - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**



- [ ] 9. Implement SMS Parser Service
  - Create `services/SmsParserService.ts` that orchestrates all parsing utilities
  - Implement `parseTransaction(sms: RawSMS): ParsedTransaction | null`
  - Combine amount, type, account, and date-time extraction
  - Handle parsing failures and log unparseable messages
  - _Requirements: 3.1, 4.1, 5.1, 6.1, 9.1, 9.2, 9.3_

- [ ]* 9.1 Write property test for transaction record schema compliance
  - **Feature: sms-transaction-parser, Property 7: Transaction Record Schema Compliance**
  - **Validates: Requirements 8.1, 8.2, 8.3, 8.4**

- [ ] 10. Implement Transaction Validator
  - Create `services/TransactionValidator.ts`
  - Implement `validateTransaction(transaction: Transaction): ValidationResult`
  - Validate amount (positive, within reasonable threshold)
  - Validate date (not in future, not more than 90 days in past)
  - Validate account number format
  - _Requirements: 8.3_

- [ ] 11. Implement Firebase Service with Retry Logic
  - Create `services/FirebaseService.ts`
  - Implement `saveTransaction(transaction: Transaction): Promise<string>`
  - Implement retry logic with exponential backoff (up to 3 retries)
  - Generate unique transaction IDs
  - Handle Firebase authentication and connection errors
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ]* 11.1 Write property test for retry logic
  - **Feature: sms-transaction-parser, Property 9: Retry Logic with Exponential Backoff**
  - **Validates: Requirements 7.3**

- [ ] 12. Implement Local Storage Service
  - Create `services/LocalStorageService.ts` for offline queue management
  - Implement SQLite database for transaction queue
  - Implement `queueTransaction()`, `getQueuedTransactions()`, `removeFromQueue()`
  - Implement `cacheTransactions()` for local caching
  - _Requirements: 10.3_

- [ ] 13. Implement Duplicate Detection
  - Create `utils/DuplicateDetector.ts`
  - Implement hash-based duplicate detection (hash sender + content + timestamp)
  - Store hashes of processed transactions
  - Prevent duplicate records in Firebase
  - _Requirements: 10.4_

- [ ]* 13.1 Write property test for duplicate detection
  - **Feature: sms-transaction-parser, Property 11: Duplicate Detection and Prevention**
  - **Validates: Requirements 10.4**

- [ ] 14. Implement Offline Queue Sync
  - Create `services/OfflineQueueSyncService.ts`
  - Implement `syncOfflineQueue(): Promise<void>`
  - Monitor network connectivity changes
  - Sync queued transactions when connection is restored
  - Handle sync failures and re-queue
  - _Requirements: 10.3_

- [x]* 14.1 Write property test for offline queue sync



  - **Feature: sms-transaction-parser, Property 12: Offline Queue Sync Consistency**
  - **Validates: Requirements 10.3**

- [ ] 15. Integrate SMS Listener with Parser and Firebase
  - Update `SmsListenerService.ts` to call `FinancialContextDetector`
  - Chain detector → parser → validator → Firebase service
  - Implement error handling and logging at each step
  - Handle edge cases (empty messages, special characters, encoding issues)
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 9.1, 10.1, 10.2_

- [ ] 16. Create UI components for transaction display
  - Create `components/TransactionList.tsx` to display parsed transactions
  - Create `components/TransactionDetail.tsx` for transaction details
  - Implement real-time updates from Firebase
  - Add filtering and sorting options
  - _Requirements: 1.1, 7.1_

- [ ] 17. Implement Settings and Permissions Management
  - Create `services/PermissionsService.ts` for SMS permission handling
  - Implement permission request flow in UI
  - Store user preferences (notification settings, sync frequency)
  - _Requirements: 1.1, 1.4_

- [ ] 18. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 18.1 Write unit tests for parsing utilities
  - Test `AmountParser.ts` with various amount formats
  - Test `TransactionTypeClassifier.ts` with keyword variations
  - Test `AccountNumberExtractor.ts` with different account formats
  - Test `DateTimeParser.ts` with multiple date/time formats
  - _Requirements: 3.1, 4.1, 5.1, 6.1_

- [ ]* 18.2 Write unit tests for validation logic
  - Test `TransactionValidator.ts` with valid and invalid transactions
  - Test boundary conditions (max amount, date ranges)
  - Test error cases and validation error messages
  - _Requirements: 8.3_

- [ ]* 18.3 Write unit tests for Firebase integration
  - Test `FirebaseService.ts` with mock Firebase
  - Test transaction persistence and retrieval
  - Test error handling and retry logic
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ]* 18.4 Write unit tests for offline queue
  - Test `LocalStorageService.ts` queue operations
  - Test `OfflineQueueSyncService.ts` sync logic
  - Test network connectivity monitoring
  - _Requirements: 10.3_

- [ ] 19. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

