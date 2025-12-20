# PayLog - UI & User Experience Documentation

## Overview

PayLog's user interface is built with Flutter, providing a native mobile experience on Android devices. The UI follows Material Design 3 principles with a clean, intuitive design focused on financial data visualization and easy transaction management.

## Design Philosophy

### Core Principles

1. **Simplicity First**: Clean, uncluttered interface that prioritizes essential information
2. **Financial Focus**: Design optimized for financial data display and interaction
3. **Accessibility**: Supports screen readers, high contrast, and large text
4. **Performance**: Smooth animations and responsive interactions
5. **Trust & Security**: Visual cues that reinforce data security and privacy

### Color Scheme

```dart
// Primary Colors
Primary: Colors.green (Financial growth, positive transactions)
Secondary: Colors.blue (Trust, stability)
Surface: Colors.white / Colors.grey[50]
Background: Colors.grey[100]

// Transaction Colors
Credit: Colors.green[600] (Money received)
Debit: Colors.red[600] (Money spent)
Unknown: Colors.orange[600] (Needs attention)

// Status Colors
Success: Colors.green[500]
Warning: Colors.orange[500]
Error: Colors.red[500]
Info: Colors.blue[500]
```

## Screen Architecture

### Navigation Structure

```
Dashboard (Home)
├── Transaction List
├── SMS Monitoring Controls
├── Service Status
└── Manual Entry (FAB)

Settings
├── Permissions
├── Firebase Status
├── Data Management
└── About
```

## Core Screens

### 1. Dashboard Page

The main screen that users see when opening the app.

#### Layout Structure

```
AppBar
├── Title: "PayLog"
├── Actions: [Settings, Refresh]

Body
├── Service Status Card
├── SMS Monitoring Controls
├── Transaction Statistics
└── Transaction List

FloatingActionButton
└── Manual Entry
```

#### Key Components

**Service Status Card**
```dart
Card(
  child: Column(
    children: [
      // Firebase connection status
      StatusIndicator(
        icon: Icons.cloud,
        label: "Firebase",
        status: isFirebaseConnected ? "Connected" : "Offline",
        color: isFirebaseConnected ? Colors.green : Colors.orange,
      ),
      
      // SMS monitoring status
      StatusIndicator(
        icon: Icons.sms,
        label: "SMS Monitoring",
        status: isSmsActive ? "Active" : "Inactive",
        color: isSmsActive ? Colors.green : Colors.grey,
      ),
    ],
  ),
)
```

**SMS Monitoring Controls**
```dart
Card(
  child: Row(
    children: [
      // Start/Stop monitoring button
      ElevatedButton.icon(
        onPressed: toggleSmsMonitoring,
        icon: Icon(isSmsActive ? Icons.stop : Icons.play_arrow),
        label: Text(isSmsActive ? "Stop Monitoring" : "Start Monitoring"),
      ),
      
      // Permission status
      Chip(
        avatar: Icon(hasPermissions ? Icons.check : Icons.warning),
        label: Text(hasPermissions ? "Permissions OK" : "Need Permissions"),
      ),
    ],
  ),
)
```

**Transaction Statistics**
```dart
Card(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      StatisticItem(
        label: "Today",
        value: "₹${todayTotal.toStringAsFixed(2)}",
        color: Colors.blue,
      ),
      StatisticItem(
        label: "This Month",
        value: "₹${monthTotal.toStringAsFixed(2)}",
        color: Colors.green,
      ),
      StatisticItem(
        label: "Total",
        value: "${totalCount} transactions",
        color: Colors.grey,
      ),
    ],
  ),
)
```

#### State Management

The Dashboard uses BLoC pattern for state management:

```dart
class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Listen to transaction updates
        BlocListener<TransactionBloc, TransactionState>(
          listener: (context, state) {
            if (state is TransactionError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
        ),
        
        // Listen to SMS monitoring updates
        BlocListener<SmsBloc, SmsState>(
          listener: (context, state) {
            if (state is SmsPermissionDenied) {
              _showPermissionDialog(context);
            }
          },
        ),
      ],
      child: Scaffold(
        body: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            return _buildDashboardContent(state);
          },
        ),
      ),
    );
  }
}
```

