import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sms_parser/presentation/pages/manual_input_page.dart';

void main() {
  group('ManualInputPage', () {
    Widget createTestWidget() {
      return const MaterialApp(
        home: ManualInputPage(userId: 'test-user'),
      );
    }

    testWidgets('should display basic UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify the page has an app bar with title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Manual SMS Entry'), findsAtLeastNWidgets(1));

      // Verify form fields are present
      expect(find.byType(TextFormField), findsNWidgets(2));
      
      // Verify action buttons exist
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Parse & Save Transaction'), findsOneWidget);

      // Verify help button exists
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('should show help dialog when help button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap the help button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      // Verify help dialog is shown
      expect(find.text('Manual SMS Entry Help'), findsOneWidget);
      expect(find.text('How to use Manual SMS Entry:'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.text('Manual SMS Entry Help'), findsNothing);
    });

    testWidgets('should show example SMS in hint section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify example SMS is shown
      expect(find.text('Example SMS:'), findsOneWidget);
      expect(find.textContaining('Dear Customer, Rs.5000.00 has been debited'), findsOneWidget);
    });

    testWidgets('should have proper form structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify form exists
      expect(find.byType(Form), findsOneWidget);
      
      // Verify text form fields exist
      expect(find.byType(TextFormField), findsNWidgets(2));
      
      // Verify info card exists
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}