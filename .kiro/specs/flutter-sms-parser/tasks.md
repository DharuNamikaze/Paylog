# Implementation Plan: Flutter SMS Transaction Parser

## Overview
This implementation plan converts the Flutter SMS Transaction Parser design into a series of incremental coding tasks. Each task builds on previous ones, with core functionality implemented first, followed by optional testing tasks.

## Current Status
**Core parsing and data layer:** ✅ Complete
- All parsing utilities (amount, type, account, datetime) implemented
- Transaction validation and duplicate detection complete
- Firestore repository with retry logic implemented
- Local storage and offline queue sync implemented
- BLoC state management (SMS and Transaction BLoCs) implemented
- SMS listener service integration complete
- Permissions management complete
- All UI pages implemented (Dashboard, Transaction Detail, Manual Input)

**Remaining work:** Final app integration and wiring
- Main app entry point needs BLoC providers and dependency injection
- SMS service integration with UI controls
- Final end-to-end testing and integration

---

## Completed Tasks

- [x] 1. Set up Flutter project structure and dependencies
  - Create new Flutter project with Android support
  - Add dependencies: `firebase_core`, `cloud_firestore`, `hive`, `flutter_bloc`, `permission_handler`
  - Configure Firebase project and add `google-services.json`
  - Set up directory structure: `lib/data/`, `lib/domain/`, `lib/presentation/`, `lib/core/`
  - Configure Android permissions in `android/app/src/main/AndroidManifest.xml`
  - _Requirements: 1.1, 7.2, 8.1_

- [x] 2. Define data models and entities
  - Create `lib/domain/entities/sms_message.dart` with SmsMessage class
  - Create `lib/domain/entities/transaction.dart` with Transaction and ParsedTransaction classes
  - Create `lib/domain/entities/transaction_type.dart` enum
  - Create `lib/domain/entities/validation_result.dart` class
  - Implement JSON serialization for all entities using `json_annotation`
  - _Requirements: 8.1, 8.2_

- [x] 3. Implement Android SMS platform channel
  - Create `android/app/src/main/kotlin/SmsReceiver.kt` BroadcastReceiver
  - Create `android/app/src/main/kotlin/SmsPlugin.kt` for Flutter method channel
  - Implement `lib/data/datasources/sms_platform_channel.dart`
  - Add SMS permissions handling and permission requests
  - Test SMS interception and message extraction
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 4. Implement Financial Context Detector
  - Create `lib/domain/usecases/detect_financial_context.dart`
  - Implement keyword-based classification logic
  - Define financial keyword lists for credit, debit, amount, and account indicators
  - Implement confidence scoring algorithm
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 5. Implement Amount Parser utility
  - Create `lib/core/utils/amount_parser.dart`
  - Implement numeric amount extraction with regex patterns
  - Implement word-to-number conversion (e.g., "One Thousand" → 1000)
  - Handle currency symbols and abbreviations (₹, Rs., INR)
  - Handle multiple amounts and primary amount identification
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 6. Implement Transaction Type Classifier
  - Create `lib/core/utils/transaction_type_classifier.dart`
  - Implement debit keyword detection (debited, withdrawn, transferred out, paid, deducted)
  - Implement credit keyword detection (credited, received, deposited, transferred in, added)
  - Handle ambiguous cases and mark as "unknown"
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 7. Implement Account Number Extractor
  - Create `lib/core/utils/account_number_extractor.dart`
  - Extract account numbers in various formats (full, masked like "xxxxxx2323")
  - Handle multiple account references and identify primary account
  - Return null when no account number is present
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 8. Implement Date-Time Parser
  - Create `lib/core/utils/datetime_parser.dart`
  - Parse dates in formats: DD-MM-YYYY, DD/MM/YYYY, text formats (today, yesterday)
  - Normalize dates to ISO 8601 format (YYYY-MM-DD)
  - Parse times in various formats and normalize to HH:MM:SS
  - Fallback to SMS receipt timestamp when time is not provided
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 9. Implement SMS Parser Service
  - Create `lib/domain/usecases/parse_sms_transaction.dart`
  - Orchestrate all parsing utilities (amount, type, account, date-time)
  - Implement `parseTransaction(SmsMessage sms): ParsedTransaction?`
  - Handle parsing failures and log unparseable messages
  - Generate confidence scores for parsed transactions
  - _Requirements: 3.1, 4.1, 5.1, 6.1, 9.1, 9.2, 9.3_

- [x] 10. Implement Transaction Validator
  - Create `lib/domain/usecases/validate_transaction.dart`
  - Implement `validateTransaction(Transaction transaction): ValidationResult`
  - Validate amount (positive, within reasonable threshold ₹10,000,000)
  - Validate date (not in future, not more than 90 days in past)
  - Validate account number format and required fields
  - _Requirements: 8.3_

