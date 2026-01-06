import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../core/theme/app_theme.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/sms_bloc.dart';
import '../bloc/sync_bloc.dart';
import '../widgets/sync_status_widget.dart';
import '../../core/routes/app_routes.dart';
import 'settings_page.dart';

/// Dashboard page that displays recent transactions with real-time updates
class DashboardPage extends StatefulWidget {
  /// User ID for loading transactions
  final String userId;

  const DashboardPage({
    super.key,
    required this.userId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load transactions when the page initializes
    context.read<TransactionBloc>().add(LoadTransactions(widget.userId));
    
    // Auto-start SMS monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartSmsMonitoring();
      _initializeSyncBloc();
    });
  }
  
  /// Initialize SyncBloc and start monitoring
  void _initializeSyncBloc() {
    try {
      final syncBloc = context.read<SyncBloc>();
      syncBloc.add(SyncStarted());
    } catch (e) {
      // SyncBloc not available - this is fine, sync functionality is optional
      debugPrint('Sync service not available: $e');
    }
  }

  /// Build sync button with status indicator for app bar
  /// 
  /// Requirements: 4.1, 4.2, 4.3
  Widget _buildSyncButton() {
    try {
      return BlocConsumer<SyncBloc, SyncBlocState>(
        listener: (context, state) {
          // Show snackbar when sync completes (Requirements: 4.2)
          if (state is SyncComplete) {
            _showSyncResultSnackbar(
              successCount: state.syncedCount,
              failureCount: 0,
            );
          } else if (state is SyncError) {
            _showSyncResultSnackbar(
              successCount: 0,
              failureCount: state.failedCount,
              errorMessage: state.message,
            );
          }
        },
        builder: (context, state) {
          final isSyncing = state is SyncInProgress;
          final isOffline = state is SyncOffline;
          
          return IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    _getSyncIcon(state),
                    color: _getSyncIconColor(state),
                  ),
                // Pending count badge
                if (state.pendingCount > 0 && !isSyncing)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.warningOrange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        state.pendingCount > 9 ? '9+' : state.pendingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // Disable button while syncing (Requirements: 4.3)
            onPressed: (isSyncing || isOffline) ? null : () {
              _triggerManualSync();
            },
            tooltip: _getSyncTooltip(state),
          );
        },
      );
    } catch (e) {
      // SyncBloc not available
      return const SizedBox.shrink();
    }
  }

  /// Get sync icon based on state
  IconData _getSyncIcon(SyncBlocState state) {
    if (state is SyncComplete) {
      return Icons.cloud_done;
    } else if (state is SyncPending) {
      return Icons.cloud_upload_outlined;
    } else if (state is SyncError) {
      return Icons.cloud_off;
    } else if (state is SyncOffline) {
      return Icons.cloud_off_outlined;
    }
    return Icons.cloud_outlined;
  }

  /// Get sync icon color based on state
  Color _getSyncIconColor(SyncBlocState state) {
    if (state is SyncComplete) {
      return AppTheme.successGreen;
    } else if (state is SyncPending) {
      return AppTheme.warningOrange;
    } else if (state is SyncError) {
      return AppTheme.errorRed;
    } else if (state is SyncOffline) {
      return Colors.grey;
    }
    return Colors.white;
  }

  /// Get sync tooltip based on state
  String _getSyncTooltip(SyncBlocState state) {
    if (state is SyncInProgress) {
      return 'Syncing...';
    } else if (state is SyncComplete) {
      return 'All synced';
    } else if (state is SyncPending) {
      return 'Tap to sync ${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'}';
    } else if (state is SyncError) {
      return 'Sync error - tap to retry';
    } else if (state is SyncOffline) {
      return 'Offline - ${state.pendingCount} pending';
    }
    return 'Cloud sync';
  }

  /// Trigger manual sync
  /// 
  /// Requirements: 4.1
  void _triggerManualSync() {
    try {
      context.read<SyncBloc>().add(SyncRequested());
    } catch (e) {
      debugPrint('Failed to trigger sync: $e');
    }
  }

  /// Show snackbar with sync results
  /// 
  /// Requirements: 4.2
  void _showSyncResultSnackbar({
    required int successCount,
    required int failureCount,
    String? errorMessage,
  }) {
    final hasSuccess = successCount > 0;
    final hasFailure = failureCount > 0 || errorMessage != null;
    
    String message;
    Color backgroundColor;
    IconData icon;
    
    if (hasSuccess && !hasFailure) {
      message = 'Synced $successCount transaction${successCount == 1 ? '' : 's'}';
      backgroundColor = AppTheme.successGreen;
      icon = Icons.cloud_done;
    } else if (hasFailure && !hasSuccess) {
      message = errorMessage ?? 'Failed to sync $failureCount transaction${failureCount == 1 ? '' : 's'}';
      backgroundColor = AppTheme.errorRed;
      icon = Icons.cloud_off;
    } else if (hasSuccess && hasFailure) {
      message = 'Synced $successCount, failed $failureCount';
      backgroundColor = AppTheme.warningOrange;
      icon = Icons.cloud_sync;
    } else {
      // No changes
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: hasFailure ? SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _triggerManualSync,
        ) : null,
      ),
    );
  }
  
  /// Automatically start SMS monitoring if permissions are available
  void _autoStartSmsMonitoring() {
    try {
      final smsBloc = context.read<SmsBloc>();
      final currentState = smsBloc.state;
      
      // Only auto-start if not already listening and not in error state
      if (currentState is! SmsListening && currentState is! SmsError) {
        smsBloc.add(StartSmsListening());
      }
    } catch (e) {
      // SmsBloc not available - this is fine, SMS functionality is optional
      debugPrint('SMS monitoring not available: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayLog'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Sync status indicator with manual sync button
          _buildSyncButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TransactionBloc>().add(RefreshTransactions(widget.userId));
            },
            tooltip: 'Refresh transactions',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // SMS Service Status and Controls
          _buildSmsServiceControls(),
          // Transaction List
          Expanded(
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state is TransactionError) {
                  return _buildErrorState(state);
                }

                if (state is TransactionLoaded) {
                  return _buildTransactionList(state.transactions);
                }

                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Todo FAB - positioned above manual entry FAB
          // Requirements: 1.1, 1.2, 1.3
          FloatingActionButton(
            heroTag: 'todoFab',
            onPressed: () => _navigateToTodoPage(),
            tooltip: 'Todo List',
            child: const Icon(Icons.checklist),
          ),
          const SizedBox(height: 16),
          // Manual Entry FAB - existing functionality
          FloatingActionButton.extended(
            heroTag: 'manualEntryFab',
            onPressed: () => _navigateToManualInput(),
            icon: const Icon(Icons.add),
            label: const Text('Manual Entry'),
            tooltip: 'Add transaction manually',
          ),
        ],
      ),
    );
  }

  /// Build the transaction list with pull-to-refresh
  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return _buildEmptyTransactionsState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TransactionBloc>().add(RefreshTransactions(widget.userId));
        // Wait a bit for the refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return TransactionCard(
            transaction: transaction,
            onTap: () => _onTransactionTap(transaction),
          );
        },
      ),
    );
  }

  /// Build error state with cached transactions if available
  Widget _buildErrorState(TransactionError state) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<TransactionBloc>().add(LoadTransactions(widget.userId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        if (state.cachedTransactions != null && state.cachedTransactions!.isNotEmpty)
          Expanded(
            child: _buildTransactionList(state.cachedTransactions!),
          )
        else
          const Expanded(
            child: Center(
              child: Text('No cached transactions available'),
            ),
          ),
      ],
    );
  }

  /// Build empty state when no transactions are loaded
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Loading transactions...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty transactions state
  Widget _buildEmptyTransactionsState() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TransactionBloc>().add(RefreshTransactions(widget.userId));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        children: const [
          SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pull down to refresh or wait for new SMS messages',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Handle transaction tap - navigate to transaction detail page
  void _onTransactionTap(Transaction transaction) {
    AppNavigator.toTransactionDetail(context, transaction);
  }

  /// Navigate to manual input page
  void _navigateToManualInput() {
    AppNavigator.toManualInput(context, widget.userId);
  }

  /// Navigate to todo page
  /// Requirements: 1.2
  void _navigateToTodoPage() {
    AppNavigator.toTodo(context);
  }

  /// Build SMS service controls and status
  Widget _buildSmsServiceControls() {
    // Check if SmsBloc is available
    try {
      return BlocBuilder<SmsBloc, SmsState>(
        builder: (context, smsState) {
        return Container(
          margin: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.sms,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SMS Monitoring',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      _buildServiceStatusIndicator(smsState),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Status message and controls
                  _buildServiceStatusMessage(smsState),
                  const SizedBox(height: 12),
                  
                  // Control buttons
                  _buildServiceControlButtons(smsState),
                ],
              ),
            ),
          ),
        );
      },
    );
    } catch (e) {
      // SmsBloc is not available, show a message
      return Container(
        margin: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sms_failed,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SMS Monitoring Unavailable',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SMS monitoring service is not available. You can still add transactions manually using the button below.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.warningOrange,
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
    }
  }

  /// Build service status indicator
  Widget _buildServiceStatusIndicator(SmsState state) {
    Color color;
    IconData icon;
    String tooltip;

    if (state is SmsListening) {
      color = AppTheme.successGreen;
      icon = Icons.radio_button_checked;
      tooltip = 'SMS monitoring is active';
    } else if (state is SmsPermissionDenied) {
      color = AppTheme.warningOrange;
      icon = Icons.warning;
      tooltip = 'SMS permissions required';
    } else if (state is SmsError) {
      color = AppTheme.errorRed;
      icon = Icons.error;
      tooltip = 'SMS monitoring error';
    } else {
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
      tooltip = 'SMS monitoring is inactive';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
          size: 16,
        ),
      ),
    );
  }

  /// Build service status message
  Widget _buildServiceStatusMessage(SmsState state) {
    String message;
    Color? textColor;
    IconData messageIcon;

    if (state is SmsListening) {
      message = 'Monitoring SMS messages for financial transactions';
      textColor = AppTheme.successGreen;
      messageIcon = Icons.check_circle_outline;
    } else if (state is SmsPermissionDenied) {
      message = state.message;
      textColor = AppTheme.warningOrange;
      messageIcon = Icons.warning_amber;
    } else if (state is SmsError) {
      message = state.error;
      textColor = AppTheme.errorRed;
      messageIcon = Icons.error_outline;
    } else {
      message = 'SMS monitoring is stopped. Start monitoring to automatically detect transaction messages.';
      textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      messageIcon = Icons.info_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          messageIcon,
          size: 16,
          color: textColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Build service control buttons
  Widget _buildServiceControlButtons(SmsState state) {
    return Row(
      children: [
        if (state is SmsListening) ...[
          ElevatedButton.icon(
            onPressed: () {
              try {
                context.read<SmsBloc>().add(StopSmsListening());
              } catch (e) {
                // SmsBloc not available
              }
            },
            icon: const Icon(Icons.stop),
            label: const Text('Stop Monitoring'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed.withValues(alpha: 0.1),
              foregroundColor: AppTheme.errorRed,
            ),
          ),
        ] else if (state is SmsPermissionDenied) ...[
          ElevatedButton.icon(
            onPressed: () {
              try {
                context.read<SmsBloc>().add(RequestSmsPermissions());
              } catch (e) {
                // SmsBloc not available
              }
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningOrange.withValues(alpha: 0.1),
              foregroundColor: AppTheme.warningOrange,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _showPermissionHelpDialog();
            },
            child: const Text('Help'),
          ),
        ] else if (state is SmsError) ...[
          ElevatedButton.icon(
            onPressed: () {
              try {
                context.read<SmsBloc>().add(StartSmsListening());
              } catch (e) {
                // SmsBloc not available
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _showErrorDetailsDialog(state.error);
            },
            child: const Text('Details'),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: () {
              try {
                context.read<SmsBloc>().add(StartSmsListening());
              } catch (e) {
                // SmsBloc not available
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Monitoring'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen.withValues(alpha: 0.1),
              foregroundColor: AppTheme.successGreen,
            ),
          ),
        ],
        const Spacer(),
        // Settings/Info button
        IconButton(
          onPressed: () {
            _showSmsMonitoringInfo();
          },
          icon: const Icon(Icons.info_outline),
          tooltip: 'SMS Monitoring Info',
        ),
      ],
    );
  }

  /// Show permission help dialog
  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Permissions Required'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To automatically detect financial transactions, this app needs permission to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Read incoming SMS messages'),
              Text('• Receive SMS messages in real-time'),
              SizedBox(height: 12),
              Text(
                'Your privacy is protected:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Only financial messages are processed'),
              Text('• Non-financial messages are ignored'),
              Text('• SMS content is only used for transaction parsing'),
              Text('• No messages are shared with third parties'),
              SizedBox(height: 12),
              Text(
                'You can also use Manual Entry if you prefer not to grant SMS permissions.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              try {
                context.read<SmsBloc>().add(RequestSmsPermissions());
              } catch (e) {
                // SmsBloc not available
              }
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  /// Show error details dialog
  void _showErrorDetailsDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Monitoring Error'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'An error occurred while monitoring SMS messages:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Possible solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Check SMS permissions in device settings'),
              const Text('• Restart the app'),
              const Text('• Use Manual Entry as an alternative'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              try {
                context.read<SmsBloc>().add(StartSmsListening());
              } catch (e) {
                // SmsBloc not available
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Show SMS monitoring information dialog
  void _showSmsMonitoringInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Monitoring'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How it works:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. The app monitors incoming SMS messages'),
              Text('2. Financial messages are automatically detected'),
              Text('3. Transaction details are parsed and saved'),
              Text('4. Non-financial messages are ignored'),
              SizedBox(height: 16),
              Text(
                'Supported banks and services:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• All major Indian banks (HDFC, ICICI, SBI, Axis, etc.)'),
              Text('• Payment services (Paytm, PhonePe, GPay, etc.)'),
              Text('• Credit card companies'),
              Text('• Digital wallets'),
              SizedBox(height: 16),
              Text(
                'Privacy & Security:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Only financial messages are processed'),
              Text('• All data is stored locally and in your Firebase'),
              Text('• No data is shared with third parties'),
              Text('• You can stop monitoring at any time'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Custom widget to display individual transaction information
class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebit = transaction.transactionType == TransactionType.debit;
    final isCredit = transaction.transactionType == TransactionType.credit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount and transaction type row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Transaction type icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getTransactionColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getTransactionIcon(),
                            color: _getTransactionColor(context),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Amount
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isDebit ? '-' : isCredit ? '+' : ''}₹${_formatAmount(transaction.amount)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: _getTransactionColor(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getTransactionTypeText(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Manual entry indicator and sync status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sync status indicator (Requirements: 2.5, 3.1)
                      TransactionSyncIndicator(
                        isSynced: transaction.syncedToFirestore,
                        size: 16,
                      ),
                      if (transaction.isManualEntry) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Manual',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Account number and date/time row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Account number
                  if (transaction.accountNumber != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'A/C: ${transaction.accountNumber}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDate(transaction.date)} ${_formatTime(transaction.time)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Sender information
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'From: ${transaction.senderPhoneNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Confidence score indicator
                  if (transaction.confidenceScore < 0.8)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            size: 12,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Low confidence',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.warningOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get the appropriate icon for the transaction type
  IconData _getTransactionIcon() {
    switch (transaction.transactionType) {
      case TransactionType.debit:
        return Icons.arrow_upward;
      case TransactionType.credit:
        return Icons.arrow_downward;
      case TransactionType.unknown:
        return Icons.help_outline;
    }
  }

  /// Get the appropriate color for the transaction type
  Color _getTransactionColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (transaction.transactionType) {
      case TransactionType.debit:
        return AppTheme.errorRed;
      case TransactionType.credit:
        return AppTheme.successGreen;
      case TransactionType.unknown:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// Get the text representation of the transaction type
  String _getTransactionTypeText() {
    switch (transaction.transactionType) {
      case TransactionType.debit:
        return 'Debit';
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.unknown:
        return 'Unknown';
    }
  }

  /// Format amount with proper comma separation
  String _formatAmount(double amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final amountStr = amount.toStringAsFixed(2);
    return amountStr.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  /// Format date from ISO 8601 to readable format
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final transactionDate = DateTime(date.year, date.month, date.day);

      if (transactionDate == today) {
        return 'Today';
      } else if (transactionDate == yesterday) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return isoDate;
    }
  }

  /// Format time from HH:MM:SS to readable format
  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
      return time;
    } catch (e) {
      return time;
    }
  }
}
