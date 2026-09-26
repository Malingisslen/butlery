// Android 13+ POST_NOTIFICATIONS runtime permission handling.
//
// iOS and Android 12 or below: permission is implicit or install-time granted
// — this service short-circuits to `true`. Android 13+: delegates to
// `OsPermissionHelper` with notification-specific l10n strings.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';

// Re-export the shared gateway so existing callers importing this file keep
// compiling without touching their imports.
export 'package:butlery/core/utils/os_permission_helper.dart'
    show PermissionGateway;

/// Injectable wrapper for Android SDK version lookup. Returns null on
/// non-Android platforms so callers can short-circuit.
abstract class AndroidSdkVersionProvider {
  Future<int?> sdkInt();
}

class _DefaultAndroidSdkVersionProvider implements AndroidSdkVersionProvider {
  const _DefaultAndroidSdkVersionProvider();

  @override
  Future<int?> sdkInt() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (e) {
      AppLogger.warning('NotificationPermissionService: SDK lookup failed: $e');
      return null;
    }
  }
}

/// Rationale dialog presenter — single-arg signature kept for test-seam
/// compatibility. The service wraps it to feed the helper's richer typedef.
typedef RationaleDialogPresenter = Future<bool> Function(BuildContext context);

/// Settings-snackbar presenter — two-arg signature for the same reason.
typedef SettingsSnackbarPresenter =
    void Function(
      BuildContext context,
      VoidCallback onOpenSettings,
    );

/// API 33 is the floor where `POST_NOTIFICATIONS` becomes a runtime
/// permission. Below this, `flutter_local_notifications` and FCM post without
/// asking.
const int _androidTiramisuSdkInt = 33;

class NotificationPermissionService extends BaseService {
  NotificationPermissionService({
    PermissionGateway? gateway,
    AndroidSdkVersionProvider? sdkVersionProvider,
    RationaleDialogPresenter? rationalePresenter,
    SettingsSnackbarPresenter? settingsSnackbarPresenter,
  }) : _gateway = gateway ?? const DefaultPermissionGateway(),
       _sdkVersionProvider =
           sdkVersionProvider ?? const _DefaultAndroidSdkVersionProvider(),
       _rationalePresenter = rationalePresenter,
       _settingsSnackbarPresenter = settingsSnackbarPresenter;

  @override
  String get serviceName => 'NotificationPermissionService';

  final PermissionGateway _gateway;
  final AndroidSdkVersionProvider _sdkVersionProvider;
  final RationaleDialogPresenter? _rationalePresenter;
  final SettingsSnackbarPresenter? _settingsSnackbarPresenter;

  /// Returns true if the app may post notifications. Never throws; side
  /// effects (rationale dialog, settings snackbar) depend on the current
  /// permission state. Call from notification-feature first-use.
  ///
  /// Platform detection is delegated to [AndroidSdkVersionProvider]: a null
  /// SDK means non-Android (iOS/web/desktop) and short-circuits to true. iOS
  /// permission is owned by `FCMService` via `firebase_messaging`.
  Future<bool> requestIfNeeded(BuildContext context) async {
    final sdk = await _sdkVersionProvider.sdkInt();

    // Null → non-Android. Below Tiramisu → permission granted at install time.
    if (sdk == null || sdk < _androidTiramisuSdkInt) return true;

    if (!context.mounted) return false;
    return (await _request(context)).isUsable;
  }

  /// Our explanation, then the OS prompt, then the settings link on a
  /// permanent no (produktregler.md:682), with the typed answer.
  Future<OsPermissionOutcome> _request(BuildContext context) {
    final l10n = context.l10n;
    return OsPermissionHelper.request(
      context: context,
      permission: Permission.notification,
      rationaleTitle: l10n.notificationPermissionTitle,
      rationaleBody: l10n.notificationPermissionBody,
      grantLabel: l10n.notificationPermissionGrant,
      permanentlyDeniedMessage:
          l10n.notificationPermissionPermanentlyDeniedMessage,
      openSettingsLabel: l10n.notificationPermissionOpenSettings,
      gateway: _gateway,
      rationalePresenter: _rationalePresenter == null
          ? null
          : (ctx, _, __, ___) => _rationalePresenter(ctx),
      settingsSnackbarPresenter: _settingsSnackbarPresenter == null
          ? null
          : (ctx, _, __, onOpenSettings) =>
                _settingsSnackbarPresenter(ctx, onOpenSettings),
    );
  }

