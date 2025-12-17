/// Financial Context Detector for SMS messages
/// 
/// This class analyzes SMS message content to determine if it contains
/// financial transaction information using keyword-based classification.
class FinancialContextDetector {
  // Credit transaction indicators
  static const List<String> _creditKeywords = [
    'credited',
    'received',
    'deposited',
    'transferred in',
    'added',
    'credit',
    'deposit',
    'refund',
    'cashback',
  ];

  // Debit transaction indicators
  static const List<String> _debitKeywords = [
    'debited',
    'withdrawn',
    'transferred',
    'paid',
    'deducted',
    'debit',
    'withdrawal',
    'purchase',
    'spent',
    'charged',
  ];

  // Amount indicators
  static const List<String> _amountKeywords = [
    'rupees',
    'rs',
    '₹',
    'amount',
    'inr',
    'balance',
    'sum',
    'total',
  ];

  // Account indicators
  static const List<String> _accountKeywords = [
    'account',
    'ac no',
    'a/c',
    'account number',
    'acc',
    'bank',
    'card',
    'upi',
  ];

  // Additional financial context keywords
  static const List<String> _generalFinancialKeywords = [
    'transaction',
    'payment',
    'transfer',
    'bank',
    'atm',
    'pos',
    'online',
    'mobile banking',
    'net banking',
    'wallet',
    'paytm',
    'gpay',
    'phonepe',
    'bhim',
    'imps',
    'neft',
    'rtgs',
    'upi',
  ];

  /// All financial keywords combined for easy access
  static final List<String> _allFinancialKeywords = [
    ..._creditKeywords,
    ..._debitKeywords,
    ..._amountKeywords,
    ..._accountKeywords,
    ..._generalFinancialKeywords,
  ];

  /// Determines if an SMS message contains financial transaction context
  /// 
  /// Returns true if the message content contains financial keywords
  /// that indicate it's likely a transaction notification.
  bool isFinancialMessage(String content) {
    if (content.trim().isEmpty) {
      return false;
    }

    final normalizedContent = content.toLowerCase();
    
    // Check if any financial keywords are present
    final matchedKeywords = extractFinancialKeywords(content);
    
    // A message is considered financial if it has at least one keyword
    // and meets minimum confidence threshold
    return matchedKeywords.isNotEmpty && getConfidenceScore(content) >= 0.3;
  }

  /// Returns a confidence score (0.0-1.0) indicating how likely
  /// the message is to be a financial transaction notification
  /// 
  /// The score is calculated based on:
  /// - Number of financial keywords found
  /// - Presence of amount indicators
  /// - Presence of transaction type indicators
  /// - Presence of account indicators
  double getConfidenceScore(String content) {
    if (content.trim().isEmpty) {
      return 0.0;
    }

    final normalizedContent = content.toLowerCase();
    double score = 0.0;
    
    // Base score for any financial keywords (0.2)
    final matchedKeywords = extractFinancialKeywords(content);
    if (matchedKeywords.isNotEmpty) {
      score += 0.2;
    }

    // Additional score for transaction type keywords (0.3)
    final hasTransactionType = _creditKeywords.any((keyword) => 
        normalizedContent.contains(keyword.toLowerCase())) ||
      _debitKeywords.any((keyword) => 
        normalizedContent.contains(keyword.toLowerCase()));
    
    if (hasTransactionType) {
      score += 0.3;
    }

    // Additional score for amount indicators (0.3)
    final hasAmountIndicator = _amountKeywords.any((keyword) => 
        normalizedContent.contains(keyword.toLowerCase())) ||
      _containsNumericAmount(normalizedContent);
    
    if (hasAmountIndicator) {
      score += 0.3;
    }

    // Additional score for account indicators (0.2)
    final hasAccountIndicator = _accountKeywords.any((keyword) => 
        normalizedContent.contains(keyword.toLowerCase()));
    
    if (hasAccountIndicator) {
      score += 0.2;
    }

    // Cap the score at 1.0
    return score > 1.0 ? 1.0 : score;
  }

  /// Extracts all financial keywords found in the message content
  /// 
  /// Returns a list of matched keywords in lowercase
  List<String> extractFinancialKeywords(String content) {
    if (content.trim().isEmpty) {
      return [];
    }

    final normalizedContent = content.toLowerCase();
    final matchedKeywords = <String>[];

    for (final keyword in _allFinancialKeywords) {
      if (normalizedContent.contains(keyword.toLowerCase())) {
        matchedKeywords.add(keyword.toLowerCase());
      }
    }

    // Remove duplicates and return
    return matchedKeywords.toSet().toList();
  }

  /// Helper method to check if content contains numeric amounts
  /// Looks for patterns like: 123, 1,234, 12.34, etc.
  bool _containsNumericAmount(String content) {
    // Regex pattern for numeric amounts
    // Matches: 123, 1,234, 12.34, 1,23,456.78, etc.
    final amountPattern = RegExp(r'\d{1,3}(?:,\d{3})*(?:\.\d{2})?|\d+(?:\.\d{2})?');
    return amountPattern.hasMatch(content);
  }

  /// Gets all available financial keywords for reference
  static List<String> getAllFinancialKeywords() {
    return List.unmodifiable(_allFinancialKeywords);
  }

  /// Gets credit-specific keywords
  static List<String> getCreditKeywords() {
    return List.unmodifiable(_creditKeywords);
  }

  /// Gets debit-specific keywords
  static List<String> getDebitKeywords() {
    return List.unmodifiable(_debitKeywords);
  }

  /// Gets amount-specific keywords
  static List<String> getAmountKeywords() {
    return List.unmodifiable(_amountKeywords);
  }

  /// Gets account-specific keywords
  static List<String> getAccountKeywords() {
    return List.unmodifiable(_accountKeywords);
  }
}