import 'package:json_annotation/json_annotation.dart';

part 'validation_result.g.dart';

/// Result of transaction validation containing validity status and messages
@JsonSerializable()
class ValidationResult {
  /// Whether the validation passed
  final bool isValid;
  
  /// List of validation errors (blocking issues)
  final List<String> errors;
  
  /// List of validation warnings (non-blocking issues)
  final List<String> warnings;
  
  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
  
  /// Create a successful validation result
  factory ValidationResult.success() {
    return const ValidationResult(
      isValid: true,
      errors: [],
      warnings: [],
    );
  }
  
  /// Create a failed validation result with errors
  factory ValidationResult.failure(List<String> errors, [List<String>? warnings]) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }
  
  /// Create validation result with warnings only
  factory ValidationResult.withWarnings(List<String> warnings) {
    return ValidationResult(
      isValid: true,
      errors: [],
      warnings: warnings,
    );
  }
  
  /// JSON serialization
  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
  
  /// JSON deserialization
  Map<String, dynamic> toJson() => _$ValidationResultToJson(this);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          _listEquals(errors, other.errors) &&
          _listEquals(warnings, other.warnings);
  
  @override
  int get hashCode => isValid.hashCode ^ errors.hashCode ^ warnings.hashCode;
  
  @override
  String toString() {
    return 'ValidationResult{isValid: $isValid, errors: $errors, warnings: $warnings}';
  }
  
  /// Helper method to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}