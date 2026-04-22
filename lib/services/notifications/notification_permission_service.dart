// lib/services/notifications/notification_permission_service.dart
//
// BUT-414: Android 13+ POST_NOTIFICATIONS runtime permission handling.
//
// iOS and Android 12 or below: permission is implicit or granted at install
// time — this service short-circuits to `true`. Android 13+: request via
// `permission_handler` with a rationale on first denial and a settings
// snackbar on permanent denial. Never hard-gates features.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Injectable wrapper for `permission_handler` static APIs. Lets tests drive
/// status transitions without touching plugin channels.
abstract class NotificationPermissionGateway {
  Future<PermissionStatus> status();
  Future<PermissionStatus> request();
  Future<bool> openSettings();
}

/// Injectable wrapper for Android SDK version lookup. Returns null on
/// non-Android platforms so callers can short-circuit.
abstract class AndroidSdkVersionProvider {
  Future<int?> sdkInt();
}

class _DefaultNotificationPermissionGateway
    implements NotificationPermissionGateway {
  const _DefaultNotificationPermissionGateway();

  @override
  Future<PermissionStatus> status() => Permission.notification.status;

  @override
  Future<PermissionStatus> request() => Permission.notification.request();

  @override
  Future<bool> openSettings() => openAppSettings();
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

/// Rationale dialog presenter — injectable so widget tests can stub the
/// user's choice without pumping the real dialog.
typedef RationaleDialogPresenter = Future<bool> Function(BuildContext context);

/// Settings-snackbar presenter — injectable for the same reason.
typedef SettingsSnackbarPresenter = void Function(
  BuildContext context,
  VoidCallback onOpenSettings,
);

/// API 33 is the floor where `POST_NOTIFICATIONS` becomes a runtime
/// permission. Below this, `flutter_local_notifications` and FCM post without
/// asking.
const int _androidTiramisuSdkInt = 33;

class NotificationPermissionService extends BaseService {
  NotificationPermissionService({
    NotificationPermissionGateway? gateway,
    AndroidSdkVersionProvider? sdkVersionProvider,
    RationaleDialogPresenter? rationalePresenter,
    SettingsSnackbarPresenter? settingsSnackbarPresenter,
  })  : _gateway = gateway ?? const _DefaultNotificationPermissionGateway(),
        _sdkVersionProvider =
            sdkVersionProvider ?? const _DefaultAndroidSdkVersionProvider(),
        _rationalePresenter = rationalePresenter ?? _defaultRationalePresenter,
        _settingsSnackbarPresenter =
            settingsSnackbarPresenter ?? _defaultSettingsSnackbarPresenter;

  @override
  String get serviceName => 'NotificationPermissionService';

  final NotificationPermissionGateway _gateway;
  final AndroidSdkVersionProvider _sdkVersionProvider;
  final RationaleDialogPresenter _rationalePresenter;
  final SettingsSnackbarPresenter _settingsSnackbarPresenter;

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

    final current = await _gateway.status();

    if (current.isGranted || current.isLimited || current.isProvisional) {
      return true;
    }

    if (current.isPermanentlyDenied) {
      if (context.mounted) {
        _settingsSnackbarPresenter(context, () async {
          await _gateway.openSettings();
        });
      }
      return false;
    }

    // First denial path: show our rationale before the OS prompt. We only
    // call request() when the user taps "Allow" to avoid burning the OS's
    // "don't ask again" budget on a silent re-prompt.
    if (current.isDenied) {
      if (!context.mounted) return false;
      final wantsToGrant = await _rationalePresenter(context);
      if (!wantsToGrant) return false;

      final outcome = await _gateway.request();
      if (outcome.isGranted || outcome.isLimited || outcome.isProvisional) {
        return true;
      }
      if (outcome.isPermanentlyDenied && context.mounted) {
        _settingsSnackbarPresenter(context, () async {
          await _gateway.openSettings();
        });
      }
      // Second denial: silent skip. Never hard-gate cooking or other features.
      return false;
    }

    // Restricted (device policy) or unknown: nothing we can do.
    return false;
  }
}

Future<bool> _defaultRationalePresenter(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _NotificationRationaleDialog(),
  );
  return result ?? false;
}

void _defaultSettingsSnackbarPresenter(
  BuildContext context,
  VoidCallback onOpenSettings,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        context.l10n.notificationPermissionPermanentlyDeniedMessage,
      ),
      action: SnackBarAction(
        label: context.l10n.notificationPermissionOpenSettings,
        onPressed: onOpenSettings,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Rationale dialog shown once before the Android OS prompt. Square corners
/// per Butlery design language; colors and spacing via theme tokens.
@visibleForTesting
class NotificationRationaleDialog extends StatelessWidget {
  const NotificationRationaleDialog({super.key});

  @override
  Widget build(BuildContext context) => const _NotificationRationaleDialog();
}

class _NotificationRationaleDialog extends StatelessWidget {
  const _NotificationRationaleDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationPermissionTitle,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              l10n.notificationPermissionBody,
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.notificationPermissionGrant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
