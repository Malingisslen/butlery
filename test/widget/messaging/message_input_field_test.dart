// test/widget/messaging/message_input_field_test.dart
// Comprehensive tests for MessageInputField widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('MessageInputField Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget({
      required TextEditingController controller,
      required FocusNode focusNode,
      String hintText = 'Type a message',
      VoidCallback? onSubmitted,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: MessageInputField(
                controller: controller,
                focusNode: focusNode,
                hintText: hintText,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ),
      );
    }

    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    group('Rendering', () {
      testWidgets('should render with required properties',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        expect(find.byType(MessageInputField), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(DecoratedBox), findsOneWidget);
      });

      testWidgets('should display hint text', (WidgetTester tester) async {
        const hintText = 'Write your message here';

        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
        ));

        expect(find.text(hintText), findsOneWidget);
      });

      testWidgets('should have rounded border decoration',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusL)));
        expect(decoration.color, equals(AppColors.cream));
        expect(decoration.border, isNotNull);
      });

      testWidgets('should have proper border styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final border = decoration.border as Border;

        expect(border.top.color, equals(AppColors.divider));
        expect(border.top.width, equals(1.0));
      });

      testWidgets('should have proper content padding',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        final inputDecoration = textField.decoration as InputDecoration;

        expect(
            inputDecoration.contentPadding,
            equals(
              const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
            ));
      });

      testWidgets('should remove default input border',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        final inputDecoration = textField.decoration as InputDecoration;

        expect(inputDecoration.border, equals(InputBorder.none));
      });
    });

    group('Text Input', () {
      testWidgets('should accept text input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        const inputText = 'Hello, this is a test message';
        await tester.enterText(find.byType(TextField), inputText);

        expect(controller.text, equals(inputText));
      });

      testWidgets('should support multiline text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        const multilineText = 'Line 1\nLine 2\nLine 3';
        await tester.enterText(find.byType(TextField), multilineText);

        expect(controller.text, equals(multilineText));
      });

      testWidgets('should have minLines of 1', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.minLines, equals(1));
      });

      testWidgets('should have maxLines of 5', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, equals(5));
      });

      testWidgets('should capitalize sentences', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
            textField.textCapitalization, equals(TextCapitalization.sentences));
      });
    });

    group('Focus Management', () {
      testWidgets('should respond to focus changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        expect(focusNode.hasFocus, isFalse);

        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('should use provided FocusNode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode, equals(focusNode));
      });
    });

    group('Submit Functionality', () {
      testWidgets('should call onSubmitted when provided',
          (WidgetTester tester) async {
        var submitted = false;

        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: () => submitted = true,
        ));

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(submitted, isTrue);
      });

      testWidgets('should handle null onSubmitted gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: null,
        ));

        // Should not crash when submitting with null callback
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Test passes if no exception is thrown
        expect(find.byType(MessageInputField), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish hint text',
          (WidgetTester tester) async {
        const swedishHint = 'Skriv ett meddelande';

        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
          hintText: swedishHint,
        ));

        expect(find.text(swedishHint), findsOneWidget);
      });

      testWidgets('should handle Swedish characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        const swedishText = 'Hej! Hur mår du? Jag äter smörgås';
        await tester.enterText(find.byType(TextField), swedishText);

        expect(controller.text, equals(swedishText));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        await tester.enterText(find.byType(TextField), '');
        expect(controller.text, isEmpty);
      });

      testWidgets('should handle very long text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        final longText = 'a' * 1000;
        await tester.enterText(find.byType(TextField), longText);

        expect(controller.text, equals(longText));
      });

      testWidgets('should handle rapid text changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        await tester.enterText(find.byType(TextField), 'First');
        expect(controller.text, equals('First'));

        await tester.enterText(find.byType(TextField), 'Second');
        expect(controller.text, equals('Second'));

        await tester.enterText(find.byType(TextField), 'Third');
        expect(controller.text, equals('Third'));
      });

      testWidgets('should handle controller text updates',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        controller.text = 'Programmatically set';
        await tester.pump();

        expect(find.text('Programmatically set'), findsOneWidget);
      });

      testWidgets('should preserve text when widget rebuilds',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        await tester.enterText(find.byType(TextField), 'Persistent text');

        // Rebuild widget
        await tester.pumpWidget(createTestWidget(
          controller: controller,
          focusNode: focusNode,
        ));

        expect(controller.text, equals('Persistent text'));
        expect(find.text('Persistent text'), findsOneWidget);
      });
    });
  });
}
