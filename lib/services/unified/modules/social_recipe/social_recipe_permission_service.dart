// lib/services/unified/modules/social_recipe/social_recipe_permission_service.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';

/// Social Recipe Permission Service
/// Handles ONLY permission validation and checks for collaborative recipes.
/// This includes checking edit rights, member management rights, and view permissions.
class SocialRecipePermissionService extends BaseService {
  @override
  String get serviceName => 'SocialRecipePermissionService';

  final Future<Recipe?> Function(String) _getRecipe;

  SocialRecipePermissionService({
    required Future<Recipe?> Function(String) getRecipe,
  }) : _getRecipe = getRecipe;

  /// Check if user can edit a recipe
  Future<bool> canEditRecipe(String recipeId, String userId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return false;

      // Personal recipes - only owner can edit
      if (!recipe.isCollaborative) {
        return recipe.createdBy == userId;
      }

      // Collaborative recipes - check permissions
      final permission = recipe.socialData?.memberPermissions?[userId];
      return permission == ResourcePermission.admin ||
          permission == ResourcePermission.editor;
    } catch (e) {
      AppLogger.error('Error checking edit permission: $e');
      return false;
    }
  }

  /// Check if user can manage members of a recipe
  Future<bool> canManageRecipeMembers(String recipeId, String userId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return false;

      // Only collaborative recipes have member management
      if (!recipe.isCollaborative) return false;

      // Owner can always manage members
      if (recipe.socialData?.ownerId == userId) return true;

      // Admin permission can manage members
      final permission = recipe.socialData?.memberPermissions?[userId];
      return permission == ResourcePermission.admin;
    } catch (e) {
      AppLogger.error('Error checking member management permission: $e');
      return false;
    }
  }

  /// Check if user can view a recipe
  Future<bool> canViewRecipe(String recipeId, String userId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return false;

      // Personal recipes - only owner can view
      if (!recipe.isCollaborative) {
        return recipe.createdBy == userId;
      }

      // Owner can always view
      if (recipe.socialData?.ownerId == userId) return true;

      // Check if user is a member
      if (recipe.socialData?.memberPermissions?.containsKey(userId) == true) {
        return true;
      }

      // Check guest viewing settings
      return recipe.socialData?.allowGuestViewing ?? false;
    } catch (e) {
      AppLogger.error('Error checking view permission: $e');
      return false;
    }
  }

  /// Get user's permission level for a recipe
  Future<ResourcePermission?> getUserPermissionForRecipe(
    String recipeId,
    String userId,
  ) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return null;

      // Personal recipes - owner has admin-like access
      if (!recipe.isCollaborative) {
        return recipe.createdBy == userId ? ResourcePermission.admin : null;
      }

      // Owner has admin access
      if (recipe.socialData?.ownerId == userId) {
        return ResourcePermission.admin;
      }

      // Return the user's explicit permission
      return recipe.socialData?.memberPermissions?[userId];
    } catch (e) {
      AppLogger.error('Error getting user permission: $e');
      return null;
    }
  }

  /// Check if user has admin permission for recipe
  Future<bool> hasAdminPermission(String recipeId, String userId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return false;

      // Owner always has admin permission
      if (recipe.createdBy == userId || recipe.socialData?.ownerId == userId) {
        return true;
      }

      // Check explicit admin permission
      return recipe.socialData?.memberPermissions?[userId] ==
          ResourcePermission.admin;
    } catch (e) {
      AppLogger.error('Error checking admin permission: $e');
      return false;
    }
  }

  /// Check if user can share a recipe
  Future<bool> canShareRecipe(String recipeId, String userId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return false;

      // Owner can always share
      if (recipe.createdBy == userId || recipe.socialData?.ownerId == userId) {
        return true;
      }

      // Check if recipe allows member invites and user has permission
      if (recipe.socialData?.allowMemberInvites == true) {
        final permission = recipe.socialData?.memberPermissions?[userId];
        return permission == ResourcePermission.admin ||
            permission == ResourcePermission.editor;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking share permission: $e');
      return false;
    }
  }

  /// Get all users with specific permission level for a recipe
  Future<List<String>> getUsersWithPermission(
    String recipeId,
    ResourcePermission permission,
  ) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null || !recipe.isCollaborative) return [];

      final usersWithPermission = <String>[];

      // Check owner first
      if (permission == ResourcePermission.admin &&
          recipe.socialData?.ownerId != null) {
        usersWithPermission.add(recipe.socialData!.ownerId!);
      }

      // Check member permissions
      recipe.socialData?.memberPermissions?.forEach((userId, userPermission) {
        if (userPermission == permission &&
            !usersWithPermission.contains(userId)) {
          usersWithPermission.add(userId);
        }
      });

      return usersWithPermission;
    } catch (e) {
      AppLogger.error('Error getting users with permission: $e');
      return [];
    }
  }

  /// Check if recipe allows guest viewing
  Future<bool> allowsGuestViewing(String recipeId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      return recipe?.socialData?.allowGuestViewing ?? false;
    } catch (e) {
      AppLogger.error('Error checking guest viewing permission: $e');
      return false;
    }
  }

  /// Check if recipe allows member invites
  Future<bool> allowsMemberInvites(String recipeId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      return recipe?.socialData?.allowMemberInvites ?? false;
    } catch (e) {
      AppLogger.error('Error checking member invite permission: $e');
      return false;
    }
  }
}
