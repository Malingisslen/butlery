// lib/services/unified/modules/social_recipe_module.dart
// 
// ✅ REFACTORED: Split into focused services for better Single Responsibility Principle
// This file now acts as a facade that delegates to specialized services:
// - SocialRecipeCreationService: Recipe creation operations
// - SocialRecipeMembershipService: Member management operations  
// - SocialRecipeSharingService: Sharing and unsharing operations
// - SocialRecipePermissionService: Permission validation logic
// - SocialRecipeQueryService: Queries and analytics operations

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';

/// Social Recipe Module (Facade)
/// 
/// ✅ REFACTORED: Now delegates to focused services while maintaining backward compatibility.
/// This facade coordinates social recipe operations through specialized services.
/// 
/// Previous 859-line monolithic class split into:
/// - 5 focused services (150-200 lines each)
/// - 1 coordinator facade (maintains original interface)
/// 
/// Benefits:
/// - Single Responsibility Principle compliance
/// - Easier testing and maintenance
/// - Clear separation of concerns
/// - Backward compatibility preserved
class SocialRecipeModule extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeModule';
  
  // Coordinator that handles all the actual work
  late final SocialRecipeCoordinator _coordinator;

  SocialRecipeModule({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    RecipeServiceAdapter? serviceAdapter,
  }) {
    // Initialize the coordinator with all dependencies
    _coordinator = SocialRecipeCoordinator(
      cacheHelper: cacheHelper,
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
      serviceAdapter: serviceAdapter,
    );
  }

  // ===== FACADE METHODS - Delegate to Coordinator =====

  /// Creates a new collaborative recipe with initial sharing settings
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    List<String>? initialMembers,
    Map<String, ResourcePermission>? initialPermissions,
    String? description,
    int? portions,
    int? cookingTime,
    List<String>? tags,
  }) async {
    return await _coordinator.createCollaborativeRecipe(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      initialMembers: initialMembers,
      initialPermissions: initialPermissions,
      description: description,
      portions: portions,
      cookingTime: cookingTime,
      tags: tags,
    );
  }

  /// Add member to collaborative recipe with specified permission
  Future<bool> addMemberToRecipe(String recipeId, String userId, ResourcePermission permission) async {
    return await _coordinator.addMemberToRecipe(recipeId, userId, permission);
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _coordinator.removeMemberFromRecipe(recipeId, userId);
  }

  /// Update member permission for collaborative recipe
  Future<bool> updateMemberPermission(String recipeId, String userId, ResourcePermission permission) async {
    return await _coordinator.updateMemberPermission(recipeId, userId, permission);
  }

  /// Share a personal recipe with specific users
  Future<bool> shareRecipeWithUsers(String recipeId, List<String> userIds, ResourcePermission permission) async {
    return await _coordinator.shareRecipeWithUsers(recipeId, userIds, permission);
  }

  /// Share recipe with friend categories/groups
  Future<bool> shareRecipeWithGroups(String recipeId, List<String> groupIds, ResourcePermission permission) async {
    return await _coordinator.shareRecipeWithGroups(recipeId, groupIds, permission);
  }

  /// Unshare recipe (remove all collaborative access)
  Future<bool> unshareRecipe(String recipeId) async {
    return await _coordinator.unshareRecipe(recipeId);
  }

  /// Check if user can edit a recipe
  Future<bool> canEditRecipe(String recipeId, String userId) async {
    return await _coordinator.canEditRecipe(recipeId, userId);
  }

  /// Check if user can manage members of a recipe
  Future<bool> canManageRecipeMembers(String recipeId, String userId) async {
    return await _coordinator.canManageRecipeMembers(recipeId, userId);
  }

  /// Check if user can view a recipe
  Future<bool> canViewRecipe(String recipeId, String userId) async {
    return await _coordinator.canViewRecipe(recipeId, userId);
  }

  /// Get user's permission level for a recipe
  Future<ResourcePermission?> getUserPermissionForRecipe(String recipeId, String userId) async {
    return await _coordinator.getUserPermissionForRecipe(recipeId, userId);
  }

  /// Get collaborative recipes where user is a member using repository pattern
  Future<List<Recipe>> getCollaborativeRecipesForUser() async {
    return await _coordinator.getCollaborativeRecipesForUser();
  }

  /// Get recipes shared by specific user using repository pattern
  Future<List<Recipe>> getRecipesSharedByUser(String userId) async {
    return await _coordinator.getRecipesSharedByUser(userId);
  }

  /// Get recipes with specific permission level using repository pattern
  Future<List<Recipe>> getRecipesWithPermission(ResourcePermission permission) async {
    return await _coordinator.getRecipesWithPermission(permission);
  }

  /// Get collaboration statistics for user
  Future<Map<String, int>> getCollaborationStats() async {
    return await _coordinator.getCollaborationStats();
  }

  /// Get most active collaborators
  Future<List<String>> getMostActiveCollaborators({int limit = 10}) async {
    return await _coordinator.getMostActiveCollaborators(limit: limit);
  }

  /// Load cached collaborative recipes
  Future<List<Recipe>> loadCachedCollaborativeRecipes() async {
    return await _coordinator.loadCachedCollaborativeRecipes();
  }

  /// Send collaboration invitations
  Future<void> sendCollaborationInvitations(String recipeId, List<String> userIds) async {
    return await _coordinator.sendCollaborationInvitations(recipeId, userIds);
  }

  /// Send member addition notification
  Future<void> sendMemberAdditionNotification(String recipeId, String addedUserId) async {
    return await _coordinator.sendMemberAdditionNotification(recipeId, addedUserId);
  }

  /// Send recipe sharing notifications
  Future<void> sendRecipeSharingNotifications(String recipeId, List<String> sharedWithUserIds) async {
    return await _coordinator.sendRecipeSharingNotifications(recipeId, sharedWithUserIds);
  }

  /// Validates collaborative recipe data before creation
  bool validateCollaborativeRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    return _coordinator.validateCollaborativeRecipeData(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  /// Create success result
  RecipeOperationResult createSuccessResult([String? message]) {
    return _coordinator.createSuccessResult(message);
  }

  /// Create failure result
  RecipeOperationResult createFailureResult(String error) {
    return _coordinator.createFailureResult(error);
  }
}