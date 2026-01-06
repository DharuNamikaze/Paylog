import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/entities/transaction.dart';

/// Computes a unique SHA-256 hash for transaction deduplication.
/// 
/// The hash is used as the Firestore document ID to prevent duplicate
/// uploads at the cloud level (cloud-side deduplication).
/// 
/// Hash input fields are normalized before hashing to prevent duplicate
/// cloud documents from parsing variations:
/// - amount: Fixed 2 decimal places (e.g., "1500.00")
/// - date: Trimmed (expected ISO 8601 format YYYY-MM-DD)
/// - time: Trimmed (expected 24-hour format HH:MM:SS)
/// - accountNumber: Uppercase, trimmed, null becomes empty string
/// - smsContent: Trimmed, normalized whitespace (multiple spaces → single space)
/// 
/// Requirements: 7.1, 7.6
String computeTransactionHash(Transaction transaction) {
  // Normalize amount to 2 decimal places
  final normalizedAmount = transaction.amount.toStringAsFixed(2);
  
  // Normalize date (trim whitespace)
  final normalizedDate = transaction.date.trim();
  
  // Normalize time (trim whitespace)
  final normalizedTime = transaction.time.trim();
  
  // Normalize account number - null becomes empty, trim and uppercase
  final normalizedAccount = (transaction.accountNumber ?? '').trim().toUpperCase();
  
  // Normalize SMS content - trim and collapse multiple whitespace to single space
  final normalizedSms = transaction.smsContent.trim().replaceAll(RegExp(r'\s+'), ' ');
  
  // Combine normalized fields with pipe delimiter
  final data = '$normalizedAmount|$normalizedDate|$normalizedTime|$normalizedAccount|$normalizedSms';
  
  // Compute SHA-256 hash
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  
  return digest.toString();
}

/// Computes a transaction hash from a ParsedTransaction.
/// 
/// This is a convenience method for computing hashes before a full
/// Transaction object is created.
String computeParsedTransactionHash(ParsedTransaction transaction) {
  // Normalize amount to 2 decimal places
  final normalizedAmount = transaction.amount.toStringAsFixed(2);
  
  // Normalize date (trim whitespace)
  final normalizedDate = transaction.date.trim();
  
  // Normalize time (trim whitespace)
  final normalizedTime = transaction.time.trim();
  
  // Normalize account number - null becomes empty, trim and uppercase
  final normalizedAccount = (transaction.accountNumber ?? '').trim().toUpperCase();
  
  // Normalize SMS content - trim and collapse multiple whitespace to single space
  final normalizedSms = transaction.smsContent.trim().replaceAll(RegExp(r'\s+'), ' ');
  
  // Combine normalized fields with pipe delimiter
  final data = '$normalizedAmount|$normalizedDate|$normalizedTime|$normalizedAccount|$normalizedSms';
  
  // Compute SHA-256 hash
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  
  return digest.toString();
}
