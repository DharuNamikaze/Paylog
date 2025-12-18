import 'package:paylog/core/utils/duplicate_detector.dart';
import 'package:paylog/domain/entities/sms_message.dart';

/// Example usage of DuplicateDetector
/// 
/// This example demonstrates how to use the DuplicateDetector to prevent
/// duplicate SMS messages from being processed and stored in Firestore.
void main() async {
  // Initialize the duplicate detector
  final duplicateDetector = DuplicateDetector();
  await duplicateDetector.initialize();
  
  // Example 1: Check if an SMS message is a duplicate
  final sms1 = SmsMessage(
    sender: 'HDFC',
    content: 'Rs.1000 debited from account xxxx2323 on 01-Jan-24',
    timestamp: DateTime(2024, 1, 1, 12, 0, 0),
  );
  
  // Check if this message has been processed before
  final isDuplicate1 = await duplicateDetector.isSmsMessageDuplicate(sms1);
  print('Is SMS 1 a duplicate? $isDuplicate1'); // false
  
  if (!isDuplicate1) {
    // Process the message (parse, validate, save to Firestore)
    print('Processing SMS 1...');
    
    // Mark as processed to prevent future duplicates
    await duplicateDetector.markSmsAsProcessed(sms1);
    final hash = duplicateDetector.generateHash(sms1);
    print('SMS 1 marked as processed with hash: $hash');
  }
  
  // Example 2: Try to process the same message again
  final isDuplicate2 = await duplicateDetector.isSmsMessageDuplicate(sms1);
  print('Is SMS 1 a duplicate now? $isDuplicate2'); // true
  
  if (isDuplicate2) {
    print('SMS 1 is a duplicate, skipping processing');
  }
  
  // Example 3: Different message with same content but different timestamp
  final sms2 = SmsMessage(
    sender: 'HDFC',
    content: 'Rs.1000 debited from account xxxx2323 on 01-Jan-24',
    timestamp: DateTime(2024, 1, 1, 12, 0, 1), // 1 second later
  );
  
  final isDuplicate3 = await duplicateDetector.isSmsMessageDuplicate(sms2);
  print('Is SMS 2 a duplicate? $isDuplicate3'); // false (different timestamp)
  
  // Example 4: Generate hash manually for Transaction entity
  final hash = duplicateDetector.generateHashFromComponents(
    sender: 'ICICI',
    content: 'Rs.2000 credited to account xxxx4545',
    timestamp: DateTime(2024, 1, 2, 14, 30, 0),
  );
  print('Generated hash: $hash');
  
  // This hash can be stored in the Transaction.duplicateCheckHash field
  
  // Example 5: Cleanup old hashes (maintenance operation)
  print('\nPerforming cleanup...');
  final removedCount = await duplicateDetector.cleanupOldHashes(
    maxAge: const Duration(days: 90),
  );
  print('Removed $removedCount old hashes');
  
  // Example 6: Get statistics
  final hashCount = await duplicateDetector.getHashCount();
  print('Total hashes stored: $hashCount');
  
  // Clean up
  await duplicateDetector.close();
}

/// Example integration with SMS processing workflow
Future<void> processSmsMessage(
  SmsMessage sms,
  DuplicateDetector duplicateDetector,
) async {
  // Step 1: Check for duplicates
  if (await duplicateDetector.isSmsMessageDuplicate(sms)) {
    print('Duplicate SMS detected, skipping processing');
    return;
  }
  
  // Step 2: Detect financial context
  // final isFinancial = financialDetector.isFinancialMessage(sms.content);
  // if (!isFinancial) return;
  
  // Step 3: Parse transaction
  // final parsedTransaction = smsParser.parseTransaction(sms);
  // if (parsedTransaction == null) return;
  
  // Step 4: Generate duplicate check hash for Transaction entity
  final duplicateHash = duplicateDetector.generateHash(sms);
  
  // Step 5: Create Transaction with hash
  // final transaction = Transaction.fromParsedTransaction(
  //   id: uuid.v4(),
  //   userId: currentUserId,
  //   createdAt: DateTime.now(),
  //   syncedToFirestore: false,
  //   duplicateCheckHash: duplicateHash,
  //   isManualEntry: false,
  //   parsedTransaction: parsedTransaction,
  // );
  
  // Step 6: Save to Firestore
  // await transactionRepository.saveTransaction(transaction);
  
  // Step 7: Mark SMS as processed
  await duplicateDetector.markAsProcessed(duplicateHash);
  
  print('SMS processed successfully');
}
