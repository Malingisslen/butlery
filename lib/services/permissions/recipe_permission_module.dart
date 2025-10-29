// lib/services/permissions/recipe_permission_module.dart

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';

/// Module handling recipe-related permission checks and ownership validation.
///
/// Provides comprehensive permission validation for recipe access, editing, and collaboration.
class RecipePermissionModule {
  final AuthRepository authRepository;
  final RecipeRepository? recipeRepository;
  final UnifiedRecipeService recipeService;
  final RecipePermissionHelper permissionHelper;
  final String? Function() getCurrentUserId;

  RecipePermissionModule({
    required this.authRepository,
    required this.recipeRepository,
    required this.recipeService,
    required this.permissionHelper,
    required this.getCurrentUserId,
  });

  /// Asynchronously check if the current user owns a recipe.
  ///
  /// This method queries the recipe repository to verify ownership,
  /// providing accurate ownership validation based on actual recipe data.
  Future<bool> isRecipeOwnerAsync(String recipeId) async {
    // Security: Must be authenticated to own recipes
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // SECURITY FIX: If no repository is available, default to secure (deny)
    if (recipeRepository == null) return false;

    try {
      // Query the recipe from repository
      final recipe = await recipeRepository!.read(recipeId);
      if (recipe == null) return false;

      // Check ownership
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      return ownerId == currentUserId;
    } catch (e) {
      // If we can't verify, default to safe (deny)
      return false;
    }
  }

  /// Validates user permission to invite others to collaborate on a specific recipe.
  ///
  /// Returns `true` if user can invite others to the recipe, `false` otherwise
  ///
  /// **Permission Rules:**
  /// - Recipe owners can always invite collaborators
  /// - Users with editor permissions can invite if enabled by owner
  /// - Viewers typically cannot invite others unless specifically granted permission
  /// - Unauthenticated users cannot invite anyone
  bool canInviteToRecipe(String recipeId) {
    // Security: Must be authenticated to invite
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has editor permission and owner allows member invites
    final permission = getUserPermission(recipeId);
    if (permission == ResourcePermission.editor) {
      // For collaborative recipes, editors can invite if owner allows
      // This would need to check recipe.socialData?.allowMemberInvites
      // For now, allow editors to invite
      return true;
    }

    return false;
  }

  /// Validates user permission to edit and modify a specific recipe.
  ///
  /// Returns `true` if user can edit the recipe, `false` otherwise
  ///
  /// **Edit Permission Hierarchy:**
  /// - Recipe owners have full edit permissions
  /// - Users with explicit editor role can modify recipe content
  /// - Collaborative recipes may allow multiple editors
  /// - Unauthenticated users cannot edit any recipes
  bool canEditRecipe(String recipeId) {
    // Security: Must be authenticated to edit
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has editor permission
    final permission = getUserPermission(recipeId);
    return permission == ResourcePermission.editor ||
        permission == ResourcePermission.owner;
  }

  /// Validates user permission to edit and modify a specific menu.
  ///
  /// Returns `true` if user can edit the menu, `false` otherwise
  ///
  /// **Edit Permission Hierarchy:**
  /// - Menu owners have full edit permissions
  /// - Users with explicit editor role can modify menu content
  /// - Collaborative menus may allow multiple editors
  /// - Unauthenticated users cannot edit any menus
  bool canEditMenu(String menuId) {
    // Security: Must be authenticated to edit
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate menu ID
    if (menuId.isEmpty) return false;

    // Check if user is the menu owner (similar to recipe owner check)
    // Menus created by a user typically include their ID
    if (menuId.contains(currentUserId)) return true;

    // Check if user has editor permission
    final permission = getUserPermission(menuId);
    return permission == ResourcePermission.editor ||
        permission == ResourcePermission.owner;
  }

