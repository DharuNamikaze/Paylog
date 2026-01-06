# Requirements Document

## Introduction

This feature enables automatic synchronization of locally stored SMS transaction data to a cloud database (Firebase Firestore). The system implements a **production-locked, offline-first, upload-only sync pipeline**.

### Pipeline Flow (FINAL)
```
SMS received → parse transaction → store locally (SOURCE OF TRUTH)
            → if internet available → upload to Firestore
            → mark as synced → KEEP local data permanently
```

### Core Rules (NON-NEGOTIABLE)

**Local Storage is Source of Truth:**
- UI MUST always read from local DB
- UI MUST NEVER depend on Firestore reads
- Local transactions are kept indefinitely
- No automatic cleanup based on sync status
- Deletion is user-initiated only

**Firestore is Replication Only:**
- Firestore is used for backup/mirror ONLY
- Firestore writes MUST be idempotent (hash-based IDs)
- Firestore is NOT a primary store for UI

**Sync is Upload-Only:**
- Sync uploads ONLY `syncedToFirestore == false` transactions
- Sync NEVER deletes local data
- Sync NEVER pulls or overwrites local data

**UI Behavior:**
- UI shows ALL local transactions at all times
- `syncedToFirestore` affects ONLY: cloud status icon, retry logic, debug info
- Sync completion MUST NOT refresh or clear UI

**Failure Handling:**
- If offline → queue locally
- If Firestore fails → retry later
- Firestore failure MUST NOT affect UI

### Explicitly OUT OF SCOPE
- Pulling from Firestore
- Replacing local data with cloud data
- Auto-cleanup after sync
- UI refresh tied to sync completion

## Glossary

- **Sync_Service**: The service responsible for coordinating transaction uploads from local storage to Firestore (upload-only, never pulls)
- **Transaction**: A parsed financial transaction record extracted from SMS messages
- **Offline_Queue**: Local storage queue holding transactions pending cloud synchronization
- **Firestore**: Google's cloud-hosted NoSQL database used for remote transaction backup/mirror (NOT primary store)
- **Sync_Status**: Indicator showing whether a transaction has been successfully uploaded to the cloud
- **Connectivity_Monitor**: Component that detects network availability changes
- **Transaction_Hash**: A unique hash derived from transaction content (amount, date, time, account, SMS content) used as the Firestore document ID for cloud-side deduplication
- **Anonymous_Auth**: Firebase Anonymous Authentication that creates a unique user ID (UID) per device without requiring login credentials
- **Sync_Trigger**: A specific event that initiates the sync process (app startup, app resume, connectivity regain)

## Requirements

### Requirement 1: Local-First Data Access (NON-NEGOTIABLE)

**User Story:** As a user, I want my transactions to always be visible from local storage, so that I can access my financial data regardless of sync status or network conditions.

#### Acceptance Criteria

1. THE System SHALL read ALL transactions from local storage for UI display
2. THE System SHALL NEVER read transactions from Firestore for UI display
3. THE System SHALL display ALL local transactions regardless of syncedToFirestore status
4. THE System SHALL retain local transactions indefinitely after successful sync
5. THE Sync_Service SHALL NEVER delete local transactions after upload
6. THE Sync_Service SHALL NEVER pull or overwrite local data from Firestore
7. WHEN sync completes, THE System SHALL NOT refresh or clear the transaction list
8. THE syncedToFirestore flag SHALL affect ONLY: cloud status icon, retry logic, and debug info

### Requirement 2: Event-Driven Transaction Sync (Upload-Only)

**User Story:** As a user, I want my transactions to be automatically uploaded to the cloud database at appropriate times, so that my financial data is backed up without draining my battery.

#### Acceptance Criteria

1. WHEN a new transaction is saved locally, THE Sync_Service SHALL queue it for cloud upload
2. WHEN the app starts, THE Sync_Service SHALL trigger a sync if network is available and not already syncing
3. WHEN the app resumes from background, THE Sync_Service SHALL trigger a sync if network is available and not already syncing
4. WHEN network connectivity changes from offline to online, THE Sync_Service SHALL trigger a sync if not already syncing
5. WHEN a transaction is successfully uploaded, THE Sync_Service SHALL update the local transaction's syncedToFirestore flag to true
6. WHEN a transaction is successfully uploaded, THE Sync_Service SHALL NOT delete or move the local transaction
7. WHEN a transaction upload fails, THE Sync_Service SHALL retain the transaction in the Offline_Queue for retry
8. THE Sync_Service SHALL upload transactions in chronological order (oldest first)
9. THE Sync_Service SHALL NOT trigger sync on every transaction insert to prevent battery drain
10. THE Sync_Service SHALL upload ONLY transactions where syncedToFirestore equals false

### Requirement 3: Offline Queue Management

