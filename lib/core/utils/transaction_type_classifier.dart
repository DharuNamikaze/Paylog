import '../../domain/entities/transaction_type.dart';

/// Utility class for classifying transaction types from SMS messages
/// 
/// Handles:
/// - Debit keyword detection (debited, withdrawn, transferred out, paid, deducted)
/// - Credit keyword detection (credited, received, deposited, transferred in, added)
/// - Ambiguous cases marked as "unknown"
class TransactionTypeClassifier {
  /// Keywords indicating a debit transaction (money going out)
  static const List<String> _debitKeywords = [
    'debited',
    'withdrawn',
    'transferred out',
    'paid',
    'deducted',
    'spent',
    'purchase',
    'payment',
    'debit',
    'withdraw',
    'sent',
    'transfer to',
    'transferred to',
    'used',
    'charged',
  ];
  
  /// Keywords indicating a credit transaction (money coming in)
  static const List<String> _creditKeywords = [
    'credited',
    'received',
    'deposited',
    'transferred in',
    'added',
    'credit',
    'deposit',
    'refund',
    'refunded',
    'cashback',
    'transfer from',
    'transferred from',
    'received from',
  ];

  /// Classify the transaction type based on SMS content
  /// 
  /// Returns:
  /// - TransactionType.debit if debit keywords are found
  /// - TransactionType.credit if credit keywords are found
  /// - TransactionType.unknown if no clear classification or ambiguous
  static TransactionType classifyTransaction(String content) {
    if (content.trim().isEmpty) {
      return TransactionType.unknown;
    }
    
    final contentLower = content.toLowerCase();
    
    // Check for debit keywords
    final hasDebitKeyword = _debitKeywords.any(
      (keyword) => contentLower.contains(keyword.toLowerCase())
    );
    
    // Check for credit keywords
    final hasCreditKeyword = _creditKeywords.any(
      (keyword) => contentLower.contains(keyword.toLowerCase())
    );
    
    // Handle ambiguous cases (both or neither)
    if (hasDebitKeyword && hasCreditKeyword) {
      // Ambiguous: both debit and credit keywords present
      // Try to determine which is more prominent
      return _resolveAmbiguousCase(contentLower);
    } else if (hasDebitKeyword) {
      return TransactionType.debit;
    } else if (hasCreditKeyword) {
      return TransactionType.credit;
    } else {
      // No clear keywords found
      return TransactionType.unknown;
    }
  }
  
  /// Resolve ambiguous cases where both debit and credit keywords are present
  /// 
  /// Strategy:
  /// 1. Count occurrences of each type
  /// 2. Check position of keywords (earlier keywords are more important)
  /// 3. Look for stronger indicators
  static TransactionType _resolveAmbiguousCase(String contentLower) {
    int debitScore = 0;
    int creditScore = 0;
    int firstDebitIndex = -1;
    int firstCreditIndex = -1;
    
    // Score based on keyword presence and position
    for (final keyword in _debitKeywords) {
      if (contentLower.contains(keyword.toLowerCase())) {
        final index = contentLower.indexOf(keyword.toLowerCase());
        if (firstDebitIndex == -1 || index < firstDebitIndex) {
          firstDebitIndex = index;
        }
        // Earlier keywords get higher score
        debitScore += 10;
        if (index < contentLower.length / 2) {
          debitScore += 5; // Bonus for appearing in first half
        }
      }
    }
    
    for (final keyword in _creditKeywords) {
      if (contentLower.contains(keyword.toLowerCase())) {
        final index = contentLower.indexOf(keyword.toLowerCase());
        if (firstCreditIndex == -1 || index < firstCreditIndex) {
          firstCreditIndex = index;
        }
        // Earlier keywords get higher score
        creditScore += 10;
        if (index < contentLower.length / 2) {
          creditScore += 5; // Bonus for appearing in first half
        }
      }
    }
    
    // Return the type with higher score
    if (debitScore > creditScore) {
      return TransactionType.debit;
    } else if (creditScore > debitScore) {
      return TransactionType.credit;
    } else {
      // If tied, prefer the one that appears first
      if (firstDebitIndex != -1 && firstCreditIndex != -1) {
        return firstDebitIndex < firstCreditIndex 
            ? TransactionType.debit 
            : TransactionType.credit;
      } else if (firstDebitIndex != -1) {
        return TransactionType.debit;
      } else if (firstCreditIndex != -1) {
        return TransactionType.credit;
      } else {
        return TransactionType.unknown;
      }
    }
  }

  /// Get confidence score for the classification (0.0 to 1.0)
  /// 
  /// Higher score indicates more confidence in the classification
  static double getConfidenceScore(String content, TransactionType type) {
    if (content.trim().isEmpty || type == TransactionType.unknown) {
      return 0.0;
    }
    
    final contentLower = content.toLowerCase();
    int matchCount = 0;
    
    final keywords = type == TransactionType.debit 
        ? _debitKeywords 
        : _creditKeywords;
    
    for (final keyword in keywords) {
      if (contentLower.contains(keyword.toLowerCase())) {
        matchCount++;
      }
    }
    
    // Base confidence on number of matching keywords
    // 1 keyword = 0.7, 2+ keywords = 0.9+
    if (matchCount == 0) {
      return 0.0;
    } else if (matchCount == 1) {
      return 0.7;
    } else if (matchCount == 2) {
      return 0.85;
    } else {
      return 0.95;
    }
  }
  
  /// Check if content contains any transaction type keywords
  static bool hasTransactionTypeKeywords(String content) {
    if (content.trim().isEmpty) {
      return false;
    }
    
    final contentLower = content.toLowerCase();
    
    return _debitKeywords.any(
      (keyword) => contentLower.contains(keyword.toLowerCase())
    ) || _creditKeywords.any(
      (keyword) => contentLower.contains(keyword.toLowerCase())
    );
  }
  
  /// Alias for hasTransactionTypeKeywords for backward compatibility
  static bool hasTransactionKeywords(String content) {
    return hasTransactionTypeKeywords(content);
  }
  
  /// Get all matched keywords from the content
  static List<String> getMatchedKeywords(String content) {
    if (content.trim().isEmpty) {
      return [];
    }
    
    final contentLower = content.toLowerCase();
    final matched = <String>[];
    
    for (final keyword in [..._debitKeywords, ..._creditKeywords]) {
      if (contentLower.contains(keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }
    
    return matched;
  }
}
