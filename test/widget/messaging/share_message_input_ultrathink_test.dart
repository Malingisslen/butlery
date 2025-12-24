// test/widget/messaging/share_message_input_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ShareMessageInput Widget - 39 lines of production code
// Testing message input for sharing dialogs with Swedish localization

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code
import 'package:butlery/widgets/common/share_dialog/share_message_input.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('ShareMessageInput Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.light(
            onSurfaceVariant: Colors.grey[600]!,
          ),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Basic Widget Structure Tests', () {
      testWidgets('builds widget with required parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 8-38
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Should render main Column structure
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(
            find.byType(SizedBox),
            findsNWidgets(
                3)); // Three SizedBox widgets (2 from ShareMessageInput + 1 shrink from framework)

        controller.dispose();
      });

      testWidgets('renders with all three parameters provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with all parameters
        final controller = TextEditingController();
        const initialMessage = 'Initial test message';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                initialMessage,
              ),
            ),
          ),
        );

        // Should render without issues when all parameters provided
        expect(find.byType(ShareMessageInput),
            findsNothing); // Static class, no instance
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        controller.dispose();
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('shows Swedish title text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 16-21
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Should show Swedish title
        expect(find.text('Meddelande (valfritt)'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('shows Swedish hint text in TextField',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 26-27
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Should show Swedish hint text
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
            textField.decoration?.hintText, equals('Skriv ett meddelande...'));

        controller.dispose();
      });
    });

    group('Title Styling Tests', () {
      testWidgets('title has correct text style', (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 17-20
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final titleText =
            tester.widget<Text>(find.text('Meddelande (valfritt)'));
        expect(titleText.style?.fontWeight, equals(FontWeight.w600));
        // Style should be based on AppTextStyles.titleMedium with copyWith

        controller.dispose();
      });
    });

    group('TextField Configuration Tests', () {
      testWidgets('TextField has correct basic properties',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 23-34
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller, equals(controller));
        expect(textField.maxLines, equals(3));
        expect(textField.textInputAction, equals(TextInputAction.newline));

        controller.dispose();
      });

      testWidgets('TextField hint style uses theme color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 27-29
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        // Hint style should be based on AppTextStyles.bodySmall with copyWith using theme color
        expect(textField.decoration?.hintStyle, isNotNull);

        controller.dispose();
      });

      testWidgets('TextField style is set correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 33
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.style, equals(AppTextStyles.bodyLarge));

        controller.dispose();
      });
    });

    group('Layout and Spacing Tests', () {
      testWidgets('Column has correct CrossAxisAlignment',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 14
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));

        controller.dispose();
      });

      testWidgets('has correct spacing between elements',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 22, 35
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.length,
            equals(3)); // 2 from ShareMessageInput + 1 shrink from framework

        // Find SizedBoxes with specific heights from ShareMessageInput
        final spacingMBoxes =
            sizedBoxes.where((box) => box.height == AppDimensions.spacingM);
        final spacingXlBoxes =
            sizedBoxes.where((box) => box.height == AppDimensions.spacingXl);

        // Should have one SizedBox with spacingM height and one with spacingXl height
        expect(spacingMBoxes.length, equals(1));
        expect(spacingXlBoxes.length, equals(1));

        controller.dispose();
      });
    });

    group('Controller Integration Tests', () {
      testWidgets('TextField controller receives text input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test controller functionality
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Enter text into the field
        const testText = 'Detta är ett testmeddelande på svenska!';
        await tester.enterText(find.byType(TextField), testText);
        await tester.pump();

        // Controller should contain the entered text
        expect(controller.text, equals(testText));

        controller.dispose();
      });

      testWidgets('TextField controller can be pre-populated',
          (WidgetTester tester) async {
        // ULTRATHINK: Test pre-populated controller
        final controller = TextEditingController(text: 'Initial text');

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Should display the initial text
        expect(find.text('Initial text'), findsOneWidget);
        expect(controller.text, equals('Initial text'));

        controller.dispose();
      });

      testWidgets('TextField supports multi-line text input',
          (WidgetTester tester) async {
        // ULTRATHINK: Test multi-line capability from maxLines: 3
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        const multiLineText = 'Line 1\nLine 2\nLine 3\nLine 4';
        await tester.enterText(find.byType(TextField), multiLineText);
        await tester.pump();

        expect(controller.text, equals(multiLineText));

        // Verify maxLines property allows this
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, equals(3));

        controller.dispose();
      });
    });

    group('Initial Message Parameter Tests', () {
      testWidgets('initialMessage parameter does not affect UI directly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code - initialMessage is passed but not used in UI
        final controller = TextEditingController();
        const initialMessage = 'This should not appear in UI';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                initialMessage,
              ),
            ),
          ),
        );

        // The initialMessage parameter is not used in the widget build
        // It's likely used by calling code to pre-populate the controller
        expect(find.text(initialMessage), findsNothing);
        expect(find.text('Meddelande (valfritt)'), findsOneWidget);
        // Note: Hint text may be visible depending on framework rendering

        controller.dispose();
      });

      testWidgets('widget renders same regardless of initialMessage value',
          (WidgetTester tester) async {
        // ULTRATHINK: Test that initialMessage doesn't change widget structure
        final controller1 = TextEditingController();
        final controller2 = TextEditingController();

        // Test with null initialMessage
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller1,
                null,
              ),
            ),
          ),
        );

        final column1 = tester.widget<Column>(find.byType(Column));
        final childrenCount1 = column1.children.length;

        // Test with non-null initialMessage
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller2,
                'Some initial message',
              ),
            ),
          ),
        );

        final column2 = tester.widget<Column>(find.byType(Column));
        final childrenCount2 = column2.children.length;

        // Should have same number of children regardless of initialMessage
        expect(childrenCount1, equals(childrenCount2));

        controller1.dispose();
        controller2.dispose();
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles empty controller gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test with empty controller
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        // Should render without error with empty controller
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(controller.text, isEmpty);
        expect(tester.takeException(), isNull);

        controller.dispose();
      });

      testWidgets('handles very long text input', (WidgetTester tester) async {
        // ULTRATHINK: Test with long text input
        final controller = TextEditingController();
        final longText =
            'Detta är ett mycket långt meddelande som testar ' * 20;

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        // Should handle long text without error
        expect(controller.text, equals(longText));
        expect(tester.takeException(), isNull);

        controller.dispose();
      });

      testWidgets('handles special Swedish characters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        final controller = TextEditingController();
        const swedishText = 'Åsa äter äpplen och öl i Göteborg!';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), swedishText);
        await tester.pump();

        // Should handle Swedish characters correctly
        expect(controller.text, equals(swedishText));
        expect(find.text(swedishText), findsOneWidget);

        controller.dispose();
      });

      testWidgets('handles newline input correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test newline handling with TextInputAction.newline
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ShareMessageInput.build(
                context,
                controller,
                null,
              ),
            ),
          ),
        );

        const textWithNewlines = 'First line\nSecond line\nThird line';
        await tester.enterText(find.byType(TextField), textWithNewlines);
        await tester.pump();

        // Should preserve newlines
        expect(controller.text, equals(textWithNewlines));

        // Verify textInputAction is set for newlines
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.textInputAction, equals(TextInputAction.newline));

        controller.dispose();
      });
    });

    group('Integration Tests', () {
      testWidgets('complete widget integration with real usage pattern',
          (WidgetTester tester) async {
        // ULTRATHINK: Test real-world usage scenario
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => ShareMessageInput.build(
                  context,
                  controller,
                  'Prefilled message for sharing',
                ),
              ),
            ),
          ),
        );

        // Should render all components correctly
        expect(find.text('Meddelande (valfritt)'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Should be able to interact with the field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        // Should be able to modify text
        await tester.enterText(
            find.byType(TextField), 'Modified sharing message');
        await tester.pump();

        expect(controller.text, equals('Modified sharing message'));

        controller.dispose();
      });

      testWidgets('works correctly when wrapped in scrollable content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test in scrollable context
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Header content'),
                    const SizedBox(height: 20),
                    Builder(
                      builder: (context) => ShareMessageInput.build(
                        context,
                        controller,
                        null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Footer content'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Should work correctly in scrollable context
        expect(find.text('Meddelande (valfritt)'), findsOneWidget);
        expect(find.text('Header content'), findsOneWidget);
        expect(find.text('Footer content'), findsOneWidget);

        // Should be interactive
        await tester.enterText(find.byType(TextField), 'Scrollable test');
        expect(controller.text, equals('Scrollable test'));

        controller.dispose();
      });
    });
  });
}
