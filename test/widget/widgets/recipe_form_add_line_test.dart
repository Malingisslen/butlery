/// BUT-2301: a paste or dictation into the last ingredient or instruction
/// line asks for the next empty line, and a visible button adds one too.
///
/// `enterText` delivers the whole string as ONE change, which is exactly
/// what a paste or a dictation result does on a device. That the request
/// adds at most one line is the view model's job and is pinned in
/// recipe_form_viewmodel_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/recipe_form/ingredient_section_state.dart';
import 'package:butlery/widgets/recipe/recipe_form/dynamic_list_builder.dart';
import 'package:butlery/widgets/recipe/recipe_form/sectioned_ingredient_list_builder.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('SectionedIngredientListBuilder', () {
    late List<TextEditingController> controllers;
    late int filled;
    late int adds;

    setUp(() {
      controllers = [TextEditingController(), TextEditingController()];
      filled = 0;
      adds = 0;
    });

    tearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    Widget build() => createLocalizedTestApp(
      wrapInScrollView: true,
      child: SectionedIngredientListBuilder(
        label: 'Ingrediens',
        rows: const [LineRow(), LineRow()],
        lineControllers: controllers,
        headingControllerFor: (_) => TextEditingController(),
        onLineChanged: (_, __) {},
        onAddLine: () => adds++,
        onLastLineFilled: () => filled++,
        onRemoveLine: (_) {},
        onReorder: (_, __) {},
        onAddHeading: () {},
        onRemoveHeading: (_) {},
        onMoveLineToSection: (_, __) {},
        canAddHeading: true,
      ),
    );

    testWidgets('a pasted line in the last field asks for a new line', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.enterText(find.byType(TextFormField).last, '6 dl mjölk');
      await tester.pump();

      expect(filled, 1);
    });

    testWidgets('a pasted line in an earlier field asks for nothing', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.enterText(find.byType(TextFormField).first, '6 dl mjölk');
      await tester.pump();

      expect(filled, 0);
    });

    testWidgets('"Lägg till ingrediens" adds a line', (tester) async {
      await tester.pumpWidget(build());

      await tester.tap(find.text('Lägg till ingrediens'));
      await tester.pump();

      expect(adds, 1);
    });

    testWidgets('a line keeps its length limit, without a counter', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.enterText(find.byType(TextFormField).first, 'x' * 600);
      await tester.pump();

      expect(controllers.first.text.length, 500);
      expect(find.textContaining('/500'), findsNothing);
    });

    testWidgets('a heading keeps its length limit', (tester) async {
      final heading = TextEditingController();
      addTearDown(heading.dispose);
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: SectionedIngredientListBuilder(
            label: 'Ingrediens',
            rows: const [HeadingRow('h1'), LineRow(), LineRow()],
            lineControllers: controllers,
            headingControllerFor: (_) => heading,
            onLineChanged: (_, __) {},
            onAddLine: () {},
            onLastLineFilled: () {},
            onRemoveLine: (_) {},
            onReorder: (_, __) {},
            onAddHeading: () {},
            onRemoveHeading: (_) {},
            onMoveLineToSection: (_, __) {},
            canAddHeading: true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'x' * 100);
      await tester.pump();

      expect(heading.text.length, IngredientSectionState.maxHeadingLength);
    });
  });

  group('DynamicListBuilder', () {
    late List<TextEditingController> controllers;
    late int filled;
    late int adds;

    setUp(() {
      controllers = [TextEditingController()];
      filled = 0;
      adds = 0;
    });

    tearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    Widget build() => createLocalizedTestApp(
      wrapInScrollView: true,
      child: DynamicListBuilder(
        label: 'Instruktion',
        controllers: controllers,
        onUpdate: (_, __) {},
        onAdd: () => adds++,
        onLastFilled: () => filled++,
        onRemove: (_) {},
        onReorder: (_, __) {},
      ),
    );

    testWidgets('a pasted step in the last field asks for a new line', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.enterText(
        find.byType(TextFormField),
        'Koka upp mjölken och rör ner mjölet.',
      );
      await tester.pump();

      expect(filled, 1);
    });

    testWidgets('"Lägg till instruktion" shows with rows and adds a line', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.tap(find.text('Lägg till instruktion'));
      await tester.pump();

      expect(adds, 1);
    });

    for (final reorderable in [true, false]) {
      testWidgets(
        'each step has a remove button that removes that step'
        '${reorderable ? '' : ' (not reorderable)'}',
        (tester) async {
          final handle = tester.ensureSemantics();
          final two = [TextEditingController(), TextEditingController()];
          addTearDown(() {
            for (final c in two) {
              c.dispose();
            }
          });
          final removed = <int>[];
          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScrollView: true,
              child: DynamicListBuilder(
                label: 'Instruktion',
                controllers: two,
                onUpdate: (_, __) {},
                onAdd: () {},
                onLastFilled: () {},
                onRemove: removed.add,
                onReorder: reorderable ? (_, __) {} : null,
              ),
            ),
          );

          final remove = find.semantics.byLabel(RegExp('Ta bort Instruktion'));
          expect(remove, findsNWidgets(2));

          tester.semantics.tap(remove.first);
          await tester.pump();
          expect(removed, [0]);

          tester.semantics.tap(remove.last);
          await tester.pump();
          expect(removed, [0, 1]);
          handle.dispose();
        },
      );
    }

    testWidgets('a lone step has no remove button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(build());

      expect(
        find.semantics.byLabel(RegExp('Ta bort Instruktion')),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('a step keeps its length limit, without a counter', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.enterText(find.byType(TextFormField), 'x' * 600);
      await tester.pump();

      expect(controllers.first.text.length, 500);
      expect(find.textContaining('/500'), findsNothing);
    });

    // BUT-2455: a step an import cut in two is joined back from the form.
    for (final reorderable in [true, false]) {
      testWidgets(
        'a merge link sits under every step but the last'
        '${reorderable ? '' : ' (not reorderable)'}',
        (tester) async {
          final handle = tester.ensureSemantics();
          final three = [
            TextEditingController(text: 'Smält smöret.'),
            TextEditingController(),
            TextEditingController(text: 'Servera.'),
          ];
          addTearDown(() {
            for (final c in three) {
              c.dispose();
            }
          });
          final merged = <int>[];
          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScrollView: true,
              child: DynamicListBuilder(
                label: 'Instruktion',
                controllers: three,
                onUpdate: (_, __) {},
                onAdd: () {},
                onLastFilled: () {},
                onRemove: (_) {},
                onReorder: reorderable ? (_, __) {} : null,
                onMergeWithNext: merged.add,
              ),
            ),
          );

          expect(find.text('Slå ihop med nästa'), findsNWidgets(2));
          expect(
            find.semantics.byLabel('Slå ihop steg 2 med steg 3'),
            findsOneWidget,
          );
          expect(
            find.semantics.byLabel('Slå ihop steg 3 med steg 4'),
            findsNothing,
          );

          tester.semantics.tap(
            find.semantics.byLabel('Slå ihop steg 2 med steg 3'),
          );
          await tester.pump();
          expect(merged, [1]);
          handle.dispose();
        },
      );
    }

    testWidgets('no merge link above the empty last line', (tester) async {
      final lines = [
        TextEditingController(text: 'Stek löken.'),
        TextEditingController(text: 'Servera.'),
        TextEditingController(),
      ];
      addTearDown(() {
        for (final c in lines) {
          c.dispose();
        }
      });
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: DynamicListBuilder(
            label: 'Instruktion',
            controllers: lines,
            onUpdate: (_, __) {},
            onAdd: () {},
            onLastFilled: () {},
            onRemove: (_) {},
            onMergeWithNext: (_) {},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('step-merge-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('step-merge-1')), findsNothing);
    });

    testWidgets('no merge link without a merge callback', (tester) async {
      controllers.add(TextEditingController(text: 'Servera.'));
      await tester.pumpWidget(build());

      expect(find.text('Slå ihop med nästa'), findsNothing);
    });
  });
}
