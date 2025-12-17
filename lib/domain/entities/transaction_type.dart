/// Enum representing the type of financial transaction
enum TransactionType {
  /// Money withdrawn or sent from an account
  debit,
  
  /// Money received or deposited into an account
  credit,
  
  /// Transaction type could not be determined
  unknown;
  
  /// Convert enum to string for JSON serialization
  String toJson() => name;
  
  /// Create enum from string for JSON deserialization
  static TransactionType fromJson(String json) {
    switch (json.toLowerCase()) {
      case 'debit':
        return TransactionType.debit;
      case 'credit':
        return TransactionType.credit;
      case 'unknown':
        return TransactionType.unknown;
      default:
        return TransactionType.unknown;
    }
  }
}