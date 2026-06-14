import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/widgets/cooking/active_timers_strip.dart';

/// BUT-1283: Behavioural coverage for the cooking-mode active-timers overview
/// strip. We drive a REAL [StepTimerService] (the contract under test is "the
/// strip reflects the live timer set"), never a mock — mocking the service
/// would mock away the exact behaviour the strip exists to render.
///
/// What each test proves:
///  - one chip per running/paused timer (the glanceable overview is complete);
///  - idle and expired timers are filtered out (the strip shows only live
///    countdowns, never stale rows);
///  - it renders nothing when no timer is active (no empty bar eating the cook's
///    instruction space);
///  - tapping a chip reopens THAT step's sheet (the index handed back must match
///    the chip's `step-N` id, or the cook lands on the wrong step).
void main() {
  Widget harness(
    StepTimerService service, {
    required ValueChanged<int> onTapTimer,
  }) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: const [Locale('sv'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: ActiveTimersStrip(service: service, onTapTimer: onTapTimer),
      ),
    );
  }

  Future<void> cleanUp(WidgetTester tester, StepTimerService service) async {
    service.resetTimer('step-0');
    service.resetTimer('step-1');
    service.resetTimer('step-2');
    service.reset();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await service.dispose();
  }

  testWidgets('renders one chip per running timer', (tester) async {
    final service = StepTimerService();
    service.startTimer(id: 'step-0', duration: const Duration(minutes: 10));
    service.startTimer(id: 'step-1', duration: const Duration(minutes: 3));

    await tester.pumpWidget(harness(service, onTapTimer: (_) {}));
    await tester.pump();

    // Title is shown plus the two distinct countdowns — one chip each.
    expect(find.text('Aktiva timers'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);

    await cleanUp(tester, service);
  });

  testWidgets('paused timers still appear; the strip reflects running + paused',
      (tester) async {
    final service = StepTimerService();
    service.startTimer(id: 'step-0', duration: const Duration(minutes: 10));
    service.startTimer(id: 'step-1', duration: const Duration(minutes: 3));
    service.pauseTimer('step-1');

    await tester.pumpWidget(harness(service, onTapTimer: (_) {}));
    await tester.pump();

    // Both the running and the paused timer keep their chip — pausing must not
    // drop a timer the cook is mid-way through.
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    // The paused chip swaps the timer glyph for a pause glyph.
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await cleanUp(tester, service);
  });

  testWidgets('idle and expired timers are filtered out of the strip',
      (tester) async {
    final service = StepTimerService();
    // step-0 runs; step-1 expires (drive past its 1s duration); the legacy
    // default timer is reset to idle. Only step-0 should show a chip.
    service.startTimer(id: 'step-0', duration: const Duration(minutes: 10));
    service.startTimer(id: 'step-1', duration: const Duration(seconds: 1));
    service.start(const Duration(minutes: 5)); // legacy default timer
    service.reset(); // → idle, must not show

    await tester.pumpWidget(harness(service, onTapTimer: (_) {}));
    await tester.pump();

    // Let step-1's 1s ticker fire and expire it.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isRunningFor('step-0'), isTrue);
    expect(service.isRunningFor('step-1'), isFalse,
        reason: 'step-1 must have expired after its 1s duration');
    // Exactly one live chip remains — the running step-0. The expired step-1 and
    // the idle default timer contribute no chip, so only one timer glyph shows.
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    // No paused timer → no pause glyph.
    expect(find.byIcon(Icons.pause), findsNothing);

    await cleanUp(tester, service);
  });

  testWidgets('renders nothing when no timer is active', (tester) async {
    final service = StepTimerService();

    await tester.pumpWidget(harness(service, onTapTimer: (_) {}));
    await tester.pump();

    // Empty state collapses to a zero-size box — no title, no bar.
    expect(find.text('Aktiva timers'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // SizedBox.shrink present

    await service.dispose();
  });

  testWidgets('tapping a chip reports the correct step index', (tester) async {
    final service = StepTimerService();
    service.startTimer(id: 'step-0', duration: const Duration(minutes: 10));
    service.startTimer(id: 'step-2', duration: const Duration(minutes: 3));

    final tapped = <int>[];
    await tester.pumpWidget(harness(service, onTapTimer: tapped.add));
    await tester.pump();

    // Tap the step-2 chip (its countdown is 03:00) and assert index 2 — not 1,
    // not the chip's position in the row. The id, not the ordinal, decides.
    await tester.tap(find.text('03:00'));
    await tester.pump();

    expect(tapped, [2]);

    await cleanUp(tester, service);
  });
}
