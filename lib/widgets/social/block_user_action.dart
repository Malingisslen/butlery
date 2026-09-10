/// Shared confirm-and-block flow used by every surface that offers blocking.

import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Confirmation + block + feedback for a single user.
///
/// Blocking is class-2 destructive per `.claude/rules/ui-conventions.md`: the
/// friendship and both directions of pending requests are gone and unblocking
/// does not bring them back, so it gets a confirm dialog and no undo snackbar.
class BlockUserAction {
  BlockUserAction._();

  /// Returns true when the BLOCK ROW landed — including when the cleanup
  /// after it did not. A caller asking this is asking whether the person
  /// is blocked, which is true in both of those cases.
  /// [staysInGroup] appends the group-chat sentence. Only the group picker
  /// passes it: soft blocking leaves the person among the members, and that is
  /// the expectation the sentence exists to correct.
  static Future<bool> confirmAndBlock(
    BuildContext context, {
    required String userId,
    required String displayName,
    required FriendsViewModel viewModel,
    bool staysInGroup = false,
  }) async {
    final l10n = context.l10n;
    final message = staysInGroup
        ? '${l10n.socialBlockUserMessage(displayName)} '
              '${l10n.socialBlockUserStaysInGroup}'
        : l10n.socialBlockUserMessage(displayName);

    // `customContent` rather than the shared body: that body appends the item
    // name and a question mark AFTER the message, which would land past the
    // sentence saying the friendship does not come back.
    final confirmed =
        await DestructiveConfirmationDialog.show(
          context,
          title: l10n.socialBlockUserConfirm,
          message: '',
          itemName: '',
          customContent: Text(message, style: AppTextStyles.bodyMedium),
          primaryActionText: l10n.socialBlock,
        ) ??
        false;
    if (!confirmed) return false;

    final outcome = await viewModel.blockUser(userId);
    if (!context.mounted) return outcome.blockLanded;

    // The message follows the BLOCK ROW, not the last step to run. A cleanup
    // failure after a successful block used to surface as "kunde inte
    // blockera" — the app denying a protection that was in force, on the
    // screen someone reaches when they want distance from a person
    // (BUT-2022).
    switch (outcome) {
      case BlockOutcome.blocked:
        SnackBarUtils.showSuccess(context, l10n.socialUserBlocked(displayName));
      case BlockOutcome.blockedWithCleanupIssues:
        SnackBarUtils.showWarning(
          context,
          l10n.socialUserBlockedCleanupIncomplete(displayName),
        );
      case BlockOutcome.failed:
        SnackBarUtils.showError(context, l10n.socialCouldNotBlockUser);
    }
    return outcome.blockLanded;
  }
}
