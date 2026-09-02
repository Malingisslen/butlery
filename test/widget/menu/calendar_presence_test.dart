/// BUT-1611 widget tests: the per-meal presence faces row on a calendar
/// [DayCell]. Proves the two invariants the unit tests can't see:
///   - a household with family renders a tappable presence row (with faces)
///     under each of the day's lunch + middag cells;
///   - a solo account (roster ≤ 1) renders no presence UI at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

HouseholdRosterMember _member(String id, String name) =>
    HouseholdRosterMember.fromUser(userId: id, displayName: name);

WeeklyMenuPlan _emptyPlan() => WeeklyMenuPlan(
  id: 'u1_2026-W16',
  userId: 'u1',
  weekStartDate: DateTime.utc(2026, 4, 13),
  entries: const [],
  createdAt: DateTime.utc(2026, 4, 13),
  updatedAt: DateTime.utc(2026, 4, 13),
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// BUT-1991: a week with a dish actually placed.
///
/// The empty fixture above cannot reach `_AssignedSlot`, so the branch that
/// unbounded the cell's height was invisible to every test in this file.
WeeklyMenuPlan _plannedPlan() => _emptyPlan().copyWith(
  entries: [
    WeeklyMenuPlanEntry.create(
      day: DayOfWeek.mon,
      slot: MealSlot.lunch,
      recipeId: 'r1',
      recipeTitle: 'Pannkakor',
    ),
    WeeklyMenuPlanEntry.create(
      day: DayOfWeek.mon,
      slot: MealSlot.middag,
      recipeId: 'r2',
      recipeTitle: 'Köttbullar',
    ),
  ],
);

Widget _dayCell(
  WeeklyMenuPlanViewModel vm,
  List<HouseholdRosterMember> roster, {
  WeeklyMenuPlan? plan,
}) {
  plan ??= _emptyPlan();
  return _host(
    DayCell(
      vm: vm,
      plan: plan,
      day: DayOfWeek.mon,
      isToday: false,
      onTapEmptySlot: (_, _) {},
      onTapRecipe: (_, {presentServings}) {},
      roster: roster,
      onTapPresence: (_, _) {},
    ),
  );
}

void main() {
  late _MockVm vm;

  setUp(() {
    vm = _MockVm();
    when(() => vm.selectionMode).thenReturn(false);
  });

  testWidgets('a household with family shows a presence row on both meals', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Malin'), _member('g1', 'Mormor')]),
    );

    // One presence row per real meal slot (lunch + middag), each a tappable
    // "who's home" target with its own semantics label.
    expect(find.bySemanticsLabel(RegExp('är hemma')), findsNWidgets(2));
    // Everyone home by default → both members' faces render on both slots.
    expect(find.byType(FamilyAvatar), findsNWidgets(4));
    handle.dispose();
  });

  testWidgets('a solo account shows no presence UI', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_dayCell(vm, [_member('u1', 'Malin')]));

    expect(find.bySemanticsLabel(RegExp('är hemma')), findsNothing);
    expect(find.byType(FamilyAvatar), findsNothing);
    handle.dispose();
  });

  // BUT-1991. The presence row is the variable, not the dish: only when the
  // roster is > 1 does `_SingleSlotCell` add the wrapping Column, and only then
  // does the dish cell's own `Expanded` face a main-axis extent nothing bounds.
  // Both cases are here because the roster-1 one is what proves the wrapper is
  // the cause rather than the dish.
  testWidgets('a household with family renders a placed dish without '
      'unbounding the cell', (tester) async {
    when(() => vm.isRecentlyPlaced(any())).thenReturn(false);
    when(() => vm.isSelected(any())).thenReturn(false);

    await tester.pumpWidget(
      _dayCell(vm, [
        _member('u1', 'Malin'),
        _member('g1', 'Mormor'),
      ], plan: _plannedPlan()),
    );

    expect(tester.takeException(), isNull);
    // Lowercased by the cell, so this also pins that the dish really rendered
    // rather than the finder matching some other node.
    expect(find.text('pannkakor'), findsOneWidget);
    expect(find.text('köttbullar'), findsOneWidget);
  });

  testWidgets('a solo account renders a placed dish (the control)', (
    tester,
  ) async {
    when(() => vm.isRecentlyPlaced(any())).thenReturn(false);
    when(() => vm.isSelected(any())).thenReturn(false);

    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Malin')], plan: _plannedPlan()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('pannkakor'), findsOneWidget);
  });
}
