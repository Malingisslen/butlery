// The one-time code field: one logical field behind six boxes, so a code
// can be pasted or autofilled whole and is read as one field (inmatningsfält
// riktning A, del 4 "Kodfält"; Grafisk manual v6:587).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/butlery_code_field.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  TextEditingController controller, {
  bool hasError = false,
  FocusNode? focusNode,
  ValueChanged<String>? onSubmitted,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ButleryCodeField(
            controller: controller,
            label: 'Sexsiffrig kod',
            hasError: hasError,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    ),
  );
}

/// The edge of every box, in order.
List<BorderSide> _edges(WidgetTester tester, Color fill) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.color == fill)
    .map((d) => (d.border! as Border).top)
    .toList();

/// The focus rings drawn around a box.
Iterable<BoxDecoration> _rings(WidgetTester tester, ColorScheme cs) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .where(
      (d) =>
          d.border is Border &&
          (d.border! as Border).top.color ==
              AppModeColors.focusRing(cs.brightness),
    );

void main() {
  testWidgets('a pasted code lands whole, one digit per box', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, AppTheme.lightTheme, controller);

    await tester.enterText(find.byType(ButleryCodeField), '482913');
    await tester.pump();

    expect(controller.text, '482913');
    for (final digit in ['4', '8', '2', '9', '1', '3']) {
      expect(find.text(digit), findsOneWidget);
    }
  });

  testWidgets('keeps only digits, at most six, without a counter', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, AppTheme.lightTheme, controller);

    await tester.enterText(find.byType(ButleryCodeField), '48 29-13 77');
    await tester.pump();

    expect(controller.text, '482913');
    expect(find.textContaining('/6'), findsNothing);
  });

  testWidgets('asks for the number keyboard and one-time code autofill', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, AppTheme.lightTheme, controller);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofillHints, [AutofillHints.oneTimeCode]);
  });

  testWidgets('a screen reader meets one text field named by the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController(text: '482');
    addTearDown(controller.dispose);
    await _pump(tester, AppTheme.lightTheme, controller);

    final fields = find.semantics.byPredicate(
      (node) => node.getSemanticsData().flagsCollection.isTextField,
    );
    expect(fields, findsOne);
    expect(
      fields.evaluate().single.getSemanticsData().label,
      contains('Sexsiffrig kod'),
    );
    // The digits are read as the field's value, not again from the boxes.
    expect(find.bySemanticsLabel('4'), findsNothing);
    handle.dispose();
  });

  testWidgets('submitting the field hands over the code', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await _pump(
      tester,
      AppTheme.lightTheme,
      controller,
      onSubmitted: (v) => submitted = v,
    );

    await tester.enterText(find.byType(ButleryCodeField), '482913');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(submitted, '482913');
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('ButleryCodeField, $mode', () {
      testWidgets('six boxes with the resting edge on the field paper', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await _pump(tester, theme, controller);

        final edges = _edges(tester, cs.surface);
        expect(edges, hasLength(ButleryCodeField.length));
        for (final edge in edges) {
          expect(edge.color, cs.outline);
          expect(edge.width, AppDimensions.borderWidthStandard);
        }
        expect(
          tester.getSize(find.byType(ButleryCodeField)).height,
          greaterThanOrEqualTo(ButleryCodeField.boxHeight),
        );
      });

      testWidgets('an error draws every box with the error edge', (
        tester,
      ) async {
        final controller = TextEditingController(text: '12');
        addTearDown(controller.dispose);
        await _pump(tester, theme, controller, hasError: true);

        final edges = _edges(tester, cs.surface);
        expect(edges, hasLength(ButleryCodeField.length));
        for (final edge in edges) {
          expect(edge.color, cs.error);
          expect(edge.width, AppDimensions.borderWidthOutlinedEdge);
        }
      });

      testWidgets('with focus the ring marks the box the next digit goes '
          'into, and the box edge stays as it was', (tester) async {
        final controller = TextEditingController(text: '482');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await _pump(tester, theme, controller, focusNode: focus);

        expect(_rings(tester, cs), isEmpty);

        focus.requestFocus();
        await tester.pump();

        final ring = _rings(tester, cs).single;
        expect(
          (ring.border! as Border).top.width,
          AppDimensions.focusRingWidth,
        );
        // The ring stands around the fourth box, the first empty one.
        final ringBox = find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration == ring,
        );
        final boxes = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == cs.surface,
        );
        final fourth = tester.getRect(boxes.at(3));
        expect(
          tester.getRect(ringBox),
          fourth.inflate(AppDimensions.focusRingOffset),
        );
        for (final edge in _edges(tester, cs.surface)) {
          expect(edge.color, cs.outline);
          expect(edge.width, AppDimensions.borderWidthStandard);
        }
      });

      testWidgets('with a whole code the ring rests on the last box',
          (tester) async {
        final controller = TextEditingController(text: '482913');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await _pump(tester, theme, controller, focusNode: focus);
        focus.requestFocus();
        await tester.pump();

        final ring = _rings(tester, cs).single;
        final ringBox = find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration == ring,
        );
        final boxes = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == cs.surface,
        );
        expect(
          tester.getRect(ringBox),
          tester.getRect(boxes.at(5)).inflate(AppDimensions.focusRingOffset),
        );
      });
    });
  }
}
