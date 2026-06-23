import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/notifications/local_timer_notification_service.dart';

/// BUT-1242: records schedule/cancel calls without touching the real plugin or
/// the timezone database, so the service's notification side-effects are
/// assertable in a pure-Dart test.
class _RecordingNotifications extends LocalTimerNotificationService {
  final List<({String id, Duration duration, String? label})> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> schedule({
    required String timerId,
    required Duration duration,
    String? label,
  }) async {
    scheduled.add((id: timerId, duration: duration, label: label));
  }

  @override
  Future<void> cancel(String timerId) async {
    cancelled.add(timerId);
  }
}

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
        Clock(
          () => DateTime.fromMillisecondsSinceEpoch(
            DateTime(2026, 1, 1).millisecondsSinceEpoch +
                async.elapsed.inMilliseconds,
          ),
        ),
        () {
          body(async);
        },
      );
    });
  }

  group('StepTimerService', () {
    test(
      'start(Duration) emits initial duration and ticks down each second',
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
      },
    );

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

    test(
      'elapsed past duration → auto-transitions to expired (emits zero)',
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
      },
    );

    test('background-restore: resuming after long gap reconciles remaining', () {
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

  group('StepTimerService — multiple concurrent timers (BUT-1242)', () {
    test('two labelled timers count down independently', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.startTimer(
          id: 'step-0',
          duration: const Duration(seconds: 30),
          label: 'pasta',
        );
        service.startTimer(
          id: 'step-1',
          duration: const Duration(seconds: 10),
          label: 'lök',
        );

        async.elapse(const Duration(seconds: 4));

        expect(
          service.currentRemainingFor('step-0'),
          const Duration(seconds: 26),
        );
        expect(
          service.currentRemainingFor('step-1'),
          const Duration(seconds: 6),
        );

        // The shorter timer expires first without disturbing the other.
        async.elapse(const Duration(seconds: 6));
        expect(service.isRunningFor('step-1'), isFalse);
        expect(service.isRunningFor('step-0'), isTrue);
        expect(
          service.currentRemainingFor('step-0'),
          const Duration(seconds: 20),
        );

        service.dispose();
      });
    });

    test('timers snapshot stream lists active timers sorted soonest-first', () {
      withFakeTime((async) {
        final service = StepTimerService();
        final snapshots = <List<StepTimerEntry>>[];
        final sub = service.timers.listen(snapshots.add);

        service.startTimer(id: 'step-0', duration: const Duration(seconds: 30));
        service.startTimer(id: 'step-1', duration: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 1));

        final latest = snapshots.last;
        expect(latest.map((e) => e.id).toList(), ['step-1', 'step-0']);
        expect(
          latest.first.remaining.inSeconds,
          lessThan(latest.last.remaining.inSeconds),
        );

        sub.cancel();
        service.dispose();
      });
    });

    test('resetTimer removes a named timer from the snapshot', () {
      withFakeTime((async) {
        final service = StepTimerService();
        service.startTimer(id: 'step-0', duration: const Duration(seconds: 30));
        service.startTimer(id: 'step-1', duration: const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 1));
        expect(service.currentTimers.length, 2);

        service.resetTimer('step-0');
        expect(service.currentTimers.map((e) => e.id).toList(), ['step-1']);

        service.dispose();
      });
    });
  });

  group('StepTimerService — expiry notifications (BUT-1242)', () {
    test('startTimer schedules a notification with the remaining + label', () {
      withFakeTime((async) {
        final notes = _RecordingNotifications();
        final service = StepTimerService(notifications: notes);

        service.startTimer(
          id: 'step-0',
          duration: const Duration(minutes: 10),
          label: 'koka pasta',
        );

        expect(notes.scheduled, hasLength(1));
        expect(notes.scheduled.single.id, 'step-0');
        expect(notes.scheduled.single.duration, const Duration(minutes: 10));
        expect(notes.scheduled.single.label, 'koka pasta');

        service.dispose();
      });
    });

    test('pause cancels the scheduled notification', () {
      withFakeTime((async) {
        final notes = _RecordingNotifications();
        final service = StepTimerService(notifications: notes);
        service.startTimer(id: 'step-0', duration: const Duration(minutes: 5));
        async.elapse(const Duration(seconds: 2));

        service.pauseTimer('step-0');
        expect(notes.cancelled, contains('step-0'));

        service.dispose();
      });
    });

    test('reset cancels the scheduled notification', () {
      withFakeTime((async) {
        final notes = _RecordingNotifications();
        final service = StepTimerService(notifications: notes);
        service.startTimer(id: 'step-0', duration: const Duration(minutes: 5));

        service.resetTimer('step-0');
        expect(notes.cancelled, contains('step-0'));

        service.dispose();
      });
    });

    test('resume re-schedules a notification for the remaining time', () {
      withFakeTime((async) {
        final notes = _RecordingNotifications();
        final service = StepTimerService(notifications: notes);
        service.startTimer(id: 'step-0', duration: const Duration(seconds: 60));
        async.elapse(const Duration(seconds: 20));
        service.pauseTimer('step-0');

        notes.scheduled.clear();
        service.resumeTimer('step-0');

        expect(notes.scheduled, hasLength(1));
        // ~40s remaining when resumed.
        expect(notes.scheduled.single.duration.inSeconds, closeTo(40, 1));

        service.dispose();
      });
    });
  });
}
