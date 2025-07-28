// lib/views/social/group_detail/group_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';

/// GroupDetailActions - Group action methods
///
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
      title: 'Ta bort medlem',
      message: 'Vill du ta bort ${member.displayName} från gruppen "${group.name}"?',
      confirmText: 'Ta bort',
      icon: Icons.person_remove,
      isDangerous: true,
    );

    if (shouldRemove == true) {
      try {
        final categoriesService = sl<UnifiedFriendsService>();
        final success = await categoriesService.categories.removeFriendFromCategory(
          friendId: member.uid,
          categoryId: group.id,
        );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.displayName} har tagits bort från gruppen'),
              backgroundColor: AppColors.success,
            ),
          );
          // GroupEventBus.emit(GroupEventType.memberRemoved);
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte ta bort medlem: $e'),
              backgroundColor: AppColors.error,
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
    final descriptionController = TextEditingController(text: group.description);
    final emojiController = TextEditingController(text: group.emoji);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera grupp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Gruppnamn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingL),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beskrivning',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.spacingL),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final categoriesService = sl<UnifiedFriendsService>();
        final success = await categoriesService.categories.updateCategory(
          categoryId: group.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
        );

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gruppen har uppdaterats'),
              backgroundColor: AppColors.success,
            ),
          );
          // GroupEventBus.emit(GroupEventType.updated);
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte uppdatera grupp: $e'),
              backgroundColor: AppColors.error,
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
      itemType: 'grupp',
      warningMessage: 'Denna åtgärd kan inte ångras.',
      icon: Icons.group,
    );

    if (shouldDelete == true) {
      try {
        final categoriesService = sl<UnifiedFriendsService>();
        final success = await categoriesService.categories.deleteCategory(group.id);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gruppen har tagits bort'),
              backgroundColor: AppColors.success,
            ),
          );
          // GroupEventBus.emit(GroupEventType.deleted);
          Navigator.pop(context);
          return true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte ta bort grupp: $e'),
              backgroundColor: AppColors.error,
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
      title: 'Lämna grupp',
      message: 'Vill du lämna gruppen "${group.name}"?\n\nDu kan bli inbjuden igen av andra medlemmar.',
      confirmText: 'Lämna',
      icon: Icons.exit_to_app,
      isDangerous: true,
    );

    if (shouldLeave == true) {
      try {
        final categoriesService = sl<UnifiedFriendsService>();
        final permissionService = sl<PermissionService>();
        final currentUserId = permissionService.currentUserId;

        if (currentUserId != null) {
          final success = await categoriesService.categories.removeFriendFromCategory(
            friendId: currentUserId,
            categoryId: group.id,
          );

          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Du har lämnat gruppen'),
                backgroundColor: AppColors.success,
              ),
            );
            // GroupEventBus.emit(GroupEventType.memberRemoved);
            Navigator.pop(context);
            return true;
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte lämna grupp: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    return false;
  }
}