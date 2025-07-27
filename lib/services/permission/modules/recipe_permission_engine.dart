// lib/services/permission/modules/recipe_permission_engine.dart

import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission/modules/auth_permission_engine.dart';

/// Focused module for recipe-specific permission engine
/// 
/// This module handles ONLY recipe permission operations:
/// - Recipe viewing, editing, deletion permissions
/// - Recipe ownership and collaboration validation
/// - Recipe sharing and invitation permissions
/// - Recipe edit mode determination
/// 
/// ❌ DOES NOT CONTAIN: Shopping lists, groups, profiles, auth logic
class RecipePermissionEngine {
  final AuthPermissionEngine _authEngine;
  final UnifiedRecipeService _recipeService;
  final Map<String, bool> _recipePermissionCache = {};

  RecipePermissionEngine(this._authEngine, this._recipeService);

  // ===== CORE RECIPE PERMISSIONS =====

  /// Check if current user can view a recipe
  bool canViewRecipe(String recipeId) {
    return _getCachedRecipePermission('recipe_view_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _hasRecipePermission(recipe, _authEngine.currentUserId!, 'view');
    });
  }

  /// Check if current user can edit a recipe
  bool canEditRecipe(String recipeId) {
    return _getCachedRecipePermission('recipe_edit_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _hasRecipePermission(recipe, _authEngine.currentUserId!, 'edit');
    });
  }

  /// Check if current user can delete a recipe
  bool canDeleteRecipe(String recipeId) {
    return _getCachedRecipePermission('recipe_delete_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      // Only owner can delete
      return _authEngine.isOwner(recipe.socialData?.ownerId ?? recipe.core.createdBy ?? '');
    });
  }

  /// Check if current user can share a recipe
  bool canShareRecipe(String recipeId) {
    return canViewRecipe(recipeId); // Can share if can view
  }

  /// Check if current user can duplicate a recipe
  bool canDuplicateRecipe(String recipeId) {
    return canViewRecipe(recipeId) && _authEngine.isAuthenticated;
  }

  // ===== RECIPE OWNERSHIP VALIDATION =====

  /// Check if current user is recipe owner
  bool isRecipeOwner(String recipeId) {
    return _getCachedRecipePermission('recipe_owner_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _authEngine.isOwner(recipe.socialData?.ownerId ?? recipe.core.createdBy ?? '');
    });
  }

  /// Check if recipe belongs to current user
  bool isOwnRecipe(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  /// Check if current user is creator of recipe
  bool isRecipeCreator(String recipeId) {
    return _getCachedRecipePermission('recipe_creator_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _authEngine.currentUserId == recipe.core.createdBy;
    });
  }

  // ===== RECIPE COLLABORATION PERMISSIONS =====

  /// Check if current user can invite members to a recipe
  bool canInviteToRecipe(String recipeId) {
    return _getCachedRecipePermission('recipe_invite_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _hasRecipePermission(recipe, _authEngine.currentUserId!, 'admin');
    });
  }

  /// Check if current user can manage recipe members
  bool canManageRecipeMembers(String recipeId) {
    return _getCachedRecipePermission('recipe_manage_$recipeId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;
      
      return _hasRecipePermission(recipe, _authEngine.currentUserId!, 'admin');
    });
  }

  /// Check if current user can remove members from recipe
  bool canRemoveMembersFromRecipe(String recipeId) {
    return canManageRecipeMembers(recipeId);
  }

  /// Check if current user can leave recipe collaboration
  bool canLeaveRecipe(String recipeId) {
    return canViewRecipe(recipeId) && !isRecipeOwner(recipeId);
  }

  // ===== RECIPE CREATION PERMISSIONS =====

  /// Check if current user can create recipes
  bool canCreateRecipe() {
    return _authEngine.isAuthenticated; // All authenticated users can create recipes
  }

  /// Check if current user can fork a recipe
  bool canForkRecipe(String recipeId) {
    return canViewRecipe(recipeId) && _authEngine.isAuthenticated;
  }

  /// Check if current user can copy recipe content
  bool canCopyRecipeContent(String recipeId) {
    return canViewRecipe(recipeId);
  }

  // ===== RECIPE EDIT MODE DETERMINATION =====

  /// Get edit mode for a recipe
  EditMode getRecipeEditMode(String recipeId) {
    if (!_authEngine.isAuthenticated) return EditMode.noAccess;
    
    final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return EditMode.noAccess;
    
    if (_authEngine.isOwner(recipe.socialData?.ownerId ?? recipe.core.createdBy ?? '')) return EditMode.owner;
    if (recipe.isCollaborative && canEditRecipe(recipeId)) return EditMode.collaborative;
    if (canViewRecipe(recipeId)) return EditMode.readOnlyWithFork;
    
    return EditMode.noAccess;
  }

  /// Check if recipe is in collaborative mode
  bool isRecipeCollaborative(String recipeId) {
    final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
    return recipe?.isCollaborative ?? false;
  }

  /// Check if recipe is personal
  bool isRecipePersonal(String recipeId) {
    final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
    return recipe?.isPersonal ?? true;
  }

  // ===== RECIPE ACCESS VALIDATION =====

  /// Check if user has any access to recipe
  bool hasRecipeAccess(String recipeId) {
    return canViewRecipe(recipeId);
  }

  /// Check if user has read access to recipe
  bool hasReadAccess(String recipeId) {
    return canViewRecipe(recipeId);
  }

  /// Check if user has write access to recipe
  bool hasWriteAccess(String recipeId) {
    return canEditRecipe(recipeId);
  }

  /// Check if user has admin access to recipe
  bool hasAdminAccess(String recipeId) {
    return canManageRecipeMembers(recipeId);
  }

  /// Check if user has owner access to recipe
  bool hasOwnerAccess(String recipeId) {
    return isRecipeOwner(recipeId);
  }

  // ===== RECIPE PERMISSION LEVEL =====

  /// Get resource permission level for current user
  ResourcePermission getRecipePermissionLevel(String recipeId) {
    if (canDeleteRecipe(recipeId)) return ResourcePermission.owner;
    if (canEditRecipe(recipeId)) return ResourcePermission.editor;
    if (canViewRecipe(recipeId)) return ResourcePermission.viewer;
    return ResourcePermission.viewer; // Default fallback
  }

  /// Check if user has minimum required permission
  bool hasMinimumRecipePermission(String recipeId, ResourcePermission required) {
    final current = getRecipePermissionLevel(recipeId);
    return ResourcePermissionHelper.isHigherPermission(current, required) || current == required;
  }

  // ===== RECIPE VALIDATION =====

  /// Validate recipe ID format
  bool isValidRecipeId(String recipeId) {
    return recipeId.isNotEmpty && recipeId.trim().isNotEmpty;
  }

  /// Check if recipe exists and user has access
  bool validateRecipeAccess(String recipeId) {
    if (!isValidRecipeId(recipeId)) return false;
    return hasRecipeAccess(recipeId);
  }

  /// Get recipe permission validation result
  Map<String, bool> validateAllRecipePermissions(String recipeId) {
    return {
      'canView': canViewRecipe(recipeId),
      'canEdit': canEditRecipe(recipeId),
      'canDelete': canDeleteRecipe(recipeId),
      'canShare': canShareRecipe(recipeId),
      'canDuplicate': canDuplicateRecipe(recipeId),
      'canInvite': canInviteToRecipe(recipeId),
      'canManageMembers': canManageRecipeMembers(recipeId),
      'isOwner': isRecipeOwner(recipeId),
      'isCreator': isRecipeCreator(recipeId),
      'isCollaborative': isRecipeCollaborative(recipeId),
    };
  }

  // ===== RECIPE PERMISSION CONTEXT =====

  /// Create permission context for recipe operations
  Map<String, dynamic> createRecipePermissionContext(String recipeId) {
    return {
      'recipeId': recipeId,
      'userId': _authEngine.currentUserId,
      'permissions': validateAllRecipePermissions(recipeId),
      'editMode': getRecipeEditMode(recipeId).toString(),
      'permissionLevel': getRecipePermissionLevel(recipeId).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on recipe
  bool canPerformRecipeOperation(String recipeId, String operation) {
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
      case 'fork':
        return canForkRecipe(recipeId);
      case 'invite':
        return canInviteToRecipe(recipeId);
      case 'manage_members':
        return canManageRecipeMembers(recipeId);
      case 'copy_content':
        return canCopyRecipeContent(recipeId);
      default:
        return false;
    }
  }

  // ===== CACHE MANAGEMENT =====

  /// Clear recipe permission cache
  void clearRecipePermissionCache() {
    _recipePermissionCache.clear();
    AppLogger.info('🔐 Recipe permission cache cleared');
  }

  /// Clear specific recipe permission from cache
  void clearRecipePermissionFromCache(String key) {
    _recipePermissionCache.remove(key);
    AppLogger.debug('🔐 Recipe permission cache cleared for key: $key');
  }

  // ===== ASYNC RECIPE OPERATIONS =====

  /// Update recipe permission for a user
  Future<void> updateRecipePermission(String recipeId, String userId, ResourcePermission permission) async {
    // Implementation depends on your permission storage system
    AppLogger.info('Updating recipe permission for $userId to $permission');
    clearRecipePermissionFromCache('recipe_view_$recipeId');
    clearRecipePermissionFromCache('recipe_edit_$recipeId');
    clearRecipePermissionFromCache('recipe_manage_$recipeId');
  }

  /// Remove recipe permission for a user
  Future<void> removeRecipePermission(String recipeId, String userId) async {
    // Implementation depends on your permission storage system
    AppLogger.info('Removing recipe permission for $userId');
    clearRecipePermissionFromCache('recipe_view_$recipeId');
    clearRecipePermissionFromCache('recipe_edit_$recipeId');
    clearRecipePermissionFromCache('recipe_manage_$recipeId');
  }

  /// Share recipe with specific users
  Future<void> shareRecipe(String recipeId, List<String> userIds, ResourcePermission permission) async {
    // Implementation depends on your sharing system
    AppLogger.info('Sharing recipe $recipeId with $userIds');
    clearRecipePermissionCache();
  }

  // ===== PRIVATE HELPERS =====

  /// Get cached recipe permission result or compute and cache it
  bool _getCachedRecipePermission(String key, bool Function() computation) {
    if (_recipePermissionCache.containsKey(key)) {
      return _recipePermissionCache[key]!;
    }
    
    final result = computation();
    _recipePermissionCache[key] = result;
    return result;
  }

  /// Check if user has specific permission for a recipe
  bool _hasRecipePermission(Recipe recipe, String userId, String permission) {
    // Check if user is the creator/owner
    if (userId == recipe.core.createdBy) return true;
    if (recipe.socialData?.ownerId != null && userId == recipe.socialData!.ownerId) return true;
    
    if (recipe.isPersonal) return userId == recipe.core.createdBy;
    
    final userPermission = recipe.socialData?.memberPermissions?[userId];
    if (userPermission == null) return false;
    
    switch (permission) {
      case 'view':
        return true; // All members can view
      case 'edit':
        return userPermission == ResourcePermission.editor || userPermission == ResourcePermission.owner;
      case 'admin':
        return userPermission == ResourcePermission.owner;
      default:
        return false;
    }
  }
}