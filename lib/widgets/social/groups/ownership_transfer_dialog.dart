// lib/widgets/social/groups/ownership_transfer_dialog.dart

import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog for selecting a new group owner when the current owner wants to leave.
/// Returns the selected UserProfile or null if cancelled.
/// This dialog doesn't perform any actions - it just captures user selection.
class OwnershipTransferDialog extends StatelessWidget {
  final FriendCategory group;
  final List<UserProfile> availableMembers;

  const OwnershipTransferDialog({
    super.key,
    required this.group,
    required this.availableMembers,
  });

  /// Show the dialog and return selected member
  static Future<UserProfile?> show({
    required BuildContext context,
    required FriendCategory group,
    required List<UserProfile> availableMembers,
  }) async {
    return await showButleryDialog<UserProfile>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => OwnershipTransferDialog(
        group: group,
        availableMembers: availableMembers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ButleryDialog(
      title: context.l10n.groupTransferOwnership,
      scrollable: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.groupTransferOwnershipMessage(group.name),
          ),
          const SizedBox(height: AppDimensions.space12),
          Text(
            context.l10n.groupSelectNewOwner,
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: AppDimensions.space8),
          // List of available members
          ...availableMembers.map(
            (member) => ButleryItemRow(
              leading: AvatarCircle(
                imageUrl: member.avatarUrl,
                displayName: member.displayName,
              ),
              title: member.displayName,
              padded: false,
              onTap: () => Navigator.pop(context, member),
            ),
          ),
        ],
      ),
      actions: const [DialogCancelButton()],
    );
  }
}
