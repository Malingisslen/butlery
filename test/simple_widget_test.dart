import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Simple widget test', (WidgetTester tester) async {
    // Build a simple widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text('Hello Test'),
        ),
      ),
    );

    // Verify the text appears
    expect(find.text('Hello Test'), findsOneWidget);
  });
}
