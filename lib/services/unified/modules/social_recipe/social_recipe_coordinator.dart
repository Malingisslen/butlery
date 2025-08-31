// lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
// Temporarily disabled notification imports
// import 'package:butlery/services/notifications/notification_service.dart' as notif;
// import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Import the focused services
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_creation_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_membership_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_sharing_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_query_service.dart';

/// Social Recipe Coordinator (Facade)
/// 
/// Coordinates all social recipe operations by delegating to focused services.
/// Maintains backward compatibility while providing clean separation of concerns.
/// 
/// This is a facade pattern that:
/// - Provides the same interface as the original SocialRecipeModule
/// - Delegates operations to appropriate focused services
/// - Handles notifications and cross-cutting concerns
/// - Maintains state and error handling
class SocialRecipeCoordinator extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeCoordinator';

  // Focused services
  late final SocialRecipeCreationService _creationService;
  late final SocialRecipeMembershipService _membershipService;
  late final SocialRecipeSharingService _sharingService;
  late final SocialRecipePermissionService _permissionService;
  late final SocialRecipeQueryService _queryService;

  // Dependencies (passed to focused services)
  final RecipeServiceAdapter _serviceAdapter;
  
  /// Notification service for social notifications (temporarily disabled)
  // late final notif.NotificationService? _notificationService;

  SocialRecipeCoordinator({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    RecipeServiceAdapter? serviceAdapter,
  }) : _serviceAdapter = serviceAdapter ?? SocialRecipeCoordinator._createDefaultServiceAdapter() {
    
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
    
    // Initialize focused services
    _creationService = SocialRecipeCreationService(
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _membershipService = SocialRecipeMembershipService(
      getCurrentUserId: getCurrentUserId,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _sharingService = SocialRecipeSharingService(
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _permissionService = SocialRecipePermissionService(
      getRecipe: getRecipe,
    );

    _queryService = SocialRecipeQueryService(
      cacheHelper: cacheHelper,
      getCurrentUserId: getCurrentUserId,
      setError: setError,
      serviceAdapter: _serviceAdapter,
    );

    // _initializeNotificationService(); // Temporarily disabled
  }

  // ===== CREATION OPERATIONS (Delegate to CreationService) =====

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
    return await _creationService.createCollaborativeRecipe(
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

  // ===== MEMBERSHIP OPERATIONS (Delegate to MembershipService) =====

  Future<bool> addMemberToRecipe(String recipeId, String userId, ResourcePermission permission) async {
    final result = await _membershipService.addMemberToRecipe(recipeId, userId, permission);
    
    // Send notification after successful addition
    if (result) {
      await sendMemberAdditionNotification(recipeId, userId);
    }
    
    return result;
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _membershipService.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(String recipeId, String userId, ResourcePermission permission) async {
    return await _membershipService.updateMemberPermission(recipeId, userId, permission);
  }

  // ===== SHARING OPERATIONS (Delegate to SharingService) =====

  Future<bool> shareRecipeWithUsers(String recipeId, List<String> userIds, ResourcePermission permission) async {
    final result = await _sharingService.shareRecipeWithUsers(recipeId, userIds, permission);
    
    // Send notifications after successful sharing
    if (result) {
      await sendRecipeSharingNotifications(recipeId, userIds);
    }
    
    return result;
  }

  Future<bool> shareRecipeWithGroups(String recipeId, List<String> groupIds, ResourcePermission permission) async {
    return await _sharingService.shareRecipeWithGroups(recipeId, groupIds, permission);
  }

  Future<bool> unshareRecipe(String recipeId) async {
    return await _sharingService.unshareRecipe(recipeId);
  }

  // ===== PERMISSION OPERATIONS (Delegate to PermissionService) =====

  Future<bool> canEditRecipe(String recipeId, String userId) async {
    return await _permissionService.canEditRecipe(recipeId, userId);
  }

  Future<bool> canManageRecipeMembers(String recipeId, String userId) async {
    return await _permissionService.canManageRecipeMembers(recipeId, userId);
  }

  Future<bool> canViewRecipe(String recipeId, String userId) async {
    return await _permissionService.canViewRecipe(recipeId, userId);
  }

  Future<ResourcePermission?> getUserPermissionForRecipe(String recipeId, String userId) async {
    return await _permissionService.getUserPermissionForRecipe(recipeId, userId);
  }

  // ===== QUERY OPERATIONS (Delegate to QueryService) =====

  Future<List<Recipe>> getCollaborativeRecipesForUser() async {
    return await _queryService.getCollaborativeRecipesForUser();
  }

  Future<List<Recipe>> getRecipesSharedByUser(String userId) async {
    return await _queryService.getRecipesSharedByUser(userId);
  }

  Future<List<Recipe>> getRecipesWithPermission(ResourcePermission permission) async {
    return await _queryService.getRecipesWithPermission(permission);
  }

  Future<Map<String, int>> getCollaborationStats() async {
    return await _queryService.getCollaborationStats();
  }

  Future<List<String>> getMostActiveCollaborators({int limit = 10}) async {
    return await _queryService.getMostActiveCollaborators(limit: limit);
  }

  Future<List<Recipe>> loadCachedCollaborativeRecipes() async {
    return await _queryService.loadCachedCollaborativeRecipes();
  }

  // ===== NOTIFICATION OPERATIONS (Temporarily Simplified) =====

  Future<void> sendCollaborationInvitations(String recipeId, List<String> userIds) async {
    AppLogger.info('📧 Sending collaboration invitations to ${userIds.length} users for recipe $recipeId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendMemberAdditionNotification(String recipeId, String addedUserId) async {
    AppLogger.info('📧 Sending member addition notification for recipe $recipeId to user $addedUserId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendRecipeSharingNotifications(String recipeId, List<String> sharedWithUserIds) async {
    AppLogger.info('📧 Sending sharing notifications to ${sharedWithUserIds.length} users for recipe $recipeId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  // ===== UTILITY OPERATIONS =====

  bool validateCollaborativeRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    return _creationService.validateCollaborativeRecipeData(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(message ?? 'Operation completed successfully');
  }

  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  // Note: _hasAdminPermission removed - now handled by SocialRecipePermissionService
  
  /// Create default service adapter using ServiceLocator
  static RecipeServiceAdapter _createDefaultServiceAdapter() {
    return RecipeServiceAdapter(
      recipeRepository: ServiceLocator.get(),
      commentsRepository: ServiceLocator.tryGet(),
      ratingsRepository: ServiceLocator.tryGet(),
      notificationsRepository: ServiceLocator.tryGet(),
    );
  }
}