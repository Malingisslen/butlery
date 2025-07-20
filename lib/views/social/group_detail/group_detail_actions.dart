// lib/views/social/group_detail/group_detail_actions.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../services/permission_service.dart';
import '../../../core/injection.dart';
import '../../../theme/app_dimensions.dart';
import '../add_members_to_group_view.dart';

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
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort medlem'),
        content: Text(
          'Vill du ta bort ${member.displayName} från gruppen "${group.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
              SizedBox(height: AppDimensions.spacingL),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beskrivning',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: AppDimensions.spacingL),
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
            SnackBar(
              content: const Text('Gruppen har uppdaterats'),
              backgroundColor: Theme.of(context).colorScheme.primary,
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort grupp'),
        content: Text(
          'Vill du ta bort gruppen "${group.name}"?\n\n'
          'Denna åtgärd kan inte ångras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final categoriesService = sl<UnifiedFriendsService>();
        final success = await categoriesService.categories.deleteCategory(group.id);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Gruppen har tagits bort'),
              backgroundColor: Theme.of(context).colorScheme.primary,
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
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lämna grupp'),
        content: Text(
          'Vill du lämna gruppen "${group.name}"?\n\n'
          'Du kan bli inbjuden igen av andra medlemmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Lämna'),
          ),
        ],
      ),
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
              SnackBar(
                content: const Text('Du har lämnat gruppen'),
                backgroundColor: Theme.of(context).colorScheme.primary,
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
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return false;
  }
}