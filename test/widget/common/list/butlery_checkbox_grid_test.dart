// The checkbox grid draws a chosen word with a tick, never a colour alone,
// and reads as a checked box to a screen reader.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    bool ticked(Finder within) => tester
        .widgetList<Checkbox>(
          find.descendant(of: within, matching: find.byType(Checkbox)),
        )
        .single
        .value!;

    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .where((box) => box.value == true),
      hasLength(1),
    );
    expect(
      ticked(
        find.ancestor(of: find.text('Mjölk'), matching: find.byType(InkWell)),
      ),
      isTrue,
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

  group('columns', () {
    Future<void> pumpWords(
      WidgetTester tester, {
      required double width,
      double textScale = 1,
    }) {
      return tester.pumpWidget(
        createLocalizedTestApp(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Center(
              child: SizedBox(
                width: width,
                child: ButleryCheckboxGrid(
                  options: const {'a': 'Kosheranpassad', 'b': 'Ägg'},
                  isSelected: (_) => false,
                  onToggle: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('two columns while the longest word fits one', (tester) async {
      await pumpWords(tester, width: 700);

      expect(
        tester.getTopLeft(find.text('Kosheranpassad')).dy,
        tester.getTopLeft(find.text('Ägg')).dy,
      );
    });

    testWidgets('one column once the longest word would be broken', (
      tester,
    ) async {
      await pumpWords(tester, width: 300, textScale: 2);

      expect(
        tester.getTopLeft(find.text('Kosheranpassad')).dy,
        lessThan(tester.getTopLeft(find.text('Ägg')).dy),
      );
    });
  });
}
