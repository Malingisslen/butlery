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

/// Comprehensive social recipe module providing coordinated social cooking and sharing functionality.
///
/// This module implements sophisticated social recipe management using facade pattern with specialized services
/// for recipe creation, membership management, sharing operations, permission validation, and social analytics.
/// It provides comprehensive social cooking features while maintaining clean architecture separation and
/// backward compatibility for existing social recipe functionality.
///
/// **Refactored Architecture Benefits:**
/// This facade represents a complete refactoring from monolithic 859-line class into focused services:
/// - **5 Specialized Services**: Each handling 150-200 lines of focused functionality
/// - **1 Coordinator Facade**: Maintaining original interface for backward compatibility
/// - **Single Responsibility Compliance**: Each service handles one specific aspect of social recipes
/// - **Enhanced Testability**: Focused services enable comprehensive unit testing
/// - **Improved Maintainability**: Clean separation enables independent service evolution
///
/// **Specialized Services Coordination:**
/// This facade coordinates between focused social recipe services:
/// - **[SocialRecipeCreationService]**: Social recipe creation and initial setup operations
/// - **[SocialRecipeMembershipService]**: Member management, invitations, and participation tracking
/// - **[SocialRecipeSharingService]**: Recipe sharing, unsharing, and visibility management operations
/// - **[SocialRecipePermissionService]**: Comprehensive permission validation and access control logic
/// - **[SocialRecipeQueryService]**: Social queries, analytics, and discovery operations
///
/// **Social Recipe Features:**
/// - **Social Creation**: Recipe creation with immediate sharing and collaboration setup
/// - **Member Management**: Comprehensive friend and group member invitation and management
/// - **Sharing Control**: Granular sharing permissions with visibility and access management
/// - **Permission System**: Sophisticated permission validation for social recipe access
/// - **Social Discovery**: Recipe discovery through social networks and friend recommendations
///
/// **Usage Examples:**
/// ```dart
/// final socialModule = SocialRecipeModule(coordinator);
/// 
/// // Create social recipe with initial sharing
/// final socialRecipe = await socialModule.createSocialRecipe(
///   title: 'Familjerecept Köttbullar',
///   initialMembers: ['friend1', 'friend2'],
/// );
/// 
/// // Manage recipe membership
/// await socialModule.inviteMemberToRecipe(recipeId, friendId);
/// 
/// // Control sharing permissions
/// await socialModule.updateSharingPermissions(recipeId, permissions);
/// 
/// // Discover social recipes
/// final recommendations = await socialModule.getSocialRecipeRecommendations();
/// ```
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
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
    
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