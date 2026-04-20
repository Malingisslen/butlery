import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/cooking/step_timer_service.dart';

/// BUT-406: Service-level tests. All time-dependent behaviour runs inside
/// `fakeAsync` + `withClock(Clock(() => async.elapse.now))` so the
/// `Stopwatch`-free implementation (absolute-endtime via `clock.now()`)
/// can be advanced deterministically.
void main() {
  /// Wraps a body with synchronised fake-async + fake-clock. Any call to
  /// `clock.now()` or `Timer.periodic` inside [body] advances in lockstep
  /// with `async.elapse(...)`.
  void withFakeTime(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(
          Clock(() => DateTime.fromMillisecondsSinceEpoch(
                DateTime(2026, 1, 1).millisecondsSinceEpoch +
                    async.elapsed.inMilliseconds,
              )), () {
        body(async);
      });
    });
  }

  group('StepTimerService', () {
    test('start(Duration) emits initial duration and ticks down each second',
        () {
      withFakeTime((async) {
        final service = StepTimerService();
        final emissions = <Duration>[];
        final sub = service.remaining.listen(emissions.add);

        service.start(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));

        // Initial 3s + three ticks (2s, 1s, 0s).
        expect(emissions, [
          const Duration(seconds: 3),
          const Duration(seconds: 2),
          const Duration(seconds: 1),
          Duration.zero,
        ]);
        expect(service.isRunning, isFalse);

        sub.cancel();
        service.dispose();
      });
    });

    test('pause() freezes remaining and stops ticking', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.start(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 3));
        expect(service.currentRemaining, const Duration(seconds: 7));

        service.pause();
        expect(service.isPaused, isTrue);
        expect(service.currentRemaining, const Duration(seconds: 7));

        // Time passes while paused — remaining must NOT decrease.
        async.elapse(const Duration(seconds: 5));
        expect(service.currentRemaining, const Duration(seconds: 7));

        service.dispose();
      });
    });

    test('resume() continues from the paused remaining', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.start(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 4));
        service.pause();
        expect(service.currentRemaining, const Duration(seconds: 6));

        // Time passes while paused; resume should still give us 6s remaining.
        async.elapse(const Duration(seconds: 100));
        service.resume();
        expect(service.isRunning, isTrue);
        expect(service.currentRemaining, const Duration(seconds: 6));

        async.elapse(const Duration(seconds: 2));
        expect(service.currentRemaining, const Duration(seconds: 4));

        service.dispose();
      });
    });

    test('reset() clears timer and emits zero from any state', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.start(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 2));
        service.reset();

        expect(service.isRunning, isFalse);
        expect(service.isPaused, isFalse);
        expect(service.currentRemaining, Duration.zero);

        // Subsequent ticks should not fire.
        async.elapse(const Duration(seconds: 5));
        expect(service.currentRemaining, Duration.zero);

        service.dispose();
      });
    });

    test('elapsed past duration → auto-transitions to expired (emits zero)',
        () {
      withFakeTime((async) {
        final service = StepTimerService();
        final emissions = <Duration>[];
        final sub = service.remaining.listen(emissions.add);

        service.start(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 5));

        expect(emissions.last, Duration.zero);
        expect(service.isRunning, isFalse);
        expect(service.isPaused, isFalse);

        sub.cancel();
        service.dispose();
      });
    });

    test('background-restore: resuming after long gap reconciles remaining',
        () {
      // Simulates: start 10s timer, app backgrounds (Timer.periodic pauses),
      // foreground 30s later. Because we use absolute endtime via clock.now(),
      // the next tick correctly shows expired.
      withFakeTime((async) {
        final service = StepTimerService();
        service.start(const Duration(seconds: 10));

        // Backgrounding: flush all timers that would have fired during gap.
        // FakeAsync's elapse runs them, which mimics iOS pausing periodic
        // timers then catching up on resume.
        async.elapse(const Duration(seconds: 30));

        expect(service.currentRemaining, Duration.zero);
        expect(service.isRunning, isFalse);

        service.dispose();
      });
    });

    test('double-start guard: calling start() again resets and restarts', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.start(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 2));
        expect(service.currentRemaining, const Duration(seconds: 3));

        // Restart with a fresh 10s.
        service.start(const Duration(seconds: 10));
        expect(service.isRunning, isTrue);
        expect(service.currentRemaining, const Duration(seconds: 10));

        async.elapse(const Duration(seconds: 1));
        expect(service.currentRemaining, const Duration(seconds: 9));

        service.dispose();
      });
    });

    test('start(Duration.zero) throws ArgumentError', () {
      final service = StepTimerService();
      expect(
        () => service.start(Duration.zero),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });
  });
}
