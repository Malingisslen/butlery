/// Ingredient sections (PR #211) — the sectioned editor widget.
///
/// Covers the visible contract: heading rows carry Semantics(header: true)
/// (criterion 11, the form surface), the heading delete announces the
/// heading-specific label (not the ingredient-delete one), the
/// "Lägg till rubrik" button appears, and the non-drag "Flytta till rubrik"
/// affordance shows only once a heading exists (criterion 12). Interaction
/// wiring (reorder → callback) is proven at the model level
/// (ingredient_section_state_test.dart); this is the render/a11y layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/recipe_form/ingredient_section_state.dart';
import 'package:butlery/widgets/recipe/recipe_form/sectioned_ingredient_list_builder.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late TextEditingController line1;
  late TextEditingController line2;
  late TextEditingController heading;

  setUp(() {
    line1 = TextEditingController(text: '5 dl vetemjöl');
    line2 = TextEditingController(text: '75 g smör');
    heading = TextEditingController(text: 'Deg');
  });

  tearDown(() {
    line1.dispose();
    line2.dispose();
    heading.dispose();
  });

  Widget build({
    required List<IngredientRow> rows,
    required List<TextEditingController> lineControllers,
    bool canAddHeading = true,
  }) => createLocalizedTestApp(
    wrapInScrollView: true,
    child: SectionedIngredientListBuilder(
      label: 'Ingrediens',
      rows: rows,
      lineControllers: lineControllers,
      headingControllerFor: (_) => heading,
      onLineChanged: (_, __) {},
      onAddLine: () {},
      onRemoveLine: (_) {},
      onReorder: (_, __) {},
      onAddHeading: () {},
      onRemoveHeading: (_) {},
      onMoveLineToSection: (_, __) {},
      canAddHeading: canAddHeading,
    ),
  );

  testWidgets('heading row carries Semantics(header: true)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow(), LineRow()],
        lineControllers: [line1, line2],
      ),
    );

    // The heading field shows the label; its row is flagged as a header.
    final headingField = find.widgetWithText(TextField, 'Deg');
    expect(headingField, findsOneWidget);
    final headerNode = find.ancestor(
      of: headingField,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.header ?? false),
      ),
    );
    expect(headerNode, findsOneWidget);
    handle.dispose();
  });

  testWidgets('heading delete announces the heading-specific label', (
    tester,
  ) async {
    // bySemanticsLabel requires the semantics tree to be enabled; enable it
    // here rather than relying on a preceding test leaving it on (that made
    // this test order-dependent and flaky in isolation).
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow(), LineRow()],
        lineControllers: [line1, line2],
      ),
    );
    // "Ta bort rubrik" (remove heading), NOT the ingredient delete. Match by
    // regex: the node label merges the wrapping Semantics(label:) with the
    // IconButton tooltip, so an exact-string match is frame-timing brittle.
    expect(find.bySemanticsLabel(RegExp('Ta bort rubrik')), findsWidgets);
    handle.dispose();
  });

  testWidgets('"Lägg till rubrik" button is shown', (tester) async {
    await tester.pumpWidget(
      build(
        rows: const [LineRow()],
        lineControllers: [line1],
      ),
    );
    expect(find.text('Lägg till rubrik'), findsOneWidget);
  });

  testWidgets('move-to-section menu appears only when a heading exists', (
    tester,
  ) async {
    // No heading → no "Flytta till rubrik" affordance.
    await tester.pumpWidget(
      build(
        rows: const [LineRow(), LineRow()],
        lineControllers: [line1, line2],
      ),
    );
    expect(find.byTooltip('Flytta till rubrik'), findsNothing);

    // With a heading → the affordance appears on the line rows.
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow(), LineRow()],
        lineControllers: [line1, line2],
      ),
    );
    expect(find.byTooltip('Flytta till rubrik'), findsWidgets);
  });

  testWidgets('renders line rows with their text', (tester) async {
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow(), LineRow()],
        lineControllers: [line1, line2],
      ),
    );
    expect(find.widgetWithText(TextFormField, '5 dl vetemjöl'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '75 g smör'), findsOneWidget);
  });
}
