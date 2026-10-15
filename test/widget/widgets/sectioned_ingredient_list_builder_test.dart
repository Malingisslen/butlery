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
import '../../test_support/semantics_announcement.dart';

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
    void Function(String id)? onRemoveHeading,
    void Function(int index)? onRemoveLine,
  }) => createLocalizedTestApp(
    wrapInScrollView: true,
    child: SectionedIngredientListBuilder(
      label: 'Ingrediens',
      rows: rows,
      lineControllers: lineControllers,
      headingControllerFor: (_) => heading,
      onLineChanged: (_, __) {},
      onAddLine: () {},
      onLastLineFilled: () {},
      onRemoveLine: onRemoveLine ?? (_) {},
      onReorder: (_, __) {},
      onAddHeading: () {},
      onRemoveHeading: onRemoveHeading ?? (_) {},
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

  testWidgets('a filled heading field is a header text field, named once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow()],
        lineControllers: [line1],
      ),
    );

    final headingNode = tester.getSemantics(
      find.widgetWithText(TextField, 'Deg'),
    );
    final data = headingNode.getSemanticsData();
    expect(data.flagsCollection.isTextField, isTrue);
    expect(data.flagsCollection.isHeader, isTrue);
    // Its text is the whole announcement: the delete button's label must not
    // bleed into the field's node.
    expect(announcedLines(tester, find.widgetWithText(TextField, 'Deg')), [
      'Deg',
    ]);

    final lineData = tester
        .getSemantics(find.widgetWithText(TextFormField, '5 dl vetemjöl'))
        .getSemanticsData();
    expect(lineData.flagsCollection.isHeader, isFalse);
    handle.dispose();
  });

  testWidgets('the heading delete is one activatable button node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? removed;
    await tester.pumpWidget(
      build(
        rows: const [HeadingRow('h0'), LineRow()],
        lineControllers: [line1],
        onRemoveHeading: (id) => removed = id,
      ),
    );

    final delete = find.bySemanticsLabel(RegExp('Ta bort rubrik'));
    expect(delete, findsOneWidget);
    expect(announcedLines(tester, delete), ['Ta bort rubrik']);
    expect(
      tester.getSemantics(delete).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    expectActivatable(tester, delete);

    tester.semantics.tap(find.semantics.byLabel(RegExp('Ta bort rubrik')));
    expect(removed, 'h0');
    handle.dispose();
  });

  testWidgets('each line delete is one activatable button node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    int? removed;
    await tester.pumpWidget(
      build(
        rows: const [LineRow(), LineRow()],
        lineControllers: [line1, line2],
        onRemoveLine: (i) => removed = i,
      ),
    );

    final delete = find.bySemanticsLabel(RegExp('Ta bort Ingrediens'));
    expect(delete, findsNWidgets(2));
    expect(announcedLines(tester, delete.first), ['Ta bort Ingrediens']);
    expectActivatable(tester, delete.first);

    tester.semantics.tap(
      find.semantics.byLabel(RegExp('Ta bort Ingrediens')).first,
    );
    expect(removed, 0);
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

  group('"Flytta till rubrik" menu reports (row index, heading id)', () {
    late TextEditingController deg;
    late TextEditingController unnamed;
    late List<(int, String?)> moves;

    const rows = [HeadingRow('h0'), LineRow(), HeadingRow('h1'), LineRow()];

    setUp(() {
      deg = TextEditingController(text: 'Deg');
      unnamed = TextEditingController();
      moves = [];
    });

    tearDown(() {
      deg.dispose();
      unnamed.dispose();
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: SectionedIngredientListBuilder(
          label: 'Ingrediens',
          rows: rows,
          lineControllers: [line1, line2],
          headingControllerFor: (id) => id == 'h0' ? deg : unnamed,
          onLineChanged: (_, __) {},
          onAddLine: () {},
          onLastLineFilled: () {},
          onRemoveLine: (_) {},
          onReorder: (_, __) {},
          onAddHeading: () {},
          onRemoveHeading: (_) {},
          onMoveLineToSection: (row, id) => moves.add((row, id)),
          canAddHeading: true,
        ),
      ),
    );

    // ButleryMenuItem subclasses PopupMenuItem; byType matches exactly.
    final menuItems = find.byWidgetPredicate((w) => w is PopupMenuItem<String>);

    Future<void> openMenuOfLine(WidgetTester tester, int lineIndex) async {
      await tester.tap(find.byTooltip('Flytta till rubrik').at(lineIndex));
      await tester.pumpAndSettle();
    }

    testWidgets('"Ingen rubrik" moves that row out of every section', (
      tester,
    ) async {
      await pump(tester);

      await openMenuOfLine(tester, 1);
      await tester.tap(find.text('Ingen rubrik'));
      await tester.pumpAndSettle();

      expect(moves, [(3, null)]);
    });

    testWidgets('a heading entry moves that row under the heading id', (
      tester,
    ) async {
      await pump(tester);

      await openMenuOfLine(tester, 0);
      await tester.tap(
        find.descendant(
          of: menuItems,
          matching: find.text('Deg'),
        ),
      );
      await tester.pumpAndSettle();

      expect(moves, [(1, 'h0')]);
    });

    testWidgets('a heading without a label is offered under the hint text', (
      tester,
    ) async {
      await pump(tester);

      await openMenuOfLine(tester, 1);
      final entry = find.descendant(
        of: menuItems,
        matching: find.text('Rubrik, till exempel Deg'),
      );
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(moves, [(3, 'h1')]);
    });

    testWidgets('the menu lists "Ingen rubrik" first, then each heading', (
      tester,
    ) async {
      await pump(tester);

      await openMenuOfLine(tester, 0);

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: menuItems,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(labels, ['Ingen rubrik', 'Deg', 'Rubrik, till exempel Deg']);
    });
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
