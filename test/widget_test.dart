import 'package:flutter_test/flutter_test.dart';

import 'package:paylog/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(servicesInitialized: true));

    // Verify that our app starts with the correct title.
    expect(find.text('SMS Transaction Parser'), findsOneWidget);
  });
}