**User Story:** As a user, I want my transactions to be safely stored when offline, so that no data is lost due to connectivity issues.

#### Acceptance Criteria

1. WHEN the device is offline, THE Sync_Service SHALL store transactions in the Offline_Queue
2. WHEN connectivity is restored, THE Sync_Service SHALL automatically process the Offline_Queue
3. THE Sync_Service SHALL persist the Offline_Queue across app restarts
4. WHEN a transaction is in the Offline_Queue, THE Sync_Service SHALL prevent duplicate entries for the same transaction
5. WHEN viewing transactions, THE System SHALL display both synced and unsynced transactions with appropriate status indicators

### Requirement 4: Sync Status Visibility

**User Story:** As a user, I want to see the sync status of my transactions, so that I know which transactions have been backed up to the cloud.

#### Acceptance Criteria

1. WHEN displaying a transaction, THE System SHALL show whether it is synced or pending sync
2. WHEN transactions are pending sync, THE System SHALL display the count of pending transactions
3. WHEN a sync operation is in progress, THE System SHALL display a sync indicator
4. WHEN all transactions are synced, THE System SHALL indicate the sync is complete

### Requirement 5: Manual Sync Trigger (Idempotent)

**User Story:** As a user, I want to manually trigger a sync operation, so that I can ensure my data is uploaded when I have a good connection.

#### Acceptance Criteria

1. WHEN the user triggers a manual sync, THE Sync_Service SHALL attempt to upload all queued transactions
2. WHEN manual sync completes, THE System SHALL display the result (success count, failure count)
3. IF a sync is already in progress, THEN THE System SHALL inform the user and not start a duplicate sync
4. WHEN manual sync completes, THE System SHALL NOT alter the UI transaction list
5. THE manual sync operation SHALL be idempotent (safe to trigger multiple times)

### Requirement 6: Connectivity Monitoring

**User Story:** As a user, I want the app to automatically detect when I'm online, so that syncing happens without my intervention.

#### Acceptance Criteria

1. THE Connectivity_Monitor SHALL detect changes in network connectivity state
2. WHEN connectivity changes from offline to online, THE Sync_Service SHALL automatically start syncing queued transactions
3. WHEN connectivity is lost during sync, THE Sync_Service SHALL gracefully pause and resume when connectivity returns
4. THE Connectivity_Monitor SHALL distinguish between WiFi and mobile data connections

### Requirement 7: Error Handling and Retry (UI Isolation)

**User Story:** As a user, I want failed uploads to be automatically retried, so that temporary network issues don't cause data loss.

#### Acceptance Criteria

1. WHEN a transaction upload fails due to network error, THE Sync_Service SHALL retry with exponential backoff
2. THE Sync_Service SHALL limit retry attempts to a maximum of 5 per transaction
3. WHEN maximum retries are exceeded, THE Sync_Service SHALL mark the transaction as failed and notify the user
4. WHEN a Firestore permission error occurs, THE Sync_Service SHALL not retry and SHALL notify the user of authentication issues
5. THE Sync_Service SHALL log all sync errors for debugging purposes
6. WHEN Firestore fails, THE System SHALL NOT affect UI display of transactions
7. WHEN offline, THE System SHALL continue to display all local transactions normally

### Requirement 8: Data Integrity and Cloud-Side Deduplication

**User Story:** As a user, I want my transaction data to remain consistent between local and cloud storage, so that I can trust my financial records.

#### Acceptance Criteria

1. THE Sync_Service SHALL use the Transaction_Hash as the Firestore document ID to prevent duplicate uploads at the cloud level
2. WHEN uploading a transaction, THE Sync_Service SHALL use the path `/users/{uid}/transactions/{transactionHash}` in Firestore
3. IF a transaction already exists in Firestore with the same Transaction_Hash, THEN THE Sync_Service SHALL update rather than create a duplicate
4. WHEN uploading a transaction, THE Sync_Service SHALL include all transaction fields without data loss
5. THE Sync_Service SHALL validate transaction data before upload
6. THE Transaction_Hash SHALL be computed from: amount, date, time, accountNumber, and smsContent

### Requirement 9: Firebase Anonymous Authentication

**User Story:** As a user, I want my transactions to be securely associated with my device, so that my data is protected and can be migrated to a full account later.

#### Acceptance Criteria

1. WHEN the app starts for the first time, THE System SHALL create a Firebase Anonymous Auth session
2. THE System SHALL persist the Anonymous Auth UID across app restarts
3. WHEN uploading transactions, THE Sync_Service SHALL use the Anonymous Auth UID as the userId
4. THE Firestore security rules SHALL restrict transaction access to the owning UID only
5. WHEN the user signs in with a full account later, THE System SHALL support migrating transactions from the anonymous UID to the authenticated UID
6. IF Anonymous Auth fails, THEN THE System SHALL operate in local-only mode and notify the user
