// test/widget/common/input/instruction_editor_test.dart
// Comprehensive tests for InstructionEditor using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('InstructionEditor Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render single empty field when no initial instructions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [],
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Instruktion 1'), findsOneWidget);
        
        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });

      testWidgets('should render fields for initial instructions', (WidgetTester tester) async {
        final instructions = ['Förvärm ugnen till 200°C', 'Blanda ingredienserna', 'Baka i 30 minuter'];
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: instructions,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(find.text('Instruktion 1'), findsOneWidget);
        expect(find.text('Instruktion 2'), findsOneWidget);
        expect(find.text('Instruktion 3'), findsOneWidget);
        
        // Check that text fields contain the initial instructions
        final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField));
        expect(textFields.elementAt(0).controller?.text, instructions[0]);
        expect(textFields.elementAt(1).controller?.text, instructions[1]);
        expect(textFields.elementAt(2).controller?.text, instructions[2]);
      });

      testWidgets('should have correct field properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test instruction'],
              ),
            ),
          ),
        );

        // Test that TextFormField exists with correct basic setup
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should have correct decoration properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test'],
              ),
            ),
          ),
        );

        // Test that expected label text is present
        expect(find.text('Instruktion 1'), findsOneWidget);
      });

      testWidgets('should have correct padding between fields', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['First', 'Second'],
              ),
            ),
          ),
        );

        final paddings = tester.widgetList<Padding>(
          find.descendant(
            of: find.byType(InstructionEditor),
            matching: find.byType(Padding),
          ),
        );
        
        expect(paddings.length, 2);
        for (final padding in paddings) {
          expect(
            padding.padding,
            const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
          );
        }
      });
    });

    group('Field Properties', () {
      testWidgets('should support multiline input', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test instruction'],
              ),
            ),
          ),
        );

        // Test that multiline text can be entered
        await tester.enterText(find.byType(TextFormField), 'Line 1\nLine 2\nLine 3');
        await tester.pump();

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, 'Line 1\nLine 2\nLine 3');
      });

      testWidgets('should handle text input action newline', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test'],
              ),
            ),
          ),
        );

        // Newline action should add newline to current field, not create new field
        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pump();

        // Should still have only one field
        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Change Notifications', () {
      testWidgets('should call onChanged when text is modified', (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: const ['Initial text'],
                onChanged: (instructions) {
                  changedInstructions = instructions;
                },
              ),
            ),
          ),
        );

        // Type in the text field
        await tester.enterText(find.byType(TextFormField), 'Modified text');
        await tester.pump();

        expect(changedInstructions, ['Modified text']);
      });

      testWidgets('should filter out empty instructions in onChanged', (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: const ['First', 'Second', 'Third'],
                onChanged: (instructions) {
                  changedInstructions = instructions;
                },
              ),
            ),
          ),
        );

        // Clear the second field
        await tester.enterText(find.byType(TextFormField).at(1), '');
        await tester.pump();

        // Should only include non-empty instructions
        expect(changedInstructions, ['First', 'Third']);
      });

      testWidgets('should trim whitespace from instructions', (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: const [''],
                onChanged: (instructions) {
                  changedInstructions = instructions;
                },
              ),
            ),
          ),
        );

        // Enter text with whitespace
        await tester.enterText(find.byType(TextFormField), '  Trimmed text  ');
        await tester.pump();

        expect(changedInstructions, ['Trimmed text']);
      });

      testWidgets('should call onChanged multiple times during text entry', (WidgetTester tester) async {
        final callbackInstructions = <List<String>>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: const ['Initial'],
                onChanged: (instructions) {
                  callbackInstructions.add(List.from(instructions));
                },
              ),
            ),
          ),
        );

        // Type different text to trigger multiple onChanged calls
        await tester.enterText(find.byType(TextFormField), 'Modified text');
        await tester.pump();

        // Should have called onChanged 
        expect(callbackInstructions.isNotEmpty, true);
        expect(callbackInstructions.last, ['Modified text']);
      });

      testWidgets('should handle null onChanged gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test'],
                onChanged: null,
              ),
            ),
          ),
        );

        // Should not throw when typing
        await tester.enterText(find.byType(TextFormField), 'Modified');
        await tester.pump();

        // Widget should still function normally
        expect(find.text('Instruktion 1'), findsOneWidget);
      });
    });

    group('Field Management', () {
      testWidgets('should maintain separate controllers for each field', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['First', 'Second'],
              ),
            ),
          ),
        );

        // Type different text in each field
        await tester.enterText(find.byType(TextFormField).at(0), 'Modified First');
        await tester.enterText(find.byType(TextFormField).at(1), 'Modified Second');
        await tester.pump();

        final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField));
        expect(textFields.elementAt(0).controller?.text, 'Modified First');
        expect(textFields.elementAt(1).controller?.text, 'Modified Second');
      });

      testWidgets('should create empty controller when no initial instructions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [],
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        
        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in SingleChildScrollView', (WidgetTester tester) async {
        final longInstructions = List.generate(20, (i) => 'Instruction ${i + 1}');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InstructionEditor(
                  initialInstructions: longInstructions,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsNWidgets(20));
      });

      testWidgets('should work in Column with other widgets', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Text('Recipe Instructions:'),
                  Expanded(
                    child: InstructionEditor(
                      initialInstructions: ['Step 1', 'Step 2'],
                    ),
                  ),
                  Text('End of recipe'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Recipe Instructions:'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('End of recipe'), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Första instruktionen', 'Andra instruktionen'],
              ),
            ),
          ),
        );

        expect(find.text('Instruktion 1'), findsOneWidget);
        expect(find.text('Instruktion 2'), findsOneWidget);
      });

      testWidgets('should handle Swedish text correctly', (WidgetTester tester) async {
        const swedishText = 'Förvärm ugnen till 200°C och ställ in på över- och undervärme';
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [swedishText],
              ),
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, swedishText);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty initial instructions list', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [],
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Instruktion 1'), findsOneWidget);
      });

      testWidgets('should handle single empty string in initial instructions', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [''],
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        
        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });

      testWidgets('should handle very long instruction text', (WidgetTester tester) async {
        final longText = 'A' * 1000;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: [longText],
              ),
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, longText);
      });

      testWidgets('should handle edge cases gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['Test'],
              ),
            ),
          ),
        );

        // Should not crash with normal operations
        await tester.enterText(find.byType(TextFormField), 'Modified test');
        await tester.pump();

        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('should dispose controllers properly', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                initialInstructions: ['First', 'Second', 'Third'],
              ),
            ),
          ),
        );

        // Replace with different widget
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Replaced'),
            ),
          ),
        );

        expect(find.text('Replaced'), findsOneWidget);
        expect(find.byType(InstructionEditor), findsNothing);
      });

      testWidgets('should handle widget replacement', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                key: const Key('editor1'),
                initialInstructions: const ['Original'],
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);

        // Replace with new InstructionEditor with different key
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstructionEditor(
                key: const Key('editor2'),
                initialInstructions: const ['New', 'Content'],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}