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
import 'package:butlery/widgets/menu/calendar/presence_overview.dart';
import '../../infrastructure/helpers/ink_fill.dart';

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

  testWidgets('household members with the same initials get distinct faces', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Maria A'), _member('g1', 'Mikael A')]),
    );

    // Two meal slots, each showing both people.
    expect(find.text('Ma'), findsNWidgets(2));
    expect(find.text('Mi'), findsNWidgets(2));
    expect(find.text('MA'), findsNothing);
  });

  testWidgets('a slot with only one of two same-initial members home still '
      'shows the distinct initials', (tester) async {
    final plan = _emptyPlan().copyWith(
      presenceBySlot: {
        DayOfWeek.mon: {
          MealSlot.lunch: ['g1'],
        },
      },
    );
    await tester.pumpWidget(
      _dayCell(vm, [
        _member('u1', 'Maria A'),
        _member('g1', 'Mikael A'),
      ], plan: plan),
    );

    // Lunch shows Mikael alone; middag shows both (no explicit selection).
    expect(find.text('Mi'), findsNWidgets(2));
    expect(find.text('Ma'), findsOneWidget);
    expect(find.text('M'), findsNothing);
    expect(find.text('MI'), findsNothing);
    expect(find.text('MA'), findsNothing);
  });

  testWidgets('the expanded week overview gives same-initial members '
      'distinct faces', (tester) async {
    await tester.pumpWidget(
      _host(
        PresenceOverview(
          roster: [_member('u1', 'Maria A'), _member('g1', 'Mikael A')],
          plan: _emptyPlan(),
          expanded: true,
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(find.text('Ma'), findsOneWidget);
    expect(find.text('Mi'), findsOneWidget);
    expect(find.text('MA'), findsNothing);
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

  // BUT-2205: the row's own fill used to sit above the ink layer, so a
  // pressed presence row showed nothing.
  testWidgets('a pressed presence row shows surface.raised', (tester) async {
    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Malin'), _member('g1', 'Mormor')]),
    );
    final face = find.byType(FamilyAvatar).first;
    expect(pressIsCovered(tester, face), isFalse);
    expect(borderIsAbovePress(tester, face), isTrue);
    final gesture = await holdPress(tester, face);
    expect(
      paintsInkFill(
        tester,
        face,
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      ),
      isTrue,
    );
    await gesture.cancel();
  });
}
