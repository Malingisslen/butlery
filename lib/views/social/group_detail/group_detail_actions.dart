// lib/views/social/group_detail/group_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
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
  /// Partial failures don't abort the loop — each member's outcome is
  /// independent so one failure doesn't strand the rest. Returns what
  /// happened per member (by uid), or null when the user cancelled.
  ///
  /// P5-U33 (produktregler.md:905-909, § 17.6): a partial result is a third
  /// outcome, not a success and not an error, so this reports only the two
  /// whole outcomes: all removed (a success snackbar) and none removed (a
  /// failure that says the selection is kept). A partial result is shown by
  /// the list as a [PartialOutcome] next to the rows that are still selected.
  static Future<MemberRemovalOutcome?> removeMultipleMembers(
    BuildContext context,
    List<UserProfile> members,
    FriendCategory group,
  ) async {
    if (members.isEmpty) return null;

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
    if (shouldRemove != true) return null;

    final categoriesService = ServiceLocator.get<UnifiedFriendsService>();
    final removed = <String>[];
    final failed = <UserProfile>[];
    for (final member in members) {
      try {
        final success = await categoriesService.categories
            .removeFriendFromCategory(member.uid, group.id);
        if (success) {
          removed.add(member.uid);
        } else {
          failed.add(member);
        }
      } catch (_) {
        failed.add(member);
      }
    }
    final outcome = MemberRemovalOutcome(removedIds: removed, failed: failed);

    if (context.mounted) {
      if (outcome.isComplete) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.groupMembersRemoved(removed.length),
        );
      } else if (removed.isEmpty) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupMembersRemoveNone,
          preserved: context.l10n.selectionFailedKept,
        );
      }
    }

    if (removed.isNotEmpty) GroupEventBus.memberRemoved();
    return outcome;
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
          SnackBarUtils.showSuccess(
            context,
            context.l10n.groupMemberRemoved(member.displayName),
          );
          GroupEventBus.memberRemoved();
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
            context,
            context.l10n.groupCouldNotRemoveMember('$e'),
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
          SnackBarUtils.showSuccess(context, context.l10n.groupUpdated);
          GroupEventBus.groupUpdated();
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
            context,
            context.l10n.groupCouldNotUpdate('$e'),
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
          SnackBarUtils.showSuccess(
            context,
            context.l10n.groupDeleted(group.name),
          );
          GroupEventBus.groupDeleted();
          // Pop back to groups tab (tabIndex: 1)
          Navigator.pop(context, {'navigateToGroups': true});
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
            context,
            context.l10n.groupCouldNotDelete('$e'),
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
            SnackBarUtils.showSuccess(context, context.l10n.groupLeftGroup);
            GroupEventBus.memberRemoved();
            // Pop back to groups tab (tabIndex: 1)
            Navigator.pop(context, {'navigateToGroups': true});
            return true;
          } else {}
        } else {}
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
            context,
            context.l10n.groupCouldNotLeave('$e'),
          );
        }
      }
    }

    return false;
  }
}

/// What a bulk member removal did, per member (P5-U33). Identity is the uid,
/// never the row or the name.
@immutable
class MemberRemovalOutcome {
  const MemberRemovalOutcome({required this.removedIds, required this.failed});

  /// The uids that are no longer in the group.
  final List<String> removedIds;

  /// The members still in the group. `removeFriendFromCategory` answers only
  /// yes or no, so the reason shown is that the change was not saved.
  final List<UserProfile> failed;

  /// Everyone went.
  bool get isComplete => failed.isEmpty;

  /// Some went and some did not: the third outcome (produktregler.md:907).
  bool get isPartial => removedIds.isNotEmpty && failed.isNotEmpty;
}
