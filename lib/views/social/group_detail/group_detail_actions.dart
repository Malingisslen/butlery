// lib/views/social/group_detail/group_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupDetailActions - Group action methods
/// Handles group-related actions like adding/removing members, editing, deleting.
class GroupDetailActions {
  /// Add members to group
  static Future<bool> addMembers(
    BuildContext context,
    FriendCategory group,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersToGroupView(groupId: group.id),
      ),
    );
    return result ?? false;
  }

  /// Remove member from group
  static Future<bool> removeMember(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
  ) async {
    final shouldRemove = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.groupRemoveMember,
      message:
          context.l10n.groupRemoveMemberConfirm(member.displayName, group.name),
      confirmText: context.l10n.commonRemove,
      icon: Icons.person_remove,
      isDangerous: true,
    );

    if (shouldRemove == true) {
      try {
        final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
        final success =
            await categoriesService.categories.removeFriendFromCategory(
          member.uid,
          group.id,
        );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.l10n.groupMemberRemoved(member.displayName)),
              backgroundColor: context.butleryColors.success,
            ),
          );
          GroupEventBus.memberRemoved();
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupCouldNotRemoveMember('$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return false;
  }

  /// Edit group
  static Future<bool> editGroup(
    BuildContext context,
    FriendCategory group,
  ) async {
    final nameController = TextEditingController(text: group.name);
    final descriptionController =
        TextEditingController(text: group.description);
    final emojiController = TextEditingController(text: group.emoji);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.groupEditGroup),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StyledInput(
                controller: nameController,
                label: context.l10n.groupGroupName,
              ),
              const SizedBox(height: AppDimensions.spacingL),
              StyledInput(
                controller: descriptionController,
                label: context.l10n.commonDescription,
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.spacingL),
              StyledInput(
                controller: emojiController,
                label: context.l10n.groupEmoji,
              ),
            ],
          ),
        ),
        actions: [
          StyledButton.secondary(
            text: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          StyledButton.primary(
            text: context.l10n.commonSave,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
        final success = await categoriesService.categories.updateCategory(
          categoryId: group.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
        );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupUpdated),
              backgroundColor: context.butleryColors.success,
            ),
          );
          GroupEventBus.groupUpdated();
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupCouldNotUpdate('$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return false;
  }

  /// Delete group
  static Future<bool> deleteGroup(
    BuildContext context,
    FriendCategory group,
  ) async {
    final shouldDelete = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: group.name,
      itemType: context.l10n.groupItemType,
      warningMessage: context.l10n.commonActionCannotBeUndone,
      icon: Icons.group,
    );

    if (shouldDelete == true) {
      try {
        final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
        final success =
            await categoriesService.categories.deleteCategory(group.id);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupDeleted(group.name)),
              backgroundColor: context.butleryColors.success,
            ),
          );
          GroupEventBus.groupDeleted();
          // Pop back to groups tab (tabIndex: 1)
          Navigator.pop(context, {'navigateToGroups': true});
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupCouldNotDelete('$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return false;
  }

  /// Leave group
  static Future<bool> leaveGroup(
    BuildContext context,
    FriendCategory group,
  ) async {
    final shouldLeave = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.groupLeaveGroup,
      message: context.l10n.groupLeaveGroupConfirm(group.name),
      confirmText: context.l10n.groupLeave,
      icon: Icons.exit_to_app,
      isDangerous: true,
    );

    if (shouldLeave == true) {
      try {
        final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUserId;

        if (currentUserId != null) {
          final success =
              await categoriesService.categories.removeFriendFromCategory(
            currentUserId,
            group.id,
          );

          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.groupLeftGroup),
                backgroundColor: context.butleryColors.success,
              ),
            );
            GroupEventBus.memberRemoved();
            // Pop back to groups tab (tabIndex: 1)
            Navigator.pop(context, {'navigateToGroups': true});
            return true;
          } else {}
        } else {}
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.groupCouldNotLeave('$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return false;
  }
}
