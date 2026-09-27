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

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

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

/// What the OS answered, as the flow-07 states name it
/// (flows-roles-budget.md:98-106; produktregler.md:680-687).
///
/// - [granted]: the feature works (also iOS `provisional`).
/// - [limited]: iOS "valda bilder" — usable, and its own state with a way to
///   choose more, never an error (produktregler.md:684).
/// - [denied]: no for now. The feature stays and can ask again.
/// - [permanentlyDenied]: only the phone's settings can change it.
/// - [restricted]: the device or MDM blocks it; there is nothing the user
///   can do, so it gets an explanation without a button.
enum OsPermissionOutcome {
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
}

/// Convenience reads on [OsPermissionOutcome].
extension OsPermissionOutcomeX on OsPermissionOutcome {
  /// `granted` and `limited` both let the feature run
  /// (produktregler.md:684).
  bool get isUsable =>
      this == OsPermissionOutcome.granted ||
      this == OsPermissionOutcome.limited;
}

/// Pure helper encapsulating Butlery's OS-permission UX contract.
///
/// Contract: explanation → OS prompt → settings link on a permanent no →
/// never a hard-gated feature (produktregler.md:682). The OS is asked only
/// after the user tapped Tillåt in our dialog, and a second no is a silent
/// skip (produktregler.md:683).
class OsPermissionHelper {
  OsPermissionHelper._();

  /// Maps a `permission_handler` status to the typed flow-07 outcome.
  static OsPermissionOutcome outcomeOf(PermissionStatus status) {
    if (status.isGranted || status.isProvisional) {
      return OsPermissionOutcome.granted;
    }
    if (status.isLimited) return OsPermissionOutcome.limited;
    if (status.isPermanentlyDenied) {
      return OsPermissionOutcome.permanentlyDenied;
    }
    if (status.isRestricted) return OsPermissionOutcome.restricted;
    return OsPermissionOutcome.denied;
  }

  /// Request an OS permission with Butlery's UX contract and return the
  /// typed outcome.
  ///
  /// Callers pass already-localized strings; the helper picks no keys.
  /// Platform short-circuits (iOS, Android < 13, web) are the caller's
  /// responsibility — see `NotificationPermissionService`.
  ///
  /// [skipRationale] is for an explicit "Fråga igen": the user has just asked
  /// for the OS prompt, so our explanation is not shown a second time
  /// (produktregler.md:683). [restrictedMessage], when given, is shown
  /// without a button on a device-blocked permission
  /// (flows-roles-budget.md:104). [rationaleConsequence] and [rationaleIcon]
  /// feed the drawn explanation (Skarmar v12 etapp 3 #behkamera).
  static Future<OsPermissionOutcome> request({
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
    String? rationaleConsequence,
    IconData? rationaleIcon,
    String? declineLabel,
    String? restrictedMessage,
    bool skipRationale = false,
  }) async {
    final presentRationale =
        rationalePresenter ??
        (ctx, title, body, grant) => presentExplanation(
          ctx,
          title: title,
          body: body,
          grantLabel: grant,
          declineLabel: declineLabel,
          consequence: rationaleConsequence,
          icon: rationaleIcon,
        );
    final presentSnackbar =
        settingsSnackbarPresenter ?? _defaultSettingsSnackbarPresenter;

    final current = outcomeOf(await gateway.checkStatus(permission));

    if (current.isUsable) return current;

    if (current == OsPermissionOutcome.permanentlyDenied) {
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
      return current;
    }

    if (current == OsPermissionOutcome.restricted) {
      // Blocked by the device or MDM: explain, offer no button — there is
      // nothing the user can do (flows-roles-budget.md:104).
      if (restrictedMessage != null && context.mounted) {
        presentRestricted(context, restrictedMessage);
      }
      return current;
    }

    // Not yet decided or denied once: our explanation comes before the OS
    // prompt. We only call request() when the user taps Tillåt, to avoid
    // burning the OS's "don't ask again" budget on a silent re-prompt.
    if (!skipRationale) {
      if (!context.mounted) return OsPermissionOutcome.denied;
      final wantsToGrant = await presentRationale(
        context,
        rationaleTitle,
        rationaleBody,
        grantLabel,
      );
      if (!wantsToGrant) return OsPermissionOutcome.denied;
    }

    final outcome = outcomeOf(await gateway.request(permission));
    if (outcome.isUsable) return outcome;

    if (outcome == OsPermissionOutcome.permanentlyDenied && context.mounted) {
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
    return outcome;
  }

  /// Boolean form of [request], kept for the callers that only need to know
  /// whether the feature may run (microphone, notifications). True iff the
  /// outcome is usable (`granted`, `limited` or iOS `provisional`).
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
    final outcome = await request(
      context: context,
      permission: permission,
      rationaleTitle: rationaleTitle,
      rationaleBody: rationaleBody,
      grantLabel: grantLabel,
      permanentlyDeniedMessage: permanentlyDeniedMessage,
      openSettingsLabel: openSettingsLabel,
      gateway: gateway,
      rationalePresenter: rationalePresenter,
      settingsSnackbarPresenter: settingsSnackbarPresenter,
    );
    return outcome.isUsable;
  }

