/// P8-U03 · flow 01, the week menu transitions that only the view decides
/// and that had no test (flows-roles-budget.md:24-38; fas2/block288-
/// uxfrysning.json overgangar; fas2/ux-beslut.json D-03 and D-04).
///
/// - TR::FLOW::01::tom-vecka::generera: an empty week, Generera, and the
///   week is planned in the same view (#veckogenererar).
/// - TR::FLOW::01::vecka-med-rätter::generera: a week with dishes asks
///   "Skriv över" BEFORE anything is computed (flows-roles-budget.md:27).
/// - TR::FLOW::01::resultat::placera-i-veckan (D-04): the generated result
///   is not in the week; placing it is its own step, with two ways.
/// - TR::FLOW::01::placering::kvitto-7-s-andra (D-04): after the automatic
///   placement a receipt with ÄNDRA, the flow's only way back.
///
/// The negative D-03 and D-04 assertions live here too: no long-wait state
/// and no "Fortsätt i bakgrunden" however long the planning takes, and no
/// 30 s undo on the result.
///
/// The real VeckomenyView runs (veckomeny_flow_harness.dart), under a fixed
/// Monday so the whole week lies ahead.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import 'veckomeny_flow_harness.dart';

final _sv = AppLocalizationsSv();

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2), flowDinner(3)],
    };
  });

  tearDown(() => h.tearDown());

  Future<void> runOnMonday(Future<void> Function() body) =>
      withClock(Clock.fixed(flowMonday), body);

  group('TR::FLOW::01::tom-vecka::generera', () {
    testWidgets('an empty week: Generera plans the week in the same view, '
        'without asking first', (tester) async {
      await runOnMonday(() async {
        await h.pump(tester);
        h.menu.hold = Completer<void>();

        await h.generate(tester, 'tre middagar');
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(_sv.weeklyMenuOverwriteConfirm), findsNothing);
        expect(find.byType(VeckomenyGeneratingOverlay), findsOneWidget);
        expect(find.text(_sv.weekMenuPlanningTitle), findsWidgets);
        expect(h.menu.generations, 1);

        h.menu.hold!.complete();
        await tester.pumpAndSettle();

        expect(find.byType(VeckomenyGeneratingOverlay), findsNothing);
        expect(find.text('Middag 1'), findsOneWidget);
        // The saved week is untouched until the user places the result.
        expect(h.repository.saves, isEmpty);
      });
    });
  });

  group('TR::FLOW::01::vecka-med-rätter::generera', () {
    testWidgets('a week with dishes asks before anything is computed; '
        'Avbryt leaves the week, Fortsätt plans', (tester) async {
      await runOnMonday(() async {
        h.seedWeek(2);
        await h.pump(tester);

        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();

        expect(find.text(_sv.weeklyMenuOverwriteConfirm), findsOneWidget);
        expect(h.menu.generations, 0, reason: 'asked BEFORE the computation');

        await tester.tap(find.text(_sv.commonCancel));
        await tester.pumpAndSettle();
        expect(h.menu.generations, 0);
        expect(h.repository.saves, isEmpty);

        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();
        expect(find.text(_sv.weeklyMenuOverwriteConfirm), findsOneWidget);
        await tester.tap(find.text(_sv.commonContinue));
        await tester.pumpAndSettle();

        expect(h.menu.generations, 1);
      });
    });
  });

  group('TR::FLOW::01::genererar::offline', () {
    // veckomeny_view_flow01_test.dart pins the button while offline; this is
    // the connection going away WHILE the week is planned
    // (flows-roles-budget.md:34, "avbrutet + banner, tidigare vecka orörd";
    // veckomeny_view.dart:186-199).
    testWidgets('the connection goes during the planning: nothing is placed, '
        'the saved week stays, and the view says it stopped', (tester) async {
      await runOnMonday(() async {
        h.seedWeek(2);
        await h.pump(tester);
        h.menu.hold = Completer<void>();

        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();
        await tester.tap(find.text(_sv.commonContinue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(VeckomenyGeneratingOverlay), findsOneWidget);

        h.connectivity.set(online: false);
        h.menu.hold!.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(h.repository.saves, isEmpty, reason: 'the saved week is kept');
        expect(
          find.textContaining(_sv.menuGenerateOfflineStopped),
          findsOneWidget,
        );
        // The suggestion waits in Lista, where it can be placed later.
        expect(find.text('Middag 1'), findsOneWidget);
        expect(find.textContaining('Ingen anslutning'), findsWidgets);
      });
    });
  });

  group('TR::FLOW::01::resultat::placera-i-veckan', () {
    testWidgets('the result is not in the week; it offers the two ways, and '
        'the automatic one writes the week', (tester) async {
      await runOnMonday(() async {
        await h.pump(tester);
        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();

        // D-04: the generated result has not changed the week.
        expect(h.repository.saves, isEmpty);
        expect(find.text(_sv.menuPlaceAutoButton), findsOneWidget);
        expect(find.text(_sv.menuPlaceManualButton), findsOneWidget);
        // D-04: no undo on the result, and no 30 s window anywhere.
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('Ångra'), findsNothing);

        await tester.tap(find.text(_sv.menuPlaceAutoButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(h.repository.saves, hasLength(1));
        final placed = h.repository.saves.single.entries;
        expect(placed.map((e) => e.recipeId).toSet(), {
          'dinner-1',
          'dinner-2',
          'dinner-3',
        });
      });
    });
  });

  group('TR::FLOW::01::placering::kvitto-7-s-andra', () {
    testWidgets('the automatic placement shows a receipt with Ändra, and '
        'Ändra opens the manual placement on an empty week', (tester) async {
      await runOnMonday(() async {
        await h.pump(tester);
        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();
        await tester.tap(find.text(_sv.menuPlaceAutoButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
        expect(find.text(_sv.menuAutoPlacedChangeAction), findsOneWidget);
        // D-04: the receipt's way back is Ändra, never a 30 s Ångra.
        expect(find.text('Ångra'), findsNothing);

        await tester.tap(find.text(_sv.menuAutoPlacedChangeAction));
        await tester.pumpAndSettle();

        final placement = tester.widget<MenuPlacementView>(
          find.byType(MenuPlacementView),
        );
        expect(placement.startFromEmptyWeek, isTrue);
      });
    });

    // Known gap, shrink-only (census known_gap, proposed ticket): D-04 gives
    // the receipt 7 s, and the view asks for 7 s (veckomeny_view.dart:291),
    // but SnackBarUtils keeps every snackbar that has an action until the
    // user acts (snackbar_utils.dart:424-428, `persist ?? action != null`),
    // so the receipt never leaves by itself. The undo snackbar solves the
    // same thing with UndoWindowTimer. This test fails once the receipt
    // leaves at 7 s; then assert that instead and drop the known_gap in
    // test/fixtures/design/transition_census.json.
    testWidgets('known gap: the receipt asks for 7 s but stays until the '
        'user acts', (tester) async {
      await runOnMonday(() async {
        await h.pump(tester);
        await h.generate(tester, 'tre middagar');
        await tester.pumpAndSettle();
        await tester.tap(find.text(_sv.menuPlaceAutoButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(_sv.menuAutoPlacedToast(3)), findsOneWidget);

        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(find.text(_sv.menuAutoPlacedToast(3)), findsOneWidget);
      });
    });
  });

  group('ux-beslut D-03: no long wait and no background choice', () {
    testWidgets('a planning that takes 40 s stays the same state in the same '
        'view, with no "Fortsätt i bakgrunden"', (tester) async {
      await runOnMonday(() async {
        await h.pump(tester);
        h.menu.hold = Completer<void>();
        await h.generate(tester, 'tre middagar');

        // 11 s, 31 s and 40 s into the planning.
        for (final step in [11, 20, 9]) {
          await tester.pump(Duration(seconds: step));
          expect(find.byType(VeckomenyGeneratingOverlay), findsOneWidget);
          expect(find.textContaining('bakgrund'), findsNothing);
          expect(find.byType(Dialog), findsNothing);
        }
        h.menu.hold!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Middag 1'), findsOneWidget);
      });
    });
  });
}
