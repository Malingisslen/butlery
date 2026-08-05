// lib/services/unified/modules/social_recipe/social_recipe_membership_service.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/modules/recipe_share_grants.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Social Recipe Membership Service
/// Handles ONLY member management operations for collaborative recipes.
/// This includes adding/removing members, updating permissions, and member validation.
class SocialRecipeMembershipService extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeMembershipService';

  final void Function(String) _setError;
  final Future<Recipe?> Function(String) _getRecipe;
  final Future<bool> Function(Recipe) _saveRecipe;
  final void Function() _notifyListeners;

  SocialRecipeMembershipService({
    required String? Function() getCurrentUserId,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
  }) : _setError = setError,
       _notifyListeners = notifyListeners,
       _getRecipe = getRecipe,
       _saveRecipe = saveRecipe {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
  }

  /// Add member to collaborative recipe with specified permission
  Future<bool> addMemberToRecipe(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async {
    // Validate inputs
    final userIdError = ValidationUtils.validateUserId(userId);
    if (userIdError != null) {
      _handleError(userIdError);
      return false;
    }

    final result = await executeAsUser<bool>((currentUserId) async {
      // 1. Load the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        throw Exception('Recipe not found');
      }

      // 2. Check permissions - only admin can add members
      if (!_hasAdminPermission(recipe, currentUserId)) {
        throw Exception('No permission to add members');
      }

      // 3. Add the member
      final updatedMemberPermissions = Map<String, ResourcePermission>.from(
        recipe.socialData?.memberPermissions ?? {},
      );
      updatedMemberPermissions[userId] = permission;

      // BUT-1797: record WHY they have access, exactly as RecipeMemberManager
      // does. This is one of the membership paths the first pass missed — a sibling to
      // the two group-share paths that ticket fixed. Without the grant, someone
      // added here who is later swept into a group share holds only that group's
      // token, so revoking the group CUTS them: the one outcome Malin's decision
      // of 2026-08-03 forbids.
      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMemberPermissions,
          grants: RecipeShareGrants.add(
            recipe.socialData?.grants,
            userId,
            RecipeSocialData.directGrant,
          ),
        ),
      );

      // 4. Save back to Firebase and cache
      final success = await _saveRecipe(updatedRecipe);
      if (success) {
        _notifyListeners(); // Notify UI of changes
        AppLogger.success('✅ Added member to recipe: ${userId.maskedUserId}');
      }

      return success;
    }, operationName: 'Add recipe member');
    return result ?? false;
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    final result = await executeAsUser<bool>((currentUserId) async {
      // 1. Load the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        throw Exception('Recipe not found');
      }

      // 2. Check admin permissions - only admin can remove members
      if (!_hasAdminPermission(recipe, currentUserId)) {
        throw Exception('No permission to remove members');
      }

      // 3. Remove the member
      final updatedMemberPermissions = Map<String, ResourcePermission>.from(
        recipe.socialData?.memberPermissions ?? {},
      );
      updatedMemberPermissions.remove(userId);

      // BUT-1797: an explicit removal overrides every reason at once, so the
      // member's whole grants entry goes with the permission. A stale entry left
      // here would make a later group revoke count a ghost — reporting them as
      // newly cut and re-notifying someone already gone.
      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMemberPermissions,
          grants: RecipeShareGrants.dropMember(
            recipe.socialData?.grants,
            userId,
          ),
        ),
      );

      // 4. Save back to Firebase and cache
      final success = await _saveRecipe(updatedRecipe);
      if (success) {
        _notifyListeners(); // Notify UI of changes
        AppLogger.success(
          '✅ Removed member from recipe: ${userId.maskedUserId}',
        );
      }

      return success;
    }, operationName: 'Remove recipe member');
    return result ?? false;
  }

  /// Update member permission for collaborative recipe
  Future<bool> updateMemberPermission(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async {
    final result = await executeAsUser<bool>((currentUserId) async {
      // 1. Load the recipe
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        throw Exception('Recipe not found');
      }

      // 2. Check admin permissions - only admin can update permissions
      if (!_hasAdminPermission(recipe, currentUserId)) {
        throw Exception('No permission to update permissions');
      }

      // 3. Update the permission
      final updatedMemberPermissions = Map<String, ResourcePermission>.from(
        recipe.socialData?.memberPermissions ?? {},
      );
      // BUT-1797: this is named "update" but has no is-already-a-member guard,
      // so it can INTRODUCE one. A member created here with no recorded reason
      // would later be cut by revoking a group they were swept into — access
      // granted by an individual act, withdrawn by a group one.
      final introducesMember = !updatedMemberPermissions.containsKey(userId);
      updatedMemberPermissions[userId] = permission;

      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMemberPermissions,
          // An existing member keeps the provenance they had: changing someone's
          // permission is not a reason to rewrite why they are here.
          grants: introducesMember
              ? RecipeShareGrants.add(
                  recipe.socialData?.grants,
                  userId,
                  RecipeSocialData.directGrant,
                )
              : recipe.socialData?.grants,
        ),
      );

      // 4. Save back to Firebase and cache
      final success = await _saveRecipe(updatedRecipe);
      if (success) {
        _notifyListeners(); // Notify UI of changes
        AppLogger.success(
          '✅ Updated member permission: ${userId.maskedUserId} -> $permission',
        );
      }

      return success;
    }, operationName: 'Update recipe member permission');
    return result ?? false;
  }

  /// Get all members of a collaborative recipe with their permissions
  Future<Map<String, ResourcePermission>> getRecipeMembers(
    String recipeId,
  ) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        AppLogger.warning('Recipe not found: $recipeId');
        return {};
      }

      return recipe.socialData?.memberPermissions ?? {};
    } catch (e) {
      AppLogger.error('Failed to get recipe members', e);
      _handleError('Failed to get recipe members: $e');
      return {};
    }
  }

  /// Check if user has admin permission for recipe
  bool _hasAdminPermission(Recipe recipe, String userId) {
    return recipe.socialData?.memberPermissions?[userId] ==
        ResourcePermission.admin;
  }

  /// Helper method for error handling
  void _handleError(String message) {
    AppLogger.error('❌ SocialRecipeMembershipService: $message');
    _setError(message);
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
}
