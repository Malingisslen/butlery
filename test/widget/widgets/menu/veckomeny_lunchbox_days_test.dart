import 'dart:ui' show Tristate;

// BUT-2486 part 6: the weekday chips that say where lunchboxes are wanted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/widgets/menu/veckomeny_lunchbox_days.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Finder _chip(DayOfWeek day) => find.byKey(ValueKey('lunchbox-day-${day.name}'));

Finder _filterChip(DayOfWeek day) =>
    find.descendant(of: _chip(day), matching: find.byType(FilterChip));

Future<void> _pump(
  WidgetTester tester, {
  required Set<DayOfWeek> selected,
  required ValueChanged<DayOfWeek> onToggle,
}) => tester.pumpWidget(
  createLocalizedTestApp(
    child: VeckomenyLunchboxDays(selected: selected, onToggle: onToggle),
  ),
);

void main() {
  testWidgets('shows one chip for every weekday', (tester) async {
    await _pump(tester, selected: const {}, onToggle: (_) {});

    for (final day in DayOfWeek.values) {
      expect(_chip(day), findsOneWidget, reason: day.name);
    }
    expect(find.byType(FilterChip), findsNWidgets(7));
  });

  testWidgets('tapping a chip reports exactly that day', (tester) async {
    final toggled = <DayOfWeek>[];
    await _pump(tester, selected: const {}, onToggle: toggled.add);

    await tester.tap(_chip(DayOfWeek.thu));
    await tester.pump();

    expect(toggled, [DayOfWeek.thu]);

    await tester.tap(_chip(DayOfWeek.sun));
    await tester.pump();

    expect(toggled, [DayOfWeek.thu, DayOfWeek.sun]);
  });

  testWidgets('only the days in selected read as selected', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        selected: const {DayOfWeek.mon, DayOfWeek.fri},
        onToggle: (_) {},
      );

      for (final day in DayOfWeek.values) {
        final on = tester
            .getSemantics(_filterChip(day))
            .getSemanticsData()
            .flagsCollection
            .isSelected;
        expect(
          on,
          const {DayOfWeek.mon, DayOfWeek.fri}.contains(day)
              ? Tristate.isTrue
              : Tristate.isFalse,
          reason: day.name,
        );
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('every weekday is announced by its full name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, selected: const {}, onToggle: (_) {});

      for (final name in const [
        'måndag',
        'tisdag',
        'onsdag',
        'torsdag',
        'fredag',
        'lördag',
        'söndag',
      ]) {
        expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
      }
    } finally {
      handle.dispose();
    }
  });
}
