/// Shared confirm-and-block flow used by every surface that offers blocking.

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

  /// Returns true when the block landed.
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

    final success = await viewModel.blockUser(userId);
    if (!context.mounted) return success;

    if (success) {
      SnackBarUtils.showSuccess(context, l10n.socialUserBlocked(displayName));
    } else {
      SnackBarUtils.showError(context, l10n.socialCouldNotBlockUser);
    }
    return success;
  }
}
