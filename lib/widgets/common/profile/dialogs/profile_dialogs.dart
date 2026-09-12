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
  ///
  /// [mayHaveOpenReview] adds a hedged line saying a moderation review may have
  /// to be kept after the deletion. It comes from the user's own
  /// `totalReports` counter, which counts reports EVER FILED and cannot tell a
  /// closed case from an open one — so the copy must stay conditional. Do not
  /// edit `profileDeleteAccountMayHaveReview` into a statement of fact; the
  /// hedge is the only thing keeping the sentence true.
  ///
  /// Defaults to false, so every caller that does not know stays as it was.
  static Future<bool?> showDeleteAccountDialog(
    BuildContext context, {
    bool mayHaveOpenReview = false,
  }) {
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
              if (mayHaveOpenReview) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                Text(l10n.profileDeleteAccountMayHaveReview),
              ],
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
  /// [provisional] hedges the WHAT line. A provisional hold is placed without
  /// the predicate being answered — the query threw, or the hold write did —
  /// so asserting a pending review as fact would tell the person something
  /// nobody measured. Malin's call, 2026-09-09 (BUT-2047).
  /// [startCollapsed] opens on a neutral line with a "Visa mer" button, and is
  /// for the notice RE-SHOWN on the sign-in screen — where the person reading
  /// may not be the person the notice is about. Malin's call, 2026-09-12,
  /// option (b): on a shared family device the next person must not be told
  /// that the previous account holder had content under moderation review.
  ///
  /// The notice shown live, right after the deletion, passes false — there is
  /// no bystander in a session that has not ended yet, and an extra tap there
  /// would only make the original easier to miss. That asymmetry is the
  /// decision, not an oversight.
  ///
  /// ONE method rather than two dialogs: the four Art. 12(4) elements exist at
  /// exactly one place in this codebase, and a second implementation of a legal
  /// notice is how the two drift apart.
  static Future<void> showRetentionNoticeDialog(
    BuildContext context, {
    DateTime? holdUntil,
    bool provisional = false,
    bool startCollapsed = false,
  }) {
    final l10n = context.l10n;
    final howLong = holdUntil == null
        ? l10n.profileDeletionNoticeHowLongUnknown
        : l10n.profileDeletionNoticeHowLong(
            DateFormat.yMMMMd(
              Localizations.localeOf(context).languageCode,
            ).format(holdUntil),
          );

    // Per CALL, never a static: the bystander protection is per-showing, and a
    // flag living on the class would stay set when a dialog is torn down
    // without completing — handing the next person the expanded notice, which
    // is the exact disclosure the collapsed state exists to prevent.
    bool expanded = !startCollapsed;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setState) {
          return AlertDialog(
            // Scrollable because the four blocks below grow with the text
            // scale, and the one clipped at the bottom would be the remedies
            // line — exactly the Art. 12(4) element a notice most easily ships
            // without.
            scrollable: true,
            title: Text(
              expanded
                  ? l10n.profileDeletionNoticeTitle
                  : l10n.profileDeletionNoticeCollapsed,
            ),
            content: expanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provisional
                            ? l10n.profileDeletionNoticeWhatUnclear
                            : l10n.profileDeletionNoticeWhat,
                      ),
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
                  )
                : null,
            actions: [
              if (!expanded)
                TextButton(
                  onPressed: () => setState(() => expanded = true),
                  child: Text(l10n.commonShowMore),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.commonClose),
              ),
            ],
          );
        },
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