- [x] 11. Implement Firestore Repository
  - Create `lib/data/repositories/transaction_repository_impl.dart`
  - Implement `saveTransaction(Transaction transaction): Future<String>`
  - Implement retry logic with exponential backoff (up to 3 retries)
  - Generate unique transaction IDs using UUID
  - Handle Firestore authentication and connection errors
  - Implement `getTransactions(String userId): Stream<List<Transaction>>`
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 12. Implement Local Storage with Hive
  - Create `lib/data/datasources/local_storage_datasource.dart`
  - Set up Hive boxes for transaction queue and cache
  - Implement `queueTransaction()`, `getQueuedTransactions()`, `removeFromQueue()`
  - Implement `cacheTransactions()` for local caching
  - Handle Hive initialization and encryption
  - _Requirements: 10.3_

- [x] 13. Implement Duplicate Detection
  - Create `lib/core/utils/duplicate_detector.dart`
  - Implement hash-based duplicate detection (hash sender + content + timestamp)
  - Store hashes of processed transactions in Hive
  - Prevent duplicate records in Firestore
  - _Requirements: 10.4_

- [x] 14. Implement Offline Queue Sync Service
  - Create `lib/domain/usecases/sync_offline_queue.dart`
  - Monitor network connectivity changes using `connectivity_plus`
  - Sync queued transactions when connection is restored
  - Handle sync failures and re-queue transactions
  - Clear local queue after successful sync
  - _Requirements: 10.3_

- [x] 15. Implement BLoC State Management
- [x] 15.1 Create SMS BLoC
  - Create `lib/presentation/bloc/sms_bloc.dart` for SMS monitoring
  - Define states: SmsInitial, SmsListening, SmsPermissionDenied, SmsError
  - Define events: StartSmsListening, StopSmsListening, SmsReceived, RequestSmsPermissions
  - Implement event handlers and state transitions
  - _Requirements: 1.1, 11.4_

- [x] 15.2 Create Transaction BLoC
  - Create `lib/presentation/bloc/transaction_bloc.dart` for transaction management
  - Define states: TransactionInitial, TransactionLoading, TransactionLoaded, TransactionError
  - Define events: LoadTransactions, AddTransaction, DeleteTransaction, RefreshTransactions
  - Implement event handlers and state transitions
  - Handle error states and loading states
  - _Requirements: 7.1, 11.4_

- [x] 16. Create SMS Listener Service Integration
  - Create `lib/data/services/sms_listener_service.dart`
  - Integrate SMS platform channel with Financial Context Detector
  - Chain detector → parser → validator → repository
  - Implement background service for continuous monitoring
  - Handle edge cases (empty messages, special characters, encoding issues)
  - _Requirements: 1.1, 1.4, 2.1, 10.1, 10.2_

- [x] 17. Implement Permissions Management
  - Create `lib/core/services/permissions_service.dart`
  - Handle SMS permission requests using `permission_handler`
  - Implement permission status checking and user prompts
  - Handle permission denied scenarios gracefully
  - Store permission preferences in local storage
  - _Requirements: 1.1_

- [x] 18. Create Transaction Dashboard UI
  - Create `lib/presentation/pages/dashboard_page.dart`
  - Display recent transactions using ListView with custom widgets
  - Show amount, type, account, date, and time in clear format
  - Implement real-time updates using BLoC streams
  - Add pull-to-refresh functionality
  - _Requirements: 11.1, 11.2, 11.4_

- [x] 19. Create Transaction Detail UI
  - Create `lib/presentation/pages/transaction_detail_page.dart`
  - Show detailed transaction information including original SMS content
  - Display all parsed fields in organized sections
  - Add navigation from dashboard to detail page
  - Include edit/delete functionality if needed
  - _Requirements: 11.3_

- [x] 20. Implement Manual SMS Input Feature
  - Create `lib/presentation/pages/manual_input_page.dart`
  - Provide text input for manual SMS entry
  - Parse manually entered SMS using same logic as automatic messages
  - Validate input format and provide user feedback
  - Mark manually entered transactions appropriately
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

---

## Remaining Implementation Tasks

- [x] 21. Update Main App Entry Point and Dependency Injection




- [x] 21.1 Set up dependency injection container


  - Create service locator or dependency injection setup in `lib/main.dart`
  - Register all repositories, use cases, and services
  - Initialize Firebase, Hive, and other required services
  - _Requirements: 1.1, 7.2_

- [x] 21.2 Configure BLoC providers and app structure


  - Update `lib/main.dart` to use MultiBlocProvider
  - Provide SMS BLoC and Transaction BLoC at app level
  - Set up proper app routing structure
  - Replace placeholder home page with DashboardPage
  - _Requirements: 11.1, 11.4_

- [x] 21.3 Implement app navigation and routing


  - Set up navigation between dashboard, detail, and manual input pages
  - Handle deep linking and route parameters
  - Implement proper back navigation and state management
  - _Requirements: 11.3, 12.1_

- [x] 22. Integrate SMS BLoC with SMS Listener Service


  - Update SMS BLoC to use SMS Listener Service instead of direct platform channel
  - Connect SMS BLoC events to service start/stop methods
  - Handle SMS Listener Service events and update BLoC state accordingly
  - Integrate permissions service with SMS BLoC for permission handling
  - _Requirements: 1.1, 1.4, 11.4_

