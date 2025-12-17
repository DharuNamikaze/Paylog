/// Utility class for extracting account numbers from SMS messages
/// 
/// Handles:
/// - Full account numbers in various formats
/// - Masked account numbers (e.g., "xxxxxx2323", "XXXX1234")
/// - Multiple account references with primary account identification
/// - Returns null when no account number is present
class AccountNumberExtractor {
  /// Regex pattern for masked account numbers
  /// Matches patterns like: xxxxxx2323, XXXX1234, ******5678, XX-XX-1234
  static final RegExp _maskedAccountPattern = RegExp(
    r'([xX*]{2,}[-\s]?[0-9]{2,6})',
  );
  
  /// Regex pattern for short account endings (like "ending 9012")
  static final RegExp _accountEndingPattern = RegExp(
    r'ending\s+([0-9]{4})\b',
    caseSensitive: false,
  );
  
  /// Regex pattern for full account numbers
  /// Matches 8-18 digit account numbers with optional spaces/hyphens
  static final RegExp _fullAccountPattern = RegExp(
    r'\b([0-9]{8,18})\b|([0-9]{4}[-\s][0-9]{4}[-\s][0-9]{4,10})\b',
  );
  
  /// Regex pattern for account number with context keywords
  /// Matches patterns like: "A/c 1234567890", "Account No: 1234567890", "ac no 1234567890", "ending 9012"
  static final RegExp _accountWithContextPattern = RegExp(
    r'(?:a/?c\.?\s*(?:no\.?|number)?|account\s*(?:no\.?|number)?|acct\.?\s*(?:no\.?|number)?|ending)[:\s]*([xX*0-9][-\s0-9xX*]{2,20})',
    caseSensitive: false,
  );
  
  /// Regex pattern for card numbers (to exclude them)
  /// Card numbers are typically 16 digits in groups of 4
  static final RegExp _cardNumberPattern = RegExp(
    r'\b([0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{4})\b',
  );
  
  /// Extract the primary account number from SMS content
  /// 
  /// Returns null if no account number can be extracted
  static String? extractAccountNumber(String content) {
    if (content.trim().isEmpty) {
      return null;
    }
    
    final accounts = extractAllAccountNumbers(content);
    
    if (accounts.isEmpty) {
      return null;
    }
    
    // Return the primary account (usually the one with most context)
    return _identifyPrimaryAccount(accounts, content);
  }
  
  /// Extract all account numbers found in the SMS content
  static List<String> extractAllAccountNumbers(String content) {
    final accounts = <String>[];
    final seenAccounts = <String>{};
    
    // First priority: Account numbers with context keywords
    final contextMatches = _accountWithContextPattern.allMatches(content);
    for (final match in contextMatches) {
      final accountStr = match.group(1);
      if (accountStr != null) {
        final cleaned = _cleanAccountNumber(accountStr);
        if (cleaned != null && !seenAccounts.contains(cleaned)) {
          accounts.add(cleaned);
          seenAccounts.add(cleaned);
        }
      }
    }
    
    // Second priority: Masked account numbers
    if (accounts.isEmpty) {
      final maskedMatches = _maskedAccountPattern.allMatches(content);
      for (final match in maskedMatches) {
        final accountStr = match.group(1);
        if (accountStr != null) {
          final cleaned = _cleanAccountNumber(accountStr);
          if (cleaned != null && !seenAccounts.contains(cleaned)) {
            accounts.add(cleaned);
            seenAccounts.add(cleaned);
          }
        }
      }
    }
    
    // Also check for account endings (like "ending 9012")
    if (accounts.isEmpty) {
      final endingMatches = _accountEndingPattern.allMatches(content);
      for (final match in endingMatches) {
        final accountStr = match.group(1);
        if (accountStr != null && !seenAccounts.contains(accountStr)) {
          accounts.add(accountStr);
          seenAccounts.add(accountStr);
        }
      }
    }
    
    // Third priority: Full account numbers (but exclude card numbers)
    if (accounts.isEmpty) {
      final fullMatches = _fullAccountPattern.allMatches(content);
      for (final match in fullMatches) {
        final accountStr = match.group(1) ?? match.group(2);
        if (accountStr != null && !_isCardNumber(content, accountStr)) {
          final cleaned = _cleanAccountNumber(accountStr);
          if (cleaned != null && 
              !seenAccounts.contains(cleaned) && 
              _isValidAccountNumber(cleaned)) {
            accounts.add(cleaned);
            seenAccounts.add(cleaned);
          }
        }
      }
    }
    
    return accounts;
  }
  