  /// Shows our own explanation, as drawn in Skarmar v12 etapp 3 #behkamera,
  /// and returns true when the user tapped the grant button. Dismissing the
  /// dialog counts as "Inte nu".
  static Future<bool> presentExplanation(
    BuildContext context, {
    required String title,
    required String body,
    required String grantLabel,
    String? declineLabel,
    String? consequence,
    IconData? icon,
  }) async {
    final result = await presentExplanationChoice(
      context,
      title: title,
      body: body,
      grantLabel: grantLabel,
      declineLabel: declineLabel,
      consequence: consequence,
      icon: icon,
    );
    return result ?? false;
  }

  /// [presentExplanation] that tells the two buttons apart from a dismissal:
  /// true for the grant button, false for the decline button, null when the
  /// dialog was dismissed.
  static Future<bool?> presentExplanationChoice(
    BuildContext context, {
    required String title,
    required String body,
    required String grantLabel,
    String? declineLabel,
    String? consequence,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _OsPermissionRationaleDialog(
        title: title,
        body: body,
        grantLabel: grantLabel,
        cancelLabel: declineLabel,
        consequence: consequence,
        icon: icon,
      ),
    );
  }

  /// Shows [message] without a button, for a permission the device blocks
  /// (flows-roles-budget.md:104: "Ingen knapp — det finns inget användaren
  /// kan göra").
  static void presentRestricted(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Opens the phone's settings for this app. The one way back from a
  /// permanent no (flows-roles-budget.md:103).
  static Future<bool> openSettings({
    PermissionGateway gateway = const DefaultPermissionGateway(),
  }) => gateway.openSettings();
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

/// Rationale dialog shown once before the OS prompt. Public wrapper exists so
/// widget tests can pump it directly.
@visibleForTesting
class OsPermissionRationaleDialog extends StatelessWidget {
  const OsPermissionRationaleDialog({
    super.key,
    required this.title,
    required this.body,
    required this.grantLabel,
    required this.cancelLabel,
    this.consequence,
    this.icon,
  });

  final String title;
  final String body;
  final String grantLabel;
  final String cancelLabel;
  final String? consequence;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _OsPermissionRationaleDialog(
    title: title,
    body: body,
    grantLabel: grantLabel,
    cancelLabel: cancelLabel,
    consequence: consequence,
    icon: icon,
  );
}

/// The explanation before the system prompt, as drawn in Skarmar v12
/// etapp 3 #behkamera (:530-547): radius 12, an icon beside a bold title, the
/// body saying what the feature is used for, an optional line saying what
/// still works after a no, and two equal buttons — "Inte nu" outlined and
/// the saffron grant action.
///
/// Colours, both modes:
/// - Card: slot 835, #F5F4ED light = cs.surface, #24382C dark = cs.primary.
/// - Title and icon: #24382C light / #F5F4ED dark = cs.onSurface.
/// - Body: slot 833 = text.bodyMuted, #37453A light / #C9D3C4 dark
///   (tokens.json:174-177). The theme has no bodyMuted member yet, so this
///   is a stand-in: AppModeColors.textBody, right in light mode, #F5F4ED in
///   dark mode where the drawing has #C9D3C4. Open until D1 delivers the
///   member.
/// - Consequence line: slot 702, #627061 light / #93A48D dark =
///   cs.onSurfaceVariant.
/// - Buttons: the shared outlined and hero styles (tokens.json:137-144).
class _OsPermissionRationaleDialog extends StatelessWidget {
  const _OsPermissionRationaleDialog({
    required this.title,
    required this.body,
    required this.grantLabel,
    this.cancelLabel,
    this.consequence,
    this.icon,
  });

  final String title;
  final String body;
  final String grantLabel;
  final String? cancelLabel;
  final String? consequence;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    // The cancel label falls back to MaterialLocalizations so the helper can
    // present without forcing every caller to pipe a cancel string.
    final cancel =
        cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
    return Dialog(
      backgroundColor: dark ? cs.primary : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  ExcludeSemantics(
                    child: ButleryIcon(
                      icon,
                      color: cs.onSurface,
                      size: AppDimensions.iconSizeM,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              body,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppModeColors.textBody(cs.brightness),
              ),
            ),
            if (consequence != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                consequence!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: ComponentThemes.outlinedButtonStyle(cs),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancel, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: FilledButton(
                    style: ComponentThemes.heroButtonStyle(cs),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(grantLabel, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
