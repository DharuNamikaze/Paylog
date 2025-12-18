import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import '../../lib/data/services/sms_listener_service.dart';
import '../../lib/data/datasources/sms_platform_channel.dart' as platform;
import '../../lib/domain/entities/sms_message.dart';
import '../../lib/domain/entities/transaction.dart';
import '../../lib/domain/repositories/transaction_repository.dart';

/// Mock Transaction Repository for comprehensive testing
class ComprehensiveTestRepository implements TransactionRepository {
  final List<Transaction> _transactions = [];
  bool _shouldFailSave = false;
  int _saveDelay = 0;
  
  @override
  Future<String> saveTransaction(Transaction transaction) async {
    if (_saveDelay > 0) {
      await Future.delayed(Duration(milliseconds: _saveDelay));
    }
    
    if (_shouldFail
