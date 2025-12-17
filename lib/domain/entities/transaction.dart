import 'package:json_annotation/json_annotation.dart';
import 'transaction_type.dart';

part 'transaction.g.dart';

/// Represents a parsed transaction from an SMS message
@JsonSerializable()
class ParsedTransaction {
  /// Transaction amount in Rupees
  final double amount;
  
  /// Type of transaction (debit, credit, or unknown)
  @JsonKey(fromJson: TransactionType.fromJson, toJson: _transactionTypeToJson)
  final TransactionType transactionType;
  
  /// Masked account number (optional)
  final String? accountNumber;
  
  /// Transaction date in ISO 8601 format (YYYY-MM-DD)
  final String date;
  
  /// Transaction time in 24-hour format (HH:MM:SS)
  final String time;
  
  /// Original SMS text content
  final String smsContent;
  
  /// Bank's phone number that sent the SMS
  final String senderPhoneNumber;
  
  /// Confidence score in parsing accuracy (0.0-1.0)
  final double confidenceScore;
  
  const ParsedTransaction({
    required this.amount,
    required this.transactionType,
    this.accountNumber,
    required this.date,
    required this.time,
    required this.smsContent,
    required this.senderPhoneNumber,
    required this.confidenceScore,
  });
  
  /// JSON serialization
  factory ParsedTransaction.fromJson(Map<String, dynamic> json) =>
      _$ParsedTransactionFromJson(json);
  
  /// JSON deserialization
  Map<String, dynamic> toJson() => _$ParsedTransactionToJson(this);
  
  /// Helper method to convert TransactionType to JSON
  static String _transactionTypeToJson(TransactionType type) => type.toJson();
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedTransaction &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          transactionType == other.transactionType &&
          accountNumber == other.accountNumber &&
          date == other.date &&
          time == other.time &&
          smsContent == other.smsContent &&
          senderPhoneNumber == other.senderPhoneNumber &&
          confidenceScore == other.confidenceScore;
  
  @override
  int get hashCode =>
      amount.hashCode ^
      transactionType.hashCode ^
      accountNumber.hashCode ^
      date.hashCode ^
      time.hashCode ^
      smsContent.hashCode ^
      senderPhoneNumber.hashCode ^
      confidenceScore.hashCode;
  
  @override
  String toString() {
    return 'ParsedTransaction{amount: $amount, transactionType: $transactionType, accountNumber: $accountNumber, date: $date, time: $time, senderPhoneNumber: $senderPhoneNumber, confidenceScore: $confidenceScore}';
  }
  
  /// Create a copy of this parsed transaction with updated fields
  ParsedTransaction copyWith({
    double? amount,
    TransactionType? transactionType,
    String? accountNumber,
    String? date,
    String? time,
    String? smsContent,
    String? senderPhoneNumber,
    double? confidenceScore,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      accountNumber: accountNumber ?? this.accountNumber,
      date: date ?? this.date,
      time: time ?? this.time,
      smsContent: smsContent ?? this.smsContent,
      senderPhoneNumber: senderPhoneNumber ?? this.senderPhoneNumber,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}

/// Represents a persisted transaction record with additional metadata
@JsonSerializable()
class Transaction extends ParsedTransaction {
  /// Unique transaction ID
  final String id;
  
  /// User who owns this transaction
  final String userId;
  
  /// When the record was created
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;
  
  /// Whether the transaction has been synced to Firestore
  final bool syncedToFirestore;
  
  /// Hash for duplicate detection
  final String duplicateCheckHash;
  
  /// Whether this transaction was manually entered
  final bool isManualEntry;
  
  const Transaction({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.syncedToFirestore,
    required this.duplicateCheckHash,
    required this.isManualEntry,
    required super.amount,
    required super.transactionType,
    super.accountNumber,
    required super.date,
    required super.time,
    required super.smsContent,
    required super.senderPhoneNumber,
    required super.confidenceScore,
  });
  
  /// Create a Transaction from a ParsedTransaction
  factory Transaction.fromParsedTransaction({
    required String id,
    required String userId,
    required DateTime createdAt,
    required bool syncedToFirestore,
    required String duplicateCheckHash,
    required bool isManualEntry,
    required ParsedTransaction parsedTransaction,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      createdAt: createdAt,
      syncedToFirestore: syncedToFirestore,
      duplicateCheckHash: duplicateCheckHash,
      isManualEntry: isManualEntry,
      amount: parsedTransaction.amount,
      transactionType: parsedTransaction.transactionType,
      accountNumber: parsedTransaction.accountNumber,
      date: parsedTransaction.date,
      time: parsedTransaction.time,
      smsContent: parsedTransaction.smsContent,
      senderPhoneNumber: parsedTransaction.senderPhoneNumber,
      confidenceScore: parsedTransaction.confidenceScore,
    );
  }
  
  /// JSON serialization
  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
  
  /// JSON deserialization
  @override
  Map<String, dynamic> toJson() => _$TransactionToJson(this);
  
  /// Helper method to convert DateTime to JSON
  static String _dateTimeToJson(DateTime dateTime) =>
      dateTime.millisecondsSinceEpoch.toString();
  
  /// Helper method to convert JSON to DateTime
  static DateTime _dateTimeFromJson(dynamic json) {
    if (json is String) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(json));
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    throw ArgumentError('Invalid timestamp format: $json');
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          createdAt == other.createdAt &&
          syncedToFirestore == other.syncedToFirestore &&
          duplicateCheckHash == other.duplicateCheckHash &&
          isManualEntry == other.isManualEntry &&
          super == other;
  
  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      createdAt.hashCode ^
      syncedToFirestore.hashCode ^
      duplicateCheckHash.hashCode ^
      isManualEntry.hashCode ^
      super.hashCode;
  
  @override
  String toString() {
    return 'Transaction{id: $id, userId: $userId, createdAt: $createdAt, syncedToFirestore: $syncedToFirestore, duplicateCheckHash: $duplicateCheckHash, isManualEntry: $isManualEntry, ${super.toString()}}';
  }
  
  /// Create a copy of this transaction with updated fields
  @override
  Transaction copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    bool? syncedToFirestore,
    String? duplicateCheckHash,
    bool? isManualEntry,
    double? amount,
    TransactionType? transactionType,
    String? accountNumber,
    String? date,
    String? time,
    String? smsContent,
    String? senderPhoneNumber,
    double? confidenceScore,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      syncedToFirestore: syncedToFirestore ?? this.syncedToFirestore,
      duplicateCheckHash: duplicateCheckHash ?? this.duplicateCheckHash,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      accountNumber: accountNumber ?? this.accountNumber,
      date: date ?? this.date,
      time: time ?? this.time,
      smsContent: smsContent ?? this.smsContent,
      senderPhoneNumber: senderPhoneNumber ?? this.senderPhoneNumber,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
  
  /// Convert this Transaction to a ParsedTransaction
  ParsedTransaction toParsedTransaction() {
    return ParsedTransaction(
      amount: amount,
      transactionType: transactionType,
      accountNumber: accountNumber,
      date: date,
      time: time,
      smsContent: smsContent,
      senderPhoneNumber: senderPhoneNumber,
      confidenceScore: confidenceScore,
    );
  }
}