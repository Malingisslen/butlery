import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';

/// BUT-1242: Schedules an OS-level local notification for a cooking step timer
/// so the user is alerted on expiry even when the app is backgrounded (the
/// in-process `Timer.periodic` in [StepTimerService] is suspended by the OS
/// while backgrounded, so the in-app pulse/snackbar alone can be missed).
///
/// One notification per timer id. Scheduling at `start`/`resume` and cancelling
/// at `pause`/`reset`/expiry keeps the OS-scheduled alert in lockstep with the
/// in-memory timer state — a paused timer must never fire a phantom alert.
///
/// Local-only: no Firestore/FCM. Uses `flutter_local_notifications`'
/// `zonedSchedule` (exact wall-clock delivery). The timezone database is
/// initialised lazily on first schedule so the service is self-contained and
/// doesn't depend on app bootstrap ordering.
class LocalTimerNotificationService extends BaseService {
  LocalTimerNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    bool Function()? isMobileOverride,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _isMobileOverride = isMobileOverride;

  @override
  String get serviceName => 'LocalTimerNotificationService';

  final FlutterLocalNotificationsPlugin _plugin;

  /// Test-only seam for the platform gate. `Platform.isAndroid/isIOS` are both
  /// false on a pure-Dart test VM, so without this `schedule` would always take
  /// its non-mobile early return and the prepare/init ordering would never run.
  /// Production passes nothing and the real platform check is used.
  final bool Function()? _isMobileOverride;

  /// Android channel dedicated to step-timer alerts. High importance so the
  /// expiry alert surfaces over a backgrounded app (you're at the stove).
  static const String channelId = 'step_timer_alerts';

  /// Notification ids are derived from the timer id so cancel/schedule target
  /// the exact pending alert. Hashing keeps them stable and collision-rare
  /// within the small set of concurrent cooking timers.
  static int notificationIdFor(String timerId) => timerId.hashCode & 0x7fffffff;

  bool _tzReady = false;
  bool _channelReady = false;
  bool _pluginInitialized = false;

  /// True once timezone init + plugin init + Android channel creation have run.
  /// Exposed for tests; production code never reads it.
  bool get isPrepared => _tzReady && _pluginInitialized && _channelReady;

  /// Schedules a one-shot alert [duration] from now for [timerId], replacing
  /// any pending alert for the same id. [label] (e.g. the step phrase) is shown
  /// in the body so concurrent timers are distinguishable. No-op on web /
  /// non-mobile and when [duration] is not positive.
  Future<void> schedule({
    required String timerId,
    required Duration duration,
    String? label,
  }) async {
    if (kIsWeb || !_isMobile) return;
    if (duration <= Duration.zero) return;

    await _ensurePrepared();

    final fireAt = tz.TZDateTime.from(
      clock.now().add(duration),
      tz.local,
    );

    final body = (label != null && label.trim().isNotEmpty)
        ? AppLocale.current.timerNotificationBodyLabeled(label.trim())
        : AppLocale.current.timerNotificationBody;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        AppLocale.current.timerNotificationChannelTitle,
        channelDescription:
            AppLocale.current.timerNotificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: notificationIdFor(timerId),
        title: AppLocale.current.timerNotificationTitle,
        body: body,
        scheduledDate: fireAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // No matchDateTimeComponents → fires once, not recurring.
      );
    } catch (e) {
      // Exact-alarm permission can be revoked on Android 14+; degrade to the
      // in-app pulse rather than crashing the timer flow.
      AppLogger.warning(
        'LocalTimerNotificationService: schedule failed for $timerId: $e',
      );
    }
  }

  /// Cancels the pending alert for [timerId]. Safe to call when none exists.
  Future<void> cancel(String timerId) async {
    if (kIsWeb || !_isMobile) return;
    try {
      await _plugin.cancel(id: notificationIdFor(timerId));
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: cancel failed for $timerId: $e',
      );
    }
  }

  Future<void> _ensurePrepared() async {
    if (!_tzReady) {
      tz_data.initializeTimeZones();
      _tzReady = true;
    }
    if (!_pluginInitialized) {
      await _initializePlugin();
      _pluginInitialized = true;
    }
    if (!_channelReady) {
      await _createAndroidChannel();
      _channelReady = true;
    }
  }

  /// Initialises the plugin and, on iOS, requests the alert/sound permission.
  ///
  /// `zonedSchedule` is a no-op until `initialize` has run, and on iOS a
  /// scheduled local notification is silently dropped unless the user has
  /// granted permission — so without this the iOS half of BUT-1242 (alert the
  /// cook on timer expiry while backgrounded) never fires. We request the
  /// permission here at first-schedule rather than at app launch so the prompt
  /// appears in-context (the user just started a cooking timer) instead of on a
  /// cold start before the feature is relevant.
  ///
  /// Android permissions are handled separately: notifications post without a
  /// runtime grant pre-Android-13, and the POST_NOTIFICATIONS / exact-alarm
  /// permissions are requested by the app's main notification setup. The
  /// `requestPermission: false` Darwin flags below keep [initialize] from
  /// prompting; we drive the prompt explicitly via the iOS plugin so it only
  /// fires when a timer is actually scheduled.
  Future<void> _initializePlugin() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(settings: initSettings);
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: plugin init failed: $e',
      );
    }
    await _requestIosPermission();
  }

  Future<void> _requestIosPermission() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: iOS permission request failed: $e',
      );
    }
  }

  Future<void> _createAndroidChannel() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          AppLocale.current.timerNotificationChannelTitle,
          description: AppLocale.current.timerNotificationChannelDescription,
          importance: Importance.high,
        ),
      );
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: channel create failed: $e',
      );
    }
  }

  bool get _isMobile {
    if (kIsWeb) return false;
    final override = _isMobileOverride;
    if (override != null) return override();
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}
