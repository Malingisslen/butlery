/// The line under the week table names only the marks the week shows: the
/// new dot, the allergen warning and the "not everyone is home" mark each
/// follow their own flag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

class _FakeEntry extends Fake implements WeeklyMenuPlanEntry {}

final _sv = AppLocalizationsSv();

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

  final roster = [
    HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Malin'),
    HouseholdRosterMember.fromUser(userId: 'g1', displayName: 'Mormor'),
  ];

  WeeklyMenuPlan plan({
    Map<DayOfWeek, Map<MealSlot, List<String>>>? presence,
  }) => WeeklyMenuPlan(
    id: 'u1_2026-W16',
    userId: 'u1',
    weekStartDate: DateTime.utc(2026, 4, 13),
    entries: [
      WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r1',
        recipeTitle: 'Köttbullar',
      ),
    ],
    createdAt: DateTime.utc(2026, 4, 13),
    updatedAt: DateTime.utc(2026, 4, 13),
    presenceBySlot: presence ?? const {},
  );

  Future<void> pump(WidgetTester tester, WeeklyMenuPlan plan) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarWeekTable(
              vm: vm,
              plan: plan,
              todayIndex: -1,
              onTapEmptySlot: (_, _) {},
              onTapRecipe: (_, {presentServings}) {},
              onTapOvrigt: (_) {},
              roster: roster,
              onTapPresence: (_, _) {},
            ),
          ),
        ),
      ),
    );
    // Premise for every case: the dish is on screen.
    expect(find.text('Köttbullar'), findsOneWidget);
  }

  testWidgets('a week with no marks has no legend', (tester) async {
    await pump(tester, plan());

    expect(find.byKey(CalendarLegend.legendKey), findsNothing);
  });

  testWidgets('a new dish adds "ny" and nothing else', (tester) async {
    when(() => vm.isRecentlyPlaced(any())).thenReturn(true);
    await pump(tester, plan());

    expect(find.text(_sv.weeklyMenuLegendNew), findsOneWidget);
    expect(find.text(_sv.weeklyMenuLegendAllergen), findsNothing);
    expect(find.text(_sv.weeklyMenuLegendPresence), findsNothing);
    expect(find.byKey(CalendarNewDot.dotKey), findsOneWidget);
  });

  testWidgets('an unsafe dish adds the allergen entry and nothing else', (
    tester,
  ) async {
    when(() => vm.isAllergenUnsafe(any())).thenReturn(true);
    await pump(tester, plan());

    expect(find.text(_sv.weeklyMenuLegendAllergen), findsOneWidget);
    expect(find.text(_sv.weeklyMenuLegendNew), findsNothing);
    expect(find.text(_sv.weeklyMenuLegendPresence), findsNothing);
  });

  testWidgets('a meal with only some home adds the presence entry and '
      'nothing else', (tester) async {
    await pump(
      tester,
      plan(
        presence: {
          DayOfWeek.mon: {
            MealSlot.middag: ['g1'],
          },
        },
      ),
    );

    expect(find.text(_sv.weeklyMenuLegendPresence), findsOneWidget);
    expect(find.text(_sv.weeklyMenuLegendNew), findsNothing);
    expect(find.text(_sv.weeklyMenuLegendAllergen), findsNothing);
  });
}
