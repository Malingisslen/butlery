// lib/views/social/group_detail/group_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
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

  /// Report a member's profile / behavior within a group context.
  ///
  /// BUT-511 (Apple 1.2 / Play UGC): every member surface needs a report
  /// entry-point. Member-level reports use `contentType: 'profile'` since the
  /// target is the user themselves (not the group). The reviewer/admin
  /// workflow surfaces these alongside other profile reports.
  static Future<void> reportMember(
    BuildContext context,
    UserProfile member,
  ) async {
    await ReportContentDialog.show(
      context: context,
      contentType: ContentType.profile,
      contentId: member.uid,
      contentOwnerId: member.uid,
    );
  }

  /// BUT-997: bulk-remove multiple members from a group in one confirmation
  /// step. Loops the existing per-member service call client-side — no
  /// batched endpoint is needed because `removeFriendFromCategory` is
  /// idempotent and its Cloud Function side-effects (audit log entry,
  /// notification) are intentionally fire-per-removal.
  ///
  /// Returns the count of removals that actually landed. Partial failures
  /// don't abort the loop — each member's outcome is independent so a
  /// permission-denied on one shouldn't strand the rest. A trailing snackbar
  /// summarises "removed N of M" and includes the failed names if any.
  ///
  /// UI integration (long-press selection mode, bulk-remove button) is
  /// tracked in the BUT-997 follow-up ticket.
  static Future<int> removeMultipleMembers(
    BuildContext context,
    List<UserProfile> members,
    FriendCategory group,
  ) async {
    if (members.isEmpty) return 0;

    final shouldRemove = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.groupRemoveMember,
      message: context.l10n.groupRemoveMultipleConfirm(
        members.length,
        group.name,
      ),
      confirmText: context.l10n.commonRemove,
      icon: Icons.person_remove,
      isDangerous: true,
    );
    if (shouldRemove != true) return 0;

    final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
    var removed = 0;
    final failed = <String>[];
    for (final member in members) {
      try {
        final success = await categoriesService.categories
            .removeFriendFromCategory(member.uid, group.id);
        if (success) {
          removed++;
        } else {
          failed.add(member.displayName);
        }
      } catch (_) {
        failed.add(member.displayName);
      }
    }

    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      if (failed.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupMembersRemoved(removed)),
            backgroundColor: context.butleryColors.success,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.groupMembersPartiallyRemoved(
                removed,
                failed.join(', '),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    if (removed > 0) GroupEventBus.memberRemoved();
    return removed;
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
      message: context.l10n.groupRemoveMemberConfirm(
        member.displayName,
        group.name,
      ),
      confirmText: context.l10n.commonRemove,
      icon: Icons.person_remove,
      isDangerous: true,
    );

    if (shouldRemove == true) {
      try {
        final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
        final success = await categoriesService.categories
            .removeFriendFromCategory(
              member.uid,
              group.id,
            );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.groupMemberRemoved(member.displayName),
              ),
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
    final descriptionController = TextEditingController(
      text: group.description,
    );
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
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonSave,
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
        final success = await categoriesService.categories.deleteCategory(
          group.id,
        );

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
          final success = await categoriesService.categories
              .removeFriendFromCategory(
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
