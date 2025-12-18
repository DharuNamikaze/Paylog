import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/sms_message.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/usecases/parse_sms_transaction.dart';
import '../../domain/usecases/validate_transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../../core/routes/app_routes.dart';

/// Manual SMS Input page that allows users to manually enter SMS messages
/// when automatic detection fails or SMS permissions are unavailable
class ManualInputPage extends StatefulWidget {
  /// User ID for saving transactions
  final String userId;

  const ManualInputPage({
    super.key,
    required this.userId,
  });

  @override
  State<ManualInputPage> createState() => _ManualInputPageState();
}

class _ManualInputPageState extends State<ManualInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _smsContentController = TextEditingController();
  final _senderController = TextEditingController();
  
  final _parseSmsTransaction = ParseSmsTransaction();
  final _validateTransaction = ValidateTransaction();
  
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  Transaction? _parsedTransaction;

  @override
  void dispose() {
    _smsContentController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual SMS Entry'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Information card
              _buildInfoCard(context),
              const SizedBox(height: 24),
              
              // SMS input form
              _buildInputForm(context),
              const SizedBox(height: 24),
              
              // Action buttons
              _buildActionButtons(context),
              const SizedBox(height: 24),
              
              // Results section
              if (_errorMessage != null || _successMessage != null || _parsedTransaction != null)
                _buildResultsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the information card explaining manual entry
  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Manual SMS Entry',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this feature when automatic SMS detection is unavailable or when you need to manually add transaction SMS messages.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The system will parse your SMS using the same logic as automatic messages and validate the transaction before saving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the SMS input form
  Widget _buildInputForm(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SMS Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Sender phone number field
        TextFormField(
          controller: _senderController,
          decoration: const InputDecoration(
            labelText: 'Sender Phone Number',
            hintText: 'e.g., HDFC-BANK, ICICI, or +919876543210',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the sender phone number or name';
            }
            if (value.trim().length < 3) {
              return 'Sender must be at least 3 characters long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // SMS content field
        TextFormField(
          controller: _smsContentController,
          decoration: const InputDecoration(
            labelText: 'SMS Content',
            hintText: 'Paste the complete SMS message here...',
            prefixIcon: Icon(Icons.message),
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the SMS content';
            }
            if (value.trim().length < 10) {
              return 'SMS content seems too short to be a valid transaction message';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        
        // Example SMS hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Example SMS:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dear Customer, Rs.5000.00 has been debited from your account XXXXXX1234 on 15-Dec-24 at 14:30. Available balance: Rs.25000.00',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build the action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isProcessing ? null : _clearForm,
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processSms,
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Parse & Save Transaction'),
          ),
        ),
      ],
    );
  }

  /// Build the results section
  Widget _buildResultsSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Error message
        if (_errorMessage != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parsing Failed',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Success message
        if (_successMessage != null)
          Card(
            color: Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Saved Successfully',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _successMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Parsed transaction preview
        if (_parsedTransaction != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.preview,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Parsed Transaction',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _viewTransactionDetails(_parsedTransaction!),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTransactionSummary(_parsedTransaction!),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Build a summary of the parsed transaction
  Widget _buildTransactionSummary(Transaction transaction) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Amount',
                '₹${_formatAmount(transaction.amount)}',
                Icons.currency_rupee,
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Type',
                _getTransactionTypeText(transaction),
                _getTransactionIcon(transaction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Date',
                _formatDate(transaction.date),
                Icons.calendar_today,
              ),
            ),
            Expanded(
              child: _buildSummaryItem(
                'Confidence',
                '${(transaction.confidenceScore * 100).toStringAsFixed(1)}%',
                Icons.analytics,
              ),
            ),
          ],
        ),
        if (transaction.accountNumber != null) ...[
          const SizedBox(height: 8),
          _buildSummaryItem(
            'Account',
            transaction.accountNumber!,
            Icons.account_balance,
          ),
        ],
      ],
    );
  }

  /// Build a summary item
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Clear the form and reset state
  void _clearForm() {
    _smsContentController.clear();
    _senderController.clear();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _parsedTransaction = null;
    });
  }

  /// Process the manually entered SMS
  Future<void> _processSms() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
      _parsedTransaction = null;
    });

    try {
      // Create SMS message from input
      final smsMessage = SmsMessage(
        sender: _senderController.text.trim(),
        content: _smsContentController.text.trim(),
        timestamp: DateTime.now(),
      );

      // Parse the SMS message
      final parsedTransaction = _parseSmsTransaction.parseTransaction(smsMessage);
      
      if (parsedTransaction == null) {
        setState(() {
          _errorMessage = 'Unable to parse transaction from the SMS content. '
              'Please ensure the message contains transaction information like amount, '
              'transaction type (debit/credit), and other financial details.';
          _isProcessing = false;
        });
        return;
      }

      // Create full transaction object
      final transaction = Transaction(
        id: _generateTransactionId(),
        userId: widget.userId,
        createdAt: DateTime.now(),
        syncedToFirestore: false,
        duplicateCheckHash: _generateDuplicateHash(smsMessage),
        isManualEntry: true, // Mark as manual entry
        amount: parsedTransaction.amount,
        transactionType: parsedTransaction.transactionType,
        accountNumber: parsedTransaction.accountNumber,
        date: parsedTransaction.date,
        time: parsedTransaction.time,
        smsContent: parsedTransaction.smsContent,
        senderPhoneNumber: parsedTransaction.senderPhoneNumber,
        confidenceScore: parsedTransaction.confidenceScore,
      );

      // Validate the transaction
      final validationResult = _validateTransaction.validateTransaction(transaction);
      
      if (!validationResult.isValid) {
        setState(() {
          _errorMessage = 'Transaction validation failed:\n${validationResult.errors.join('\n')}';
          if (validationResult.warnings.isNotEmpty) {
            _errorMessage = '$_errorMessage\n\nWarnings:\n${validationResult.warnings.join('\n')}';
          }
          _isProcessing = false;
        });
        return;
      }

      // Save the transaction
      if (mounted) {
        context.read<TransactionBloc>().add(AddTransaction(transaction));
      }

      setState(() {
        _parsedTransaction = transaction;
        _successMessage = 'Transaction parsed and saved successfully. '
            'Confidence score: ${(transaction.confidenceScore * 100).toStringAsFixed(1)}%';
        if (validationResult.warnings.isNotEmpty) {
          _successMessage = '$_successMessage\n\nWarnings: ${validationResult.warnings.join(', ')}';
        }
        _isProcessing = false;
      });

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while processing the SMS: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  /// Generate a unique transaction ID
  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'manual_$timestamp';
  }

  /// Generate a duplicate check hash
  String _generateDuplicateHash(SmsMessage sms) {
    final content = '${sms.sender}_${sms.content}_${sms.timestamp.millisecondsSinceEpoch}';
    return content.hashCode.toString();
  }

  /// View transaction details
  void _viewTransactionDetails(Transaction transaction) {
    AppNavigator.toTransactionDetail(context, transaction);
  }

  /// Show help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual SMS Entry Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use Manual SMS Entry:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Enter the sender name or phone number (e.g., HDFC-BANK, ICICI, +919876543210)'),
              SizedBox(height: 4),
              Text('2. Paste or type the complete SMS content'),
              SizedBox(height: 4),
              Text('3. Click "Parse & Save Transaction" to process'),
              SizedBox(height: 16),
              Text(
                'The SMS should contain:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Transaction amount (e.g., Rs.5000, ₹1,500)'),
              SizedBox(height: 4),
              Text('• Transaction type keywords (debited, credited, transferred)'),
              SizedBox(height: 4),
              Text('• Account information (optional)'),
              SizedBox(height: 4),
              Text('• Date and time (optional - current time will be used if not found)'),
              SizedBox(height: 16),
              Text(
                'Note:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Manually entered transactions are marked as "Manual Entry" and use the same parsing logic as automatic SMS detection.'),
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

  /// Helper methods for formatting and display
  String _formatAmount(double amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final amountStr = amount.toStringAsFixed(2);
    return amountStr.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  String _getTransactionTypeText(Transaction transaction) {
    switch (transaction.transactionType) {
      case TransactionType.debit:
        return 'Debit';
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.unknown:
        return 'Unknown';
    }
  }

  IconData _getTransactionIcon(Transaction transaction) {
    switch (transaction.transactionType) {
      case TransactionType.debit:
        return Icons.arrow_upward;
      case TransactionType.credit:
        return Icons.arrow_downward;
      case TransactionType.unknown:
        return Icons.help_outline;
    }
  }
}
