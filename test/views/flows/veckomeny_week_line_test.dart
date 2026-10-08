/// The line under "Veckomeny" on the root bar counts the dishes SAVED in the
/// week (Skarmar v12 del 1 #veckomeny "Vecka 28 · 5 rätter", #tomvecka
/// "Vecka 28 · inget planerat").
///
/// The two-device run on 2026-10-08 found it saying "inget planerat" over a
/// week with seven dishes: it counted only the menu generated in this
/// session, which a week saved on another device or in an earlier session
/// never has.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/persistence_service.dart';

import 'veckomeny_flow_harness.dart';

final _sv = AppLocalizationsSv();

void main() {
  late VeckomenyFlowHarness h;
  final week = IsoWeekUtils.isoWeekNumber(flowMonday);

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> openOnMonday(WidgetTester tester) =>
      withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await tester.pumpAndSettle();
      });

  testWidgets('a saved week of seven dishes says so, in Kalender', (
    tester,
  ) async {
    h.seedWeek(7);
    await openOnMonday(tester);

    expect(find.text(_sv.menuWeekBadgeWithCount(week, 7)), findsOneWidget);
    expect(find.text(_sv.menuWeekBadgeEmpty(week)), findsNothing);
  });

  testWidgets('a saved week says so in Lista too, where nothing was '
      'generated', (tester) async {
    await PersistenceService().setVeckomenyViewMode('lista');
    h.seedWeek(7);
    await openOnMonday(tester);

    expect(find.text(_sv.menuWeekBadgeWithCount(week, 7)), findsOneWidget);
  });

  testWidgets('one dish is "1 rätt"', (tester) async {
    h.seedWeek(1);
    await openOnMonday(tester);

    expect(find.text('Vecka $week · 1 rätt'), findsOneWidget);
  });

  testWidgets('a week with nothing saved says "inget planerat"', (
    tester,
  ) async {
    await openOnMonday(tester);

    expect(find.text(_sv.menuWeekBadgeEmpty(week)), findsOneWidget);
  });

  testWidgets('a generated menu not yet placed is not planned', (
    tester,
  ) async {
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2), flowDinner(3)],
    };
    await withClock(Clock.fixed(flowMonday), () async {
      await h.pump(tester);
      await tester.pumpAndSettle();
      await h.generate(tester, 'tre middagar');
      await tester.pumpAndSettle();
    });

    expect(find.text('Middag 1'), findsOneWidget);
    expect(find.text(_sv.menuWeekBadgeEmpty(week)), findsOneWidget);
  });

  testWidgets('a week that could not be read claims no count', (tester) async {
    await PersistenceService().setVeckomenyViewMode('kalender');
    h.seedWeek(7);
    h.repository.fetchError = StateError('unreachable');
    await openOnMonday(tester);

    expect(find.text(_sv.menuWeekBadgeOnly(week)), findsOneWidget);
    expect(find.text(_sv.menuWeekBadgeEmpty(week)), findsNothing);
  });
}
