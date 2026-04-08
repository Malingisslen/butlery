// lib/widgets/social/groups/group_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/social/groups/create_group_dialog.dart';
import 'package:butlery/widgets/social/groups/edit_group_dialog.dart';
import 'package:butlery/widgets/social/groups/delete_group_dialog.dart';
import 'package:butlery/widgets/social/groups/remove_member_dialog.dart';

/// Group dialog show methods
/// This module provides methods for showing various group-related dialogs
/// including create, edit, delete, and member management dialogs.
class GroupDialogs {
  /// Show create group dialog
  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateGroupDialog(
        preSelectedMembers: preSelectedMembers,
      ),
    );
  }

  /// Show edit group dialog
  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditGroupDialog(group: group),
    );
  }

  /// Show delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteGroupDialog(group: group),
    );

    return result ?? false;
  }

  /// Show remove member dialog
  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RemoveMemberDialog(
        group: group,
        member: member,
      ),
    );

    return result ?? false;
  }

  /// Show target selection dialog
  static Future<List<InvitationTarget>?> showTargetSelectionDialog(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget> initialSelection = const [],
    String? title,
    bool allowMultiple = true,
  }) {
    return _showTargetSelectionDialog(
      context,
      availableTargets: availableTargets,
      initialSelection: initialSelection,
      title: title ?? context.l10n.groupSelectShareTarget,
      allowMultiple: allowMultiple,
    );
  }
}

/// Target selection dialog with selectable list of [InvitationTarget]s.
Future<List<InvitationTarget>?> _showTargetSelectionDialog(
  BuildContext context, {
  required List<InvitationTarget> availableTargets,
  List<InvitationTarget> initialSelection = const [],
  required String title,
  bool allowMultiple = true,
}) async {
  final selected = Set<String>.from(
    initialSelection.map((t) => t.targetId),
  );

  return showDialog<List<InvitationTarget>>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: availableTargets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: Text(
                      context.l10n.socialNoFriendsYet,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: availableTargets.length,
                  itemBuilder: (context, index) {
                    final target = availableTargets[index];
                    final isSelected = selected.contains(target.targetId);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            if (!allowMultiple) selected.clear();
                            selected.add(target.targetId);
                          } else {
                            selected.remove(target.targetId);
                          }
                        });
                      },
                      title: Text(
                        target.displayName,
                        style: AppTextStyles.titleSmall,
                      ),
                      secondary: target.type == InvitationTargetType.group
                          ? const Icon(Icons.group)
                          : const Icon(Icons.person),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              final result = availableTargets
                  .where((t) => selected.contains(t.targetId))
                  .toList();
              Navigator.pop(context, result);
            },
            child: Text(context.l10n.commonDone),
          ),
        ],
      ),
    ),
  );
}
