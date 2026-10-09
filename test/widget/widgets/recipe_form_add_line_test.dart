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
  });
}
