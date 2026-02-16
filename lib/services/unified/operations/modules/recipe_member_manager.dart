// lib/services/unified/operations/modules/recipe_member_manager.dart

// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic _parent fields
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// Collaborative recipe membership management module
class RecipeMemberManager {
  final UnifiedRecipeService _parent;
  final NotificationService? _notificationService;

  RecipeMemberManager(this._parent, this._notificationService);

  /// Add member to collaborative recipe with specified permission level
  Future<bool> addMember({
    required String recipeId,
    required String memberId,
    required String memberDisplayName,
    ResourcePermission? permission,
  }) async {
    try {
      permission ??= ResourcePermission.viewer;
      AppLogger.info('Adding member $memberId to recipe $recipeId');
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot add member: Recipe not found');
        return false;
      }
      if (recipe.socialData?.memberPermissions?.containsKey(memberId) == true) {
        AppLogger.warning('User already a member');
        return false;
      }
      if (!_canInviteMembers(recipe)) {
        AppLogger.error('No permission to invite');
        return false;
      }
      final currentPermissions = Map<String, ResourcePermission>.from(
          recipe.socialData?.memberPermissions ?? {});
      currentPermissions[memberId] = permission;
      final updatedSocialData = RecipeSocialData(
        ownerId: recipe.socialData?.ownerId,
        ownerDisplayName: recipe.socialData?.ownerDisplayName,
        memberPermissions: currentPermissions,
        allowGuestViewing: recipe.socialData?.allowGuestViewing ?? false,
        allowMemberInvites: recipe.socialData?.allowMemberInvites ?? true,
        categoryIds: recipe.socialData?.categoryIds,
        descriptionCollaborative: recipe.socialData?.descriptionCollaborative,
      );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _parent.updateRecipe(updatedRecipe);
      if (!success) {
        AppLogger.error('Failed to update recipe with new member');
        return false;
      }

      AppLogger.success('Successfully added member $memberId to recipe');

      await _sendMemberAddedNotification(
        recipeId: recipeId,
        recipeTitle: recipe.title,
        newMemberId: memberId,
        newMemberName: memberDisplayName,
        permission: permission,
      );

      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'member_added',
        permission: permission,
      );

