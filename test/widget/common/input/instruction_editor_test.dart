// test/widget/common/input/instruction_editor_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/theme/app_dimensions.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('InstructionEditor Widget Tests', () {
    group('Basic Rendering', () {
      testWidgets('renders single empty field when no initial instructions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(initialInstructions: []),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });

      testWidgets('renders fields for initial instructions',
          (WidgetTester tester) async {
        final instructions = [
          'Forvarm ugnen till 200C',
          'Blanda ingredienserna',
          'Baka i 30 minuter',
        ];

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(initialInstructions: instructions),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(3));

        final textFields =
            tester.widgetList<TextFormField>(find.byType(TextFormField));
        expect(textFields.elementAt(0).controller?.text, instructions[0]);
        expect(textFields.elementAt(1).controller?.text, instructions[1]);
        expect(textFields.elementAt(2).controller?.text, instructions[2]);
      });

      testWidgets('has correct padding between fields',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['First', 'Second'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Each field is wrapped in a Padding inside the Column
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
      testWidgets('supports multiline input', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['Test instruction'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byType(TextFormField), 'Line 1\nLine 2\nLine 3');
        await tester.pump();

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, 'Line 1\nLine 2\nLine 3');
      });

      testWidgets('handles text input action newline',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['Test'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pump();

        // Newline action doesn't create new field (only Enter/submit does)
        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Change Notifications', () {
      testWidgets('calls onChanged when text is modified',
          (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(
              initialInstructions: const ['Initial text'],
              onChanged: (instructions) {
                changedInstructions = instructions;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Modified text');
        await tester.pump();

        expect(changedInstructions, ['Modified text']);
      });

      testWidgets('filters out empty instructions in onChanged',
          (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(
              initialInstructions: const ['First', 'Second', 'Third'],
              onChanged: (instructions) {
                changedInstructions = instructions;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Clear the second field
        await tester.enterText(find.byType(TextFormField).at(1), '');
        await tester.pump();

        expect(changedInstructions, ['First', 'Third']);
      });

      testWidgets('trims whitespace from instructions',
          (WidgetTester tester) async {
        List<String>? changedInstructions;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(
              initialInstructions: const [''],
              onChanged: (instructions) {
                changedInstructions = instructions;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), '  Trimmed text  ');
        await tester.pump();

        expect(changedInstructions, ['Trimmed text']);
      });

      testWidgets('calls onChanged on each text entry',
          (WidgetTester tester) async {
        final callbackInstructions = <List<String>>[];

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(
              initialInstructions: const ['Initial'],
              onChanged: (instructions) {
                callbackInstructions.add(List.from(instructions));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Modified text');
        await tester.pump();

        expect(callbackInstructions.isNotEmpty, true);
        expect(callbackInstructions.last, ['Modified text']);
      });

      testWidgets('handles null onChanged gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['Test'],
              onChanged: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should not throw when typing without onChanged
        await tester.enterText(find.byType(TextFormField), 'Modified');
        await tester.pump();

        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Field Management', () {
      testWidgets('maintains separate controllers for each field',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['First', 'Second'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byType(TextFormField).at(0), 'Modified First');
        await tester.enterText(
            find.byType(TextFormField).at(1), 'Modified Second');
        await tester.pump();

        final textFields =
            tester.widgetList<TextFormField>(find.byType(TextFormField));
        expect(textFields.elementAt(0).controller?.text, 'Modified First');
        expect(textFields.elementAt(1).controller?.text, 'Modified Second');
      });

      testWidgets('creates empty controller when no initial instructions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(initialInstructions: []),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });
    });

    group('Layout Integration', () {
      testWidgets('works in SingleChildScrollView',
          (WidgetTester tester) async {
        final longInstructions =
            List.generate(20, (i) => 'Instruction ${i + 1}');

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: true,
            child: SingleChildScrollView(
              child: InstructionEditor(
                initialInstructions: longInstructions,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(20));
      });

      testWidgets('works in Column with other widgets',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const Column(
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
        );
        await tester.pumpAndSettle();

        expect(find.text('Recipe Instructions:'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('End of recipe'), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: [
                'Forsta instruktionen',
                'Andra instruktionen',
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The labels are generated by context.l10n.instructionLabel(i + 1)
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('handles Swedish text correctly',
          (WidgetTester tester) async {
        const swedishText =
            'Forvarm ugnen till 200C och stall in pa over- och undervarm';

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: [swedishText],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, swedishText);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty initial instructions list',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(initialInstructions: []),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('handles single empty string in initial instructions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(initialInstructions: ['']),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, '');
      });

      testWidgets('handles very long instruction text',
          (WidgetTester tester) async {
        final longText = 'A' * 1000;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: InstructionEditor(initialInstructions: [longText]),
          ),
        );
        await tester.pumpAndSettle();

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.controller?.text, longText);
      });

      testWidgets('handles normal operations gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(initialInstructions: ['Test']),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Modified test');
        await tester.pump();

        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('disposes controllers properly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              initialInstructions: ['First', 'Second', 'Third'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Replace with different widget to trigger dispose
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const Text('Replaced'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Replaced'), findsOneWidget);
        expect(find.byType(InstructionEditor), findsNothing);
      });

      testWidgets('handles widget replacement with different key',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              key: Key('editor1'),
              initialInstructions: ['Original'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: const InstructionEditor(
              key: Key('editor2'),
              initialInstructions: ['New', 'Content'],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(2));
      });
    });
  });
}
