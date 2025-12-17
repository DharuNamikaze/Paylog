import 'dart:async';
import 'dart:developer' as developer;

import 'sms_platform_channel.dart';

/// Demo class to show how the SMS platform channel would be used
class SmsPlatformDemo {
  final SmsPlatformChannel _smsPlatformChannel = SmsPlatformChannel();
  StreamSubscription<SmsMessage>? _smsSubscription;

  /// Initialize and start SMS monitoring
  Future<void> initialize() async {
    try {
      developer.log('Initializing SMS platform demo...', name: 'SmsPlatformDemo');

      // Check if permissions are already granted
      final hasPermissions = await _smsPlatformChannel.checkPermissions();
      
      if (!hasPermissions) {
        developer.log('SMS permissions not granted, requesting...', name: 'SmsPlatformDemo');
        
        // Request permissions from user
        final granted = await _smsPlatformChannel.requestPermissions();
        
        if (!granted) {
          throw Exception('SMS permissions denied by user');
        }
        
        developer.log('SMS permissions granted', name: 'SmsPlatformDemo');
      } else {
        developer.log('SMS permissions already granted', name: 'SmsPlatformDemo');
      }

      // Start listening for SMS messages
      await _smsPlatformChannel.startListening();
      developer.log('SMS listening started', name: 'SmsPlatformDemo');

      // Subscribe to SMS stream
      _smsSubscription = _smsPlatformChannel.smsStream.listen(
        _handleSmsMessage,
        onError: _handleSmsError,
      );

      developer.log('SMS platform demo initialized successfully', name: 'SmsPlatformDemo');
    } catch (e) {
      developer.log('Failed to initialize SMS platform: $e', name: 'SmsPlatformDemo', error: e);
      rethrow;
    }
  }

  /// Handle incoming SMS messages
  void _handleSmsMessage(SmsMessage sms) {
    developer.log(
      'SMS received from ${sms.sender}: ${sms.content.substring(0, sms.content.length > 100 ? 100 : sms.content.length)}...',
      name: 'SmsPlatformDemo',
    );

    // This is where the SMS would be passed to the Financial Context Detector
    // and then to the SMS Parser Service (implemented in future tasks)
    
    // For now, just log the message details
    _logSmsDetails(sms);
  }

  /// Handle SMS stream errors
  void _handleSmsError(dynamic error) {
    developer.log('SMS stream error: $error', name: 'SmsPlatformDemo', error: error);
  }

  /// Log detailed SMS information
  void _logSmsDetails(SmsMessage sms) {
    developer.log(
      '''
SMS Details:
- Sender: ${sms.sender}
- Content: ${sms.content}
- Timestamp: ${sms.timestamp}
- Thread ID: ${sms.threadId ?? 'N/A'}
- Content Length: ${sms.content.length} characters
      ''',
      name: 'SmsPlatformDemo',
    );
  }

  /// Stop SMS monitoring and cleanup
  Future<void> dispose() async {
    try {
      developer.log('Disposing SMS platform demo...', name: 'SmsPlatformDemo');

      await _smsSubscription?.cancel();
      _smsSubscription = null;

      await _smsPlatformChannel.stopListening();
      _smsPlatformChannel.dispose();

      developer.log('SMS platform demo disposed', name: 'SmsPlatformDemo');
    } catch (e) {
      developer.log('Error disposing SMS platform: $e', name: 'SmsPlatformDemo', error: e);
    }
  }

  /// Check if currently listening for SMS
  bool get isListening => _smsPlatformChannel.isListening;

  /// Simulate receiving an SMS message (for testing without actual SMS)
  void simulateSmsMessage({
    required String sender,
    required String content,
    DateTime? timestamp,
    String? threadId,
  }) {
    final sms = SmsMessage(
      sender: sender,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      threadId: threadId,
    );

    developer.log('Simulating SMS message from $sender', name: 'SmsPlatformDemo');
    _handleSmsMessage(sms);
  }
}

/// Example usage and test scenarios
class SmsPlatformExamples {
  static void demonstrateUsage() {
    developer.log('SMS Platform Channel Examples', name: 'SmsPlatformExamples');

    // Example 1: HDFC Bank debit SMS
    final hdfc_debit = SmsMessage(
      sender: 'HDFC-BANK',
      content: 'Dear Customer, your account XXXXXX1234 has been debited with Rs.1,500.00 on 15-Dec-2024 at 14:30. Available balance: Rs.25,000.00. -HDFC Bank',
      timestamp: DateTime.now(),
      threadId: 'hdfc_001',
    );

    // Example 2: ICICI Bank credit SMS
    final icici_credit = SmsMessage(
      sender: 'ICICI-BANK',
      content: 'Your A/c no XX1234 is credited with INR 2500.00 on 15-Dec-24. Available Bal: INR 15000.00. Thank you for banking with ICICI Bank.',
      timestamp: DateTime.now(),
      threadId: 'icici_001',
    );

    // Example 3: SBI Bank transfer SMS
    final sbi_transfer = SmsMessage(
      sender: 'SBI-BANK',
      content: 'SBI: Rs 1000 debited from a/c **1234 on 15Dec24 for UPI/P2P transfer to VPA test@paytm. Available bal Rs 5000. Not you? Call 1800111109',
      timestamp: DateTime.now(),
      threadId: 'sbi_001',
    );

    // Example 4: Non-financial SMS (should be filtered out)
    final non_financial = SmsMessage(
      sender: 'PROMO-MSG',
      content: 'Congratulations! You have won a free vacation. Click here to claim your prize.',
      timestamp: DateTime.now(),
      threadId: 'promo_001',
    );

    final examples = [hdfc_debit, icici_credit, sbi_transfer, non_financial];

    for (final sms in examples) {
      developer.log(
        '''
Example SMS:
- Sender: ${sms.sender}
- Content: ${sms.content}
- Is Financial: ${_isLikelyFinancial(sms.content)}
        ''',
        name: 'SmsPlatformExamples',
      );
    }
  }

  /// Simple heuristic to check if SMS content is likely financial
  /// (This logic will be implemented properly in the Financial Context Detector)
  static bool _isLikelyFinancial(String content) {
    final financialKeywords = [
      'debited', 'credited', 'transferred', 'payment', 'rupees', 'rs', '₹',
      'amount', 'balance', 'account', 'bank', 'upi', 'transaction'
    ];

    final lowerContent = content.toLowerCase();
    return financialKeywords.any((keyword) => lowerContent.contains(keyword));
  }
}