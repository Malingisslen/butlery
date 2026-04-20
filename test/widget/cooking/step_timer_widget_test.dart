import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/widgets/cooking/step_timer_widget.dart';

/// BUT-406: Widget-level tests. We drive a real [StepTimerService] and
/// pump the widget through its state matrix (running / paused / expired /
/// re-entry) — the service is already thoroughly tested in its own suite
/// so here we only verify the widget renders the right chrome for each
/// state.
void main() {
  Widget harness(
    StepTimerService service, {
    Duration initialDuration = const Duration(minutes: 5),
    String? sourcePhrase,
    VoidCallback? onExpired,
  }) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: const [Locale('sv'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: StepTimerWidget(
          service: service,
          initialDuration: initialDuration,
          sourcePhrase: sourcePhrase,
          onExpired: onExpired,
        ),
      ),
    );
  }

  testWidgets(
      'idle: auto-starts the timer on first build and shows running controls',
      (tester) async {
    final service = StepTimerService();

    await tester.pumpWidget(
        harness(service, initialDuration: const Duration(minutes: 3)));
    // Let the post-frame auto-start fire.
    await tester.pump();

    // mm:ss format with tabular figures.
    expect(find.text('03:00'), findsOneWidget);
    // Running state → Pausa button visible.
    expect(find.text('Pausa'), findsOneWidget);
    expect(service.isRunning, isTrue);

    // Clear the periodic timer before the framework's pending-timer check.
    service.reset();
    await service.dispose();
  });

  testWidgets('running → paused shows "Återuppta" label', (tester) async {
    final service = StepTimerService();

    await tester.pumpWidget(
        harness(service, initialDuration: const Duration(minutes: 2)));
    await tester.pump();

    // Tap pause.
    await tester.tap(find.byTooltip('Pausa'));
    await tester.pump();

    expect(service.isPaused, isTrue);
    expect(find.text('Återuppta'), findsOneWidget);
    expect(find.text('Pausa'), findsNothing);

    await service.dispose();
  });

  testWidgets('expired: fires onExpired callback when timer hits zero',
      (tester) async {
    var expiredCount = 0;
    final service = StepTimerService();

    await tester.pumpWidget(harness(
      service,
      initialDuration: const Duration(seconds: 1),
      onExpired: () => expiredCount++,
    ));
    await tester.pump(); // post-frame auto-start

    // Drive the timer past expiry. StepTimerService uses Timer.periodic(1s),
    // so we need to let wall-clock pass AND the periodic tick fire.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(); // propagate state change

    expect(expiredCount, 1);
    expect(find.text('00:00'), findsOneWidget);

    // The pulse animation runs forever (reverse-repeat). Reset the service
    // (stops the ticker) then replace the widget tree with an empty scaffold
    // so the AnimationController disposes cleanly.
    service.reset();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await service.dispose();
  });

  testWidgets('re-entry: reopening sheet does not reset a running timer',
      (tester) async {
    final service = StepTimerService();

    // First pump: service starts.
    await tester.pumpWidget(
        harness(service, initialDuration: const Duration(minutes: 10)));
    await tester.pump();
    expect(service.isRunning, isTrue);

    // Let some time pass on the periodic ticker.
    await tester.pump(const Duration(seconds: 3));
    final remainingAfterTick = service.currentRemaining;
    expect(remainingAfterTick, lessThan(const Duration(minutes: 10)));

    // Simulate reopening the sheet: rebuild widget with same service.
    await tester.pumpWidget(
        harness(service, initialDuration: const Duration(minutes: 10)));
    await tester.pump();

    // Service must still be running with the original countdown, not reset.
    expect(service.isRunning, isTrue);
    expect(
      service.currentRemaining.inSeconds,
      lessThanOrEqualTo(remainingAfterTick.inSeconds),
    );

    service.reset();
    await service.dispose();
  });
}
