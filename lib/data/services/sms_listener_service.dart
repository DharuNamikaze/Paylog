import 'dart:async';
import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';

import '../datasources/sms_platform_channel.dart' as platform;
import '../../domain/entities/sms_message.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/detect_financial_context.dart';
import '../../domain/usecases/parse_sms_transaction.dart';
import '../../domain/usecases/validate_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../core/utils/duplicate_detector.dart';

/// Exception thrown when SMS listener service operations fail
class SmsListenerException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const SmsListenerException(this.message, {this.code, this.details});

  @override
  String toString() {
    return 'SmsListenerException: $message${code != null ? ' (code: $code)' : ''}';
  }
}

/// Service that integrates SMS monitoring with transaction processing
/// 
/// This service orchestrates the complete flow:
/// SMS Reception → Financial Detection → Parsing → Validation → Storage
/// 
/// Features:
/// - Continuous background SMS monitoring
/// - Automatic financial message detection
/// - Transaction parsing and validation
/// - Duplicate detection and prevention
/// - Error handling and logging
/// - Edge case handling (empty messages, encoding issues)
class SmsListenerService {
  final platform.SmsPlatformChannel _smsChannel;
  final FinancialContextDetector _financialDetector;
  final ParseSmsTransaction _smsParser;
  final ValidateTransaction _validator;
  final TransactionRepository _repository;
  final DuplicateDetector _duplicateDetector;
  final Uuid _uuid;
  
  StreamSubscription<platform.SmsMessage>? _smsSubscription;
  bool _isListening = false;
  String? _currentUserId;
  
  /// Statistics for monitoring service performance
  final Map<String, int> _stats = {
    'totalReceived': 0,
    'financialMessages': 0,
    'successfullyParsed': 0,
    'validationPassed': 0,
    'savedToDatabase': 0,
    'duplicatesDetected': 0,
    'errors': 0,
  };
  
  /// Stream controller for service events
  final StreamController<SmsListenerEvent> _eventController = 
      StreamController<SmsListenerEvent>.broadcast();
  
  SmsListenerService({
    platform.SmsPlatformChannel? smsChannel,
    FinancialContextDetector? financialDetector,
    ParseSmsTransaction? smsParser,
    ValidateTransaction? validator,
    required TransactionRepository repository,
    DuplicateDetector? duplicateDetector,
    Uuid? uuid,
  })  : _smsChannel = smsChannel ?? platform.SmsPlatformChannel(),
        _financialDetector = financialDetector ?? FinancialContextDetector(),
        _smsParser = smsParser ?? ParseSmsTransaction(),
        _validator = validator ?? ValidateTransaction(),
        _repository = repository,
        _duplicateDetector = duplicateDetector ?? DuplicateDetector(),
        _uuid = uuid ?? const Uuid();
  
  /// Stream of service events for monitoring
  Stream<SmsListenerEvent> get eventStream => _eventController.stream;
  
  /// Current service statistics
  Map<String, int> get statistics => Map.unmodifiable(_stats);
  
  /// Whether the service is currently listening for SMS messages
  bool get isListening => _isListening;
  
  /// Current user ID being used for transaction storage
  String? get currentUserId => _currentUserId;
  