### 2. Transaction List

Displays all parsed transactions in a scrollable list.

#### Transaction Card Design

```dart
Card(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: ListTile(
    // Transaction type icon
    leading: CircleAvatar(
      backgroundColor: _getTransactionColor(transaction.transactionType),
      child: Icon(
        _getTransactionIcon(transaction.transactionType),
        color: Colors.white,
      ),
    ),
    
    // Transaction details
    title: Text(
      "₹${transaction.amount.toStringAsFixed(2)}",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(transaction.senderPhoneNumber),
        Text("${transaction.date} ${transaction.time}"),
        if (transaction.accountNumber != null)
          Text("Account: ${transaction.accountNumber}"),
      ],
    ),
    
    // Confidence indicator
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getConfidenceIcon(transaction.confidenceScore),
          color: _getConfidenceColor(transaction.confidenceScore),
        ),
        Text(
          "${(transaction.confidenceScore * 100).toInt()}%",
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
    
    // Tap to view details
    onTap: () => _showTransactionDetails(context, transaction),
  ),
)
```

#### List Features

**Pull-to-Refresh**
```dart
RefreshIndicator(
  onRefresh: () async {
    context.read<TransactionBloc>().add(RefreshTransactions());
  },
  child: ListView.builder(
    itemCount: transactions.length,
    itemBuilder: (context, index) {
      return TransactionCard(transaction: transactions[index]);
    },
  ),
)
```

**Empty State**
```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.receipt_long,
        size: 64,
        color: Colors.grey[400],
      ),
      SizedBox(height: 16),
      Text(
        "No transactions yet",
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      SizedBox(height: 8),
      Text(
        "Start SMS monitoring or add transactions manually",
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => _startSmsMonitoring(context),
        icon: Icon(Icons.sms),
        label: Text("Start SMS Monitoring"),
      ),
    ],
  ),
)
```

**Loading State**
```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text("Loading transactions..."),
    ],
  ),
)
```

### 3. Transaction Details Modal

