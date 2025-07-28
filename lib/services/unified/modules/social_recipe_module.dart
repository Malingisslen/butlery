// lib/services/unified/modules/social_recipe_module.dart

import 'dart:async';
// Firebase imports removed - using repository pattern
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/notifications/notification_service.dart' as notif;
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';

/// Social recipe operations module
/// 
/// This module contains ONLY:
/// - Social recipe sharing and collaboration
/// - Member management for collaborative recipes
/// - Permission handling for shared content
/// - Social recipe creation and management
/// 
/// ❌ DOES NOT CONTAIN: Personal recipe operations, realtime editing, UI concerns, cache management
class SocialRecipeModule extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeModule';
  // Firebase instance removed - using repository pattern instead
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final Future<Recipe?> Function(String) _getRecipe;
  final Future<bool> Function(Recipe) _saveRecipe;
  final void Function() _notifyListeners;
  final RecipeServiceAdapter _serviceAdapter;
  
  /// Notification service for social notifications
  late final notif.NotificationService? _notificationService;

  SocialRecipeModule({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    RecipeServiceAdapter? serviceAdapter,
  })  : _cacheHelper = cacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _setError = setError,
        _getRecipe = getRecipe,
        _saveRecipe = saveRecipe,
        _notifyListeners = notifyListeners,
        _serviceAdapter = serviceAdapter ?? RecipeServiceAdapter() {
    // Initialize notification service
    _initializeNotificationService();
  }

  /// Initialize notification service for social notifications
  void _initializeNotificationService() {
    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId != null) {
        _notificationService = notif.NotificationService(
          userId: currentUserId,
        );
        _notificationService?.initialize();
      } else {
        _notificationService = null;
      }
    } catch (e) {
      AppLogger.warning('⚠️ Could not initialize notification service in SocialRecipeModule: $e');
      _notificationService = null;
    }
  }

  // ===== COLLABORATIVE RECIPE CREATION =====

  /// Create a new collaborative recipe
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> memberIds,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    // Validate inputs
    final titleError = ValidationUtils.validateRecipeName(title);
    if (titleError != null) {
      _handleError(titleError);
      return null;
    }

    return await executeAsUser<String>((userId) async {
      return await LoggingUtils.loggedCreate(
        'Collaborative Recipe',
        () async {
          // Create member permissions
          final memberPermissions = <String, ResourcePermission>{};
          for (final memberId in memberIds) {
            memberPermissions[memberId] = ResourcePermission.editor;
          }

          final newRecipe = Recipe.collaborative(
            title: title.trim(),
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            mealType: mealType,
            ownerId: userId,
            ownerDisplayName: _getCurrentUserDisplayName()!,
            memberPermissions: memberPermissions,
            allowGuestViewing: allowGuestViewing,
            allowMemberInvites: allowMemberInvites,
            descriptionCollaborative: descriptionCollaborative,
            portions: portions,
            timeMinutes: timeMinutes,
            rating: rating,
            tags: tags,
            sourceUrl: sourceUrl,
            imageUrls: imageUrls,
          );

          // Save to cache
          await _saveToCache(newRecipe);

          // Save using repository pattern
          await _saveRecipe(newRecipe);

          return newRecipe.id;
        },
        metadata: {'member_count': memberIds.length, 'meal_type': mealType},
      );
    }, operationName: 'Create collaborative recipe');
  }

  // ===== MEMBER MANAGEMENT =====

  /// Add member to collaborative recipe
  Future<bool> addMemberToRecipe(
      String recipeId, String userId, ResourcePermission permission) async {
    // Validate inputs
    final userIdError = ValidationUtils.validateUserId(userId);
    if (userIdError != null) {
      _handleError(userIdError);
      return false;
    }

    final result = await executeAsUser<bool>((currentUserId) async {
      return await LoggingUtils.loggedUpdate(
        'Recipe Member',
        () async {
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
          final updatedMemberPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
          updatedMemberPermissions[userId] = permission;

          final updatedRecipe = recipe.copyWith(
            socialData: recipe.socialData?.copyWith(
              memberPermissions: updatedMemberPermissions,
            ),
          );

          // 4. Save back to Firebase and cache
          final success = await _saveRecipe(updatedRecipe);
          if (success) {
            _notifyListeners(); // Notify UI of changes
          }
          
          return success;
        },
        itemId: recipeId,
        metadata: {'new_member': userId, 'permission': permission.toString()},
      );
    }, operationName: 'Add recipe member');
    return result ?? false;
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    final result = await executeAsUser<bool>((currentUserId) async {
      return await LoggingUtils.loggedDelete(
        'Recipe Member',
        () async {
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
          final updatedMemberPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
          updatedMemberPermissions.remove(userId);

          final updatedRecipe = recipe.copyWith(
            socialData: recipe.socialData?.copyWith(
              memberPermissions: updatedMemberPermissions,
            ),
          );

          // 4. Save back to Firebase and cache
          final success = await _saveRecipe(updatedRecipe);
          if (success) {
            _notifyListeners(); // Notify UI of changes
          }
          
          return success;
        },
        itemId: recipeId,
        metadata: {'removed_member': userId},
      );
    }, operationName: 'Remove recipe member');
    return result ?? false;
  }

  /// Update member permission for collaborative recipe
  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    final result = await executeAsUser<bool>((currentUserId) async {
      return await LoggingUtils.loggedUpdate(
        'Recipe Member Permission',
        () async {
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
          final updatedMemberPermissions = Map<String, ResourcePermission>.from(recipe.socialData?.memberPermissions ?? {});
          updatedMemberPermissions[userId] = permission;

          final updatedRecipe = recipe.copyWith(
            socialData: recipe.socialData?.copyWith(
              memberPermissions: updatedMemberPermissions,
            ),
          );

          // 4. Save back to Firebase and cache
          final success = await _saveRecipe(updatedRecipe);
          if (success) {
            _notifyListeners(); // Notify UI of changes
          }
          
          return success;
        },
        itemId: recipeId,
        metadata: {'member': userId, 'new_permission': permission.toString()},
      );
    }, operationName: 'Update member permission');
    return result ?? false;
  }

  // ===== RECIPE SHARING =====

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

      // 4. Sending notifications
      await sendRecipeSharingNotifications(recipeId, userIds);
      
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

      // Get member list for notifications before removing them
      final memberIds = recipe.socialData?.memberPermissions?.keys.where((id) => id != currentUserId).toList() ?? [];

      // 3. Converting back to personal recipe
      final unsharedRecipe = recipe.copyWith(
        type: RecipeType.personal,
        socialData: null, // Remove all social data
      );

      // 6. Saving to personal collection
      final success = await _saveRecipe(unsharedRecipe);
      if (!success) {
        _setError('Kunde inte spara recept');
        return false;
      }

      // 5. Notifying members (optional - members will lose access)
      if (memberIds.isNotEmpty) {
        try {
          // Could send notifications about recipe being unshared
          AppLogger.info('Recipe unshared - ${memberIds.length} members lost access');
        } catch (e) {
          AppLogger.warning('Could not notify members about unsharing: $e');
        }
      }
      
      // Notify UI of changes
      _notifyListeners();
      
      AppLogger.success('Recipe $recipeId unshared successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not unshare recipe: $e');
      _setError('Kunde inte sluta dela recept: $e');
      return false;
    }
  }

  // ===== PERMISSION VALIDATION =====

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
      return permission == ResourcePermission.admin || permission == ResourcePermission.editor;
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
  Future<ResourcePermission?> getUserPermissionForRecipe(String recipeId, String userId) async {
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

  // ===== COLLABORATIVE RECIPE QUERIES =====

  /// Get collaborative recipes where user is a member using repository pattern
  Future<List<Recipe>> getCollaborativeRecipesForUser() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return [];

    try {
      final allRecipes = await _serviceAdapter.getRecipesForUser(currentUserId);
      return allRecipes.where((recipe) => 
        recipe.isCollaborative && 
        recipe.socialData?.memberPermissions?.containsKey(currentUserId) == true
      ).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get collaborative recipes', e);
      return [];
    }
  }

  /// Get recipes shared by specific user using repository pattern
  Future<List<Recipe>> getRecipesSharedByUser(String userId) async {
    try {
      final allRecipes = await _serviceAdapter.getRecipesForUser(userId);
      return allRecipes.where((recipe) => 
        recipe.isCollaborative && 
        recipe.socialData?.ownerId == userId
      ).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes shared by user', e);
      return [];
    }
  }

  /// Get recipes with specific permission level using repository pattern
  Future<List<Recipe>> getRecipesWithPermission(ResourcePermission permission) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return [];

    try {
      final allRecipes = await _serviceAdapter.getRecipesForUser(currentUserId);
      return allRecipes.where((recipe) => 
        recipe.isCollaborative && 
        recipe.socialData?.memberPermissions?[currentUserId] == permission
      ).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes with permission', e);
      return [];
    }
  }

  // ===== COLLABORATION ANALYTICS =====

  /// Get collaboration statistics for user
  Future<Map<String, int>> getCollaborationStats() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      return <String, int>{};
    }

    try {
      // TODO: Implement collaboration statistics
      // This would count recipes by collaboration type
      return {
        'owned_collaborative': 0,
        'member_of': 0,
        'editor_access': 0,
        'viewer_access': 0,
      };
    } catch (e) {
      AppLogger.error('❌ Could not get collaboration stats: $e');
      return <String, int>{};
    }
  }

  /// Get most active collaborators
  Future<List<String>> getMostActiveCollaborators({int limit = 10}) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return [];

    try {
      // TODO: Implement active collaborators retrieval
      // This would analyze collaboration frequency
      return [];
    } catch (e) {
      AppLogger.error('❌ Could not get active collaborators: $e');
      return [];
    }
  }

  // ===== CACHE OPERATIONS =====

  /// Save collaborative recipe to cache
  Future<void> _saveToCache(Recipe recipe) async {
    try {
      final recipeData = recipe.toJson();
      await _cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Collaborative recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Cache save error: $e');
    }
  }

  /// Load cached collaborative recipes
  Future<List<Recipe>> loadCachedCollaborativeRecipes() async {
    try {
      final cachedRecipeIds = await _cacheHelper.getAllKeys();
      final recipes = <Recipe>[];

      for (final recipeId in cachedRecipeIds) {
        final recipeData = await _cacheHelper.loadJson(recipeId);
        if (recipeData != null) {
          try {
            final recipe = Recipe.fromJson(recipeData);
            if (recipe.isCollaborative) {
              recipes.add(recipe);
            }
          } catch (e) {
            AppLogger.error('Error parsing cached collaborative recipe $recipeId: $e');
            await _cacheHelper.delete(recipeId);
          }
        }
      }

      AppLogger.debug('✅ ${recipes.length} cached collaborative recipes loaded');
      return recipes;
    } catch (e) {
      AppLogger.error('Error loading cached collaborative recipes: $e');
      return [];
    }
  }

  // ===== FIREBASE OPERATIONS REMOVED =====
  // Firebase operations now handled through repository pattern via _saveRecipe callback

  // ===== NOTIFICATION INTEGRATION =====

  /// Send collaboration invitation notifications
  Future<void> sendCollaborationInvitations(String recipeId, List<String> userIds) async {
    try {
      if (_notificationService == null) {
        AppLogger.debug('Notification service not available - skipping collaboration invitations');
        return;
      }

      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return;

      final currentUserDisplayName = _getCurrentUserDisplayName() ?? 'Unknown User';

      await _notificationService.sendImmediateNotification(
        targetUserIds: userIds,
        strategy: NotificationStrategy.collaborationInvite,
        variables: {
          'senderName': currentUserDisplayName,
          'resourceName': recipe.core.title,
        },
        additionalData: {
          'type': 'collaboration_invitation',
          'recipeId': recipeId,
          'recipeTitle': recipe.core.title,
          'inviterDisplayName': currentUserDisplayName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger.success('Collaboration invitations sent for recipe $recipeId to ${userIds.length} users');
    } catch (e) {
      AppLogger.error('❌ Could not send collaboration invitations: $e');
    }
  }

  /// Send member addition notifications
  Future<void> sendMemberAdditionNotification(String recipeId, String addedUserId) async {
    try {
      if (_notificationService == null) {
        AppLogger.debug('Notification service not available - skipping member addition notification');
        return;
      }

      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return;

      final currentUserDisplayName = _getCurrentUserDisplayName() ?? 'Unknown User';

      await _notificationService.sendImmediateNotification(
        targetUserIds: [addedUserId],
        strategy: NotificationStrategy.collaborationInvite,
        variables: {
          'senderName': currentUserDisplayName,
          'resourceName': recipe.core.title,
        },
        additionalData: {
          'type': 'member_added',
          'recipeId': recipeId,
          'recipeTitle': recipe.core.title,
          'adderDisplayName': currentUserDisplayName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger.success('Member addition notification sent for recipe $recipeId to user $addedUserId');
    } catch (e) {
      AppLogger.error('❌ Could not send member addition notification: $e');
    }
  }

  /// Send recipe sharing notifications
  Future<void> sendRecipeSharingNotifications(String recipeId, List<String> sharedWithUserIds) async {
    try {
      if (_notificationService == null) {
        AppLogger.debug('Notification service not available - skipping recipe sharing notifications');
        return;
      }

      final recipe = await _getRecipe(recipeId);
      if (recipe == null) return;

      final currentUserDisplayName = _getCurrentUserDisplayName() ?? 'Unknown User';

      await _notificationService.sendImmediateNotification(
        targetUserIds: sharedWithUserIds,
        strategy: NotificationStrategy.recipeShared,
        variables: {
          'senderName': currentUserDisplayName,
          'recipeName': recipe.core.title,
        },
        additionalData: {
          'type': 'recipe_shared',
          'recipeId': recipeId,
          'recipeTitle': recipe.core.title,
          'sharerDisplayName': currentUserDisplayName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger.success('Recipe sharing notifications sent for recipe $recipeId to ${sharedWithUserIds.length} users');
    } catch (e) {
      AppLogger.error('❌ Could not send recipe sharing notifications: $e');
    }
  }

  // ===== ERROR HANDLING =====

  void _handleError(String message) {
    _setError(message); // Connect to existing error system
  }

  // ===== UTILITY METHODS =====

  /// Check if user has admin permission for recipe
  bool _hasAdminPermission(Recipe recipe, String userId) {
    if (!recipe.isCollaborative) return false;
    if (recipe.socialData?.ownerId == userId) return true;
    return recipe.socialData?.memberPermissions?[userId] == ResourcePermission.admin;
  }


  /// Create recipe operation result for success
  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(message);
  }

  /// Create recipe operation result for failure
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  /// Validate collaborative recipe data
  bool validateCollaborativeRecipeData({
    required String title,
    required List<String> memberIds,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    // Use ValidationUtils for consistent validation
    final titleError = ValidationUtils.validateRecipeName(title);
    if (titleError != null) {
      _handleError(titleError);
      return false;
    }

    if (!ValidationUtils.hasItems(memberIds)) {
      _handleError('Kollaborativt recept måste ha minst en medlem');
      return false;
    }

    if (!ValidationUtils.hasItems(ingredients)) {
      _handleError('Recept måste ha minst en ingrediens');
      return false;
    }

    if (!ValidationUtils.hasItems(instructions)) {
      _handleError('Recept måste ha minst en instruktion');
      return false;
    }

    return true;
  }
}