  /// Clean and normalize account number string
  /// 
  /// Preserves masking characters (x, X, *) and digits
  /// Removes excessive spaces and hyphens
  static String? _cleanAccountNumber(String accountStr) {
    if (accountStr.trim().isEmpty) {
      return null;
    }
    
    // Remove extra spaces but preserve the account number structure
    final cleaned = accountStr.trim().replaceAll(RegExp(r'\s+'), '');
    
    // Normalize masking characters to lowercase 'x'
    // Count the masking characters first to preserve them
    final maskCount = RegExp(r'[xX*]').allMatches(cleaned).length;
    final digitsPart = cleaned.replaceAll(RegExp(r'[xX*-]'), '');
    
    // If we have masking characters, preserve them
    String normalized;
    if (maskCount > 0) {
      // Create the masked format: xxx...xxx + digits
      normalized = 'x' * maskCount + digitsPart;
    } else {
      normalized = cleaned.replaceAll('-', '');
    }
    
    // Validate minimum length
    if (normalized.length < 4) {
      return null;
    }
    
    return normalized;
  }
  
  /// Check if a number string is likely a card number (16 digits)
  /// 
  /// Checks both the extracted number and the context around it
  static bool _isCardNumber(String fullContent, String numberStr) {
    final digitsOnly = numberStr.replaceAll(RegExp(r'[-\s]'), '');
    
    // Card numbers are typically exactly 16 digits
    if (digitsOnly.length == 16 && RegExp(r'^[0-9]{16}$').hasMatch(digitsOnly)) {
      return true;
    }
    
    // Check if the full content contains a card number pattern
    if (_cardNumberPattern.hasMatch(fullContent)) {
      // Check if this number is part of a card number pattern
      final cardMatches = _cardNumberPattern.allMatches(fullContent);
      for (final cardMatch in cardMatches) {
        final cardNumber = cardMatch.group(0);
        if (cardNumber != null && cardNumber.contains(numberStr)) {
          return true;
        }
      }
    }
    
    // Check if it matches the card number pattern with groups of 4
    if (_cardNumberPattern.hasMatch(numberStr)) {
      // Additional check: if it has exactly 4 groups of 4 digits
      final groups = numberStr.split(RegExp(r'[-\s]'));
      if (groups.length == 4 && groups.every((g) => g.length == 4)) {
        return true;
      }
    }
    
    // Check for "card" keyword nearby
    final contentLower = fullContent.toLowerCase();
    if (contentLower.contains('card')) {
      final cardIndex = contentLower.indexOf('card');
      final numberIndex = fullContent.indexOf(numberStr);
      if (numberIndex != -1 && (numberIndex - cardIndex).abs() < 30) {
        // If "card" is mentioned near this number, it's likely a card number
        return true;
      }
    }
    
    return false;
  }
  
  /// Validate if a string is a valid account number
  /// 
  /// Account numbers should be:
  /// - 8-18 characters long (including masking)
  /// - Contain at least 2 digits
  /// - Not be all the same digit (like 0000000000)
  static bool _isValidAccountNumber(String accountStr) {
    if (accountStr.length < 4 || accountStr.length > 20) {
      return false;
    }
    
    // Count digits
    final digitCount = accountStr.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount < 2) {
      return false;
    }
    
