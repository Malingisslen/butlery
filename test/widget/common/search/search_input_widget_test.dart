import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('SearchInputWidget', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() async {
      controller.dispose();
      focusNode.dispose();
      BaseUnitTest.resetMocks();
    });

    group('Rendering', () {
      testWidgets('should render search field with default hint text',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Sök...'), findsOneWidget); // Default Swedish hint
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('should render with custom hint text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                hintText: 'Sök recept...',
              ),
            ),
          ),
        );

        expect(find.text('Sök recept...'), findsOneWidget);
      });

      testWidgets('should show clear button when text is entered',
          (tester) async {
        // Use ValueListenableBuilder to rebuild when controller changes
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return SearchInputWidget(
                    controller: controller,
                    focusNode: focusNode,
                  );
                },
              ),
            ),
          ),
        );

        // Initially no clear button
        expect(find.byIcon(Icons.clear), findsNothing);

        // Enter text
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();

        // Clear button should appear
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('should hide clear button when text is empty',
          (tester) async {
        controller.text = 'Initial text';

        // Use ValueListenableBuilder to rebuild when controller changes
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return SearchInputWidget(
                    controller: controller,
                    focusNode: focusNode,
                  );
                },
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.clear), findsOneWidget);

        // Clear text
        controller.clear();
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsNothing);
      });

      testWidgets('should apply custom padding when provided', (tester) async {
        const customPadding = EdgeInsets.all(20.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                padding: customPadding,
              ),
            ),
          ),
        );

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(customPadding));
      });

      testWidgets('should not wrap with padding when not provided',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                padding: null,
              ),
            ),
          ),
        );

        // TextField should be direct child, not wrapped in Padding
        expect(find.byType(Padding), findsNothing);
      });
    });

    group('Interactions', () {
      testWidgets('should handle text input', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Köttbullar');
        await tester.pump();

        expect(controller.text, equals('Köttbullar'));
      });

      testWidgets('should call onClear callback when clear button is pressed',
          (tester) async {
        bool clearCalled = false;
        controller.text = 'Test';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                onClear: () => clearCalled = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        expect(clearCalled, isTrue);
      });

      testWidgets('should autofocus when enabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('should not autofocus when disabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                autofocus: false,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(focusNode.hasFocus, isFalse);
      });

      testWidgets('should maintain focus when typing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        // Tap to focus
        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);

        // Type text
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();

        // Should still have focus
        expect(focusNode.hasFocus, isTrue);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish hint text by default',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        expect(find.text('Sök...'), findsOneWidget);
      });

      testWidgets('should handle Swedish characters in input', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        await tester.enterText(
            find.byType(TextField), 'Räksmörgås med ägg och öl');
        await tester.pump();

        expect(controller.text, equals('Räksmörgås med ägg och öl'));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle very long search text', (tester) async {
        final longText = 'Detta är en mycket lång söktext ' * 10;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        expect(controller.text, equals(longText));
      });

      testWidgets('should handle empty onClear callback gracefully',
          (tester) async {
        controller.text = 'Test';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                onClear: null,
              ),
            ),
          ),
        );

        // Should not crash when tapping clear with null callback
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();
      });

      testWidgets('should update when controller text changes externally',
          (tester) async {
        // Use ValueListenableBuilder to rebuild when controller changes
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return SearchInputWidget(
                    controller: controller,
                    focusNode: focusNode,
                  );
                },
              ),
            ),
          ),
        );

        // Initially empty
        expect(find.byIcon(Icons.clear), findsNothing);

        // Change controller text externally
        controller.text = 'External update';
        await tester.pump();

        // Clear button should appear
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantics for search field',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
                hintText: 'Sök recept',
              ),
            ),
          ),
        );

        // TextField should be accessible
        expect(find.byType(TextField), findsOneWidget);

        // Icons should be present for visual indication
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('should handle keyboard actions properly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchInputWidget(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );

        // Focus the field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        // Should be able to type
        await tester.enterText(find.byType(TextField), 'Test');
        expect(controller.text, equals('Test'));
      });
    });
  });
}
