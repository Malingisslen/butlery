// lib/services/unified/operations/modules/recipe_member_manager.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Focused module for collaborative recipe membership management
/// 
/// This module handles ONLY member management responsibilities:
/// - Adding and removing members from collaborative recipes
/// - Updating member permissions and roles
/// - Member list retrieval and validation
/// - Member invitation permissions and limits
/// - Member-related notifications and alerts
/// 
/// ❌ DOES NOT CONTAIN: Recipe sharing, comments, discovery, ratings, general permissions
class RecipeMemberManager {
  final dynamic _parent; // UnifiedRecipeService
  final NotificationService? _notificationService;

  RecipeMemberManager(this._parent, this._notificationService);

  // ===== MEMBER ADDITION AND REMOVAL =====

  /// Add member to collaborative recipe
  /// 
  /// Adds a new member with specified permission level and sends notifications
  Future<bool> addMember({
    required String recipeId,
    required String memberId,
    required String memberDisplayName,
    ResourcePermission permission = ResourcePermission.viewer,
  }) async {
    try {
      AppLogger.info('👥 Adding member $memberId to recipe $recipeId');

      // Find the collaborative recipe
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.error('❌ Cannot add member: Recipe not found or not collaborative');
        return false;
      }

      // Check if user is already a member
      if (recipe.socialData?.memberPermissions?.containsKey(memberId) == true) {
        AppLogger.warning('⚠️ User $memberId is already a member of recipe $recipeId');
        return false;
      }

      // Check if current user can invite members
      if (!_canInviteMembers(recipe)) {
        AppLogger.error('❌ Current user does not have permission to invite members');
        return false;
      }

      // Add member to recipe
      final currentPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
      currentPermissions[memberId] = permission;

      // Update recipe with new member  
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
        AppLogger.error('❌ Failed to update recipe with new member');
        return false;
      }

      AppLogger.success('✅ Successfully added member $memberId to recipe');

      // Send notification to new member
      await _sendMemberAddedNotification(
        recipeId: recipeId,
        recipeTitle: recipe.title,
        newMemberId: memberId,
        newMemberName: memberDisplayName,
        permission: permission,
      );