- [x] 23. Implement SMS Service UI Controls


  - Add service start/stop controls to dashboard
  - Show real-time SMS processing status and statistics
  - Display permission status and provide permission request UI
  - Handle service errors and edge cases in UI
  - Show SMS processing events (financial messages detected, transactions parsed, etc.)
  - _Requirements: 1.1, 11.4_

- [x] 24. Final Integration and Testing


  - Test complete end-to-end flow: SMS reception → parsing → storage → UI display
  - Test offline functionality and sync behavior
  - Test manual input flow and validation
  - Test permission handling and error scenarios
  - Verify all error handling scenarios work correctly
  - _Requirements: All requirements_

- [x] 25. Final Checkpoint - Ensure all tests pass



  - Ensure all tests pass, ask the user if questions arise.

---

## Optional Testing Tasks

- [ ]* 7.1 Write property test for account number extraction
  - **Feature: flutter-sms-parser, Property 5: Account Number Extraction and Preservation**
  - **Validates: Requirements 5.1, 5.2, 5.4**

- [ ]* 8.1 Write property test for date-time extraction and normalization
  - **Feature: flutter-sms-parser, Property 6: Date-Time Extraction and Normalization**
  - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**

- [ ]* 9.1 Write property test for multi-bank format flexibility
  - **Feature: flutter-sms-parser, Property 10: Multi-Bank Format Flexibility**
  - **Validates: Requirements 9.1, 9.2, 9.3**

- [ ]* 11.1 Write property test for transaction persistence round trip
  - **Feature: flutter-sms-parser, Property 8: Transaction Persistence Round Trip**
  - **Validates: Requirements 7.1, 7.2, 7.4**

- [ ]* 11.2 Write property test for retry logic with exponential backoff
  - **Feature: flutter-sms-parser, Property 9: Retry Logic with Exponential Backoff**
  - **Validates: Requirements 7.3**

- [ ]* 13.1 Write property test for duplicate detection and prevention
  - **Feature: flutter-sms-parser, Property 11: Duplicate Detection and Prevention**
  - **Validates: Requirements 10.4**

- [ ]* 14.1 Write property test for offline queue sync consistency
  - **Feature: flutter-sms-parser, Property 12: Offline Queue Sync Consistency**
  - **Validates: Requirements 10.3**

- [ ]* 20.1 Write property test for manual entry parsing consistency
  - **Feature: flutter-sms-parser, Property 13: Manual Entry Parsing Consistency**
  - **Validates: Requirements 12.2**

- [ ]* 2.1 Write property test for transaction record schema compliance
  - **Feature: flutter-sms-parser, Property 7: Transaction Record Schema Compliance**
  - **Validates: Requirements 8.1, 8.2, 8.3, 8.4**

- [ ]* 3.1 Write property test for SMS extraction completeness
  - **Feature: flutter-sms-parser, Property 1: SMS Extraction Completeness**
  - **Validates: Requirements 1.2**

- [ ]* 4.1 Write property test for financial message classification
  - **Feature: flutter-sms-parser, Property 2: Financial Message Classification Accuracy**
  - **Validates: Requirements 2.1, 2.2, 2.3**

- [ ]* 5.1 Write property test for amount extraction and normalization
  - **Feature: flutter-sms-parser, Property 3: Amount Extraction and Normalization**
  - **Validates: Requirements 3.1, 3.2, 3.3**

- [ ]* 6.1 Write property test for transaction type classification
  - **Feature: flutter-sms-parser, Property 4: Transaction Type Classification**
  - **Validates: Requirements 4.1, 4.2, 4.3**

- [ ]* 23.1 Write unit tests for parsing utilities
  - Test `AmountParser` with various amount formats from Indian banks
  - Test `TransactionTypeClassifier` with keyword variations
  - Test `AccountNumberExtractor` with different account formats
  - Test `DateTimeParser` with multiple date/time formats
  - _Requirements: 3.1, 4.1, 5.1, 6.1_

- [ ]* 23.2 Write unit tests for validation logic
  - Test `TransactionValidator` with valid and invalid transactions
  - Test boundary conditions (max amount, date ranges)
  - Test error cases and validation error messages
  - _Requirements: 8.3_

- [ ]* 23.3 Write unit tests for Firestore integration
  - Test `TransactionRepository` with mock Firestore
  - Test transaction persistence and retrieval
  - Test error handling and retry logic
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ]* 23.4 Write unit tests for offline queue
  - Test `LocalStorageDataSource` queue operations
  - Test `SyncOfflineQueue` sync logic
  - Test network connectivity monitoring
  - _Requirements: 10.3_

- [ ]* 23.5 Write widget tests for UI components
  - Test `DashboardPage` transaction display
  - Test `TransactionDetailPage` navigation and display
  - Test `ManualInputPage` input validation and parsing
  - _Requirements: 11.1, 11.2, 11.3, 12.1, 12.3_