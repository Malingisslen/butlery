// The checkbox grid draws a chosen word with a tick, never a colour alone,
// and reads as a checked box to a screen reader.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_checkbox_grid.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ButleryCheckboxGrid(
          options: const {'a': 'Gluten', 'b': 'Mjölk', 'c': 'Ägg'},
          isSelected: (key) => key == 'b',
          onToggle: toggled.add,
        ),
      ),
    );
    return toggled;
  }

  testWidgets('only the chosen word carries a tick', (tester) async {
    await pump(tester);

    expect(find.byIcon(ButleryIcons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Mjölk'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(ButleryIcons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a cell is a checked or unchecked box named by its word', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    final chosen = tester
        .getSemantics(find.bySemanticsLabel('Mjölk'))
        .getSemanticsData();
    final other = tester
        .getSemantics(find.bySemanticsLabel('Gluten'))
        .getSemanticsData();
    expect(chosen.flagsCollection.isChecked, CheckedState.isTrue);
    expect(other.flagsCollection.isChecked, CheckedState.isFalse);
    handle.dispose();
  });

  testWidgets('tapping a word reports its key', (tester) async {
    final toggled = await pump(tester);

    await tester.tap(find.text('Ägg'));
    await tester.tap(find.text('Mjölk'));

    expect(toggled, ['c', 'b']);
  });
}
