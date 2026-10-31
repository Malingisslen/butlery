/// BUT-1611: presence on the calendar's week table.
/// Proves the invariants the unit tests can't see:
///   - in a household with family a dish cell opens "who is home" and says so;
///     the table draws no faces (B-40), and marks a meal only when it is not
///     everyone who is home;
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
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';
import 'package:butlery/widgets/menu/calendar/presence_overview.dart';
import '../../infrastructure/helpers/ink_fill.dart';
import '../../test_support/semantics_announcement.dart';

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

class _FakeEntry extends Fake implements WeeklyMenuPlanEntry {}

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

Widget _host(Widget child, {Locale locale = const Locale('sv')}) => MaterialApp(
  locale: locale,
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
    CalendarWeekTable(
      vm: vm,
      plan: plan,
      todayIndex: -1,
      onTapEmptySlot: (_, _) {},
      onTapRecipe: (_, {presentServings}) {},
      onTapOvrigt: (_) {},
      roster: roster,
      onTapPresence: (_, _) {},
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeEntry()));

  late _MockVm vm;

  setUp(() {
    vm = _MockVm();
    when(() => vm.selectionMode).thenReturn(false);
    when(() => vm.isRecentlyPlaced(any())).thenReturn(false);
    when(() => vm.isSelected(any())).thenReturn(false);
    when(() => vm.isAllergenUnsafe(any())).thenReturn(false);
    when(() => vm.placementOrderOf(any())).thenReturn(null);
    when(() => vm.entryTitle(any())).thenAnswer(
      (i) => (i.positionalArguments.first as WeeklyMenuPlanEntry).recipeTitle,
    );
  });

  testWidgets('a household with family opens who is home from a dish, '
      'and draws no faces', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _dayCell(vm, [
        _member('u1', 'Malin'),
        _member('g1', 'Mormor'),
      ], plan: _plannedPlan()),
    );

    // One stop per planned lunch and middag, each named by what it opens.
    expect(find.bySemanticsLabel(RegExp('är hemma')), findsNWidgets(2));
    // Everyone home is the default and says nothing: no faces, no count.
    expect(find.byType(FamilyAvatar), findsNothing);
    expect(find.byKey(CalendarPresenceMark.markKey), findsNothing);
    handle.dispose();
  });

  testWidgets(
    'an empty slot is one activatable stop that names the meal once',
    (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_dayCell(vm, [_member('u1', 'Malin')]));

      final slot = find.bySemanticsLabel(
        RegExp('^Lägg till.*lunch', caseSensitive: false),
      );
      expect(slot, findsWidgets);
      expect(announcedLines(tester, slot.first), hasLength(1));
      expectActivatable(tester, slot.first);
      handle.dispose();
    },
  );

  testWidgets('a meal with only some of the household home carries the count', (
    tester,
  ) async {
    final plan = _plannedPlan().copyWith(
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

    // Lunch has one at home; middag has no explicit selection, so no mark.
    expect(find.byKey(CalendarPresenceMark.markKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(CalendarPresenceMark.markKey),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FamilyAvatar), findsNothing);
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

  group('PresenceOverview summary', () {
    // Every slot of every day lists [home]; a member left out is away.
    WeeklyMenuPlan planWithHome(List<String> home) => _emptyPlan().copyWith(
      presenceBySlot: {
        for (final day in DayOfWeek.values)
          day: {
            MealSlot.lunch: home,
            MealSlot.middag: home,
          },
      },
    );

    Future<void> pumpSummary(
      WidgetTester tester,
      List<HouseholdRosterMember> roster,
      WeeklyMenuPlan plan, {
      Locale locale = const Locale('sv'),
    }) => tester.pumpWidget(
      _host(
        PresenceOverview(
          roster: roster,
          plan: plan,
          expanded: false,
          onToggleExpanded: () {},
        ),
        locale: locale,
      ),
    );

    final roster = [
      _member('u1', 'Malin'),
      _member('g1', 'Mormor'),
      _member('g2', 'Elias'),
    ];

    testWidgets('says everyone is home when nobody is marked away', (
      tester,
    ) async {
      await pumpSummary(tester, roster, _emptyPlan());

      expect(find.text('Alla hemma hela veckan'), findsOneWidget);
    });

    testWidgets('names one member who is away', (tester) async {
      await pumpSummary(tester, roster, planWithHome(['u1', 'g2']));

      expect(find.text('Mormor borta delar av veckan'), findsOneWidget);
    });

    testWidgets('joins two members who are away with "och"', (tester) async {
      await pumpSummary(tester, roster, planWithHome(['g2']));

      expect(
        find.text('Malin och Mormor borta delar av veckan'),
        findsOneWidget,
      );
    });

    testWidgets('joins the names with "and" in English (BUT-2392)', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        roster,
        planWithHome(['nobody']),
        locale: const Locale('en'),
      );

      expect(
        find.text('Malin, Mormor and Elias away part of the week'),
        findsOneWidget,
      );
    });

    testWidgets('joins three members who are away with commas and "och"', (
      tester,
    ) async {
      await pumpSummary(tester, roster, planWithHome(['nobody']));

      expect(
        find.text('Malin, Mormor och Elias borta delar av veckan'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a solo account shows no presence UI', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Malin')], plan: _plannedPlan()),
    );

    expect(find.bySemanticsLabel(RegExp('är hemma')), findsNothing);
    expect(find.byType(FamilyAvatar), findsNothing);
    expect(find.byKey(CalendarPresenceMark.markKey), findsNothing);
    handle.dispose();
  });

  // BUT-1991: a household with family renders a placed dish in a bounded
  // cell. The case is what proves a family household lays out at all.
  testWidgets('a household with family renders a placed dish without '
      'unbounding the cell', (tester) async {
    await tester.pumpWidget(
      _dayCell(vm, [
        _member('u1', 'Malin'),
        _member('g1', 'Mormor'),
      ], plan: _plannedPlan()),
    );

    expect(tester.takeException(), isNull);
    // This also pins that the dish really rendered rather than the finder
    // matching some other node.
    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text('Köttbullar'), findsOneWidget);
  });

  testWidgets('a solo account renders a placed dish (the control)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dayCell(vm, [_member('u1', 'Malin')], plan: _plannedPlan()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pannkakor'), findsOneWidget);
  });

  // BUT-2205: the cell's own fill used to sit above the ink layer, so a
  // pressed cell showed nothing.
  testWidgets('a pressed dish cell shows surface.raised', (tester) async {
    await tester.pumpWidget(
      _dayCell(vm, [
        _member('u1', 'Malin'),
        _member('g1', 'Mormor'),
      ], plan: _plannedPlan()),
    );
    final cell = find.text('Pannkakor');
    expect(pressIsCovered(tester, cell), isFalse);
    expect(borderIsAbovePress(tester, cell), isTrue);
    final gesture = await holdPress(tester, cell);
    expect(
      paintsInkFill(
        tester,
        cell,
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      ),
      isTrue,
    );
    await gesture.cancel();
  });
}
