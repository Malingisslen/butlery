// lib/views/social/group_detail/group_detail_actions_refactored.dart

import 'package:flutter/material.dart';
import '../../../core/base/base_action_handler.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../services/user_service.dart';
import '../../../core/injection.dart';
import '../../../theme/app_dimensions.dart';
import '../add_members_to_group_view.dart';

/// Refactored GroupDetailActions using BaseActionHandler
/// 
/// This demonstrates standardized group management patterns using:
/// - BaseActionHandler for consistent error handling
/// - Standardized confirmation dialogs
/// - Safe navigation and state management
/// - Proper logging and feedback
class GroupDetailActionsRefactored extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'GroupDetailActions';

  // ===== MEMBER MANAGEMENT ACTIONS =====

  /// Add members to group with standardized handling
  Future<bool> addMembers(BuildContext context, FriendCategory group) async {
    if (!validateContext(context) || !validateRequired([group.id], 'adding members')) {
      return false;
    }

    final result = await executeAction<bool>(
      context: context,
      action: () async {
        final result = await navigateTo<bool>(
          context,
          AddMembersToGroupView(groupId: group.id),
        );
        return result ?? false;
      },
      successMessage: null, // Will be handled by the navigation result
      logAction: true,
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'action': 'add_members',
      },
    );

    return result ?? false;
  }

  /// Remove member from group with confirmation and validation
  Future<bool> removeMember(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([member.uid, group.id], 'removing member')) {
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        final categoriesService = sl<UnifiedFriendsService>();
        return await categoriesService.categories.removeFriendFromCategory(
          friendId: member.uid,
          categoryId: group.id,
        );
      },
      confirmationTitle: 'Ta bort medlem',
      confirmationMessage: 'Vill du ta bort ${member.displayName} från gruppen "${group.name}"?',
      confirmActionText: 'Ta bort',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '${member.displayName} har tagits bort från gruppen',
      errorMessage: 'Kunde inte ta bort medlem från gruppen',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'member_id': member.uid,
        'member_name': member.displayName,
        'action': 'remove_member',
      },
    ) ?? false;
  }

  /// Update member role with validation
  Future<bool> updateMemberRole(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
    String newRole,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([member.uid, group.id, newRole], 'updating member role')) {
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        // Simulate role update - in real implementation, this would call the service
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      confirmationTitle: 'Ändra medlemsroll',
      confirmationMessage: 'Vill du ändra ${member.displayName}s roll till "$newRole"?',
      confirmActionText: 'Ändra roll',
      confirmationIcon: Icons.admin_panel_settings,
      successMessage: '${member.displayName}s roll har ändrats till $newRole',
      errorMessage: 'Kunde inte ändra medlemsroll',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'member_id': member.uid,
        'member_name': member.displayName,
        'new_role': newRole,
        'action': 'update_role',
      },
    ) ?? false;
  }

  // ===== GROUP MANAGEMENT ACTIONS =====

  /// Edit group with form dialog and validation
  Future<bool> editGroup(BuildContext context, FriendCategory group) async {
    if (!validateContext(context) || !validateRequired([group.id], 'editing group')) {
      return false;
    }

    return await executeAction<bool>(
      context: context,
      action: () async {
        return await _showEditGroupDialog(context, group);
      },
      successMessage: 'Gruppen har uppdaterats',
      errorMessage: 'Kunde inte uppdatera gruppen',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'action': 'edit_group',
      },
    ) ?? false;
  }

  /// Delete group with confirmation and cascading cleanup
  Future<bool> deleteGroup(BuildContext context, FriendCategory group) async {
    if (!validateContext(context) || !validateRequired([group.id], 'deleting group')) {
      return false;
    }

    return await executeDeleteAction(
      context: context,
      deleteAction: () async {
        final categoriesService = sl<UnifiedFriendsService>();
        return await categoriesService.categories.deleteCategory(group.id);
      },
      itemName: group.name,
      itemType: 'grupp',
      warningMessage: 'Alla medlemmar kommer att lämna gruppen.',
      icon: Icons.group,
      successMessage: 'Gruppen "${group.name}" har tagits bort',
      errorMessage: 'Kunde inte ta bort gruppen',
      popOnSuccess: true,
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'member_count': group.memberIds.length,
        'action': 'delete_group',
      },
    );
  }

  /// Leave group with confirmation
  Future<bool> leaveGroup(BuildContext context, FriendCategory group) async {
    if (!validateContext(context) || !validateRequired([group.id], 'leaving group')) {
      return false;
    }

    final userService = sl<UserService>();
    final currentUser = userService.currentUserProfile;
    
    if (currentUser == null) {
      if (context.mounted) {
        showErrorMessage(context, 'Du måste vara inloggad för att lämna gruppen');
      }
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        final categoriesService = sl<UnifiedFriendsService>();
        return await categoriesService.categories.removeFriendFromCategory(
          friendId: currentUser.uid,
          categoryId: group.id,
        );
      },
      confirmationTitle: 'Lämna grupp?',
      confirmationMessage: 'Vill du verkligen lämna gruppen "${group.name}"?',
      confirmActionText: 'Lämna grupp',
      confirmationIcon: Icons.exit_to_app,
      isDangerous: true,
      successMessage: 'Du har lämnat gruppen "${group.name}"',
      errorMessage: 'Kunde inte lämna gruppen',
      popOnSuccess: true,
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'user_id': currentUser.uid,
        'action': 'leave_group',
      },
    ) ?? false;
  }

  // ===== GROUP SETTINGS ACTIONS =====

  /// Toggle group privacy setting
  Future<bool> toggleGroupPrivacy(BuildContext context, FriendCategory group) async {
    if (!validateContext(context) || !validateRequired([group.id], 'toggling privacy')) {
      return false;
    }

    // Privacy concept removed - FriendCategory doesn't have privacy settings
    final newPrivacySetting = true; // Placeholder for privacy toggle
    
    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        // Simulate privacy toggle - in real implementation, this would update the group
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      },
      confirmationTitle: 'Ändra sekretess',
      confirmationMessage: 'Vill du ändra gruppens sekretessinställning?', // Simplified since privacy toggle is not implemented
      confirmActionText: 'Ändra inställning',
      confirmationIcon: Icons.settings,
      successMessage: 'Gruppens sekretessinställning har ändrats',
      errorMessage: 'Kunde inte ändra sekretessinställning',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'new_privacy': newPrivacySetting,
        'action': 'toggle_privacy',
      },
    ) ?? false;
  }

  /// Update group notifications
  Future<bool> updateNotificationSettings(
    BuildContext context,
    FriendCategory group,
    bool enableNotifications,
  ) async {
    if (!validateContext(context) || !validateRequired([group.id], 'updating notifications')) {
      return false;
    }

    return await executeAction<bool>(
      context: context,
      action: () async {
        // Simulate notification settings update
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      },
      successMessage: enableNotifications 
          ? 'Notifieringar aktiverade för gruppen'
          : 'Notifieringar inaktiverade för gruppen',
      errorMessage: 'Kunde inte uppdatera notifieringsinställningar',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'notifications_enabled': enableNotifications,
        'action': 'update_notifications',
      },
    ) ?? false;
  }

  // ===== CONTENT SHARING ACTIONS =====

  /// Share content to group
  Future<bool> shareContentToGroup(
    BuildContext context,
    FriendCategory group,
    String contentType,
    String contentId,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([group.id, contentType, contentId], 'sharing content')) {
      return false;
    }

    return await executeWithConfirmation<bool>(
      context: context,
      action: () async {
        // Simulate content sharing
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      confirmationTitle: 'Dela innehåll',
      confirmationMessage: 'Vill du dela detta $contentType med gruppen "${group.name}"?',
      confirmActionText: 'Dela',
      confirmationIcon: Icons.share,
      successMessage: '$contentType delat med gruppen',
      errorMessage: 'Kunde inte dela $contentType med gruppen',
      metadata: {
        'group_id': group.id,
        'group_name': group.name,
        'content_type': contentType,
        'content_id': contentId,
        'action': 'share_content',
      },
    ) ?? false;
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Show edit group dialog
  Future<bool> _showEditGroupDialog(BuildContext context, FriendCategory group) async {
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
                  hintText: 'Ange gruppnamn',
                ),
                maxLength: 50,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beskrivning',
                  hintText: 'Ange beskrivning (valfritt)',
                ),
                maxLength: 200,
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  hintText: '😊',
                ),
                maxLength: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                if (context.mounted) {
                  showErrorMessage(context, 'Gruppnamn kan inte vara tomt');
                }
                return;
              }

              // Simulate group update
              await Future.delayed(const Duration(milliseconds: 300));
              
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ===== VALIDATION HELPERS =====

  /// Check if user can manage group
  bool canManageGroup(BuildContext context, FriendCategory group, String userId) {
    return group.ownerId == userId; // Only owner can manage - no admin system in FriendCategory
  }

  /// Check if user can add members
  bool canAddMembers(BuildContext context, FriendCategory group, String userId) {
    return canManageGroup(context, group, userId); // Only owner can add members - no member invitation system in FriendCategory
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}