// lib/services/unified/operations/modules/recipe_member_manager.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/operations/modules/recipe_share_grants.dart';

/// Collaborative recipe membership management module
class RecipeMemberManager {
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final List<Recipe> Function() _getRecipes;
  final Future<bool> Function(Recipe) _updateRecipe;
  final NotificationService? _notificationService;

  RecipeMemberManager({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<Recipe> Function() getRecipes,
    required Future<bool> Function(Recipe) updateRecipe,
    required NotificationService? notificationService,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _getRecipes = getRecipes,
       _updateRecipe = updateRecipe,
       _notificationService = notificationService;

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
      final recipe = _getRecipes()
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
        recipe.socialData?.memberPermissions ?? {},
      );
      currentPermissions[memberId] = permission;
      // `RecipeSocialData` is rebuilt through `copyWith` throughout this file,
      // never field by field: one of these enumerated seven of its eight fields
      // and silently deleted `grants`, disarming the group revoke for the whole
      // recipe. A rebuild that never enumerates cannot lose a field added later
      // either. (The `Recipe(...)` construction below is a different object; it
      // passes all five of its fields today, so it carries the same future-field
      // hazard — it is simply not the one that bit us.)
      final updatedSocialData = (recipe.socialData ?? const RecipeSocialData())
          .copyWith(
            memberPermissions: currentPermissions,
            grants: RecipeShareGrants.add(
              recipe.socialData?.grants,
              memberId,
              RecipeSocialData.directGrant,
            ),
          );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _updateRecipe(updatedRecipe);
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

      final recipe = _getRecipes()
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.error(
          'Cannot remove member: Recipe not found or not collaborative',
        );
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
          'Current user does not have permission to remove members',
        );
        return false;
      }

      final currentPermissions = Map<String, ResourcePermission>.from(
        recipe.socialData?.memberPermissions ?? {},
      );
      currentPermissions.remove(memberId);

      // An explicit "remove this person" overrides every grant at once, so the
      // whole entry goes — not just the direct one. Leaving a stale group grant
      // behind would make a later group-revoke look like it had already run.
      final updatedGrants = RecipeShareGrants.dropMember(
        recipe.socialData?.grants,
        memberId,
      );

      final updatedSocialData = recipe.socialData!.copyWith(
        memberPermissions: currentPermissions,
        grants: updatedGrants,
      );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _updateRecipe(updatedRecipe);
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

  /// Revoke a shared GROUP's access to a collaborative recipe.
  ///
  /// BUT-1797: this now genuinely revokes. It could not before, and the reason
  /// is worth keeping: access lives in `memberPermissions`, the group share
  /// expanded a group into individual entries, and nothing recorded WHERE an
  /// entry came from. Without that provenance "remove the group's members" would
  /// have silently cut people who were invited individually, so the method only
  /// dropped the display label and the UI copy said so.
  ///
  /// `socialData.grants` supplies the provenance. Each member's list says why
  /// they are here — `'direct'`, `'group:<categoryId>'`, or several at once —
  /// and revoking a group removes only that group's reason. A member is cut when
  /// they have no reason left.
  ///
  /// **Malin's decision, 2026-08-03:** someone who ALSO holds a direct share
  /// keeps access. Two separate decisions were made about that person; only one
  /// is being undone.
  ///
  /// `memberPermissions` remains the sole source of truth for access, and
  /// `firestore.rules` still reads only that — `grants` never widens anything on
  /// its own. `categoryIds` stays a display/filter field
  /// (`recipe_discovery_service.getSharedWithMe`/`getCollaborativeRecipes` apply
  /// it only AFTER the membership check).
  ///
  /// A recipe with no `grants` at all has no member holding a group grant, so
  /// only the label drops. That is deliberate: the field is written from the
  /// start and the only documents without it are test data, so a "treat missing
  /// grants as all-direct" path would be dead code (Malin, 2026-08-03).
  Future<bool> removeGroup({
    required String recipeId,
    required String groupId,
  }) async {
    try {
      AppLogger.info('Removing group $groupId from recipe $recipeId');

      final recipe = _getRecipes()
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.error(
          'Cannot remove group: Recipe not found or not collaborative',
        );
        return false;
      }

      final currentCategoryIds = recipe.socialData?.categoryIds ?? const [];
      if (!currentCategoryIds.contains(groupId)) {
        AppLogger.warning(
          'Group $groupId is not shared on recipe $recipeId',
        );
        return false;
      }

      if (!_canManageMembers(recipe)) {
        AppLogger.error(
          'Current user does not have permission to remove shared groups',
        );
        return false;
      }

      final updatedCategoryIds = currentCategoryIds
          .where((id) => id != groupId)
          .toList();

      final revocation = RecipeShareGrants.revokeGroup(
        grants: recipe.socialData?.grants,
        permissions: recipe.socialData?.memberPermissions,
        groupId: groupId,
        // The owner is never cut by a group revoke, whatever the grants say —
        // the same invariant removeMember enforces explicitly.
        ownerId: recipe.socialData?.ownerId ?? recipe.createdBy,
      );

      final updatedSocialData = (recipe.socialData ?? const RecipeSocialData())
          .copyWith(
            memberPermissions: revocation.permissions,
            categoryIds: updatedCategoryIds,
            grants: revocation.grants,
          );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _updateRecipe(updatedRecipe);
      if (!success) {
        AppLogger.error('Failed to update recipe after group removal');
        return false;
      }

      AppLogger.success(
        'Revoked group $groupId from recipe: '
        '${revocation.removedMemberIds.length} member(s) lost access, '
        '${revocation.retainedMemberIds.length} kept it (another grant, or ownership)',
      );

      for (final removedId in revocation.removedMemberIds) {
        await _sendMemberRemovedNotification(
          recipeId: recipeId,
          recipeTitle: recipe.title,
          removedMemberId: removedId,
        );
      }

      _logMemberAction(
        recipeId: recipeId,
        memberId: groupId,
        action: 'group_removed',
      );

      return true;
    } catch (e) {
      AppLogger.error('Failed to remove group from recipe', e);
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
        'Updating permission for member $memberId in recipe $recipeId to ${newPermission.name}',
      );

      final recipe = _getRecipes()
          .where((r) => r.id == recipeId && r.isCollaborative)
          .firstOrNull;

      if (recipe == null) {
        AppLogger.error(
          'Cannot update permission: Recipe not found or not collaborative',
        );
        return false;
      }

      if (recipe.socialData?.memberPermissions?.containsKey(memberId) != true) {
        AppLogger.error('Cannot update permission: User is not a member');
        return false;
      }

      if (!_canManageMembers(recipe)) {
        AppLogger.error(
          'Current user does not have permission to manage member permissions',
        );
        return false;
      }

      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == memberId) {
        AppLogger.error('Cannot change recipe owner permission');
        return false;
      }

      final currentPermissions = Map<String, ResourcePermission>.from(
        recipe.socialData?.memberPermissions ?? {},
      );
      final oldPermission = currentPermissions[memberId];

      if (oldPermission == newPermission) {
        AppLogger.info('Permission is already set to ${newPermission.name}');
        return true;
      }

      currentPermissions[memberId] = newPermission;

      // `copyWith`, not a field-by-field rebuild. This enumerated seven of the
      // eight fields and silently dropped `grants` — and because the document is
      // written whole, that DELETES the provenance rather than leaving it alone.
      // One permission change then disarmed `removeGroup` for the whole recipe:
      // it took the no-grants branch, cut nobody, and still reported success.
      // A rebuild cannot fail that way if it never enumerates.
      final updatedSocialData = recipe.socialData!.copyWith(
        memberPermissions: currentPermissions,
      );

      final updatedRecipe = Recipe(
        core: recipe.core,
        type: recipe.type,
        socialData: updatedSocialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      final success = await _updateRecipe(updatedRecipe);
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

      final recipe = _getRecipes()
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
      final recipe = _getRecipes()
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
      final recipe = _getRecipes()
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
        'has_editors': permissions.values.any(
          (p) => p == ResourcePermission.editor,
        ),
        'has_admins': permissions.values.any(
          (p) => p == ResourcePermission.admin,
        ),
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
    final currentUserName = _getCurrentUserDisplayName() ?? '?';

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
    final currentUserName = _getCurrentUserDisplayName() ?? '?';

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
    final currentUserId = _getCurrentUserId();
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
    final currentUserId = _getCurrentUserId();
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
        'performedBy': _getCurrentUserId(),
        'timestamp': clock.now().toIso8601String(),
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
