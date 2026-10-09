/// BUT-2275 / BUT-2157 on the real VeckomenyView: what the user can still
/// reach when the keyboard is up, and when the planning panel meets the
/// largest text size.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/menu/veckomeny_planning_cancel_footer.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import 'veckomeny_flow_harness.dart';

final _sv = AppLocalizationsSv();

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    h.menu.next = {
      'Middag': [flowDinner(1), flowDinner(2)],
    };
  });

  tearDown(() => h.tearDown());

  testWidgets('the placement choice steps aside while the keyboard is up and '
      'comes back with it gone', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      await h.pump(tester);
      await h.generate(tester, 'två middagar');
      await tester.pumpAndSettle();
      expect(
        find.text(_sv.menuPlaceManualButton),
        findsOneWidget,
        reason: 'premise: the placement choice is offered without a keyboard',
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(find.text('Middag 1'), findsOneWidget, reason: 'the menu stays');
      expect(find.text(_sv.menuPlaceManualButton), findsNothing);
      expect(find.text(_sv.menuPlaceAutoButton), findsNothing);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text(_sv.menuPlaceManualButton), findsOneWidget);
    });
  });

  // The header's view-mode toggle overflows to the right at this text size on
  // its own, so the planning panel is judged by what overflows at the bottom.
  Future<void> cancelPlanningAt(
    WidgetTester tester, {
    required Size screen,
    required double textScale,
  }) async {
    await withClock(Clock.fixed(flowMonday), () async {
      await h.pump(tester);
      h.menu.hold = Completer<void>();
      await h.generate(tester, 'två middagar');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VeckomenyGeneratingOverlay), findsOneWidget);

      tester.view.physicalSize = screen;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final reported = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.toString());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      FlutterError.onError = previous;

      expect(
        reported.where(
          (r) => r.contains('overflowed') && r.contains('on the bottom'),
        ),
        isEmpty,
        reason: 'something in the planning view overflows at the bottom',
      );

      final cancel = find.byKey(VeckomenyPlanningCancelFooter.buttonKey);
      await tester.ensureVisible(cancel);
      await tester.pump();
      expect(
        tester.getRect(cancel).bottom,
        lessThanOrEqualTo(screen.height),
        reason: 'the cancel button could not be scrolled into view',
      );
      await tester.tap(cancel);
      await tester.pump();
      await tester.pump();

      expect(find.byType(VeckomenyGeneratingOverlay), findsNothing);

      h.menu.hold!.complete();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('at the largest text size the cancel button is scrolled into '
      'view and cancels the planning', (tester) async {
    await cancelPlanningAt(
      tester,
      screen: const Size(400, 900),
      textScale: 2.0,
    );
  });
}
