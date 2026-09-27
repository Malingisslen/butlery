// lib/widgets/common/profile/dialogs/profile_dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// What the user chose when a sign-out met unsaved changes.
enum PendingChangesChoice {
  /// "Vänta på synk": stay signed in.
  wait,

  /// "Logga ut och släng ändringarna".
  discardAndSignOut,
}

/// Dialog builders for profile actions.
/// Provides static methods for showing various confirmation and input dialogs.
class ProfileDialogs {
  /// The longest deletion reason sent to the audit record.
  static const int deleteReasonMaxLength = 500;

  /// Sign-out with unsaved changes (Skarmar v12 del 4 #utloggningko;
  /// produktregler.md:193). The count and what the changes concern are said
  /// in plain words; the destructive way out is named and never the default.
  ///
  /// "Visa vad som väntar" is drawn too. It opens the queue view, which does
  /// not exist yet (package 4), so it is left out rather than offered as a
  /// button that cannot go anywhere (produktregler.md:535).
  ///
  /// Dismissing the dialog is waiting: nothing is thrown away unless the
  /// user presses the destructive button.
  static Future<PendingChangesChoice> showPendingChangesDialog(
    BuildContext context,
    PendingChanges pending,
  ) async {
    final l10n = context.l10n;
    final choice = await showDialog<PendingChangesChoice>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          key: const ValueKey('signOut.pendingChanges'),
          scrollable: true,
          title: Text(l10n.signOutPendingTitle(pending.total)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.signOutPendingBody),
              const SizedBox(height: AppDimensions.spacingMd),
              ...pendingChangeLines(dialogContext, pending),
            ],
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton(
              key: const ValueKey('signOut.pendingChanges.discard'),
              onPressed: () => Navigator.pop(
                dialogContext,
                PendingChangesChoice.discardAndSignOut,
              ),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(l10n.signOutPendingDiscard),
            ),
            // Drawn saffron (Skarmar v12 del 4 morkt lage och etapp 0-1:312,
            // background #ce7c1e): the view's one hero, so waiting is the
            // obvious answer (Komponentark v1:843-844).
            HeroButton(
              key: const ValueKey('signOut.pendingChanges.wait'),
              label: l10n.signOutPendingWait,
              onPressed: () =>
                  Navigator.pop(dialogContext, PendingChangesChoice.wait),
            ),
          ],
        );
      },
    );
    return choice ?? PendingChangesChoice.wait;
  }

  /// One line per kind of pending change, named ("Recept · 2 ändringar").
  /// Shared by the sign-out confirmation and the timeout warning so the two
  /// never describe the same queue differently.
  static List<Widget> pendingChangeLines(
    BuildContext context,
    PendingChanges pending,
  ) {
    final l10n = context.l10n;
    final style = AppTextStyles.bodyBold;
    return [
      if (pending.recipeChanges > 0)
        Text(l10n.signOutPendingRecipes(pending.recipeChanges), style: style),
      if (pending.imageUploads > 0)
        Text(l10n.signOutPendingImages(pending.imageUploads), style: style),
    ];
  }

  /// The deletion's waiting state: "Väntan är ett tillstånd, inte en
  /// spinner — och den kan inte avbrytas när den startat"
  /// (produktregler.md:611; Skarmar v12 etapp 5-7 #kontovantan).
  ///
  /// It cannot be closed: no barrier dismissal and no system back. The
  /// drawn step list is not built, because the callable reports nothing
  /// until it returns; a list whose ticks were guessed would claim progress
  /// nobody measured.
  static void showDeletionWaitingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          key: const ValueKey('accountDeletion.waiting'),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlateLineMessage(
                  message: dialogContext.l10n.accountDeletingProgress,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  dialogContext.l10n.accountDeletionWaitNotice,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Re-authentication as a step, not an error (produktregler.md:612;
  /// Skarmar v12 etapp 5-7 #kontoreauth). Returns true for "Logga in igen".
  static Future<bool> showDeletionReauthStep(BuildContext context) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('accountDeletion.reauth'),
        title: Text(l10n.accountDeletionReauthTitle),
        content: Text(l10n.accountDeletionReauthBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.accountDeletionReauthCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.accountDeletionReauthConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// A partial deletion, its own outcome with its own words
  /// (produktregler.md:613; Skarmar v12 etapp 5-7 #kontodelvis): the account
  /// is gone, [failedCount] parts remain, the audit id is shown so it can be
  /// quoted, and the way on is support with the id — never "Försök igen",
  /// because there is no sign-in left to try with.
  ///
  /// The drawing lists each remaining part by name. The server reports
  /// internal step names only, so the count is said and the names are left
  /// to support, who can read them from the audit record.
  static Future<void> showPartialDeletionDialog(
    BuildContext context, {
    required int failedCount,
    required String? auditLogId,
    required Future<void> Function(String? auditLogId) onContactSupport,
  }) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          key: const ValueKey('accountDeletion.partial'),
          scrollable: true,
          title: Text(l10n.accountDeletionPartialTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.accountDeletionPartialHeading(failedCount),
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(l10n.accountDeletionPartialBody(failedCount)),
              const SizedBox(height: AppDimensions.spacingMd),
              if (auditLogId != null) ...[
                Text(
                  l10n.accountDeletionPartialAuditIdLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SelectableText(
                  auditLogId,
                  key: const ValueKey('accountDeletion.partial.auditId'),
                  style: AppTextStyles.bodyBold,
                ),
              ] else
                Text(l10n.accountDeletionPartialNoAuditId),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.commonClose),
            ),
            FilledButton(
              key: const ValueKey('accountDeletion.partial.contact'),
              onPressed: () {
                if (auditLogId != null) {
                  Clipboard.setData(ClipboardData(text: auditLogId));
                }
                onContactSupport(auditLogId);
              },
              child: Text(l10n.accountDeletionPartialContact),
            ),
          ],
        );
      },
    );
  }

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
  ///
  /// Returns the reason the user gave, or null when she cancelled. The
  /// reason is asked here, BEFORE the password step: "Ett skäl skickas med
  /// och hamnar i revisionsraden. Det frågas före, för efteråt finns ingen
  /// kvar att fråga" (produktregler.md:614). The drawing is a text box
  /// (Skarmar v12 etapp 5-7 #kontoradera, `data-a11y-role="textbox"`).
  ///
  /// The field is optional. Erasure is a right, and a person who does not
  /// want to say why must still be able to leave; an empty answer sends the
  /// neutral [defaultDeleteReason], as before.
  static Future<String?> showDeleteAccountDialog(
    BuildContext context, {
    bool mayHaveOpenReview = false,
  }) async {
    final l10n = context.l10n;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
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
              const SizedBox(height: AppDimensions.spacingXs),
              Text(l10n.profileDeleteNoRecallWindow),
              if (mayHaveOpenReview) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                Text(l10n.profileDeleteAccountMayHaveReview),
              ],
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                key: const ValueKey('accountDeletion.reason'),
                controller: controller,
                maxLength: deleteReasonMaxLength,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.profileDeleteReasonLabel,
                  hintText: l10n.profileDeleteReasonHint,
                  helperText: l10n.profileDeleteReasonHelp,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
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
    // Not disposed here: the dialog's closing animation still builds the
    // field, and the controller is garbage once the route is gone (the
    // password dialog below does the same).
    final typed = controller.text.trim();
    if (confirmed != true) return null;
    return typed.isEmpty ? defaultDeleteReason : typed;
  }

  /// Sent when the user left the reason empty. The same neutral wording the
  /// audit record got before the question existed.
  static const String defaultDeleteReason = 'User requested account deletion';

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
    bool reviewKept = true,
    bool ownReportKept = false,
    bool startCollapsed = false,
  }) {
    final l10n = context.l10n;
    final String what;
    if (reviewKept && ownReportKept) {
      what = provisional
          ? l10n.profileDeletionNoticeWhatBothUnclear
          : l10n.profileDeletionNoticeWhatBoth;
    } else if (ownReportKept) {
      what = l10n.profileDeletionNoticeWhatOwnReport;
    } else {
      what = provisional
          ? l10n.profileDeletionNoticeWhatUnclear
          : l10n.profileDeletionNoticeWhat;
    }
    // A kept report of the person's own is being HANDLED, not reviewed, so
    // those two lines speak of the handling whenever one is among the records.
    final why = ownReportKept
        ? l10n.profileDeletionNoticeWhyHandling
        : l10n.profileDeletionNoticeWhy;
    final String howLong;
    if (holdUntil == null) {
      howLong = ownReportKept
          ? l10n.profileDeletionNoticeHowLongHandlingUnknown
          : l10n.profileDeletionNoticeHowLongUnknown;
    } else {
      final date = DateFormat.yMMMMd(
        Localizations.localeOf(context).languageCode,
      ).format(holdUntil);
      howLong = ownReportKept
          ? l10n.profileDeletionNoticeHowLongHandling(date)
          : l10n.profileDeletionNoticeHowLong(date);
    }

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
                      Text(what),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(why),
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

  /// A failed account deletion. [message] is the whole, already translated
  /// text when more is known (a failed sign-in, a partial deletion), never
  /// an exception's text (content-style-guide.md:95); without it the dialog
  /// says only that the account could not be deleted. The button only
  /// closes, so it is "Stäng", never "OK" (content-style-guide.md:77).
  static void showErrorDialog(BuildContext context, {String? message}) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileError),
        content: Text(message ?? l10n.profileAccountDeleteFailed),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
