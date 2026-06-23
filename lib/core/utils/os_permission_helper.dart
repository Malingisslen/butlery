// Butlery's OS-permission UX contract, extracted so any future permission
// (microphone for voice-notes, location for store-maps, photos for import) can
// reuse the same rationale → request → settings-snackbar flow without copy-
// paste.
//
// The helper is locale-agnostic: callers pass already-localized strings. That
// keeps the helper free of `AppLocalizations` coupling and lets each caller
// pick the right keys (notification vs microphone vs …).

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Injectable wrapper for `permission_handler` static APIs. Lets tests drive
/// status transitions without touching plugin channels.
///
/// Shared by every OS-permission caller so the helper has one seam to mock.
abstract class PermissionGateway {
  Future<PermissionStatus> checkStatus(Permission permission);
  Future<PermissionStatus> request(Permission permission);

  /// Deliberately named `openSettings` (not `openAppSettings`) to avoid
  /// shadowing the top-level `openAppSettings()` function exported by
  /// `permission_handler`, which would silently recurse if anyone called it
  /// from inside an implementation.
  Future<bool> openSettings();
}

/// Default production gateway delegating to `permission_handler`.
class DefaultPermissionGateway implements PermissionGateway {
  const DefaultPermissionGateway();

  @override
  Future<PermissionStatus> checkStatus(Permission permission) =>
      permission.status;

  @override
  Future<PermissionStatus> request(Permission permission) =>
      permission.request();

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Rationale dialog presenter — injectable so tests can stub the user's
/// choice without pumping the real dialog.
typedef RationaleDialogPresenter =
    Future<bool> Function(
      BuildContext context,
      String title,
      String body,
      String grantLabel,
    );

/// Settings-snackbar presenter — injectable for the same reason.
typedef SettingsSnackbarPresenter =
    void Function(
      BuildContext context,
      String message,
      String openSettingsLabel,
      VoidCallback onOpenSettings,
    );

/// Pure helper encapsulating Butlery's OS-permission UX contract.
///
/// Contract: rationale dialog on first denial, settings-link snackbar on
/// permanent denial, never hard-gates features. Returns true iff the
/// permission is effectively granted (including [PermissionStatus.limited] so
/// photo-library flows work).
class OsPermissionHelper {
  OsPermissionHelper._();

  /// Request an OS permission with Butlery's UX contract.
  ///
  /// Callers pass already-localized strings; helper picks no keys. Platform
  /// short-circuits (iOS, Android < 13, web) are the caller's responsibility
  /// — see `NotificationPermissionService` for the canonical example.
  static Future<bool> requestWithRationale({
    required BuildContext context,
    required Permission permission,
    required String rationaleTitle,
    required String rationaleBody,
    required String grantLabel,
    required String permanentlyDeniedMessage,
    required String openSettingsLabel,
    required PermissionGateway gateway,
    RationaleDialogPresenter? rationalePresenter,
    SettingsSnackbarPresenter? settingsSnackbarPresenter,
  }) async {
    final presentRationale = rationalePresenter ?? _defaultRationalePresenter;
    final presentSnackbar =
        settingsSnackbarPresenter ?? _defaultSettingsSnackbarPresenter;

    final current = await gateway.checkStatus(permission);

    if (_isEffectivelyGranted(current)) return true;

    if (current.isPermanentlyDenied) {
      if (context.mounted) {
        presentSnackbar(
          context,
          permanentlyDeniedMessage,
          openSettingsLabel,
          () async {
            await gateway.openSettings();
          },
        );
      }
      return false;
    }

    // First denial path: show our rationale before the OS prompt. We only
    // call request() when the user taps "Allow" to avoid burning the OS's
    // "don't ask again" budget on a silent re-prompt.
    if (current.isDenied) {
      if (!context.mounted) return false;
      final wantsToGrant = await presentRationale(
        context,
        rationaleTitle,
        rationaleBody,
        grantLabel,
      );
      if (!wantsToGrant) return false;

      final outcome = await gateway.request(permission);
      if (_isEffectivelyGranted(outcome)) return true;

      if (outcome.isPermanentlyDenied && context.mounted) {
        presentSnackbar(
          context,
          permanentlyDeniedMessage,
          openSettingsLabel,
          () async {
            await gateway.openSettings();
          },
        );
      }
      // Second denial: silent skip. Never hard-gate the feature.
      return false;
    }

    // Restricted (device policy) or unknown: nothing we can do.
    return false;
  }

  // `limited` matters for photos; `provisional` matters for iOS push — both
  // count as "the app may proceed". Kept inline so the rule is local to the
  // helper rather than scattered across callers.
  static bool _isEffectivelyGranted(PermissionStatus s) =>
      s.isGranted || s.isLimited || s.isProvisional;
}

Future<bool> _defaultRationalePresenter(
  BuildContext context,
  String title,
  String body,
  String grantLabel,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _OsPermissionRationaleDialog(
      title: title,
      body: body,
      grantLabel: grantLabel,
    ),
  );
  return result ?? false;
}

void _defaultSettingsSnackbarPresenter(
  BuildContext context,
  String message,
  String openSettingsLabel,
  VoidCallback onOpenSettings,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: openSettingsLabel,
        onPressed: onOpenSettings,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Rationale dialog shown once before the OS prompt. Square corners per
/// Butlery design language; colors and spacing via theme tokens. Public
/// wrapper exists so widget tests can pump it directly.
@visibleForTesting
class OsPermissionRationaleDialog extends StatelessWidget {
  const OsPermissionRationaleDialog({
    super.key,
    required this.title,
    required this.body,
    required this.grantLabel,
    required this.cancelLabel,
  });

  final String title;
  final String body;
  final String grantLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => _OsPermissionRationaleDialog(
    title: title,
    body: body,
    grantLabel: grantLabel,
    cancelLabel: cancelLabel,
  );
}

class _OsPermissionRationaleDialog extends StatelessWidget {
  const _OsPermissionRationaleDialog({
    required this.title,
    required this.body,
    required this.grantLabel,
    this.cancelLabel,
  });

  final String title;
  final String body;
  final String grantLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    // The cancel label falls back to MaterialLocalizations so the helper can
    // present without forcing every caller to pipe a cancel string.
    final cancel =
        cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
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
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(body, style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancel),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(grantLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
