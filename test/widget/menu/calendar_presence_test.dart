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

Widget _dayCell(
  WeeklyMenuPlanViewModel vm,
  List<HouseholdRosterMember> roster,
) {
  final plan = _emptyPlan();
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
}