Shows complete transaction information when a transaction card is tapped.

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.7,
    maxChildSize: 0.9,
    minChildSize: 0.5,
    builder: (context, scrollController) => Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _getTransactionIcon(transaction.transactionType),
                color: _getTransactionColor(transaction.transactionType),
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${transaction.amount.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      transaction.transactionType.toString().split('.').last,
                      style: TextStyle(
                        color: _getTransactionColor(transaction.transactionType),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          Divider(height: 32),
          
          // Transaction details
          _DetailRow("Date", transaction.date),
          _DetailRow("Time", transaction.time),
          _DetailRow("From", transaction.senderPhoneNumber),
          if (transaction.accountNumber != null)
            _DetailRow("Account", transaction.accountNumber!),
          _DetailRow("Confidence", "${(transaction.confidenceScore * 100).toInt()}%"),
          _DetailRow("Entry Type", transaction.isManualEntry ? "Manual" : "Automatic"),
          
          Divider(height: 32),
          
          // Original SMS content
          Text(
            "Original SMS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              transaction.smsContent,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareTransaction(transaction),
                  icon: Icon(Icons.share),
                  label: Text("Share"),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _deleteTransaction(transaction),
                  icon: Icon(Icons.delete),
                  label: Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
```

### 4. Manual Entry Form

Allows users to manually add transactions when SMS monitoring is unavailable.

```dart
class ManualEntryForm extends StatefulWidget {
  @override
  _ManualEntryFormState createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _smsController = TextEditingController();
  TransactionType _selectedType = TransactionType.DEBIT;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Transaction"),
        actions: [
          TextButton(
            onPressed: _saveTransaction,
            child: Text("SAVE"),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Amount input
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixText: "₹ ",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter an amount";
                  }
                  if (double.tryParse(value) == null) {
                    return "Please enter a valid amount";
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Transaction type selector
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Transaction Type",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<TransactionType>(
                              title: Text("Debit"),
                              subtitle: Text("Money spent"),
                              value: TransactionType.DEBIT,
                              groupValue: _selectedType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<TransactionType>(
                              title: Text("Credit"),
                              subtitle: Text("Money received"),
                              value: TransactionType.CREDIT,
                              groupValue: _selectedType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // SMS content (optional)
              TextFormField(
                controller: _smsController,
                decoration: InputDecoration(
                  labelText: "SMS Content (Optional)",
                  hintText: "Paste the original SMS here",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              
              SizedBox(height: 24),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveTransaction,
                  icon: Icon(Icons.save),
                  label: Text("Save Transaction"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      final transaction = Transaction(
        id: Uuid().v4(),
        userId: 'current-user',
        amount: double.parse(_amountController.text),
        transactionType: _selectedType,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        time: DateFormat('HH:mm:ss').format(DateTime.now()),
        smsContent: _smsController.text.isEmpty 
            ? "Manual entry: ${_selectedType.toString().split('.').last} ₹${_amountController.text}"
            : _smsController.text,
        senderPhoneNumber: "MANUAL",
        confidenceScore: 1.0,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: '',
        isManualEntry: true,
      );
      
      context.read<TransactionBloc>().add(AddTransaction(transaction));
      Navigator.of(context).pop();
    }
  }
}
```

### 5. Settings Page

Configuration and app information.

```dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: ListView(
        children: [
          // Permissions section
          _SectionHeader("Permissions"),
          ListTile(
            leading: Icon(Icons.sms),
            title: Text("SMS Permissions"),
            subtitle: Text("Required for automatic transaction detection"),
            trailing: BlocBuilder<SmsBloc, SmsState>(
              builder: (context, state) {
                final hasPermissions = state is SmsPermissionGranted;
                return Chip(
                  label: Text(hasPermissions ? "Granted" : "Not Granted"),
                  backgroundColor: hasPermissions ? Colors.green[100] : Colors.red[100],
                );
              },
            ),
            onTap: () => _requestSmsPermissions(context),
          ),
          
          Divider(),
          
          // Data section
          _SectionHeader("Data Management"),
          ListTile(
            leading: Icon(Icons.cloud),
            title: Text("Firebase Status"),
            subtitle: Text("Cloud sync and backup"),
            trailing: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                // Determine Firebase status from state
                return Chip(
                  label: Text("Connected"), // or "Offline"
                  backgroundColor: Colors.green[100],
                );
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.storage),
            title: Text("Local Storage"),
            subtitle: Text("View local data usage"),
            onTap: () => _showStorageInfo(context),
          ),
          ListTile(
            leading: Icon(Icons.sync),
            title: Text("Sync Now"),
            subtitle: Text("Manually sync pending transactions"),
            onTap: () => _syncTransactions(context),
          ),
          
          Divider(),
          
          // App info section
          _SectionHeader("About"),
          ListTile(
            leading: Icon(Icons.info),
            title: Text("App Version"),
            subtitle: Text("1.0.0+1"),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text("Privacy Policy"),
            onTap: () => _showPrivacyPolicy(context),
          ),
          ListTile(
            leading: Icon(Icons.bug_report),
            title: Text("Report Issue"),
            onTap: () => _reportIssue(context),
          ),
        ],
      ),
    );
  }
}
```

## UI Components

### Custom Widgets

**StatusIndicator**
```dart
class StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
        Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
```

**TransactionTypeChip**
```dart
class TransactionTypeChip extends StatelessWidget {
  final TransactionType type;
  
  @override
  Widget build(BuildContext context) {
    final color = _getTransactionColor(type);
    final icon = _getTransactionIcon(type);
    final label = type.toString().split('.').last;
    
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        label,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      backgroundColor: color,
    );
  }
}
```

### Animations

**Transaction Card Entry Animation**
```dart
class AnimatedTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final int index;
  
  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: TransactionCard(transaction: transaction),
        ),
      ),
    );
  }
}
```

**Loading Shimmer Effect**
```dart
class TransactionCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.white),
          title: Container(
            height: 16,
            width: 100,
            color: Colors.white,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Container(height: 12, width: 150, color: Colors.white),
              SizedBox(height: 4),
              Container(height: 12, width: 120, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Responsive Design

### Screen Size Adaptations

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        } else {
          return tablet ?? mobile;
        }
      },
    );
  }
}
```

### Orientation Handling

```dart
@override
Widget build(BuildContext context) {
  final orientation = MediaQuery.of(context).orientation;
  
  if (orientation == Orientation.landscape) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildSidebar()),
        Expanded(flex: 2, child: _buildMainContent()),
      ],
    );
  } else {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildMainContent()),
      ],
    );
  }
}
```

## Accessibility Features

### Screen Reader Support

```dart
Semantics(
  label: "Transaction: ${transaction.transactionType.toString().split('.').last} "
         "Amount: ${transaction.amount} rupees "
         "Date: ${transaction.date} "
         "From: ${transaction.senderPhoneNumber}",
  child: TransactionCard(transaction: transaction),
)
```

### High Contrast Support

```dart
@override
Widget build(BuildContext context) {
  final highContrast = MediaQuery.of(context).highContrast;
  
  return Container(
    decoration: BoxDecoration(
      border: highContrast 
          ? Border.all(color: Colors.black, width: 2)
          : null,
    ),
    child: child,
  );
}
```

### Large Text Support

```dart
Text(
  "Transaction Amount",
  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
    fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize! * 
              MediaQuery.textScaleFactorOf(context),
  ),
)
```

## Error Handling UI

### Error States

```dart
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            "Something went wrong",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text("Try Again"),
            ),
          ],
        ],
      ),
    );
  }
}
```

### Snackbar Notifications

```dart
void _showSuccessMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}

