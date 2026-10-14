// lib/widgets/social/groups/empty_group_delete_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Dialog shown when group owner wants to leave but is the only member.
/// Returns true if user wants to delete the empty group, false or null otherwise.
/// This dialog doesn't perform any actions - it just captures user intent.
class EmptyGroupDeleteDialog extends StatelessWidget {
  final FriendCategory group;

  const EmptyGroupDeleteDialog({
    super.key,
    required this.group,
  });

  /// Show the dialog and return user's choice
  static Future<bool?> show({
    required BuildContext context,
    required FriendCategory group,
  }) async {
    return await showButleryDialog<bool>(
      context: context,
      builder: (context) => EmptyGroupDeleteDialog(group: group),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ButleryDialog(
      title: context.l10n.groupIsEmpty,
      scrollable: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.groupOnlyMember(group.name)),
          const SizedBox(height: AppDimensions.space8),
          Text(context.l10n.groupDeleteWhenLeaving),
        ],
      ),
      actions: [
        DialogCancelButton(onPressed: () => Navigator.pop(context, false)),
        ButleryDialogPrimary(
          label: context.l10n.groupDeleteTheGroup,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
