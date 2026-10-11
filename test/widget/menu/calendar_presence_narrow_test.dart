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
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart' show FamilyAvatar;
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
  entries: const [],
  createdAt: DateTime.utc(2026, 4, 13),
  updatedAt: DateTime.utc(2026, 4, 13),
  presenceBySlot: nobodyHome
      ? const {
          DayOfWeek.mon: {MealSlot.lunch: [], MealSlot.middag: []},
        }
      : const {},
);

Future<void> _pumpMonday(
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
          padding: EdgeInsets.symmetric(horizontal: width < 360 ? 20 : 24),
          child: DayCell(
            vm: vm,
            plan: _plan(nobodyHome: nobodyHome),
            day: DayOfWeek.mon,
            isToday: false,
            onTapEmptySlot: (_, _) {},
            onTapRecipe: (_, {presentServings}) {},
            roster: roster,
            onTapPresence: (_, _) {},
          ),
        ),
      ),
    ),
  );
}

/// The faces drawn in one of the two presence rows; "+N" in both rows
/// accounts for everyone the faces leave out, and the portion count is
/// shown whole: faces give way before the count does (decision B-40).
int _facesPerRowAccountedFor(
  WidgetTester tester,
  int household, {
  String locale = 'sv',
  bool countWhole = true,
}) {
  final portions = lookupAppLocalizations(
    Locale(locale),
  ).menuPresencePortions(household);
  final counts = find.text(portions);
  expect(counts, findsNWidgets(2));
  for (final e in countWhole ? counts.evaluate() : const <Element>[]) {
    final paragraph = e.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: portions);
  }
  final faces = find.byType(FamilyAvatar).evaluate().length;
  expect(faces, greaterThanOrEqualTo(2));
  expect(faces.isEven, isTrue);
  final perRow = faces ~/ 2;
  final rest = household - perRow;
  // One face may stand alone with the count when "+N" does not fit too.
  if (rest > 0 && perRow > 1) expect(find.text('+$rest'), findsNWidgets(2));
  return perRow;
}

void main() {
  setUpAll(_loadButlerySans);

  for (final width in [320.0, 360.0]) {
    for (final locale in ['sv', 'en']) {
      for (final (roster, nobodyHome) in [
        (_pair, true),
        (_pair, false),
        (_five, false),
      ]) {
        final who = nobodyHome ? 'nobody home' : 'all ${roster.length} home';
        testWidgets('the presence row fits at $width dp ($locale, $who)', (
          tester,
        ) async {
          await _pumpMonday(
            tester,
            width: width,
            roster: roster,
            locale: locale,
            nobodyHome: nobodyHome,
          );

          expect(tester.takeException(), isNull);
          if (roster.length > 4) {
            _facesPerRowAccountedFor(tester, 5, locale: locale);
          }
        });
      }
    }
  }

  testWidgets('five people: faces grow with the width, never past four', (
    tester,
  ) async {
    final seen = <int>[];
    for (final width in [320.0, 400.0, 440.0, 480.0, 560.0, 680.0, 1000.0]) {
      await _pumpMonday(tester, width: width, roster: _five);
      expect(tester.takeException(), isNull, reason: '$width dp');
      seen.add(_facesPerRowAccountedFor(tester, 5));
    }
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]), reason: '$seen');
    }
    // Every step from one face to four is reached, so each branch of the
    // fit runs.
    expect(seen.toSet(), {1, 2, 3, 4}, reason: '$seen');
  });

  testWidgets('five people at double text size fit, with fewer faces', (
    tester,
  ) async {
    await _pumpMonday(tester, width: 560, roster: _five);
    final atNormalSize = _facesPerRowAccountedFor(tester, 5);

    await _pumpMonday(tester, width: 560, roster: _five, textScale: 2);
    expect(tester.takeException(), isNull);
    // The doubled texts are measured at their real size, so they take room
    // from the faces.
    final atDoubleSize = _facesPerRowAccountedFor(tester, 5, countWhole: false);
    expect(atDoubleSize, lessThan(atNormalSize));

    await _pumpMonday(tester, width: 360, roster: _five, textScale: 2);
    expect(tester.takeException(), isNull);
    // At double size one face and the count are the floor; the count may
    // then be cut with an ellipsis rather than overflow.
    _facesPerRowAccountedFor(tester, 5, countWhole: false);
  });
}
