/// The week table fits a narrow phone with a household's presence marks.
///
/// A meal not everyone is home for carries a person and a count in the corner
/// of its cell (B-40: faces live in the sheet). This pumps the whole
/// [CalendarWeekTable] at phone widths with the real ButlerySans (the test
/// font draws every glyph one em wide), at normal and large text, with a
/// household of two and of five, in Swedish and English, and expects no
/// layout exception.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

class _FakeEntry extends Fake implements WeeklyMenuPlanEntry {}

Future<void> _loadButlerySans() async {
  final loader = FontLoader('ButlerySans');
  for (final face in ['Regular', 'Semibold', 'Bold']) {
    final bytes = File(
      'assets/fonts/ButlerySans-0.626-$face.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

final _pair = [
  HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Malin'),
  HouseholdRosterMember.fromUser(userId: 'g1', displayName: 'Mormor'),
];

final _five = [
  ..._pair,
  HouseholdRosterMember.fromUser(userId: 'g2', displayName: 'Morfar'),
  HouseholdRosterMember.fromUser(userId: 'k1', displayName: 'Alexandra'),
  HouseholdRosterMember.fromUser(userId: 'k2', displayName: 'Bertil'),
];

WeeklyMenuPlan _plan({required bool nobodyHome}) => WeeklyMenuPlan(
  id: 'u1_2026-W16',
  userId: 'u1',
  weekStartDate: DateTime.utc(2026, 4, 13),
  entries: [
    for (final day in DayOfWeek.values)
      for (final slot in [MealSlot.lunch, MealSlot.middag, MealSlot.ovrigt])
        WeeklyMenuPlanEntry.create(
          day: day,
          slot: slot,
          recipeId: 'r-${day.name}-${slot.name}',
          recipeTitle: 'Kräm sig svamp pasta med grön ärtsås',
        ),
  ],
  createdAt: DateTime.utc(2026, 4, 13),
  updatedAt: DateTime.utc(2026, 4, 13),
  presenceBySlot: nobodyHome
      ? {
          for (final day in DayOfWeek.values)
            day: const {MealSlot.lunch: [], MealSlot.middag: []},
        }
      : {
          for (final day in DayOfWeek.values)
            day: const {
              MealSlot.lunch: ['u1'],
              MealSlot.middag: ['u1'],
            },
        },
);

Future<void> _pumpWeek(
  WidgetTester tester, {
  required double width,
  required List<HouseholdRosterMember> roster,
  String locale = 'sv',
  bool nobodyHome = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final vm = _MockVm();
  when(() => vm.selectionMode).thenReturn(false);
  when(() => vm.isRecentlyPlaced(any())).thenReturn(true);
  when(() => vm.isSelected(any())).thenReturn(false);
  when(() => vm.isAllergenUnsafe(any())).thenReturn(true);
  when(() => vm.placementOrderOf(any())).thenReturn(null);
  when(() => vm.entryTitle(any())).thenAnswer(
    (i) => (i.positionalArguments.first as WeeklyMenuPlanEntry).recipeTitle,
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CalendarWeekTable(
            vm: vm,
            plan: _plan(nobodyHome: nobodyHome),
            todayIndex: 0,
            roster: roster,
            onTapEmptySlot: (_, _) {},
            onTapRecipe: (_, {presentServings}) {},
            onTapOvrigt: (_) {},
            onTapPresence: (_, _) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeEntry()));

  setUpAll(_loadButlerySans);

  for (final width in [320.0, 360.0]) {
    for (final locale in ['sv', 'en']) {
      for (final textScale in [1.0, 1.6, 2.0]) {
        for (final (roster, nobodyHome) in [
          (_pair, true),
          (_pair, false),
          (_five, false),
        ]) {
          final who = nobodyHome ? 'nobody home' : 'some of ${roster.length}';
          testWidgets(
            'the full week with every mark fits at $width dp '
            '($locale, text x$textScale, $who)',
            (tester) async {
              await _pumpWeek(
                tester,
                width: width,
                roster: roster,
                locale: locale,
                nobodyHome: nobodyHome,
                textScale: textScale,
              );

              expect(tester.takeException(), isNull);
              // The marks really rendered: without them this proves nothing.
              expect(find.byKey(CalendarPresenceMark.markKey), findsWidgets);
            },
          );
        }
      }
    }
  }
}
