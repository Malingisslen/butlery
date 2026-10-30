import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Android's "Alarm och påminnelser" access. Without USE_EXACT_ALARM, Android
/// 14+ grants exact alarms only after the user turns this on, so a timer
/// asks before choosing how to schedule.
abstract class ExactAlarmAccess {
  Future<bool> allowed();
  Future<void> openSetting();
}

class _PluginExactAlarmAccess implements ExactAlarmAccess {
  const _PluginExactAlarmAccess(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android {
    if (kIsWeb || !Platform.isAndroid) return null;
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  // A failed lookup counts as allowed so no false offer is shown; the
  // schedule call's own catch covers an OS that then refuses.
  @override
  Future<bool> allowed() async {
    final android = _android;
    if (android == null) return true;
    try {
      return await android.canScheduleExactNotifications() ?? true;
    } catch (e) {
      AppLogger.warning('ExactAlarmAccess: lookup failed: $e');
      return true;
    }
  }

  @override
  Future<void> openSetting() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      AppLogger.warning('ExactAlarmAccess: could not open the setting: $e');
    }
  }
}

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
/// `zonedSchedule`. The timezone database is
/// initialised lazily on first schedule so the service is self-contained and
/// doesn't depend on app bootstrap ordering.
class LocalTimerNotificationService extends BaseService {
  LocalTimerNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    bool Function()? isMobileOverride,
    ExactAlarmAccess? exactAlarms,
  }) : this._(
         plugin ?? FlutterLocalNotificationsPlugin(),
         isMobileOverride,
         exactAlarms,
       );

  LocalTimerNotificationService._(
    this._plugin,
    this._isMobileOverride,
    ExactAlarmAccess? exactAlarms,
  ) : _exactAlarms = exactAlarms ?? _PluginExactAlarmAccess(_plugin);

  @override
  String get serviceName => 'LocalTimerNotificationService';

  final FlutterLocalNotificationsPlugin _plugin;
  final ExactAlarmAccess _exactAlarms;

  static const String exactAlarmOfferShownKey = 'exact_alarm_offer_shown';

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

    Future<void> scheduleWith(AndroidScheduleMode mode) =>
        _plugin.zonedSchedule(
          id: notificationIdFor(timerId),
          title: AppLocale.current.timerNotificationTitle,
          body: body,
          scheduledDate: fireAt,
          notificationDetails: details,
          androidScheduleMode: mode,
          // No matchDateTimeComponents → fires once, not recurring.
        );

    final exact = await _exactAlarms.allowed();
    try {
      await scheduleWith(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: schedule failed for $timerId: $e',
      );
      // The OS can refuse an exact alarm the check allowed (access revoked
      // in between); an inexact alert still alerts.
      if (!exact) return;
      try {
        await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e) {
        AppLogger.warning(
          'LocalTimerNotificationService: inexact fallback failed for '
          '$timerId: $e',
        );
      }
    }
  }

  /// Decision D1 (Malin 2026-10-29): the first timer started while exact
  /// alarms are off offers the "Alarm och påminnelser" setting, once per
  /// device. The timer starts whatever the answer.
  Future<void> offerExactAlarmsOnce(BuildContext context) async {
    if (kIsWeb || !_isMobile) return;
    if (await _exactAlarms.allowed()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(exactAlarmOfferShownKey) ?? false) return;
      await prefs.setBool(exactAlarmOfferShownKey, true);
    } catch (e) {
      AppLogger.warning(
        'LocalTimerNotificationService: offer flag unavailable: $e',
      );
      return;
    }
    if (!context.mounted) return;
    final l10n = context.l10n;
    final open = await OsPermissionHelper.presentExplanation(
      context,
      title: l10n.timerExactAlarmTitle,
      body: l10n.timerExactAlarmBody,
      grantLabel: l10n.permOpenSettings,
      declineLabel: l10n.permNotNow,
      icon: ButleryIcons.bell,
    );
    if (open) await _exactAlarms.openSetting();
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
