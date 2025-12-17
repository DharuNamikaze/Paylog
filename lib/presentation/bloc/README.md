# BLoC State Management

This directory contains the BLoC (Business Logic Component) implementations for the Flutter SMS Transaction Parser app.

## SMS BLoC

**File:** `sms_bloc.dart`

**Purpose:** Manages SMS monitoring and permission handling.

### States
- `SmsInitial`: Initial state before any SMS operations
- `SmsListening`: Actively monitoring incoming SMS messages
- `SmsPermissionDenied`: SMS permissions not granted by user
- `SmsError`: Error occurred during SMS operations

### Events
- `StartSmsListening`: Begin monitoring SMS messages
- `StopSmsListening`: Stop monitoring SMS messages
- `SmsReceived`: Internal event when a new SMS is received
- `RequestSmsPermissions`: Request SMS permissions from user

### Usage Example
```dart
// Create the BLoC
final smsBloc = SmsBloc(
  smsPlatformChannel: SmsPlatformChannel(),
);

// Request permissions and start listening
smsBloc.add(RequestSmsPermissions());

// Stop listening
smsBloc.add(StopSmsListening());

// Listen to state changes
BlocBuilder<SmsBloc, SmsState>(
  builder: (context, state) {
    if (state is SmsListening) {
      return Text('Monitoring ${state.recentMessages.length} messages');
    } else if (state is SmsPermissionDenied) {
      return Text(state.message);
    } else if (state is SmsError) {
      return Text('Error: ${state.error}');
    }
    return Text('Not listening');
  },
)
```

## Transaction BLoC

**File:** `transaction_bloc.dart`

**Purpose:** Manages transaction data loading, adding, deleting, and refreshing.

### States
- `TransactionInitial`: Initial state before loading transactions
- `TransactionLoading`: Loading transactions from repository
- `TransactionLoaded`: Transactions successfully loaded
- `TransactionError`: Error occurred during transaction operations

### Events
- `LoadTransactions`: Load transactions for a specific user
- `AddTransaction`: Add a new transaction
- `DeleteTransaction`: Delete a transaction by ID
- `RefreshTransactions`: Refresh transactions and sync offline queue

### Usage Example
```dart
// Create the BLoC
final transactionBloc = TransactionBloc(
  transactionRepository: transactionRepository,
);

// Load transactions for a user
transactionBloc.add(LoadTransactions('user123'));

// Add a new transaction
transactionBloc.add(AddTransaction(transaction));

// Delete a transaction
transactionBloc.add(DeleteTransaction('transaction123'));

// Refresh transactions
transactionBloc.add(RefreshTransactions('user123'));

// Listen to state changes
BlocBuilder<TransactionBloc, TransactionState>(
  builder: (context, state) {
    if (state is TransactionLoading) {
      return CircularProgressIndicator();
    } else if (state is TransactionLoaded) {
      return ListView.builder(
        itemCount: state.transactions.length,
        itemBuilder: (context, index) {
          final transaction = state.transactions[index];
          return ListTile(
            title: Text('₹${transaction.amount}'),
            subtitle: Text('${transaction.date} ${transaction.time}'),
          );
        },
      );
    } else if (state is TransactionError) {
      return Text('Error: ${state.error}');
    }
    return Text('No transactions');
  },
)
```

## Integration

Both BLoCs should be provided at the app level using `MultiBlocProvider`:

```dart
MultiBlocProvider(
  providers: [
    BlocProvider<SmsBloc>(
      create: (context) => SmsBloc(
        smsPlatformChannel: SmsPlatformChannel(),
      ),
    ),
    BlocProvider<TransactionBloc>(
      create: (context) => TransactionBloc(
        transactionRepository: transactionRepository,
      ),
    ),
  ],
  child: MaterialApp(
    // Your app
  ),
)
```

## Requirements Validation

### SMS BLoC
- ✅ **Requirement 1.1**: Monitors incoming SMS messages using platform channels
- ✅ **Requirement 11.4**: Provides real-time state updates for UI

### Transaction BLoC
- ✅ **Requirement 7.1**: Manages transaction persistence through repository
- ✅ **Requirement 11.4**: Provides real-time transaction updates for UI
- ✅ Handles loading, error, and loaded states appropriately
- ✅ Sorts transactions by date and time (most recent first)
- ✅ Maintains cached transactions during errors for better UX