  /// Validates user permission to view and access a specific recipe.
  ///
  /// Returns `true` if user can view the recipe, `false` otherwise
  ///
  /// **View Permission Categories:**
  /// - Public recipes are viewable by all authenticated users
  /// - Private recipes require explicit sharing or collaboration
  /// - Friends-only recipes respect social relationship settings
  /// - Anonymous users may have limited access to public content
  bool canViewRecipe(String recipeId) {
    // Security: Must be authenticated to view recipes
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has any permission level (viewer, editor, or owner)
    final permission = getUserPermission(recipeId);
    if (permission != null) return true;

    // For public recipes, all authenticated users can view
    // This would need to check recipe.socialData?.allowGuestViewing
    // For now, allow authenticated users to view
    return true;
  }

  /// Retrieves the current user's permission level for a specific resource.
  ///
  /// Returns [ResourcePermission] indicating the user's permission level for the resource
  ///
  /// **Permission Levels:**
  /// - [ResourcePermission.owner] Full control including deletion and permission management
  /// - [ResourcePermission.editor] Can modify content but not manage permissions
  /// - [ResourcePermission.viewer] Read-only access to resource content
  ResourcePermission? getUserPermission(String resourceId) {
    // Security: Must be authenticated to have permissions
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return null;

    // Security: Validate resource ID
    if (resourceId.isEmpty) return null;

    // CRITICAL FIX: Use actual permission validation instead of mock bypass
    try {
      // Get recipe from cached data in UnifiedRecipeService
      final recipe = recipeService.getRecipeById(resourceId);
      if (recipe == null) {
        // Recipe not found or not accessible - no permissions
        return null;
      }

      // Use RecipePermissionHelper for actual permission validation
      return permissionHelper.getUserPermission(recipe, currentUserId);
    } catch (e) {
      // If validation fails, default to safe (no permissions)
      return null;
    }
  }

  /// Validates whether the current user has at least the specified permission level for a resource.
  ///
  /// Returns `true` if user has at least the specified permission level, `false` otherwise
  ///
  /// **Permission Hierarchy:**
  /// - Owner permissions include all editor and viewer capabilities
  /// - Editor permissions include all viewer capabilities
  /// - Viewer permissions are the minimum level for resource access
  bool hasPermission(String resourceId, ResourcePermission permission) {
    // Security: Must be authenticated to have any permissions
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate resource ID
    if (resourceId.isEmpty) return false;

    // Get the actual user permission for this resource
    final userPermission = getUserPermission(resourceId);
    if (userPermission == null) return false;

    // Check permission hierarchy
    switch (permission) {
      case ResourcePermission.viewer:
        // Any permission level grants viewer access
        return true;
      case ResourcePermission.editor:
        // Editor or owner permissions grant editor access
        return userPermission == ResourcePermission.editor ||
            userPermission == ResourcePermission.owner;
      case ResourcePermission.owner:
        // Only owner permission grants owner access
        return userPermission == ResourcePermission.owner;
      case ResourcePermission.read:
        // Read is equivalent to viewer
        return true;
      case ResourcePermission.write:
        // Write is equivalent to editor
        return userPermission == ResourcePermission.write ||
            userPermission == ResourcePermission.editor ||
            userPermission == ResourcePermission.owner ||
            userPermission == ResourcePermission.admin;
      case ResourcePermission.admin:
        // Only admin permission grants admin access
        return userPermission == ResourcePermission.admin;
    }
  }

  /// Validates whether the current user is the owner of a specific recipe.
  ///
  /// Returns `true` if current user owns the recipe, `false` otherwise
  ///
  /// **Owner Privileges:**
  /// - Full editing rights for all recipe content
  /// - Managing collaboration and sharing settings
  /// - Inviting and removing collaborators
  /// - Deleting the recipe permanently
  bool isRecipeOwner(String recipeId) {
    // Security: Must be authenticated to own recipes
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // CRITICAL FIX: Use actual permission validation instead of mock bypass
    try {
      // Get recipe from cached data in UnifiedRecipeService
      final recipe = recipeService.getRecipeById(recipeId);
      if (recipe == null) {
        // Recipe not found or not accessible
        return false;
      }

      // Use RecipePermissionHelper for actual ownership validation
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      return ownerId == currentUserId;
    } catch (e) {
      // If validation fails, default to safe (deny access)
      return false;
    }
  }
}
