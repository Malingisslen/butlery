/// The per-meal presence row fits its cell on a narrow phone.
///
/// Package 7 gave the row's texts the 10.5/700 size (tokens.json
/// controls.calendarPresenceRow). With overline's 1.5 px tracking the texts
/// overflowed the slot column at 320–375 dp. This pumps a whole [DayCell] at
/// phone widths with the real ButlerySans (the test font draws every glyph
/// one em wide) and a household of two, with nobody home and with everyone
/// home, in Swedish and English, and expects no layout exception.
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

class _MockVm extends Mock implements WeeklyMenuPlanViewModel {}

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

final _roster = [
  HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Malin'),
  HouseholdRosterMember.fromUser(userId: 'g1', displayName: 'Mormor'),
];

WeeklyMenuPlan _plan({required bool nobodyHome}) => WeeklyMenuPlan(
  id: 'u1_2026-W16',
  userId: 'u1',
  weekStartDate: DateTime.utc(2026, 4, 13),
  entries: const [],
  createdAt: DateTime.utc(2026, 4, 13),
  updatedAt: DateTime.utc(2026, 4, 13),
  presenceBySlot: nobodyHome
      ? const {
          DayOfWeek.mon: {MealSlot.lunch: [], MealSlot.middag: []},
        }
      : const {},
);

void main() {
  setUpAll(_loadButlerySans);

  for (final width in [320.0, 360.0]) {
    for (final locale in ['sv', 'en']) {
      for (final nobodyHome in [true, false]) {
        final who = nobodyHome ? 'nobody home' : 'everyone home';
        testWidgets('the presence row fits at $width dp ($locale, $who)', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final vm = _MockVm();
          when(() => vm.selectionMode).thenReturn(false);

          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  // The week view's layout margin: 20 at 320 dp, 24 from
                  // 360 dp (tokens.json:463-475).
                  padding: EdgeInsets.symmetric(
                    horizontal: width < 360 ? 20 : 24,
                  ),
                  child: DayCell(
                    vm: vm,
                    plan: _plan(nobodyHome: nobodyHome),
                    day: DayOfWeek.mon,
                    isToday: false,
                    onTapEmptySlot: (_, _) {},
                    onTapRecipe: (_, {presentServings}) {},
                    roster: _roster,
                    onTapPresence: (_, _) {},
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
