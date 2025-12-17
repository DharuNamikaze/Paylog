import '../entities/transaction.dart';
import '../entities/validation_result.dart';

/// Use case for validating transaction data before persistence
/// 
/// Validates:
/// - Amount is positive and within reasonable threshold (₹10,000,000)
/// - Date is not in future and not more than 90 days in past
/// - Account number format and required fields
class ValidateTransaction {
  /// Maximum allowed transaction amount in Rupees
  static const double maxAmount = 10000000.0; // ₹10,000,000
  
  /// Maximum days in the past for a valid transaction
  static const int maxDaysInPast = 90;
  
  /// Validates a transaction and returns validation result
  /// 
  /// Returns [ValidationResult] with:
  /// - isValid: true if all validations pass
  /// - errors: list of validation errors (blocking issues)
  /// - warnings: list of validation warnings (non-blocking issues)
  ValidationResult validateTransaction(Transaction transaction) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Validate amount
    _validateAmount(transaction.amount, errors, warnings);
    
    // Validate date
    _validateDate(transaction.date, errors, warnings);
    
    // Validate account number
    _validateAccountNumber(transaction.accountNumber, errors, warnings);
    
    // Validate required fields
    _validateRequiredFields(transaction, errors, warnings);
    
    if (errors.isEmpty) {
      if (warnings.isEmpty) {
        return ValidationResult.success();
      } else {
        return ValidationResult.withWarnings(warnings);
      }
    } else {
      return ValidationResult.failure(errors, warnings);
    }
  }
  
  /// Validates transaction amount
  void _validateAmount(double amount, List<String> errors, List<String> warnings) {
    // Check if amount is positive
    if (amount <= 0) {
      errors.add('Amount must be positive (got: ₹$amount)');
    }
    
    // Check if amount is within reasonable threshold
    if (amount > maxAmount) {
      errors.add('Amount exceeds maximum threshold of ₹$maxAmount (got: ₹$amount)');
    }
    
    // Warning for very small amounts
    if (amount > 0 && amount < 1) {
      warnings.add('Amount is less than ₹1 (got: ₹$amount)');
    }
  }
  
  /// Validates transaction date
  void _validateDate(String dateString, List<String> errors, List<String> warnings) {
    try {
      // Parse ISO 8601 date format (YYYY-MM-DD)
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final transactionDate = DateTime(date.year, date.month, date.day);
      
      // Check if date is in the future
      if (transactionDate.isAfter(today)) {
        errors.add('Transaction date cannot be in the future (got: $dateString)');
      }
      
      // Check if date is more than 90 days in the past
      final daysDifference = today.difference(transactionDate).inDays;
      if (daysDifference > maxDaysInPast) {
        errors.add('Transaction date is more than $maxDaysInPast days in the past (got: $dateString, $daysDifference days ago)');
      }
      
      // Warning for dates very close to the limit
      if (daysDifference > maxDaysInPast - 7 && daysDifference <= maxDaysInPast) {
        warnings.add('Transaction date is close to the $maxDaysInPast day limit ($daysDifference days ago)');
      }
    } catch (e) {
      errors.add('Invalid date format (expected YYYY-MM-DD, got: $dateString)');
    }
  }
  
  /// Validates account number format
  void _validateAccountNumber(String? accountNumber, List<String> errors, List<String> warnings) {
    // Account number is optional, but if present should be valid
    if (accountNumber != null && accountNumber.isNotEmpty) {
      // Check minimum length (at least 4 characters for masked accounts like "xx23")
      if (accountNumber.length < 4) {
        warnings.add('Account number seems too short (got: $accountNumber)');
      }
      
      // Check if it contains at least some digits or x's (for masked format)
      final hasDigitsOrMask = RegExp(r'[0-9x]', caseSensitive: false).hasMatch(accountNumber);
      if (!hasDigitsOrMask) {
        warnings.add('Account number does not contain expected digits or mask characters (got: $accountNumber)');
      }
    }
  }
  
  /// Validates required fields are present and non-empty
  void _validateRequiredFields(Transaction transaction, List<String> errors, List<String> warnings) {
    // Validate ID
    if (transaction.id.isEmpty) {
      errors.add('Transaction ID is required');
    }
    
    // Validate user ID
    if (transaction.userId.isEmpty) {
      errors.add('User ID is required');
    }
    
    // Validate SMS content
    if (transaction.smsContent.isEmpty) {
      errors.add('SMS content is required');
    }
    
    // Validate sender phone number
    if (transaction.senderPhoneNumber.isEmpty) {
      errors.add('Sender phone number is required');
    }
    
    // Validate time format (HH:MM:SS)
    if (!_isValidTimeFormat(transaction.time)) {
      errors.add('Invalid time format (expected HH:MM:SS, got: ${transaction.time})');
    }
    
    // Validate confidence score
    if (transaction.confidenceScore < 0.0 || transaction.confidenceScore > 1.0) {
      errors.add('Confidence score must be between 0.0 and 1.0 (got: ${transaction.confidenceScore})');
    }
    
    // Warning for low confidence scores
    if (transaction.confidenceScore < 0.5) {
      warnings.add('Low confidence score: ${transaction.confidenceScore}');
    }
  }
  
  /// Checks if time string is in valid HH:MM:SS format
  bool _isValidTimeFormat(String time) {
    final timeRegex = RegExp(r'^([0-1][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$');
    return timeRegex.hasMatch(time);
  }
  
  /// Validates if amount is valid (positive and within threshold)
  bool isValidAmount(double amount) {
    return amount > 0 && amount <= maxAmount;
  }
  
  /// Validates if account number format is acceptable
  bool isValidAccountNumber(String? accountNumber) {
    if (accountNumber == null || accountNumber.isEmpty) {
      return true; // Account number is optional
    }
    return accountNumber.length >= 4 && 
           RegExp(r'[0-9x]', caseSensitive: false).hasMatch(accountNumber);
  }
  
  /// Validates if date is within acceptable range
  bool isValidDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final transactionDate = DateTime(date.year, date.month, date.day);
      
      if (transactionDate.isAfter(today)) {
        return false;
      }
      
      final daysDifference = today.difference(transactionDate).inDays;
      return daysDifference <= maxDaysInPast;
    } catch (e) {
      return false;
    }
  }
}
