// lib/core/permissions/modules/recipe_permission_handler.dart

import 'base_permission_manager.dart';

/// Focused module for recipe permission handling
/// 
/// This module handles ONLY recipe-specific permissions:
/// - Recipe viewing, editing, deleting permissions
/// - Recipe ownership validation
/// - Recipe sharing and interaction permissions
/// - Recipe-specific permission queries
/// 
/// ❌ DOES NOT CONTAIN: Action builders, permission levels, other resource types
class RecipePermissionHandler {

  // ===== CORE RECIPE PERMISSIONS =====

  /// Check if user can view a recipe
  static bool canViewRecipe(String recipeId) {
    return BasePermissionManager.permissionService.canViewRecipe(recipeId);
  }

  /// Check if user can edit a recipe
  static bool canEditRecipe(String recipeId) {
    return BasePermissionManager.permissionService.canEditRecipe(recipeId);
  }

  /// Check if user can delete a recipe
  static bool canDeleteRecipe(String recipeId) {
    return BasePermissionManager.permissionService.canDeleteRecipe(recipeId);
  }

  /// Check if user can share a recipe
  static bool canShareRecipe(String recipeId) {
    return BasePermissionManager.permissionService.canShareRecipe(recipeId);
  }

  // ===== RECIPE OWNERSHIP =====

  /// Check if user is the owner of a recipe
  static bool isRecipeOwner(String recipeId) {
    return BasePermissionManager.permissionService.isRecipeOwner(recipeId);
  }

  /// Check if recipe belongs to current user
  static bool isOwnRecipe(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  // ===== DERIVED RECIPE PERMISSIONS =====

  /// Check if user can duplicate a recipe
  static bool canDuplicateRecipe(String recipeId) {
    // Can duplicate if can view
    return canViewRecipe(recipeId);
  }

  /// Check if user can comment on a recipe
  static bool canCommentOnRecipe(String recipeId) {
    // Can comment if can view
    return canViewRecipe(recipeId);
  }

  /// Check if user can rate a recipe
  static bool canRateRecipe(String recipeId) {
    // Can rate if can view
    return canViewRecipe(recipeId);
  }

  /// Check if user can add recipe to favorites
  static bool canFavoriteRecipe(String recipeId) {
    // Can favorite if can view
    return canViewRecipe(recipeId);
  }

  /// Check if user can export recipe
  static bool canExportRecipe(String recipeId) {
    // Can export if can view
    return canViewRecipe(recipeId);
  }

  /// Check if user can print recipe
  static bool canPrintRecipe(String recipeId) {
    // Can print if can view
    return canViewRecipe(recipeId);
  }

  // ===== RECIPE ACCESS VALIDATION =====

  /// Check if user has any access to recipe
  static bool hasRecipeAccess(String recipeId) {
    return canViewRecipe(recipeId);
  }

  /// Check if user has read access to recipe
  static bool hasReadAccess(String recipeId) {
    return canViewRecipe(recipeId);
  }

  /// Check if user has write access to recipe
  static bool hasWriteAccess(String recipeId) {
    return canEditRecipe(recipeId);
  }

  /// Check if user has admin access to recipe
  static bool hasAdminAccess(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  // ===== RECIPE INTERACTION PERMISSIONS =====

  /// Check if user can create recipes
  static bool canCreateRecipes() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can fork recipe (create copy)
  static bool canForkRecipe(String recipeId) {
    return canViewRecipe(recipeId) && BasePermissionManager.isAuthenticated;
  }

  /// Check if user can modify recipe metadata
  static bool canModifyRecipeMetadata(String recipeId) {
    return canEditRecipe(recipeId);
  }

  /// Check if user can modify recipe content
  static bool canModifyRecipeContent(String recipeId) {
    return canEditRecipe(recipeId);
  }

  /// Check if user can manage recipe permissions
  static bool canManageRecipePermissions(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  // ===== RECIPE COLLABORATION PERMISSIONS =====

  /// Check if user can invite others to recipe
  static bool canInviteToRecipe(String recipeId) {
    return canShareRecipe(recipeId);
  }

  /// Check if user can manage recipe collaborators
  static bool canManageRecipeCollaborators(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  /// Check if user can remove recipe collaborators
  static bool canRemoveRecipeCollaborators(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  /// Check if user can start real-time editing
  static bool canStartRealtimeEditing(String recipeId) {
    return canEditRecipe(recipeId);
  }

  // ===== RECIPE VISIBILITY PERMISSIONS =====

  /// Check if user can make recipe public
  static bool canMakeRecipePublic(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  /// Check if user can make recipe private
  static bool canMakeRecipePrivate(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  /// Check if user can change recipe visibility
  static bool canChangeRecipeVisibility(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  // ===== RECIPE VALIDATION =====

  /// Validate recipe ID format
  static bool isValidRecipeId(String recipeId) {
    return recipeId.isNotEmpty && recipeId.trim().isNotEmpty;
  }

  /// Check if recipe exists and user has access
  static bool validateRecipeAccess(String recipeId) {
    if (!isValidRecipeId(recipeId)) return false;
    return hasRecipeAccess(recipeId);
  }

  /// Get recipe permission validation result
  static Map<String, bool> validateAllRecipePermissions(String recipeId) {
    return {
      'canView': canViewRecipe(recipeId),
      'canEdit': canEditRecipe(recipeId),
      'canDelete': canDeleteRecipe(recipeId),
      'canShare': canShareRecipe(recipeId),
      'isOwner': isRecipeOwner(recipeId),
      'canDuplicate': canDuplicateRecipe(recipeId),
      'canComment': canCommentOnRecipe(recipeId),
      'canRate': canRateRecipe(recipeId),
      'canFavorite': canFavoriteRecipe(recipeId),
    };
  }

  // ===== RECIPE PERMISSION CONTEXT =====

  /// Create permission context for recipe operations
  static Map<String, dynamic> createRecipePermissionContext(String recipeId) {
    return {
      'recipeId': recipeId,
      'userId': BasePermissionManager.currentUserId,
      'permissions': validateAllRecipePermissions(recipeId),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on recipe
  static bool canPerformRecipeOperation(String recipeId, String operation) {
    switch (operation.toLowerCase()) {
      case 'view':
        return canViewRecipe(recipeId);
      case 'edit':
        return canEditRecipe(recipeId);
      case 'delete':
        return canDeleteRecipe(recipeId);
      case 'share':
        return canShareRecipe(recipeId);
      case 'duplicate':
        return canDuplicateRecipe(recipeId);
      case 'comment':
        return canCommentOnRecipe(recipeId);
      case 'rate':
        return canRateRecipe(recipeId);
      case 'favorite':
        return canFavoriteRecipe(recipeId);
      case 'export':
        return canExportRecipe(recipeId);
      case 'print':
        return canPrintRecipe(recipeId);
      default:
        return false;
    }
  }
}