void _showErrorMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 5),
      action: SnackBarAction(
        label: "DISMISS",
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}
```

## Performance Optimizations

### List Performance

```dart
ListView.builder(
  // Use itemExtent for better performance
  itemExtent: 80.0,
  
  // Cache extent for smooth scrolling
  cacheExtent: 1000.0,
  
  // Build only visible items
  itemBuilder: (context, index) {
    return TransactionCard(
      key: ValueKey(transactions[index].id),
      transaction: transactions[index],
    );
  },
  itemCount: transactions.length,
)
```

### Image Optimization

```dart
// Use cached network images for better performance
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      width: 50,
      height: 50,
      color: Colors.white,
    ),
  ),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

### Memory Management

```dart
class _TransactionListState extends State<TransactionList> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Keep state alive
  
  @override
  void dispose() {
    // Clean up controllers and subscriptions
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
```

## Testing Support

### Widget Testing Utilities

```dart
// Test helpers for UI components
Widget createTestApp(Widget child) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<TransactionBloc>(
          create: (_) => MockTransactionBloc(),
        ),
        BlocProvider<SmsBloc>(
          create: (_) => MockSmsBloc(),
        ),
      ],
      child: child,
    ),
  );
}

// Find widgets in tests
Finder findTransactionCard(String transactionId) {
  return find.byKey(ValueKey('transaction_card_$transactionId'));
}

Finder findAmountText(double amount) {
  return find.text('₹${amount.toStringAsFixed(2)}');
}
```

### Golden Tests

```dart
testWidgets('Transaction card golden test', (tester) async {
  await tester.pumpWidget(
    createTestApp(
      TransactionCard(
        transaction: createTestTransaction(),
      ),
    ),
  );
  
  await expectLater(
    find.byType(TransactionCard),
    matchesGoldenFile('transaction_card.png'),
  );
});
```

## Future UI Enhancements

### Planned Features

1. **Dark Mode**: Complete dark theme implementation
2. **Custom Themes**: User-selectable color themes
3. **Advanced Filtering**: Filter transactions by date, amount, type
4. **Search Functionality**: Search transactions by content or amount
5. **Data Visualization**: Charts and graphs for spending analysis
6. **Export Options**: Share transactions as PDF or CSV
7. **Backup/Restore UI**: Visual backup and restore process
8. **Multi-language**: Support for regional languages
9. **Tablet Layout**: Optimized layout for larger screens
10. **Wear OS Support**: Basic transaction viewing on smartwatches

### Accessibility Improvements

1. **Voice Commands**: Voice-controlled transaction entry
2. **Gesture Navigation**: Custom gestures for common actions
3. **Color Blind Support**: Alternative visual indicators
4. **Keyboard Navigation**: Full keyboard accessibility
5. **Screen Reader Enhancements**: Better semantic descriptions

The UI is designed to be intuitive, accessible, and performant while maintaining a clean, professional appearance suitable for financial data management.