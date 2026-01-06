import '../../domain/entities/transaction.dart';
import '../../domain/entities/validation_result.dart';

/// Validator for transactions before cloud sync upload
/// 
/// Validates required fields and data formats to ensure transactions
/// are valid before attempting to upload to Firestore.
/// 
/// Requirements: 7.5 - Transaction validation before upload
class TransactionSyncValidator {
  /// Date format regex: YYYY-MM-DD
  static final RegExp _dateFormatRegex = RegExp(
    r'^(\d{4})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$',
  );

  /// Time format regex: HH:MM:SS (24-hour format)
  static final RegExp _timeFormatRegex = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d):([0-5]\d)$',
  );

  /// Validates a transaction for cloud sync
  /// 
  /// Checks:
  /// - Required fields are present and non-empty: amount, date, time, smsContent, senderPhoneNumber
  /// - Amount is positive
  /// - Date format is valid (YYYY-MM-DD)
  /// - Time format is valid (HH:MM:SS)
  /// 
  /// Returns [ValidationResult] with:
  /// - isValid: true if all validations pass
  /// - errors: list of validation errors (blocking issues)
  /// - warnings: list of validation warnings (non-blocking issues)
  ValidationResult validate(Transaction transaction) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate amount (required and positive)
    _validateAmount(transaction.amount, errors, warnings);

    // Validate date (required and valid format)
    _validateDate(transaction.date, errors, warnings);

    // Validate time (required and valid format)
    _validateTime(transaction.time, errors, warnings);

    // Validate smsContent (required)
    _validateSmsContent(transaction.smsContent, errors, warnings);

    // Validate senderPhoneNumber (required)
    _validateSenderPhoneNumber(transaction.senderPhoneNumber, errors, warnings);

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

  /// Validates a ParsedTransaction for cloud sync
  /// 
  /// Same validation as [validate] but for ParsedTransaction objects.
  ValidationResult validateParsed(ParsedTransaction transaction) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate amount (required and positive)
    _validateAmount(transaction.amount, errors, warnings);

    // Validate date (required and valid format)
    _validateDate(transaction.date, errors, warnings);

    // Validate time (required and valid format)
    _validateTime(transaction.time, errors, warnings);

    // Validate smsContent (required)
    _validateSmsContent(transaction.smsContent, errors, warnings);

    // Validate senderPhoneNumber (required)
    _validateSenderPhoneNumber(transaction.senderPhoneNumber, errors, warnings);

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

  /// Validates amount is positive
  void _validateAmount(double amount, List<String> errors, List<String> warnings) {
    if (amount <= 0) {
      errors.add('Amount must be positive (got: $amount)');
    } else if (amount < 1) {
      warnings.add('Amount is less than 1 (got: $amount)');
    }
  }

  /// Validates date is present and in valid format (YYYY-MM-DD)
  void _validateDate(String date, List<String> errors, List<String> warnings) {
    if (date.isEmpty) {
      errors.add('Date is required');
      return;
    }

    if (!_dateFormatRegex.hasMatch(date)) {
      errors.add('Invalid date format (expected YYYY-MM-DD, got: $date)');
      return;
    }

    // Additional validation: check if date is actually valid
    try {
      final parsed = DateTime.parse(date);
      // Verify the parsed date matches the input (catches invalid dates like 2024-02-30)
      final formatted = '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
      if (formatted != date) {
        errors.add('Invalid date value (got: $date)');
      }
    } catch (e) {
      errors.add('Invalid date value (got: $date)');
    }
  }

  /// Validates time is present and in valid format (HH:MM:SS)
  void _validateTime(String time, List<String> errors, List<String> warnings) {
    if (time.isEmpty) {
      errors.add('Time is required');
      return;
    }

    if (!_timeFormatRegex.hasMatch(time)) {
      errors.add('Invalid time format (expected HH:MM:SS, got: $time)');
    }
  }

  /// Validates smsContent is present and non-empty
  void _validateSmsContent(String smsContent, List<String> errors, List<String> warnings) {
    if (smsContent.isEmpty) {
      errors.add('SMS content is required');
    } else if (smsContent.trim().isEmpty) {
      errors.add('SMS content cannot be only whitespace');
    }
  }

  /// Validates senderPhoneNumber is present and non-empty
  void _validateSenderPhoneNumber(String senderPhoneNumber, List<String> errors, List<String> warnings) {
    if (senderPhoneNumber.isEmpty) {
      errors.add('Sender phone number is required');
    } else if (senderPhoneNumber.trim().isEmpty) {
      errors.add('Sender phone number cannot be only whitespace');
    }
  }

  /// Quick check if amount is valid (positive)
  bool isValidAmount(double amount) {
    return amount > 0;
  }

  /// Quick check if date format is valid (YYYY-MM-DD)
  bool isValidDateFormat(String date) {
    if (date.isEmpty || !_dateFormatRegex.hasMatch(date)) {
      return false;
    }
    try {
      final parsed = DateTime.parse(date);
      final formatted = '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
      return formatted == date;
    } catch (e) {
      return false;
    }
  }

  /// Quick check if time format is valid (HH:MM:SS)
  bool isValidTimeFormat(String time) {
    return time.isNotEmpty && _timeFormatRegex.hasMatch(time);
  }

  /// Quick check if smsContent is valid (non-empty)
  bool isValidSmsContent(String smsContent) {
    return smsContent.isNotEmpty && smsContent.trim().isNotEmpty;
  }

  /// Quick check if senderPhoneNumber is valid (non-empty)
  bool isValidSenderPhoneNumber(String senderPhoneNumber) {
    return senderPhoneNumber.isNotEmpty && senderPhoneNumber.trim().isNotEmpty;
  }
}