    // Check if all digits are the same (invalid)
    final digits = accountStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && RegExp('^${digits[0]}+\$').hasMatch(digits)) {
      return false;
    }
    
    return true;
  }
  
  /// Identify the primary account from a list of extracted accounts
  /// 
  /// Strategy:
  /// 1. If only one account, return it
  /// 2. Prefer accounts with context keywords nearby
  /// 3. Prefer masked accounts (more likely to be the transaction account)
  /// 4. Return the first account found
  static String _identifyPrimaryAccount(List<String> accounts, String content) {
    if (accounts.isEmpty) {
      throw ArgumentError('accounts list cannot be empty');
    }
    
    if (accounts.length == 1) {
      return accounts.first;
    }
    
    // Keywords that typically precede the primary account with their priority
    final primaryKeywords = [
      'credited to', 'debited from', 'from account', 'to account',
      'a/c', 'account', 'ac no', 'account no', 'account number', 'acct'
    ];
    
    final contentLower = content.toLowerCase();
    
    // Try to find account near primary keywords (in order of priority)
    for (final keyword in primaryKeywords) {
      final keywordIndex = contentLower.indexOf(keyword);
      if (keywordIndex != -1) {
        // Find the closest account to this keyword (preferring accounts AFTER the keyword)
        String? closestAccount;
        int closestDistance = 1000000;
        
        for (final account in accounts) {
          // Try to find this account in the content (case-insensitive)
          final accountUpper = account.toUpperCase();
          final contentUpper = content.toUpperCase();
          final accountIndex = contentUpper.indexOf(accountUpper);
          
          if (accountIndex != -1) {
            // Calculate distance, but prefer accounts that come AFTER the keyword
            final distance = (accountIndex - keywordIndex).abs();
            final isAfterKeyword = accountIndex > keywordIndex;
            
            // Prefer accounts after the keyword by giving them a bonus
            final adjustedDistance = isAfterKeyword ? distance : distance + 50;
            
            if (adjustedDistance < closestDistance && distance < 100) {
              closestDistance = adjustedDistance;
              closestAccount = account;
            }
          }
          
          // Also try with original formatting (with spaces/hyphens)
          final variations = _getAccountVariations(account);
          for (final variation in variations) {
            final varIndex = contentUpper.indexOf(variation.toUpperCase());
            if (varIndex != -1) {
              final distance = (varIndex - keywordIndex).abs();
              final isAfterKeyword = varIndex > keywordIndex;
              final adjustedDistance = isAfterKeyword ? distance : distance + 50;
              
              if (adjustedDistance < closestDistance && distance < 100) {
                closestDistance = adjustedDistance;
                closestAccount = account;
              }
            }
          }
        }
        
        if (closestAccount != null) {
          return closestAccount;
        }
      }
    }
    
    // Prefer masked accounts (they're more likely to be the transaction account)
    for (final account in accounts) {
      if (account.contains('x')) {
        return account;
      }
    }
    
    // Fallback: return the first account
    return accounts.first;
  }
  
  /// Get variations of an account number for matching
  /// 
  /// Returns different formatting variations to help find the account in text
  static List<String> _getAccountVariations(String account) {
    final variations = <String>[account];
    
    // Add variation with spaces every 4 digits
    if (account.length >= 8 && !account.contains('x')) {
      final buffer = StringBuffer();
      for (var i = 0; i < account.length; i++) {
        if (i > 0 && i % 4 == 0) {
          buffer.write(' ');
        }
        buffer.write(account[i]);
      }
      variations.add(buffer.toString());
    }
    
    // Add variation with hyphens every 4 digits
    if (account.length >= 8 && !account.contains('x')) {
      final buffer = StringBuffer();
      for (var i = 0; i < account.length; i++) {
        if (i > 0 && i % 4 == 0) {
          buffer.write('-');
        }
        buffer.write(account[i]);
      }
      variations.add(buffer.toString());
    }
    
    return variations;
  }
  
  /// Check if content contains any account number patterns
  static bool hasAccountNumber(String content) {
    if (content.trim().isEmpty) {
      return false;
    }
    
    return _accountWithContextPattern.hasMatch(content) ||
           _maskedAccountPattern.hasMatch(content) ||
           (_fullAccountPattern.hasMatch(content) && 
            !_isCardNumber(content, content));
  }
  
  /// Get all matched account numbers with their positions in the text
  static List<AccountMatch> getAccountMatches(String content) {
    final matches = <AccountMatch>[];
    
    // Find all account numbers with context
    final contextMatches = _accountWithContextPattern.allMatches(content);
    for (final match in contextMatches) {
      final accountStr = match.group(1);
      if (accountStr != null) {
        final cleaned = _cleanAccountNumber(accountStr);
        if (cleaned != null) {
          matches.add(AccountMatch(
            account: cleaned,
            startIndex: match.start,
            endIndex: match.end,
            hasContext: true,
          ));
        }
      }
    }
    
    return matches;
  }
}

/// Represents a matched account number with its position in the text
class AccountMatch {
  final String account;
  final int startIndex;
  final int endIndex;
  final bool hasContext;
  
  const AccountMatch({
    required this.account,
    required this.startIndex,
    required this.endIndex,
    required this.hasContext,
  });
  
  @override
  String toString() {
    return 'AccountMatch(account: $account, position: $startIndex-$endIndex, hasContext: $hasContext)';
  }
}
