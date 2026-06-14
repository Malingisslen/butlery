import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:butlery/services/notifications/local_timer_notification_service.dart';

/// Records the call sequence and lets a test force `initialize` to throw, so we
/// can assert init-ordering and graceful degradation without a device. On the
/// VM `resolvePlatformSpecificImplementation` returns null (no concrete
/// platform), so the iOS-permission / Android-channel branches are skipped and
/// the prepare path reduces to: initialize → (then) zonedSchedule.
///
/// The plugin has a private constructor, so it can't be subclassed — mocktail's
/// `implements` is the only seam. We track the call order ourselves rather than
/// rely on mocktail's verification, because the *ordering* across two different
/// methods (initialize before zonedSchedule) is the contract under test.
class _RecordingPlugin extends Mock implements FlutterLocalNotificationsPlugin {
  _RecordingPlugin({this.throwOnInitialize = false}) {
    when(() => initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
          onDidReceiveBackgroundNotificationResponse:
              any(named: 'onDidReceiveBackgroundNotificationResponse'),
        )).thenAnswer((_) async {
      initializeCount++;
      calls.add('initialize');
      if (throwOnInitialize) {
        throw Exception('forced initialize failure');
      }
      return true;
    });
    when(() => zonedSchedule(
          id: any(named: 'id'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        )).thenAnswer((_) async {
      calls.add('zonedSchedule');
    });
    when(() => cancel(id: any(named: 'id'), tag: any(named: 'tag')))
        .thenAnswer((_) async {
      calls.add('cancel');
    });
  }

  final bool throwOnInitialize;
  final List<String> calls = <String>[];
  int initializeCount = 0;
}

class _FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

class _FakeTZDateTime extends Fake implements tz.TZDateTime {}

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

  group('LocalTimerNotificationService prepare/init ordering (BUT-1242)', () {
    setUpAll(() {
      registerFallbackValue(_FakeInitializationSettings());
      registerFallbackValue(_FakeNotificationDetails());
      registerFallbackValue(_FakeTZDateTime());
      registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    });

    // The platform gate is forced mobile via the injectable seam, because
    // Platform.isAndroid/isIOS are both false on the VM and schedule() would
    // otherwise short-circuit before ever preparing the plugin. This is the
    // only path that exercises the new _initializePlugin() init step folded
    // into isPrepared — the off-device group above can never reach it.

    test('initialize() runs exactly once and BEFORE the first zonedSchedule',
        () async {
      final plugin = _RecordingPlugin();
      final service = LocalTimerNotificationService(
        plugin: plugin,
        isMobileOverride: () => true,
      );

      await service.schedule(
        timerId: 'step-0',
        duration: const Duration(minutes: 5),
        label: 'koka pasta',
      );

      // Pins the contract from the class comment: on iOS zonedSchedule is a
      // silent no-op until initialize() has run, so initialize MUST precede it.
      expect(plugin.calls, equals(['initialize', 'zonedSchedule']),
          reason: 'plugin must be initialized before the first schedule');
      expect(plugin.initializeCount, equals(1));
      expect(service.isPrepared, isTrue);
    });

    test('initialize() is not repeated on a second schedule', () async {
      final plugin = _RecordingPlugin();
      final service = LocalTimerNotificationService(
        plugin: plugin,
        isMobileOverride: () => true,
      );

      await service.schedule(
        timerId: 'step-0',
        duration: const Duration(minutes: 5),
      );
      await service.schedule(
        timerId: 'step-1',
        duration: const Duration(minutes: 3),
      );

      expect(plugin.initializeCount, equals(1),
          reason: 'prepare is idempotent — initialize runs once per service');
      expect(plugin.calls,
          equals(['initialize', 'zonedSchedule', 'zonedSchedule']));
    });

    test('a thrown initialize() degrades gracefully — schedule still completes',
        () async {
      // A failing initialize must be swallowed (warned, not rethrown) so the
      // timer flow continues and the in-app pulse remains the fallback. The
      // scheduled write is still attempted; the OS-level alert just may not
      // fire. Critically, schedule() does not throw into the timer service.
      final plugin = _RecordingPlugin(throwOnInitialize: true);
      final service = LocalTimerNotificationService(
        plugin: plugin,
        isMobileOverride: () => true,
      );

      await expectLater(
        service.schedule(
          timerId: 'step-0',
          duration: const Duration(minutes: 5),
        ),
        completes,
      );
      expect(plugin.calls, equals(['initialize', 'zonedSchedule']));
      expect(service.isPrepared, isTrue,
          reason:
              'a swallowed init failure still marks prepare complete so the '
              'timer flow is never blocked by notification setup');
    });
  });
}