      // Log member addition for analytics
      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'member_added',
        permission: permission,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to add member to recipe', e);
      return false;
    }
  }

  /// Remove member from collaborative recipe
  /// 
  /// Removes member and updates permissions, with proper validation
  Future<bool> removeMember({
    required String recipeId,
    required String memberId,
  }) async {
    try {
      AppLogger.info('👥 Removing member $memberId from recipe $recipeId');

      // Find the collaborative recipe
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.error('❌ Cannot remove member: Recipe not found or not collaborative');
        return false;
      }

      // Check if user is actually a member
      if (recipe.socialData?.memberPermissions?.containsKey(memberId) != true) {
        AppLogger.warning('⚠️ User $memberId is not a member of recipe $recipeId');
        return false;
      }

      // Prevent removing the recipe owner
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == memberId) {
        AppLogger.error('❌ Cannot remove recipe owner from member list');
        return false;
      }

      // Check if current user can remove members
      if (!_canManageMembers(recipe)) {
        AppLogger.error('❌ Current user does not have permission to remove members');
        return false;
      }

      // Remove member from recipe
      final currentPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
      currentPermissions.remove(memberId);

      // Update recipe without the member
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
        AppLogger.error('❌ Failed to update recipe after member removal');
        return false;
      }

      AppLogger.success('✅ Successfully removed member $memberId from recipe');

      // Send notification to removed member
      await _sendMemberRemovedNotification(
        recipeId: recipeId,
        recipeTitle: recipe.title,
        removedMemberId: memberId,
      );

      // Log member removal for analytics
      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'member_removed',
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to remove member from recipe', e);
      return false;
    }
  }

  // ===== PERMISSION MANAGEMENT =====

  /// Update member permission level
  /// 
  /// Changes a member's permission level (viewer, editor, admin)
  Future<bool> updateMemberPermission({
    required String recipeId,
    required String memberId,
    required ResourcePermission newPermission,
  }) async {
    try {
      AppLogger.info('🔐 Updating permission for member $memberId in recipe $recipeId to ${newPermission.name}');

      // Find the collaborative recipe
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.error('❌ Cannot update permission: Recipe not found or not collaborative');
        return false;
      }

      // Check if user is actually a member
      if (recipe.socialData?.memberPermissions?.containsKey(memberId) != true) {
        AppLogger.error('❌ Cannot update permission: User is not a member');
        return false;
      }

      // Check if current user can manage permissions
      if (!_canManageMembers(recipe)) {
        AppLogger.error('❌ Current user does not have permission to manage member permissions');
        return false;
      }

      // Prevent changing owner permission
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == memberId) {
        AppLogger.error('❌ Cannot change recipe owner permission');
        return false;
      }

      // Update permission
      final currentPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
      final oldPermission = currentPermissions[memberId];
      
      if (oldPermission == newPermission) {
        AppLogger.info('📋 Permission is already set to ${newPermission.name}');
        return true;
      }

      currentPermissions[memberId] = newPermission;

      // Update recipe with new permission
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
        AppLogger.error('❌ Failed to update recipe with new permission');
        return false;
      }

      AppLogger.success('✅ Successfully updated member permission');

      // Log permission change for analytics
      _logMemberAction(
        recipeId: recipeId,
        memberId: memberId,
        action: 'permission_updated',
        permission: newPermission,
        previousPermission: oldPermission,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update member permission', e);
      return false;
    }
  }

  // ===== MEMBER INFORMATION RETRIEVAL =====

  /// Get all members of a collaborative recipe
  /// 
  /// Returns detailed member information including permissions
  Future<List<Map<String, dynamic>>> getRecipeMembers(String recipeId) async {
    try {
      AppLogger.debug('👥 Getting members for recipe $recipeId');

      final recipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.warning('⚠️ Recipe not found or not collaborative');
        return [];
      }

      final members = <Map<String, dynamic>>[];
      final permissions = recipe.socialData?.memberPermissions ?? {};
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      final ownerDisplayName = recipe.socialData?.ownerDisplayName ?? 'Okänd användare';

      // Add recipe owner first
      if (ownerId != null) {
        members.add({
          'userId': ownerId,
          'displayName': ownerDisplayName,
          'permission': ResourcePermission.owner,
          'isOwner': true,
          'joinedAt': recipe.createdAt,
        });
      }

      // Add other members
      for (final entry in permissions.entries) {
        final memberId = entry.key;
        final permission = entry.value;
        if (memberId != ownerId) { // Skip owner (already added)
          members.add({
            'userId': memberId,
            'displayName': 'Okänd användare', // Display names not stored in permissions
            'permission': permission,
            'isOwner': false,
            'joinedAt': null, // Could be tracked in future versions
          });
        }
      }

      AppLogger.debug('📋 Found ${members.length} members for recipe');
      return members;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe members', e);
      return [];
    }
  }

  /// Check if current user can invite members to recipe
  /// 
  /// Validates invitation permissions based on user role and recipe settings
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
        'has_editors': permissions.values.any((p) => p == ResourcePermission.editor),
        'has_admins': permissions.values.any((p) => p == ResourcePermission.admin),
        'allow_member_invites': recipe.socialData?.allowMemberInvites ?? true,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get member statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  // ===== MEMBER NOTIFICATIONS =====

  /// Send notification when member is added to recipe
  Future<void> _sendMemberAddedNotification({
    required String recipeId,
    required String recipeTitle,
    required String newMemberId,
    required String newMemberName,
    required ResourcePermission permission,
  }) async {
    if (_notificationService == null) return;

    try {
      final currentUserName = _parent.currentUserDisplayName ?? 'En användare';

      await _notificationService.sendImmediateNotification(
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

      AppLogger.info('📬 Sent member added notification to $newMemberId');
    } catch (e) {
      AppLogger.error('❌ Failed to send member added notification', e);
    }
  }

  /// Send notification when member is removed from recipe
  Future<void> _sendMemberRemovedNotification({
    required String recipeId,
    required String recipeTitle,
    required String removedMemberId,
  }) async {
    if (_notificationService == null) return;

    try {
      final currentUserName = _parent.currentUserDisplayName ?? 'En användare';

      // Send a silent notification for member removal
      await _notificationService.sendSilentNotification(
        targetUserIds: [removedMemberId],
        data: {
          'type': 'member_removed',
          'recipeId': recipeId,
          'recipeTitle': recipeTitle,
          'removedBy': currentUserName,
        },
      );

      AppLogger.info('📬 Sent member removed notification to $removedMemberId');
    } catch (e) {
      AppLogger.error('❌ Failed to send member removed notification', e);
    }
  }

  // ===== PERMISSION HELPERS =====

  /// Check if current user can invite members to recipe
  bool _canInviteMembers(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    // Recipe owner can always invite
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    // Check if recipe allows member invites
    final allowMemberInvites = recipe.socialData?.allowMemberInvites ?? true;
    if (!allowMemberInvites) return false;

    // Check user permission level
    final userPermission = recipe.socialData?.memberPermissions?[currentUserId] ?? ResourcePermission.viewer;
    return userPermission == ResourcePermission.admin || userPermission == ResourcePermission.editor;
  }

  /// Check if current user can manage members (add/remove/change permissions)
  bool _canManageMembers(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    // Recipe owner can always manage
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    // Only admins can manage members
    final userPermission = recipe.socialData?.memberPermissions?[currentUserId] ?? ResourcePermission.viewer;
    return userPermission == ResourcePermission.admin;
  }

  // ===== ANALYTICS AND LOGGING =====

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

      AppLogger.info('📊 Member action logged: $action');
      // This could be expanded to send analytics events
      // Analytics.logEvent('recipe_member_action', logData);
    } catch (e) {
      AppLogger.warning('⚠️ Failed to log member action: $e');
    }
  }
}