  /// Initialize the service
  /// 
  /// Must be called before starting the listener
  Future<void> initialize({String? hivePath}) async {
    try {
      developer.log('Initializing SMS Listener Service', name: 'SmsListenerService');
      
      // Initialize duplicate detector
      await _duplicateDetector.initialize(path: hivePath);
      
      developer.log('SMS Listener Service initialized successfully', name: 'SmsListenerService');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize SMS Listener Service: $e',
        name: 'SmsListenerService',
        error: e,
        stackTrace: stackTrace,
      );
      throw SmsListenerException(
        'Failed to initialize SMS Listener Service: $e',
        details: e,
      );
    }
  }
  
  /// Start listening for SMS messages
  /// 
  /// [userId] is required to associate transactions with a user
  Future<void> startListening(String userId) async {
    if (_isListening) {
      developer.log('SMS listening already started', name: 'SmsListenerService');
      return;
    }
    
    if (userId.trim().isEmpty) {
      throw const SmsListenerException('User ID is required to start listening');
    }
    
    try {
      _currentUserId = userId;
      
      // Check SMS permissions
      final hasPermissions = await _smsChannel.checkPermissions();
      if (!hasPermissions) {
        throw const SmsListenerException('SMS permissions not granted');
      }
      
      // Start SMS platform channel listening
      await _smsChannel.startListening();
      
      // Subscribe to SMS stream and process messages
      print('🟠 [SmsListenerService] Subscribing to SMS stream...');
      _smsSubscription = _smsChannel.smsStream.listen(
        (platformSmsMessage) {
          print('🟠 [SmsListenerService] SMS received from platform channel: ${platformSmsMessage.sender}');
          // Convert platform SmsMessage to domain SmsMessage
          final domainSmsMessage = SmsMessage(
            sender: platformSmsMessage.sender,
            content: platformSmsMessage.content,
            timestamp: platformSmsMessage.timestamp,
            threadId: platformSmsMessage.threadId,
          );
          print('🟠 [SmsListenerService] Processing SMS message...');
          _processSmsMessage(domainSmsMessage);
        },
        onError: (error) {
          print('❌ [SmsListenerService] SMS stream error: $error');
          _handleSmsStreamError(error);
        },
        onDone: () {
          print('⚠️ [SmsListenerService] SMS stream closed - this should not happen during normal operation');
          developer.log('SMS stream closed', name: 'SmsListenerService');
          _isListening = false;
        },
        cancelOnError: false, // Don't cancel on errors, keep listening
      );
      
      _isListening = true;
      _resetStatistics();
      
      _eventController.add(SmsListenerEvent.started(userId));
      
      developer.log(
        'SMS Listener Service started for user: $userId',
        name: 'SmsListenerService',
      );
    } catch (e, stackTrace) {
      _currentUserId = null;
      _isListening = false;
      
      developer.log(
        'Failed to start SMS listening: $e',
        name: 'SmsListenerService',
        error: e,
        stackTrace: stackTrace,
      );
      
      _eventController.add(SmsListenerEvent.error('Failed to start listening: $e'));
      
      throw SmsListenerException(
        'Failed to start SMS listening: $e',
        details: e,
      );
    }
  }
  
  /// Stop listening for SMS messages
  Future<void> stopListening() async {
    if (!_isListening) {
      developer.log('SMS listening already stopped', name: 'SmsListenerService');
      return;
    }
    
    try {
      // Cancel SMS subscription
      await _smsSubscription?.cancel();
      _smsSubscription = null;
      
      // Stop SMS platform channel
      await _smsChannel.stopListening();
      
      _isListening = false;
      _currentUserId = null;
      
      _eventController.add(SmsListenerEvent.stopped());
      
      developer.log('SMS Listener Service stopped', name: 'SmsListenerService');
    } catch (e, stackTrace) {
      developer.log(
        'Error stopping SMS listening: $e',
        name: 'SmsListenerService',
        error: e,
        stackTrace: stackTrace,
      );
      
      _eventController.add(SmsListenerEvent.error('Failed to stop listening: $e'));
      
      throw SmsListenerException(
        'Failed to stop SMS listening: $e',
        details: e,
      );
    }
  }
  
  /// Request SMS permissions from the user
  Future<bool> requestPermissions() async {
    try {
      return await _smsChannel.requestPermissions();
    } catch (e) {
      developer.log(
        'Error requesting SMS permissions: $e',
        name: 'SmsListenerService',
        error: e,
      );
      throw SmsListenerException(
        'Failed to request SMS permissions: $e',
        details: e,
      );
    }
  }
  
  /// Check if SMS permissions are granted
  Future<bool> checkPermissions() async {
    try {
      return await _smsChannel.checkPermissions();
    } catch (e) {
      developer.log(
        'Error checking SMS permissions: $e',
        name: 'SmsListenerService',
        error: e,
      );
      throw SmsListenerException(
        'Failed to check SMS permissions: $e',
        details: e,
      );
    }
  }
  
  /// Process a single SMS message through the complete pipeline
  /// 
  /// This is the core method that orchestrates:
  /// 1. Edge case handling (empty messages, encoding issues)
  /// 2. Duplicate detection
  /// 3. Financial context detection
  /// 4. Transaction parsing
  /// 5. Validation
  /// 6. Database storage
  Future<void> _processSmsMessage(SmsMessage sms) async {
    _stats['totalReceived'] = (_stats['totalReceived'] ?? 0) + 1;
    
    try {
      developer.log(
        'Processing SMS from ${sms.sender}: ${sms.content.substring(0, sms.content.length > 50 ? 50 : sms.content.length)}...',
        name: 'SmsListenerService',
      );
      
      // Step 1: Handle edge cases
      if (!_isValidSmsMessage(sms)) {
        developer.log(
          'Skipping invalid SMS message: empty or malformed content',
          name: 'SmsListenerService',
        );
        return;
      }
      
      // Step 2: Check for duplicates
      if (await _duplicateDetector.isSmsMessageDuplicate(sms)) {
        _stats['duplicatesDetected'] = (_stats['duplicatesDetected'] ?? 0) + 1;
        developer.log(
          'Duplicate SMS detected, skipping: ${sms.sender}',
          name: 'SmsListenerService',
        );
        _eventController.add(SmsListenerEvent.duplicateDetected(sms));
        return;
      }
      
      // Step 3: Financial context detection
      if (!_financialDetector.isFinancialMessage(sms.content)) {
        developer.log(
          'Non-financial SMS, skipping: ${sms.sender}',
          name: 'SmsListenerService',
        );
        _eventController.add(SmsListenerEvent.nonFinancialMessage(sms));
        return;
      }
      
      _stats['financialMessages'] = (_stats['financialMessages'] ?? 0) + 1;
      _eventController.add(SmsListenerEvent.financialMessageDetected(sms));
      
      // Step 4: Parse transaction
      final parsedTransaction = _smsParser.parseTransaction(sms);
      if (parsedTransaction == null) {
        developer.log(
          'Failed to parse transaction from SMS: ${sms.sender}',
          name: 'SmsListenerService',
        );
        _eventController.add(SmsListenerEvent.parsingFailed(sms, 'Unable to extract transaction details'));
        return;
      }
      
      _stats['successfullyParsed'] = (_stats['successfullyParsed'] ?? 0) + 1;
      _eventController.add(SmsListenerEvent.transactionParsed(sms, parsedTransaction));
      
      // Step 5: Create full transaction with metadata
      final transaction = Transaction.fromParsedTransaction(
        id: _uuid.v4(),
        userId: _currentUserId!,
        createdAt: DateTime.now(),
        syncedToFirestore: false, // Will be set to true after successful save
        duplicateCheckHash: _duplicateDetector.generateHash(sms),
        isManualEntry: false,
        parsedTransaction: parsedTransaction,
      );
      
      // Step 6: Validate transaction
      final validationResult = _validator.validateTransaction(transaction);
      if (!validationResult.isValid) {
        developer.log(
          'Transaction validation failed: ${validationResult.errors.join(', ')}',
          name: 'SmsListenerService',
        );
        _eventController.add(SmsListenerEvent.validationFailed(
          sms,
          parsedTransaction,
          validationResult.errors,
        ));
        return;
      }
      
      _stats['validationPassed'] = (_stats['validationPassed'] ?? 0) + 1;
      
      // Log validation warnings if any
      if (validationResult.warnings.isNotEmpty) {
        developer.log(
          'Transaction validation warnings: ${validationResult.warnings.join(', ')}',
          name: 'SmsListenerService',
        );
      }
      
      // Step 7: Save to database
      print('🟠 [SmsListenerService] Saving transaction to repository...');
      print('🟠 [SmsListenerService] Transaction details: amount=${parsedTransaction.amount}, user=${_currentUserId}');
      
      final transactionId = await _repository.saveTransaction(
        transaction.copyWith(syncedToFirestore: true),
      );
      
      print('✅ [SmsListenerService] Transaction saved with ID: $transactionId');
      
      _stats['savedToDatabase'] = (_stats['savedToDatabase'] ?? 0) + 1;
      
      // Step 8: Mark SMS as processed to prevent duplicates
      await _duplicateDetector.markSmsAsProcessed(sms);
      
      _eventController.add(SmsListenerEvent.transactionSaved(
        sms,
        parsedTransaction,
        transactionId,
      ));
      
      print('🟠 [SmsListenerService] Transaction processing completed successfully');
      developer.log(
        'Successfully processed transaction: $transactionId (₹${parsedTransaction.amount})',
        name: 'SmsListenerService',
      );
    } catch (e, stackTrace) {
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
      
      developer.log(
        'Error processing SMS message: $e',
        name: 'SmsListenerService',
        error: e,
        stackTrace: stackTrace,
      );
      
      _eventController.add(SmsListenerEvent.processingError(sms, e.toString()));
    }
  }
  
  /// Handle errors from the SMS stream
  void _handleSmsStreamError(dynamic error) {
    _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    
    developer.log(
      'SMS stream error: $error',
      name: 'SmsListenerService',
      error: error,
    );
    
    _eventController.add(SmsListenerEvent.error('SMS stream error: $error'));
  }
  
  /// Validate SMS message for edge cases
  /// 
  /// Handles:
  /// - Empty or whitespace-only content
  /// - Missing sender information
  /// - Special characters and encoding issues
  bool _isValidSmsMessage(SmsMessage sms) {
    // Check for empty or whitespace-only content
    if (sms.content.trim().isEmpty) {
      return false;
    }
    
    // Check for missing sender
    if (sms.sender.trim().isEmpty) {
      return false;
    }
    
    // Check for reasonable content length (not too short or too long)
    final contentLength = sms.content.length;
    if (contentLength < 10 || contentLength > 2000) {
      return false;
    }
    
    // Check for basic encoding issues (contains only printable characters)
    // Allow common Unicode characters but reject control characters
    final hasValidCharacters = sms.content.runes.every((rune) {
      return rune >= 32 || rune == 9 || rune == 10 || rune == 13; // Allow printable + tab/newline/CR
    });
    
    if (!hasValidCharacters) {
      return false;
    }
    
    return true;
  }
  
  /// Reset service statistics
  void _resetStatistics() {
    _stats.clear();
    _stats.addAll({
      'totalReceived': 0,
      'financialMessages': 0,
      'successfullyParsed': 0,
      'validationPassed': 0,
      'savedToDatabase': 0,
      'duplicatesDetected': 0,
      'errors': 0,
    });
  }
  
  /// Get detailed service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isListening': _isListening,
      'currentUserId': _currentUserId,
      'statistics': Map.from(_stats),
    };
  }
  
  /// Get detailed service status with permissions check
  Future<Map<String, dynamic>> getServiceStatusWithPermissions() async {
    return {
      'isListening': _isListening,
      'currentUserId': _currentUserId,
      'statistics': Map.from(_stats),
      'hasPermissions': await _smsChannel.checkPermissions(),
    };
  }
  
  /// Dispose service resources
  Future<void> dispose() async {
    try {
      // Stop listening if active
      if (_isListening) {
        await stopListening();
      }
      
      // Close duplicate detector
      await _duplicateDetector.close();
      
      // Close event stream
      await _eventController.close();
      
      // Dispose SMS channel
      _smsChannel.dispose();
      
      developer.log('SMS Listener Service disposed', name: 'SmsListenerService');
    } catch (e, stackTrace) {
      developer.log(
        'Error disposing SMS Listener Service: $e',
        name: 'SmsListenerService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Events emitted by the SMS Listener Service for monitoring
abstract class SmsListenerEvent {
  const SmsListenerEvent();
  
  factory SmsListenerEvent.started(String userId) = _ServiceStarted;
  factory SmsListenerEvent.stopped() = _ServiceStopped;
  factory SmsListenerEvent.error(String message) = _ServiceError;
  factory SmsListenerEvent.duplicateDetected(SmsMessage sms) = _DuplicateDetected;
  factory SmsListenerEvent.nonFinancialMessage(SmsMessage sms) = _NonFinancialMessage;
  factory SmsListenerEvent.financialMessageDetected(SmsMessage sms) = _FinancialMessageDetected;
  factory SmsListenerEvent.transactionParsed(SmsMessage sms, ParsedTransaction transaction) = _TransactionParsed;
  factory SmsListenerEvent.parsingFailed(SmsMessage sms, String reason) = _ParsingFailed;
  factory SmsListenerEvent.validationFailed(SmsMessage sms, ParsedTransaction transaction, List<String> errors) = _ValidationFailed;
  factory SmsListenerEvent.transactionSaved(SmsMessage sms, ParsedTransaction transaction, String transactionId) = _TransactionSaved;
  factory SmsListenerEvent.processingError(SmsMessage sms, String error) = _ProcessingError;
}

class _ServiceStarted extends SmsListenerEvent {
  final String userId;
  const _ServiceStarted(this.userId);
  
  @override
  String toString() => 'ServiceStarted(userId: $userId)';
}

class _ServiceStopped extends SmsListenerEvent {
  const _ServiceStopped();
  
  @override
  String toString() => 'ServiceStopped()';
}

class _ServiceError extends SmsListenerEvent {
  final String message;
  const _ServiceError(this.message);
  
  @override
  String toString() => 'ServiceError(message: $message)';
}

class _DuplicateDetected extends SmsListenerEvent {
  final SmsMessage sms;
  const _DuplicateDetected(this.sms);
  
  @override
  String toString() => 'DuplicateDetected(sender: ${sms.sender})';
}

class _NonFinancialMessage extends SmsListenerEvent {
  final SmsMessage sms;
  const _NonFinancialMessage(this.sms);
  
  @override
  String toString() => 'NonFinancialMessage(sender: ${sms.sender})';
}

class _FinancialMessageDetected extends SmsListenerEvent {
  final SmsMessage sms;
  const _FinancialMessageDetected(this.sms);
  
  @override
  String toString() => 'FinancialMessageDetected(sender: ${sms.sender})';
}

class _TransactionParsed extends SmsListenerEvent {
  final SmsMessage sms;
  final ParsedTransaction transaction;
  const _TransactionParsed(this.sms, this.transaction);
  
  @override
  String toString() => 'TransactionParsed(amount: ₹${transaction.amount}, type: ${transaction.transactionType})';
}

class _ParsingFailed extends SmsListenerEvent {
  final SmsMessage sms;
  final String reason;
  const _ParsingFailed(this.sms, this.reason);
  
  @override
  String toString() => 'ParsingFailed(sender: ${sms.sender}, reason: $reason)';
}

class _ValidationFailed extends SmsListenerEvent {
  final SmsMessage sms;
  final ParsedTransaction transaction;
  final List<String> errors;
  const _ValidationFailed(this.sms, this.transaction, this.errors);
  
  @override
  String toString() => 'ValidationFailed(errors: ${errors.join(', ')})';
}

class _TransactionSaved extends SmsListenerEvent {
  final SmsMessage sms;
  final ParsedTransaction transaction;
  final String transactionId;
  const _TransactionSaved(this.sms, this.transaction, this.transactionId);
  
  @override
  String toString() => 'TransactionSaved(id: $transactionId, amount: ₹${transaction.amount})';
}

class _ProcessingError extends SmsListenerEvent {
  final SmsMessage sms;
  final String error;
  const _ProcessingError(this.sms, this.error);
  
  @override
  String toString() => 'ProcessingError(sender: ${sms.sender}, error: $error)';
}