      return true;
    } catch (e) {
      AppLogger.error('Failed to add member to recipe', e);
      return false;
    }
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMember({
    required String recipeId,
    required String memberId,
  }) async {
    try {
      AppLogger.info('Removing member $memberId from recipe $recipeId');

      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.error(
            'Cannot remove member: Recipe not found or not collaborative');
        return false;
      }

      if (recipe.socialData?.memberPermissions?.containsKey(memberId) != true) {
        AppLogger.warning('User $memberId is not a member of recipe $recipeId');
        return false;
      }

      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == memberId) {
        AppLogger.error('Cannot remove recipe owner from member list');
        return false;
      }

      if (!_canManageMembers(recipe)) {
        AppLogger.error(
            'Current user does not have permission to remove members');
        return false;
      }

      final currentPermissions = Map<String, ResourcePermission>.from(
          recipe.socialData?.memberPermissions ?? {});
      currentPermissions.remove(memberId);

      final updatedSocialData = RecipeSocialData(
        ownerId: recipe.socialData?.ownerId,
        ownerDisplayName: recipe.socialData?.ownerDisplayName,
        memberPermissions: currentPermissions,
        allowGuestViewing: recipe.socialData?.allowGuestViewing ?? false,
        allowMemberInvites: recipe.socialData?.allowMemberInvites ?? true,
        categoryIds: recipe.socialData?.categoryIds,
        descriptionCollaborative: recipe.socialData?.descriptionCollaborative,
      );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _parent.updateRecipe(updatedRecipe);
      if (!success) {
        AppLogger.error('Failed to update recipe after member removal');
        return false;
      }

      AppLogger.success('Successfully removed member $memberId from recipe');

      await _sendMemberRemovedNotification(
        recipeId: recipeId,
        recipeTitle: recipe.title,
        removedMemberId: memberId,
      );

      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'member_removed',
      );

      return true;
    } catch (e) {
      AppLogger.error('Failed to remove member from recipe', e);
      return false;
    }
  }

  /// Update member permission level
  Future<bool> updateMemberPermission({
    required String recipeId,
    required String memberId,
    required ResourcePermission newPermission,
  }) async {
    try {
      AppLogger.info(
          'Updating permission for member $memberId in recipe $recipeId to ${newPermission.name}');

      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.error(
            'Cannot update permission: Recipe not found or not collaborative');
        return false;
      }

      if (recipe.socialData?.memberPermissions?.containsKey(memberId) != true) {
        AppLogger.error('Cannot update permission: User is not a member');
        return false;
      }

      if (!_canManageMembers(recipe)) {
        AppLogger.error(
            'Current user does not have permission to manage member permissions');
        return false;
      }

      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == memberId) {
        AppLogger.error('Cannot change recipe owner permission');
        return false;
      }

      final currentPermissions = Map<String, ResourcePermission>.from(
          recipe.socialData?.memberPermissions ?? {});
      final oldPermission = currentPermissions[memberId];

      if (oldPermission == newPermission) {
        AppLogger.info('Permission is already set to ${newPermission.name}');
        return true;
      }

      currentPermissions[memberId] = newPermission;

      final updatedSocialData = RecipeSocialData(
        ownerId: recipe.socialData?.ownerId,
        ownerDisplayName: recipe.socialData?.ownerDisplayName,
        memberPermissions: currentPermissions,
        allowGuestViewing: recipe.socialData?.allowGuestViewing ?? false,
        allowMemberInvites: recipe.socialData?.allowMemberInvites ?? true,
        categoryIds: recipe.socialData?.categoryIds,
        descriptionCollaborative: recipe.socialData?.descriptionCollaborative,
      );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _parent.updateRecipe(updatedRecipe);
      if (!success) {
        AppLogger.error('Failed to update recipe with new permission');
        return false;
      }

      AppLogger.success('Successfully updated member permission');

      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'permission_updated',
        permission: newPermission,
        previousPermission: oldPermission,
      );

      return true;
    } catch (e) {
      AppLogger.error('Failed to update member permission', e);
      return false;
    }
  }

  /// Get all members of a collaborative recipe
  Future<List<Map<String, dynamic>>> getRecipeMembers(String recipeId) async {
    try {
      AppLogger.debug('Getting members for recipe $recipeId');

      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.warning('Recipe not found or not collaborative');
        return [];
      }

      final members = <Map<String, dynamic>>[];
      final permissions = recipe.socialData?.memberPermissions ?? {};
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      final ownerDisplayName = recipe.socialData?.ownerDisplayName ?? '?';

      if (ownerId != null) {
        members.add({
          'userId': ownerId,
          'displayName': ownerDisplayName,
          'permission': ResourcePermission.owner,
          'isOwner': true,
          'joinedAt': recipe.createdAt,
        });
      }

      for (final entry in permissions.entries) {
        final memberId = entry.key;
        final permission = entry.value;
        if (memberId != ownerId) {
          members.add({
            'userId': memberId,
            'displayName': '?',
            'permission': permission,
            'isOwner': false,
            'joinedAt': null,
          });
        }
      }

      AppLogger.debug('Found ${members.length} members for recipe');
      return members;
    } catch (e) {
      AppLogger.error('Failed to get recipe members', e);
      return [];
    }
  }

  /// Check if current user can invite members to recipe
  bool canInviteMembers(String recipeId) {
    try {
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) return false;

      return _canInviteMembers(recipe);
    } catch (e) {
      AppLogger.error('❌ Failed to check invitation permissions', e);
      return false;
    }
  }

  /// Get member statistics for a recipe
  Map<String, dynamic> getMemberStatistics(String recipeId) {
    try {
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        return {'error': 'Recipe not found'};
      }

      final permissions = recipe.socialData?.memberPermissions ?? {};

      final permissionCounts = <String, int>{};
      for (final permission in permissions.values) {
        final key = permission.name;
        permissionCounts[key] = (permissionCounts[key] ?? 0) + 1;
      }

      return {
        'total_members': permissions.length + 1, // +1 for owner
        'permission_breakdown': permissionCounts,
        'has_editors':
            permissions.values.any((p) => p == ResourcePermission.editor),
        'has_admins':
            permissions.values.any((p) => p == ResourcePermission.admin),
        'allow_member_invites': recipe.socialData?.allowMemberInvites ?? true,
      };
    } catch (e) {
      AppLogger.error('Failed to get member statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  /// Send notification when member is added to recipe
  Future<void> _sendMemberAddedNotification({
    required String recipeId,
    required String recipeTitle,
    required String newMemberId,
    required String newMemberName,
    required ResourcePermission permission,
  }) async {
    final currentUserName = _parent.currentUserDisplayName ?? '?';

    await NotificationHelper.sendImmediateSafely(
      notificationService: _notificationService,
      operationName: 'Send member added notification to $newMemberId',
      targetUserIds: [newMemberId],
      strategy: NotificationStrategy.collaborationInvite,
      variables: {
        'senderName': currentUserName,
        'resourceName': recipeTitle,
      },
      additionalData: {
        'recipeId': recipeId,
        'action': 'member_added',
        'permission': permission.name,
      },
      actions: [
        NotificationAction.viewRecipe,
      ],
    );
  }

  /// Send notification when member is removed from recipe
  Future<void> _sendMemberRemovedNotification({
    required String recipeId,
    required String recipeTitle,
    required String removedMemberId,
  }) async {
    final currentUserName = _parent.currentUserDisplayName ?? '?';

    await NotificationHelper.sendSilentSafely(
      notificationService: _notificationService,
      operationName: 'Send member removed notification to $removedMemberId',
      targetUserIds: [removedMemberId],
      data: {
        'type': 'member_removed',
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'removedBy': currentUserName,
      },
    );
  }

  /// Check if current user can invite members to recipe
  bool _canInviteMembers(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    final allowMemberInvites = recipe.socialData?.allowMemberInvites ?? true;
    if (!allowMemberInvites) return false;

    final userPermission =
        recipe.socialData?.memberPermissions?[currentUserId] ??
            ResourcePermission.viewer;
    return userPermission == ResourcePermission.admin ||
        userPermission == ResourcePermission.editor;
  }

  /// Check if current user can manage members (add/remove/change permissions)
  bool _canManageMembers(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    final userPermission =
        recipe.socialData?.memberPermissions?[currentUserId] ??
            ResourcePermission.viewer;
    return userPermission == ResourcePermission.admin;
  }

  /// Log member action for analytics
  void _logMemberAction({
    required String recipeId,
    required String memberId,
    required String action,
    ResourcePermission? permission,
    ResourcePermission? previousPermission,
  }) {
    try {
      final logData = {
        'recipeId': recipeId,
        'memberId': memberId,
        'action': action,
        'performedBy': _parent.currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (permission != null) {
        logData['permission'] = permission.name;
      }

      if (previousPermission != null) {
        logData['previousPermission'] = previousPermission.name;
      }

      AppLogger.info('Member action logged: $action');
    } catch (e) {
      AppLogger.warning('Failed to log member action: $e');
    }
  }
}