  /// Whether the phone lets Butlery post notifications right now, read
  /// without asking. iOS and Android 12 or lower count as allowed: the
  /// question is only asked on Android 13 and later (produktregler.md:685;
  /// iOS permission is owned by `FCMService`). Plugin failures count as
  /// allowed, so no false warning is shown.
  Future<bool> notificationsAllowed() async =>
      (await _timerPermissionOutcome()).isUsable;

  /// The notification answer as the timer notice needs it: granted on every
  /// platform where the question is never asked (produktregler.md:685).
  Future<OsPermissionOutcome> _timerPermissionOutcome() async {
    if (kIsWeb) return OsPermissionOutcome.granted;
    final sdk = await _sdkVersionProvider.sdkInt();
    if (sdk == null || sdk < _androidTiramisuSdkInt) {
      return OsPermissionOutcome.granted;
    }
    try {
      return OsPermissionHelper.outcomeOf(
        await _gateway.checkStatus(Permission.notification),
      );
    } catch (e) {
      AppLogger.warning('NotificationPermissionService: status failed: $e');
      return OsPermissionOutcome.granted;
    }
  }

  /// True when notifications are switched off for Butlery in the phone's
  /// settings (a permanent no or a device block), so no switch in the app
  /// means anything until that changes (produktregler.md:739; Skarmar v12
  /// etapp 3 #behnotiser). A not-yet-asked permission is not "off": the
  /// master switch still asks.
  Future<bool> blockedInSystem() async {
    if (kIsWeb) return false;
    try {
      final outcome = OsPermissionHelper.outcomeOf(
        await _gateway.checkStatus(Permission.notification),
      );
      return outcome == OsPermissionOutcome.permanentlyDenied ||
          outcome == OsPermissionOutcome.restricted;
    } catch (e) {
      AppLogger.warning('NotificationPermissionService: status failed: $e');
      return false;
    }
  }

  /// Opens the phone's settings for Butlery.
  Future<bool> openSystemSettings() => _gateway.openSettings();

  /// What happens before a timer starts (flow 04 "app i bakgrunden", flow 07
  /// "Notiser → timers syns bara i appen (sägs explicit)";
  /// produktregler.md:682-685). The timer starts whatever the user picks —
  /// the feature is never hard-gated.
  ///
  /// - iOS, Android 12 or lower, or already allowed: nothing.
  /// - Android 13+ not yet asked, or a no that can still be asked again
  ///   (`denied`): our explanation, then the OS prompt. A no there is said
  ///   in one line: the timer only shows in the app.
  /// - A permanent no or a device block: the notice that the timer only
  ///   shows in the app, with the phone's settings as the way back (a
  ///   permanent no only; a device block gets no button,
  ///   flows-roles-budget.md:104).
  ///
  /// Returns true when the user was told anything, so the caller does not
  /// ask again in the same cooking session (produktregler.md:683).
  Future<bool> warnBeforeTimerIfNeeded(BuildContext context) async {
    final outcome = await _timerPermissionOutcome();
    if (outcome.isUsable || !context.mounted) return false;
    final l10n = context.l10n;

    if (outcome == OsPermissionOutcome.denied) {
      final answer = await _request(context);
      if (answer.isUsable) return false;
      if (context.mounted) {
        OsPermissionHelper.presentRestricted(context, l10n.timerInAppOnly);
      }
      return true;
    }

    if (outcome == OsPermissionOutcome.restricted) {
      OsPermissionHelper.presentRestricted(context, l10n.timerInAppOnly);
      return true;
    }

    final choice = await OsPermissionHelper.presentExplanationChoice(
      context,
      title: l10n.timerNotifDeniedTitle,
      body: l10n.timerNotifDeniedBody,
      grantLabel: l10n.timerNotifDeniedStart,
      declineLabel: l10n.permOpenSettings,
      icon: Icons.notifications_off_outlined,
    );
    if (choice == false) await openSystemSettings();
    return true;
  }
}

/// Public wrapper preserved so existing widget tests can pump the dialog
/// directly. Delegates to the shared [OsPermissionRationaleDialog] with
/// notification-specific l10n strings.
@visibleForTesting
class NotificationRationaleDialog extends StatelessWidget {
  const NotificationRationaleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OsPermissionRationaleDialog(
      title: l10n.notificationPermissionTitle,
      body: l10n.notificationPermissionBody,
      grantLabel: l10n.notificationPermissionGrant,
      cancelLabel: l10n.commonCancel,
    );
  }
}
