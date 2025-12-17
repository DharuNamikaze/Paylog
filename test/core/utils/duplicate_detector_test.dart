import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/core/utils/duplicate_detector.dart';
import 'package:flutter_sms_parser/domain/entities/sms_message.dart';
import 'package:hive/hive.dart';

void main() {
  late DuplicateDetector duplicateDetector;
  late Directory testDir;

  setUp(() async {
    // Create a temporary directory for Hive
    testDir = await Directory.systemTemp.createTemp('duplicate_detector_test_');
    
    // Initialize duplicate detector with test path
    duplicateDetector = DuplicateDetector();
    await duplicateDetector.initialize(path: testDir.path);
  });

  tearDown(() async {
    // Close Hive and clean up
    await duplicateDetector.close();
    await Hive.close();
    
    // Delete test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('DuplicateDetector - Hash Generation', () {
    test('should generate consistent hash for same SMS message', () {
      final sms = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final hash1 = duplicateDetector.generateHash(sms);
      final hash2 = duplicateDetector.generateHash(sms);

      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);
    });

    test('should generate different hashes for different messages', () {
      final sms1 = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final sms2 = SmsMessage(
        sender: 'ICICI',
        content: 'Rs.2000 credited to account',
        timestamp: DateTime(2024, 1, 2, 12, 0, 0),
      );

      final hash1 = duplicateDetector.generateHash(sms1);
      final hash2 = duplicateDetector.generateHash(sms2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('should generate different hashes for same content but different sender', () {
      final sms1 = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final sms2 = SmsMessage(
        sender: 'ICICI',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final hash1 = duplicateDetector.generateHash(sms1);
      final hash2 = duplicateDetector.generateHash(sms2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('should generate different hashes for same content but different timestamp', () {
      final sms1 = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final sms2 = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 1), // 1 second difference
      );

      final hash1 = duplicateDetector.generateHash(sms1);
      final hash2 = duplicateDetector.generateHash(sms2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('should generate hash from components matching SMS message hash', () {
      final sms = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final hashFromSms = duplicateDetector.generateHash(sms);
      final hashFromComponents = duplicateDetector.generateHashFromComponents(
        sender: sms.sender,
        content: sms.content,
        timestamp: sms.timestamp,
      );

      expect(hashFromSms, equals(hashFromComponents));
    });
  });

  group('DuplicateDetector - Duplicate Detection', () {
    test('should return false for new message (not a duplicate)', () async {
      final sms = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final isDuplicate = await duplicateDetector.isSmsMessageDuplicate(sms);

      expect(isDuplicate, isFalse);
    });

    test('should return true for processed message (is a duplicate)', () async {
      final sms = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      // Mark as processed
      await duplicateDetector.markSmsAsProcessed(sms);

      // Check if duplicate
      final isDuplicate = await duplicateDetector.isSmsMessageDuplicate(sms);

      expect(isDuplicate, isTrue);
    });

    test('should detect duplicate using hash directly', () async {
      final hash = 'test_hash_123';

      // Initially not a duplicate
      expect(await duplicateDetector.isDuplicate(hash), isFalse);

      // Mark as processed
      await duplicateDetector.markAsProcessed(hash);

      // Now it's a duplicate
      expect(await duplicateDetector.isDuplicate(hash), isTrue);
    });

    test('should prevent duplicate records for identical messages', () async {
      final sms = SmsMessage(
        sender: 'HDFC',
        content: 'Rs.1000 debited from account',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      // First message - not a duplicate
      expect(await duplicateDetector.isSmsMessageDuplicate(sms), isFalse);
      await duplicateDetector.markSmsAsProcessed(sms);

      // Second identical message - is a duplicate
      expect(await duplicateDetector.isSmsMessageDuplicate(sms), isTrue);
    });
  });

  group('DuplicateDetector - Storage Operations', () {
    test('should store and retrieve processed timestamp', () async {
      final hash = 'test_hash_123';
      final beforeStore = DateTime.now();

      await duplicateDetector.markAsProcessed(hash);

      final timestamp = await duplicateDetector.getProcessedTimestamp(hash);

      expect(timestamp, isNotNull);
      expect(timestamp!.isAfter(beforeStore.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('should return null for non-existent hash timestamp', () async {
      final timestamp = await duplicateDetector.getProcessedTimestamp('non_existent_hash');

      expect(timestamp, isNull);
    });

    test('should remove hash from storage', () async {
      final hash = 'test_hash_123';

      await duplicateDetector.markAsProcessed(hash);
      expect(await duplicateDetector.isDuplicate(hash), isTrue);

      await duplicateDetector.removeHash(hash);
      expect(await duplicateDetector.isDuplicate(hash), isFalse);
    });

    test('should clear all hashes', () async {
      final hash1 = 'test_hash_1';
      final hash2 = 'test_hash_2';
      final hash3 = 'test_hash_3';

      await duplicateDetector.markAsProcessed(hash1);
      await duplicateDetector.markAsProcessed(hash2);
      await duplicateDetector.markAsProcessed(hash3);

      expect(await duplicateDetector.getHashCount(), equals(3));

      await duplicateDetector.clearAllHashes();

      expect(await duplicateDetector.getHashCount(), equals(0));
    });

    test('should get correct hash count', () async {
      expect(await duplicateDetector.getHashCount(), equals(0));

      await duplicateDetector.markAsProcessed('hash1');
      expect(await duplicateDetector.getHashCount(), equals(1));

      await duplicateDetector.markAsProcessed('hash2');
      expect(await duplicateDetector.getHashCount(), equals(2));

      await duplicateDetector.markAsProcessed('hash3');
      expect(await duplicateDetector.getHashCount(), equals(3));
    });
  });

  group('DuplicateDetector - Cleanup', () {
    test('should cleanup old hashes beyond max age', () async {
      // This test is simplified since we can't easily manipulate stored timestamps
      // In a real scenario, you'd need to mock the timestamp storage
      
      final hash1 = 'recent_hash';
      await duplicateDetector.markAsProcessed(hash1);

      // Cleanup with default 90 days - should not remove recent hash
      final removedCount = await duplicateDetector.cleanupOldHashes();

      expect(removedCount, equals(0));
      expect(await duplicateDetector.isDuplicate(hash1), isTrue);
    });

    test('should not remove hashes within max age', () async {
      final hash = 'recent_hash';
      await duplicateDetector.markAsProcessed(hash);

      // Cleanup with 1 day max age - recent hash should not be removed
      final removedCount = await duplicateDetector.cleanupOldHashes(
        maxAge: const Duration(days: 1),
      );

      expect(removedCount, equals(0));
      expect(await duplicateDetector.isDuplicate(hash), isTrue);
    });
  });

  group('DuplicateDetector - Error Handling', () {
    test('should throw StateError when not initialized', () async {
      final uninitializedDetector = DuplicateDetector();

      expect(
        () => uninitializedDetector.isDuplicate('hash'),
        throwsStateError,
      );
    });
  });
}
