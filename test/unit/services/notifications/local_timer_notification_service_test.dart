import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/notifications/local_timer_notification_service.dart';

/// BUT-1242: Unit coverage for the OS-level timer-expiry notification service.
///
/// On a pure-Dart test VM `Platform.isAndroid`/`isIOS` are both false, so
/// `schedule`/`cancel` take their non-mobile early-return path. That is exactly
/// the behaviour we want to pin: off-device (and on web) the service must be a
/// safe no-op so the in-memory timer flow never crashes because notification
/// scheduling failed. The id-derivation is platform-independent and is the
/// contract that makes cancel target the right pending alert, so it is the
/// other thing worth proving here.
void main() {
  group('LocalTimerNotificationService.notificationIdFor', () {
    test('is deterministic for the same timer id', () {
      // Proves: cancel(id) and schedule(id) compute the SAME OS notification id,
      // so a pause/reset actually cancels the alert it scheduled (no phantom).
      expect(
        LocalTimerNotificationService.notificationIdFor('step-3'),
        LocalTimerNotificationService.notificationIdFor('step-3'),
      );
    });

    test('is non-negative for any id', () {
      // flutter_local_notifications requires a 32-bit non-negative id; the
      // `& 0x7fffffff` mask guarantees that even for ids whose hashCode is
      // negative. Break the mask and this fails.
      for (final id in [
        'step-0',
        'step-1',
        '_default',
        'koka pasta 10 min',
        'åäö-step-with-unicode',
        '',
      ]) {
        expect(
          LocalTimerNotificationService.notificationIdFor(id),
          greaterThanOrEqualTo(0),
          reason: 'id "$id" must map to a non-negative notification id',
        );
      }
    });

    test('distinct ids map to distinct notification ids (no collision)', () {
      // Concurrent cooking timers (step-0..step-9) must not share an OS id, or
      // cancelling one would dismiss another's pending alert.
      final ids = {
        for (var i = 0; i < 10; i++)
          LocalTimerNotificationService.notificationIdFor('step-$i'),
      };
      expect(ids, hasLength(10));
    });
  });

  group('LocalTimerNotificationService off-device behaviour', () {
    late LocalTimerNotificationService service;

    setUp(() => service = LocalTimerNotificationService());

    test('schedule is a safe no-op off mobile and never prepares the plugin',
        () async {
      // On the VM (non-mobile) scheduling must short-circuit before touching
      // the plugin or the timezone DB — so isPrepared stays false and no throw
      // escapes to the timer flow.
      await service.schedule(
        timerId: 'step-0',
        duration: const Duration(minutes: 5),
        label: 'koka pasta',
      );
      expect(service.isPrepared, isFalse);
    });

    test('schedule with non-positive duration is a no-op', () async {
      await service.schedule(
        timerId: 'step-0',
        duration: Duration.zero,
      );
      expect(service.isPrepared, isFalse);
    });

    test('cancel is a safe no-op off mobile', () async {
      // Must not throw even though nothing was ever scheduled.
      await expectLater(service.cancel('never-scheduled'), completes);
    });
  });
}
