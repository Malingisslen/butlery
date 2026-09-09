// lib/widgets/common/profile/dialogs/profile_dialogs.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Dialog builders for profile actions.
/// Provides static methods for showing various confirmation and input dialogs.
class ProfileDialogs {
  /// Show logout confirmation dialog.
  static Future<bool?> showLogoutDialog(BuildContext context) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileLogout),
        content: Text(l10n.profileLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.profileLogout),
          ),
        ],
      ),
    );
  }

  /// Show delete account confirmation dialog.
  static Future<bool?> showDeleteAccountDialog(BuildContext context) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDeleteAccount),
        content: Builder(
          builder: (builderContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileDeleteWarningTitle,
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text('• ${l10n.profileDeleteWarningRecipes}'),
              Text('• ${l10n.profileDeleteWarningMenus}'),
              Text('• ${l10n.profileDeleteWarningShoppingLists}'),
              Text('• ${l10n.profileDeleteWarningFriends}'),
              Text('• ${l10n.profileDeleteWarningSharedContent}'),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                l10n.profileDeleteIrreversible,
                style: AppTextStyles.bodyBold.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.profileDeleteConfirmButton),
          ),
        ],
      ),
    );
  }

  /// Show password re-authentication dialog.
  static Future<String?> showPasswordDialog(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileConfirmWithPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.profileEnterPasswordToConfirm),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.profilePassword,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.profileConfirm),
          ),
        ],
      ),
    );
  }

  /// The GDPR Art. 12(4) notice, shown when a deletion lawfully kept something.
  ///
  /// Returns a `Future` and the caller AWAITS it, which is the whole reason
  /// this is not `showErrorDialog`: that one returns `void`, so the screen would
  /// navigate away underneath it. This is also the last surface the person ever
  /// sees — their account is already gone — so it is not dismissible by tapping
  /// outside; the only way past it is the button.
  /// [holdUntil] is the outer cap the SERVER sent. It is rendered rather than
  /// stated as a number in the copy: a hardcoded "180 days" becomes untrue to
  /// the person it is legally owed to the moment `ERASURE_HOLD_MAX_DAYS`
  /// changes. A null says less instead of saying something unmeasured.
  static Future<void> showRetentionNoticeDialog(
    BuildContext context, {
    DateTime? holdUntil,
  }) {
    final l10n = context.l10n;
    final howLong = holdUntil == null
        ? l10n.profileDeletionNoticeHowLongUnknown
        : l10n.profileDeletionNoticeHowLong(
            DateFormat.yMMMMd(
              Localizations.localeOf(context).languageCode,
            ).format(holdUntil),
          );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        // Scrollable because the four blocks below grow with the text scale,
        // and the one clipped at the bottom would be the remedies line —
        // exactly the Art. 12(4) element a notice most easily ships without.
        scrollable: true,
        title: Text(l10n.profileDeletionNoticeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileDeletionNoticeWhat),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(l10n.profileDeletionNoticeWhy),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(howLong),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              l10n.profileDeletionNoticeRights,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  static void showErrorDialog(BuildContext context, String error) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileError),
        content: Text(l10n.profileCouldNotDeleteAccount(error)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}
