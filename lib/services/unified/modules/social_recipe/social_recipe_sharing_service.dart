// lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Social Recipe Sharing Service
/// 
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

  SocialRecipeSharingService({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _setError = setError,
       _notifyListeners = notifyListeners,
       _getRecipe = getRecipe,
       _saveRecipe = saveRecipe;

  /// Share a personal recipe with specific users
  Future<bool> shareRecipeWithUsers(
      String recipeId, List<String> userIds, ResourcePermission permission) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      AppLogger.info('Sharing recipe $recipeId with ${userIds.length} users');
      
      // 1. Loading the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        _setError('Receptet kunde inte hittas');
        return false;
      }

      // Check if current user can share this recipe
      if (recipe.createdBy != currentUserId && recipe.socialData?.ownerId != currentUserId) {
        _setError('Du har inte behörighet att dela detta recept');
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
        final updatedPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
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
        _setError('Kunde inte spara recept');
        return false;
      }
      
      // Notify UI of changes
      _notifyListeners();
      
      AppLogger.success('Recipe $recipeId shared with ${userIds.length} users');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not share recipe: $e');
      _setError('Kunde inte dela recept: $e');
      return false;
    }
  }

  /// Share recipe with friend categories/groups
  Future<bool> shareRecipeWithGroups(
      String recipeId, List<String> groupIds, ResourcePermission permission) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      AppLogger.info('Sharing recipe $recipeId with ${groupIds.length} groups');
      
      // TODO: Implement group sharing
      // This would involve:
      // 1. Loading the recipe
      // 2. Resolving group IDs to user IDs
      // 3. Converting to collaborative recipe if needed
      // 4. Adding group members with specified permissions
      // 5. Sending notifications
      // 6. Saving to Firebase
      
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not share recipe with groups: $e');
      _setError('Kunde inte dela recept med grupper: $e');
      return false;
    }
  }

  /// Unshare recipe (remove all collaborative access)
  Future<bool> unshareRecipe(String recipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad');
      return false;
    }

    try {
      AppLogger.info('Unsharing recipe $recipeId');
      
      // 1. Loading the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        _setError('Receptet kunde inte hittas');
        return false;
      }

      // 2. Checking owner permissions
      if (!recipe.isCollaborative) {
        _setError('Receptet är inte delat');
        return false;
      }

      if (recipe.socialData?.ownerId != currentUserId) {
        _setError('Endast ägaren kan sluta dela receptet');
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
        _setError('Kunde inte sluta dela recept');
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
      _setError('Kunde inte sluta dela recept: $e');
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
    return RecipeOperationResult.success(message ?? 'Operation completed successfully');
  }

  /// Create failure result for operations
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }
}