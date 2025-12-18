import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paylog/presentation/pages/dashboard_page.dart';
import 'package:paylog/domain/entities/transaction.dart';
import 'package:paylog/domain/entities/transaction_type.dart';

void main() {
  group('TransactionCard Widget Tests', () {
    testWidgets('should display transaction information correctly', (WidgetTester tester) async {
      // Arrange
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
        amount: 1000.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxxxx1234',
        date: '2023-12-18',
        time: '14:30:00',
        smsContent: 'Test SMS content',
        senderPhoneNumber: '+91-1234567890',
        confidenceScore: 0.95,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.text('-₹1,000.00'), findsOneWidget);
      expect(find.text('Debit'), findsOneWidget);
      expect(find.text('A/C: xxxxxx1234'), findsOneWidget);
      expect(find.text('From: +91-1234567890'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('should display credit transaction correctly', (WidgetTester tester) async {
      // Arrange
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
        amount: 2500.50,
        transactionType: TransactionType.credit,
        accountNumber: 'xxxxxx5678',
        date: '2023-12-18',
        time: '09:15:30',
        smsContent: 'Credit SMS content',
        senderPhoneNumber: '+91-9876543210',
        confidenceScore: 0.88,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.text('+₹2,500.50'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('should display manual entry indicator', (WidgetTester tester) async {
      // Arrange
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: true, // Manual entry
        amount: 500.0,
        transactionType: TransactionType.unknown,
        accountNumber: null,
        date: '2023-12-18',
        time: '12:00:00',
        smsContent: 'Manual SMS content',
        senderPhoneNumber: '+91-1111111111',
        confidenceScore: 0.60,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Low confidence'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('should format amount with commas correctly', (WidgetTester tester) async {
      // Arrange
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
        amount: 1234567.89,
        transactionType: TransactionType.credit,
        accountNumber: 'xxxxxx9999',
        date: '2023-12-18',
        time: '16:45:00',
        smsContent: 'Large amount SMS',
        senderPhoneNumber: '+91-5555555555',
        confidenceScore: 0.99,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.text('+₹1,234,567.89'), findsOneWidget);
    });

    testWidgets('should format date as Today for current date', (WidgetTester tester) async {
      // Arrange
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
        amount: 100.0,
        transactionType: TransactionType.debit,
        accountNumber: 'xxxxxx0000',
        date: todayString,
        time: '10:30:00',
        smsContent: 'Today SMS',
        senderPhoneNumber: '+91-0000000000',
        confidenceScore: 0.85,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('should handle transaction without account number', (WidgetTester tester) async {
      // Arrange
      final testTransaction = Transaction(
        id: 'test-id',
        userId: 'test-user-id',
        createdAt: DateTime.now(),
        syncedToFirestore: true,
        duplicateCheckHash: 'test-hash',
        isManualEntry: false,
        amount: 750.0,
        transactionType: TransactionType.credit,
        accountNumber: null, // No account number
        date: '2023-12-18',
        time: '18:20:00',
        smsContent: 'No account SMS',
        senderPhoneNumber: '+91-7777777777',
        confidenceScore: 0.92,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: testTransaction),
          ),
        ),
      );

      // Assert
      expect(find.text('+₹750.00'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget);
      expect(find.text('From: +91-7777777777'), findsOneWidget);
      // Should not find account number text
      expect(find.textContaining('A/C:'), findsNothing);
    });
  });
}
