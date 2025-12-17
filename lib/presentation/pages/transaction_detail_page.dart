import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../bloc/transaction_bloc.dart';

/// Transaction Detail page that shows comprehensive transaction information
/// including original SMS content and all parsed fields in organized sections
class TransactionDetailPage extends StatelessWidget {
  /// The transaction to display details for
  final Transaction transaction;

  const TransactionDetailPage({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyTransactionDetails(context),
            tooltip: 'Copy details',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_sms',
                child: Row(
                  children: [
                    Icon(Icons.message),
                    SizedBox(width: 8),
                    Text('Copy SMS'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Summary Card
            _buildTransactionSummaryCard(context),
            const SizedBox(height: 16),
            
            // Transaction Details Section
            _buildDetailsSection(context),
            const SizedBox(height: 16),
            
            // Account Information Section
            _buildAccountSection(context),
            const SizedBox(height: 16),
            
            // SMS Information Section
            _buildSmsSection(context),
            const SizedBox(height: 16),
            
            // Metadata Section
            _buildMetadataSection(context),
          ],
        ),
      ),
    );
  }

  /// Build the main transaction summary card
  Widget _buildTransactionSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDebit = transaction.transactionType == TransactionType.debit;
    final isCredit = transaction.transactionType == TransactionType.credit;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Transaction type icon and amount
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getTransactionColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    _getTransactionIcon(),
                    color: _getTransactionColor(context),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isDebit ? '-' : isCredit ? '+' : ''}₹${_formatAmount(transaction.amount)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: _getTransactionColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getTransactionTypeText(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Date and time
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(transaction.date),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(transaction.time),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Status indicators
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (transaction.isManualEntry)
                  _buildStatusChip(
                    context,
                    'Manual Entry',
                    Icons.edit,
                    theme.colorScheme.secondary,
                  ),
                if (transaction.syncedToFirestore)
                  _buildStatusChip(
                    context,
                    'Synced',
                    Icons.cloud_done,
                    Colors.green,
                  )
                else
                  _buildStatusChip(
                    context,
                    'Pending Sync',
                    Icons.cloud_upload,
                    Colors.orange,
                  ),
                if (transaction.confidenceScore < 0.8)
                  _buildStatusChip(
                    context,
                    'Low Confidence',
                    Icons.warning_amber,
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a status chip
  Widget _buildStatusChip(BuildContext context, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  /// Build the transaction details section
  Widget _buildDetailsSection(BuildContext context) {
    return _buildSection(
      context,
      'Transaction Details',
      Icons.receipt_long,
      [
        _buildDetailRow(context, 'Transaction ID', transaction.id),
        _buildDetailRow(context, 'Amount', '₹${_formatAmount(transaction.amount)}'),
        _buildDetailRow(context, 'Type', _getTransactionTypeText()),
        _buildDetailRow(context, 'Date', _formatDate(transaction.date)),
        _buildDetailRow(context, 'Time', _formatTime(transaction.time)),
        _buildDetailRow(
          context, 
          'Confidence Score', 
          '${(transaction.confidenceScore * 100).toStringAsFixed(1)}%'
        ),
      ],
    );
  }

  /// Build the account information section
  Widget _buildAccountSection(BuildContext context) {
    return _buildSection(
      context,
      'Account Information',
      Icons.account_balance,
      [
        _buildDetailRow(
          context, 
          'Account Number', 
          transaction.accountNumber ?? 'Not specified'
        ),
        _buildDetailRow(context, 'User ID', transaction.userId),
      ],
    );
  }

  /// Build the SMS information section
  Widget _buildSmsSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return _buildSection(
      context,
      'SMS Information',
      Icons.message,
      [
        _buildDetailRow(context, 'Sender', transaction.senderPhoneNumber),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Original SMS Content',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copySmsContent(context),
                  tooltip: 'Copy SMS content',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                transaction.smsContent,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build the metadata section
  Widget _buildMetadataSection(BuildContext context) {
    return _buildSection(
      context,
      'Metadata',
      Icons.info_outline,
      [
        _buildDetailRow(
          context, 
          'Created At', 
          _formatDateTime(transaction.createdAt)
        ),
        _buildDetailRow(
          context, 
          'Sync Status', 
          transaction.syncedToFirestore ? 'Synced to cloud' : 'Pending sync'
        ),
        _buildDetailRow(
          context, 
          'Entry Method', 
          transaction.isManualEntry ? 'Manual entry' : 'Automatic detection'
        ),
        _buildDetailRow(context, 'Duplicate Hash', transaction.duplicateCheckHash),
      ],
    );
  }

  /// Build a section with title and content
  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Build a detail row with label and value
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle menu actions
  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'copy_sms':
        _copySmsContent(context);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  /// Copy SMS content to clipboard
  void _copySmsContent(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transaction.smsContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SMS content copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Copy transaction details to clipboard
  void _copyTransactionDetails(BuildContext context) {
    final details = '''
Transaction Details:
ID: ${transaction.id}
Amount: ₹${_formatAmount(transaction.amount)}
Type: ${_getTransactionTypeText()}
Date: ${_formatDate(transaction.date)}
Time: ${_formatTime(transaction.time)}
Account: ${transaction.accountNumber ?? 'Not specified'}
Sender: ${transaction.senderPhoneNumber}
Confidence: ${(transaction.confidenceScore * 100).toStringAsFixed(1)}%

Original SMS:
${transaction.smsContent}
''';

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransaction(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Delete the transaction
  void _deleteTransaction(BuildContext context) {
    context.read<TransactionBloc>().add(DeleteTransaction(transaction.id));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction deleted'),
        duration: Duration(seconds: 2),
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
        return Colors.red;
      case TransactionType.credit:
        return Colors.green;
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

  /// Format DateTime to readable format
  String _formatDateTime(DateTime dateTime) {
    final date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final time = _formatTime('${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}');
    return '$date at $time';
  }
}