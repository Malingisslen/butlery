// lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Social Recipe Sharing Service
/// Handles ONLY sharing and unsharing operations for recipes.
/// This includes sharing with users, groups, and managing shared access.
class SocialRecipeSharingService extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeSharingService';

  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final Future<Recipe?> Function(String) _getRecipe;
  final Future<bool> Function(Recipe) _saveRecipe;
  final void Function() _notifyListeners;
  final FirebaseSharedRecipeRepository _sharedRecipeRepository;

  SocialRecipeSharingService({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    required FirebaseSharedRecipeRepository sharedRecipeRepository,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _setError = setError,
       _notifyListeners = notifyListeners,
       _getRecipe = getRecipe,
       _saveRecipe = saveRecipe,
       _sharedRecipeRepository = sharedRecipeRepository {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
  }

  /// Share a personal recipe with specific users
  Future<bool> shareRecipeWithUsers(
    String recipeId,
    List<String> userIds,
    ResourcePermission permission,
  ) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError(AppLocale.current.errorMustBeLoggedIn);
      return false;
    }

    try {
      AppLogger.info('Sharing recipe $recipeId with ${userIds.length} users');

      // 1. Loading the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        _setError(AppLocale.current.errorRecipeNotFound);
        return false;
      }

      // Check if current user can share this recipe
      if (recipe.createdBy != currentUserId &&
          recipe.socialData?.ownerId != currentUserId) {
        _setError(AppLocale.current.errorNoPermissionToShare);
        return false;
      }

      // BUT-955: cap-guard. Existing members + owner + new userIds (deduped)
      // must fit under the Recipe.maxSharesPerRecipe ceiling. Computed against
      // the union so re-share calls don't double-count existing members.
      final existing =
          recipe.socialData?.memberPermissions?.keys.toSet() ?? <String>{};
      final projected = {currentUserId, ...existing, ...userIds};
      if (projected.length > Recipe.maxSharesPerRecipe) {
        AppLogger.warning(
          'Share denied: recipe $recipeId would have ${projected.length} '
          'shares (cap: ${Recipe.maxSharesPerRecipe})',
        );
        _setError(
          AppLocale.current.errorShareCapReached(Recipe.maxSharesPerRecipe),
        );
        return false;
      }

      // 2. Converting to collaborative recipe if needed
      Recipe updatedRecipe;
      if (!recipe.isCollaborative) {
        // Convert personal recipe to collaborative
        final memberPermissions = <String, ResourcePermission>{};
        for (final userId in userIds) {
          memberPermissions[userId] = permission;
        }
        memberPermissions[currentUserId] = ResourcePermission.admin;

        updatedRecipe = recipe.copyWith(
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: currentUserId,
            ownerDisplayName: _getCurrentUserDisplayName(),
            memberPermissions: memberPermissions,
            allowGuestViewing: false,
            allowMemberInvites: true,
          ),
        );
      } else {
        // 3. Adding users with specified permissions to existing collaborative recipe
        final updatedPermissions = Map<String, ResourcePermission>.from(
          recipe.socialData?.memberPermissions ?? {},
        );
        for (final userId in userIds) {
          updatedPermissions[userId] = permission;
        }

        updatedRecipe = recipe.copyWith(
          socialData: recipe.socialData?.copyWith(
            memberPermissions: updatedPermissions,
          ),
        );
      }

      // 5. Saving to Firebase
      final success = await _saveRecipe(updatedRecipe);
      if (!success) {
        _setError(AppLocale.current.errorCouldNotSaveRecipe);
        return false;
      }

      // 6. ALSO write to shared_recipes collection for group content queries
      try {
        // Create SharedRecipe entry for query purposes (Issue #014: members added via subcollection)
        final sharedRecipe = SharedRecipe.create(
          originalRecipeId: recipeId,
          sharedByUserId: currentUserId,
          sharedByDisplayName: _getCurrentUserDisplayName() ?? 'Unknown',
          sharedToUserIds: userIds,
          recipeSnapshot: updatedRecipe,
          allowCollaboration:
              permission == ResourcePermission.admin ||
              permission == ResourcePermission.editor,
        );

        // Note (Issue #014): Pass recipientIds separately since arrays removed from model
        await _sharedRecipeRepository.createSharedRecipe(
          sharedRecipe,
          recipientIds: userIds,
        );

        AppLogger.debug('✅ Recipe also written to shared_recipes collection');
      } catch (e) {
        // BUT-1131: secondary `shared_recipes` write failed AFTER the primary
        // recipe save succeeded. Bump severity warning → error (this is rare
        // and worth investigating in logs) and surface a sanitised message
        // via setError so the UI can prompt the user to retry if the
        // recipient can't find the share. We still return `true` because the
        // primary write succeeded — rules-based access works without the
        // secondary doc; it's only a query-optimisation.
        AppLogger.error(
          'Failed to write to shared_recipes collection (non-critical): $e',
        );
        _setError(AppLocale.current.errorSharedRecipeMayNotBeVisible);
      }

      // Notify UI of changes
      _notifyListeners();

      AppLogger.success('Recipe $recipeId shared with ${userIds.length} users');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not share recipe: $e');
      _setError(AppLocale.current.errorCouldNotSaveRecipe);
      return false;
    }
  }

  /// Share recipe with friend categories/groups
  Future<bool> shareRecipeWithGroups(
    String recipeId,
    List<String> groupIds,
    ResourcePermission permission,
  ) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError(AppLocale.current.errorMustBeLoggedIn);
      return false;
    }

    try {
      AppLogger.info('Sharing recipe $recipeId with ${groupIds.length} groups');

      // Resolve group IDs to member user IDs
      final allMemberIds = <String>{};

      for (final groupId in groupIds) {
        final groupMembers = await _resolveGroupMembers(groupId);
        allMemberIds.addAll(groupMembers.keys);
      }

      // Don't share with yourself
      allMemberIds.remove(currentUserId);

      if (allMemberIds.isEmpty) {
        _setError(AppLocale.current.errorNoGroupMembersFound);
        return false;
      }

      // Use existing shareRecipeWithUsers method for actual sharing
      final success = await shareRecipeWithUsers(
        recipeId,
        allMemberIds.toList(),
        permission,
      );

      if (success) {
        AppLogger.success(
          '✅ Recipe shared with ${allMemberIds.length} group members',
        );
      }

      return success;
    } catch (e) {
      AppLogger.error('❌ Could not share recipe with groups: $e');
      _setError(AppLocale.current.errorCouldNotShareRecipeWithGroups);
      return false;
    }
  }

  /// Unshare recipe (remove all collaborative access)
  Future<bool> unshareRecipe(String recipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError(AppLocale.current.errorMustBeLoggedIn);
      return false;
    }

    try {
      AppLogger.info('Unsharing recipe $recipeId');

      // 1. Loading the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        _setError(AppLocale.current.errorRecipeNotFound);
        return false;
      }

      // 2. Checking owner permissions
      if (!recipe.isCollaborative) {
        _setError(AppLocale.current.errorRecipeNotShared);
        return false;
      }

      if (recipe.socialData?.ownerId != currentUserId) {
        _setError(AppLocale.current.errorOnlyOwnerCanUnshare);
        return false;
      }

      // Get member list for notifications before removing them (for future notification implementation)
      // final memberIds = recipe.socialData?.memberPermissions?.keys.where((id) => id != currentUserId).toList() ?? [];

      // 3. Converting back to personal recipe
      final unsharedRecipe = recipe.copyWith(
        type: RecipeType.personal,
        socialData: null, // Remove all social data
      );

      // 6. Saving to personal collection
      final success = await _saveRecipe(unsharedRecipe);
      if (!success) {
        _setError(AppLocale.current.errorCouldNotUnshareRecipe);
        return false;
      }

      // Notify affected members (optional)
      // await sendUnshareNotifications(recipeId, memberIds);

      // Notify UI of changes
      _notifyListeners();

      AppLogger.success('Recipe $recipeId unshared');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not unshare recipe: $e');
      _setError(AppLocale.current.errorCouldNotUnshareRecipe);
      return false;
    }
  }

  /// Check if recipe is currently shared
  Future<bool> isRecipeShared(String recipeId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      return recipe?.isCollaborative ?? false;
    } catch (e) {
      AppLogger.error('Failed to check if recipe is shared', e);
      return false;
    }
  }

  /// Get list of users a recipe is shared with
  Future<List<String>> getSharedUsers(String recipeId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe?.socialData?.memberPermissions == null) {
        return [];
      }

      return recipe!.socialData!.memberPermissions!.keys.toList();
    } catch (e) {
      AppLogger.error('Failed to get shared users', e);
      return [];
    }
  }

  /// Create success result for operations
  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(
      message ?? 'Operation completed successfully',
    );
  }

  /// Create failure result for operations
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  /// Resolve group IDs to member user IDs and display names
  /// ✅ FIXED: Integrated with friends service for actual group member resolution
  Future<Map<String, String>> _resolveGroupMembers(String groupId) async {
    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();

      // Get the group (friend category) by ID
      final group = friendsService.getCategoryByIdInternal(groupId);
      if (group == null) {
        AppLogger.warning('Group $groupId not found');
        return <String, String>{};
      }

      AppLogger.debug(
        'Resolving ${group.friendUserIds.length} members for group "${group.name}"',
      );

      // Get all friends to map user IDs to display names
      final allFriends = friendsService.friends;
      final memberMap = <String, String>{};

      // Resolve each group member ID to display name
      for (final memberId in group.friendUserIds) {
        final friend = allFriends.where((f) => f.uid == memberId).firstOrNull;
        if (friend != null) {
          memberMap[memberId] = friend.displayName;
        } else {
          // If friend not found, use fallback display name
          memberMap[memberId] = AppLocale.current.displayUnknownUser;
          AppLogger.warning('Friend $memberId not found in friends list');
        }
      }

      AppLogger.success(
        'Resolved ${memberMap.length} group members for group "${group.name}"',
      );
      return memberMap;
    } catch (e) {
      AppLogger.error('Error resolving group members for $groupId: $e');
      return <String, String>{};
    }
  }
}
