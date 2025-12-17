import '../entities/sms_message.dart';
import '../entities/transaction.dart';
import '../entities/transaction_type.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/transaction_type_classifier.dart';
import '../../core/utils/account_number_extractor.dart';
import '../../core/utils/datetime_parser.dart';
import 'detect_financial_context.dart';

/// SMS Parser Service that orchestrates all parsing utilities
/// 
/// This service is responsible for:
/// - Validating that SMS contains financial context
/// - Extracting transaction amount
/// - Classifying transaction type (debit/credit)
/// - Extracting account number
/// - Parsing date and time
/// - Generating confidence scores
/// - Handling parsing failures
class ParseSmsTransaction {
  final FinancialContextDetector _financialDetector;
  
  /// Create a new SMS parser service
  ParseSmsTransaction({
    FinancialContextDetector? financialDetector,
  }) : _financialDetector = financialDetector ?? FinancialContextDetector();
  
  /// Parse an SMS message into a structured transaction
  /// 
  /// Returns null if:
  /// - The SMS is not a financial message
  /// - Required fields (amount) cannot be extracted
  /// - Parsing fails for any critical reason
  /// 
  /// Logs unparseable messages for manual review
  ParsedTransaction? parseTransaction(SmsMessage sms) {
    try {
      // Step 1: Validate that this is a financial message
      if (!_financialDetector.isFinancialMessage(sms.content)) {
        _logUnparseableMessage(
          sms,
          'Not a financial message - no financial keywords detected',
        );
        return null;
      }
      
      // Step 2: Extract transaction amount (required field)
      final amount = AmountParser.extractAmount(sms.content);
      if (amount == null) {
        _logUnparseableMessage(
          sms,
          'Failed to extract transaction amount',
        );
        return null;
      }
      
      // Step 3: Classify transaction type
      final transactionType = TransactionTypeClassifier.classifyTransaction(
        sms.content,
      );
      
      // Step 4: Extract account number (optional)
      final accountNumber = AccountNumberExtractor.extractAccountNumber(
        sms.content,
      );
      
      // Step 5: Parse date and time
      final dateTime = DateTimeParser.extractDateTime(
        sms.content,
        sms.timestamp,
      );
      final date = dateTime['date']!;
      final time = dateTime['time']!;
      
      // Step 6: Calculate confidence score
      final confidenceScore = _calculateConfidenceScore(
        sms.content,
        amount,
        transactionType,
        accountNumber,
      );
      
      // Step 7: Create and return parsed transaction
      return ParsedTransaction(
        amount: amount,
        transactionType: transactionType,
        accountNumber: accountNumber,
        date: date,
        time: time,
        smsContent: sms.content,
        senderPhoneNumber: sms.sender,
        confidenceScore: confidenceScore,
      );
    } catch (e, stackTrace) {
      // Log parsing failures
      _logParsingError(sms, e, stackTrace);
      return null;
    }
  }
  
  /// Calculate confidence score for the parsed transaction
  /// 
  /// Confidence is based on:
  /// - Financial context detection score (0.0-0.4)
  /// - Amount extraction success (0.0-0.3)
  /// - Transaction type classification (0.0-0.2)
  /// - Account number extraction (0.0-0.1)
  /// 
  /// Returns a score between 0.0 and 1.0
  double _calculateConfidenceScore(
    String content,
    double? amount,
    TransactionType transactionType,
    String? accountNumber,
  ) {
    double score = 0.0;
    
    // Financial context score (max 0.4)
    final financialScore = _financialDetector.getConfidenceScore(content);
    score += financialScore * 0.4;
    
    // Amount extraction score (max 0.3)
    if (amount != null && amount > 0) {
      // Higher confidence for amounts with clear currency indicators
      if (content.contains('₹') || 
          content.toLowerCase().contains('rs') ||
          content.toLowerCase().contains('inr') ||
          content.toLowerCase().contains('rupees')) {
        score += 0.3;
      } else {
        score += 0.2;
      }
    }
    
    // Transaction type classification score (max 0.2)
    if (transactionType != TransactionType.unknown) {
      final typeConfidence = TransactionTypeClassifier.getConfidenceScore(
        content,
        transactionType,
      );
      score += typeConfidence * 0.2;
    }
    
    // Account number extraction score (max 0.1)
    if (accountNumber != null && accountNumber.isNotEmpty) {
      score += 0.1;
    }
    
    // Ensure score is between 0.0 and 1.0
    return score.clamp(0.0, 1.0);
  }
  
  /// Log unparseable messages for manual review
  /// 
  /// In a production system, this would write to a logging service
  /// or database for later analysis
  void _logUnparseableMessage(SmsMessage sms, String reason) {
    // TODO: Implement proper logging to a persistent store
    // For now, just print to console
    print('[SMS Parser] Unparseable message:');
    print('  Sender: ${sms.sender}');
    print('  Timestamp: ${sms.timestamp}');
    print('  Reason: $reason');
    print('  Content: ${sms.content}');
    print('---');
  }
  
  /// Log parsing errors for debugging
  /// 
  /// In a production system, this would write to an error tracking service
  void _logParsingError(SmsMessage sms, Object error, StackTrace stackTrace) {
    // TODO: Implement proper error logging to a tracking service
    // For now, just print to console
    print('[SMS Parser] Parsing error:');
    print('  Sender: ${sms.sender}');
    print('  Timestamp: ${sms.timestamp}');
    print('  Error: $error');
    print('  Stack trace: $stackTrace');
    print('  Content: ${sms.content}');
    print('---');
  }
  
  /// Parse multiple SMS messages in batch
  /// 
  /// Returns a list of successfully parsed transactions
  /// Failed parses are logged but not included in the result
  List<ParsedTransaction> parseTransactions(List<SmsMessage> messages) {
    final transactions = <ParsedTransaction>[];
    
    for (final message in messages) {
      final transaction = parseTransaction(message);
      if (transaction != null) {
        transactions.add(transaction);
      }
    }
    
    return transactions;
  }
  
  /// Check if an SMS message can be parsed (without actually parsing it)
  /// 
  /// This is useful for quick validation before attempting full parsing
  bool canParse(SmsMessage sms) {
    // Check if it's a financial message
    if (!_financialDetector.isFinancialMessage(sms.content)) {
      return false;
    }
    
    // Check if we can extract an amount
    final amount = AmountParser.extractAmount(sms.content);
    return amount != null;
  }
  
  /// Get parsing statistics for a batch of messages
  /// 
  /// Returns a map with:
  /// - 'total': Total number of messages
  /// - 'parsed': Number of successfully parsed messages
  /// - 'failed': Number of failed parses
  /// - 'notFinancial': Number of non-financial messages
  /// - 'successRate': Percentage of successful parses
  Map<String, dynamic> getParsingStats(List<SmsMessage> messages) {
    int total = messages.length;
    int parsed = 0;
    int failed = 0;
    int notFinancial = 0;
    
    for (final message in messages) {
      if (!_financialDetector.isFinancialMessage(message.content)) {
        notFinancial++;
        continue;
      }
      
      final transaction = parseTransaction(message);
      if (transaction != null) {
        parsed++;
      } else {
        failed++;
      }
    }
    
    final successRate = total > 0 ? (parsed / total * 100).toStringAsFixed(2) : '0.00';
    
    return {
      'total': total,
      'parsed': parsed,
      'failed': failed,
      'notFinancial': notFinancial,
      'successRate': '$successRate%',
    };
  }
}
