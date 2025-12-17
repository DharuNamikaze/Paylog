/// Utility class for parsing transaction amounts from SMS messages
/// 
/// Handles:
/// - Numeric amounts with various formats
/// - Word-to-number conversion (e.g., "One Thousand" → 1000)
/// - Currency symbols and abbreviations (₹, Rs., INR)
/// - Multiple amounts and primary amount identification
class AmountParser {
  /// Regex pattern for numeric amounts with currency symbols
  /// Matches patterns like: ₹1,234.56, Rs.1234.56, INR 1234, 1234.56
  static final RegExp _numericAmountPattern = RegExp(
    r'(?:₹|Rs\.?|INR|rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)|([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:₹|Rs\.?|INR|rs\.?|rupees?|Rupees?)',
    caseSensitive: false,
  );
  
  /// Regex pattern for standalone numeric amounts
  static final RegExp _standaloneNumericPattern = RegExp(
    r'\b([0-9,]+(?:\.[0-9]{1,2})?)\b',
  );
  
  /// Map for converting word numbers to numeric values
  static const Map<String, int> _wordToNumber = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
    'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
    'eighty': 80, 'ninety': 90, 'hundred': 100, 'thousand': 1000,
    'lakh': 100000, 'lac': 100000, 'lakhs': 100000, 'lacs': 100000,
    'crore': 10000000, 'crores': 10000000, 'million': 1000000,
    'billion': 1000000000,
  };
  
  /// Regex pattern for word-based amounts
  static final RegExp _wordAmountPattern = RegExp(
    r'\b((?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|lakh|lac|crore|million|billion)\s*)+(?:rupees?|Rupees?|rs\.?|Rs\.?)?',
    caseSensitive: false,
  );
  
  /// Extract the primary transaction amount from SMS content
  /// 
  /// Returns null if no amount can be extracted
  static double? extractAmount(String content) {
    if (content.trim().isEmpty) {
      return null;
    }
    
    final amounts = extractAllAmounts(content);
    
    if (amounts.isEmpty) {
      return null;
    }
    
    // Return the primary amount (usually the largest or first significant amount)
    return _identifyPrimaryAmount(amounts, content);
  }
  
  /// Extract all amounts found in the SMS content
  static List<double> extractAllAmounts(String content) {
    final amounts = <double>[];
    
    // First, try to extract amounts with currency symbols
    final currencyMatches = _numericAmountPattern.allMatches(content);
    for (final match in currencyMatches) {
      final amountStr = match.group(1) ?? match.group(2);
      if (amountStr != null) {
        final amount = _parseNumericAmount(amountStr);
        if (amount != null) {
          amounts.add(amount);
        }
      }
    }
    
    // If no currency-prefixed amounts found, try word-based amounts
    if (amounts.isEmpty) {
      final wordMatches = _wordAmountPattern.allMatches(content);
      for (final match in wordMatches) {
        final wordAmount = match.group(0);
        if (wordAmount != null) {
          final amount = _parseWordAmount(wordAmount);
          if (amount != null) {
            amounts.add(amount);
          }
        }
      }
    }
    
    // If still no amounts found, try standalone numeric patterns
    if (amounts.isEmpty) {
      final numericMatches = _standaloneNumericPattern.allMatches(content);
      for (final match in numericMatches) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = _parseNumericAmount(amountStr);
          // Only include if it looks like a reasonable transaction amount
          if (amount != null && amount >= 1.0 && amount <= 100000000.0) {
            amounts.add(amount);
          }
        }
      }
    }
    
    return amounts;
  }
  
  /// Parse a numeric amount string (e.g., "1,234.56" → 1234.56)
  static double? _parseNumericAmount(String amountStr) {
    try {
      // Remove commas and parse
      final cleanedAmount = amountStr.replaceAll(',', '').trim();
      return double.parse(cleanedAmount);
    } catch (e) {
      return null;
    }
  }
  
  /// Parse a word-based amount (e.g., "One Thousand Rupees" → 1000.0)
  static double? _parseWordAmount(String wordAmount) {
    try {
      // Normalize the string
      final normalized = wordAmount.toLowerCase()
          .replaceAll(RegExp(r'rupees?|rs\.?'), '')
          .trim();
      
      // Split into words
      final words = normalized.split(RegExp(r'\s+'));
      
      double total = 0;
      double current = 0;
      
      for (final word in words) {
        final value = _wordToNumber[word];
        
        if (value == null) {
          continue;
        }
        
        if (value >= 100) {
          // Multipliers (hundred, thousand, lakh, crore, etc.)
          if (current == 0) {
            current = 1;
          }
          current *= value;
          
          // For large multipliers, add to total and reset
          if (value >= 1000) {
            total += current;
            current = 0;
          }
        } else {
          // Regular numbers
          current += value;
        }
      }
      
      total += current;
      
      return total > 0 ? total : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Identify the primary amount from a list of extracted amounts
  /// 
  /// Strategy:
  /// 1. If only one amount, return it
  /// 2. Look for context keywords near amounts
  /// 3. Prefer amounts near "debited", "credited", "amount", "paid"
  /// 4. Otherwise, return the first amount (usually the transaction amount)
  static double _identifyPrimaryAmount(List<double> amounts, String content) {
    if (amounts.isEmpty) {
      throw ArgumentError('amounts list cannot be empty');
    }
    
    if (amounts.length == 1) {
      return amounts.first;
    }
    
    // Keywords that typically precede the primary transaction amount
    final primaryKeywords = [
      'debited', 'credited', 'paid', 'received',
      'withdrawn', 'deposited', 'transferred'
    ];
    
    // Try to find amount near primary keywords
    final contentLower = content.toLowerCase();
    
    // For each keyword, find the closest amount
    for (final keyword in primaryKeywords) {
      final keywordIndex = contentLower.indexOf(keyword);
      if (keywordIndex != -1) {
        // Find the position of each amount in the original content
        double? closestAmount;
        int closestDistance = 1000000;
        
        for (final amount in amounts) {
          // Try different representations of the amount
          final representations = [
            amount.toStringAsFixed(2),
            amount.toStringAsFixed(0),
            amount.toString(),
            _formatWithCommas(amount),
          ];
          
          for (final repr in representations) {
            final amountIndex = content.indexOf(repr);
            if (amountIndex != -1) {
              final distance = (amountIndex - keywordIndex).abs();
              if (distance < closestDistance && distance < 100) {
                closestDistance = distance;
                closestAmount = amount;
              }
            }
          }
        }
        
        if (closestAmount != null) {
          return closestAmount;
        }
      }
    }
    
    // Fallback: return the first amount (usually the transaction amount)
    return amounts.first;
  }
  
  /// Format amount with commas for Indian numbering system
  static String _formatWithCommas(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    
    // Add commas
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
      count++;
    }
    
    return '${buffer.toString().split('').reversed.join()}.$decPart';
  }
  
  /// Normalize amount to standard format (removes currency symbols, etc.)
  static double? normalizeAmount(String amountStr) {
    // Remove currency symbols and abbreviations
    final cleaned = amountStr
        .replaceAll(RegExp(r'₹|Rs\.?|INR|rs\.?|rupees?|Rupees?', caseSensitive: false), '')
        .trim();
    
    return _parseNumericAmount(cleaned);
  }
}
