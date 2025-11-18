// lib/services/unified/modules/social_recipe/social_recipe_query_service.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Social Recipe Query Service
/// Handles ONLY query operations for collaborative recipes.
/// This includes getting collaborative recipes, analytics, and cached data.
class SocialRecipeQueryService extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeQueryService';

  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final RecipeServiceAdapter _serviceAdapter;

  SocialRecipeQueryService({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required void Function(String) setError,
    RecipeServiceAdapter? serviceAdapter,
  }) : _cacheHelper = cacheHelper,
       _getCurrentUserId = getCurrentUserId,
       _serviceAdapter = serviceAdapter ?? SocialRecipeQueryService._createDefaultServiceAdapter() {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
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

  /// Get recipes that user owns (admin permission)
  Future<List<Recipe>> getOwnedCollaborativeRecipes() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return [];

    try {
      final allRecipes = await _serviceAdapter.getRecipesForUser(currentUserId);
      return allRecipes.where((recipe) => 
        recipe.isCollaborative && 
        recipe.socialData?.ownerId == currentUserId
      ).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get owned collaborative recipes', e);
      return [];
    }
  }

  /// Search collaborative recipes by title
  Future<List<Recipe>> searchCollaborativeRecipes(String query) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return [];

    try {
      final collaborativeRecipes = await getCollaborativeRecipesForUser();
      final lowerQuery = query.toLowerCase();
      
      return collaborativeRecipes.where((recipe) =>
        recipe.title.toLowerCase().contains(lowerQuery)
      ).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to search collaborative recipes', e);
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
      final collaborativeRecipes = await getCollaborativeRecipesForUser();
      final ownedRecipes = collaborativeRecipes.where((r) => r.socialData?.ownerId == currentUserId).length;
      final memberRecipes = collaborativeRecipes.where((r) => r.socialData?.ownerId != currentUserId).length;
      
      final editorAccess = collaborativeRecipes.where((r) => 
        r.socialData?.memberPermissions?[currentUserId] == ResourcePermission.editor
      ).length;
      
      final viewerAccess = collaborativeRecipes.where((r) => 
        r.socialData?.memberPermissions?[currentUserId] == ResourcePermission.viewer
      ).length;

      return {
        'owned_collaborative': ownedRecipes,
        'member_of': memberRecipes,
        'editor_access': editorAccess,
        'viewer_access': viewerAccess,
        'total_collaborative': collaborativeRecipes.length,
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
      final collaborativeRecipes = await getCollaborativeRecipesForUser();
      final collaboratorCounts = <String, int>{};
      
      // Count appearances of each collaborator
      for (final recipe in collaborativeRecipes) {
        recipe.socialData?.memberPermissions?.keys.forEach((userId) {
          if (userId != currentUserId) {
            collaboratorCounts[userId] = (collaboratorCounts[userId] ?? 0) + 1;
          }
        });
      }
      
      // Sort by count and return top collaborators
      final sortedCollaborators = collaboratorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedCollaborators
          .take(limit)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      AppLogger.error('❌ Could not get active collaborators: $e');
      return [];
    }
  }

  /// Get collaboration activity summary
  Future<Map<String, dynamic>> getCollaborationActivity() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return {};

    try {
      final stats = await getCollaborationStats();
      final activeCollaborators = await getMostActiveCollaborators();
      
      return {
        'stats': stats,
        'active_collaborators': activeCollaborators,
        'has_collaborative_activity': (stats['total_collaborative'] ?? 0) > 0,
      };
    } catch (e) {
      AppLogger.error('❌ Could not get collaboration activity: $e');
      return {};
    }
  }

  // ===== CACHE OPERATIONS =====

  /// Save collaborative recipe to cache
  Future<void> saveToCache(Recipe recipe) async {
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
      AppLogger.info('Loading cached collaborative recipes');
      
      final cachedRecipes = <Recipe>[];
      final cachedKeys = await _cacheHelper.getAllKeys();
      
      for (final key in cachedKeys) {
        try {
          final recipeData = await _cacheHelper.loadJson(key);
          if (recipeData != null) {
            final recipe = Recipe.fromJson(recipeData);
            if (recipe.isCollaborative) {
              cachedRecipes.add(recipe);
            }
          }
        } catch (e) {
          AppLogger.warning('Failed to load cached recipe $key: $e');
        }
      }
      
      AppLogger.success('Loaded ${cachedRecipes.length} cached collaborative recipes');
      return cachedRecipes;
    } catch (e) {
      AppLogger.error('Failed to load cached collaborative recipes: $e');
      return [];
    }
  }

  /// Clear cached collaborative recipes
  Future<void> clearCachedRecipes() async {
    try {
      await _cacheHelper.clear();
      AppLogger.success('Collaborative recipe cache cleared');
    } catch (e) {
      AppLogger.error('Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final cachedKeys = await _cacheHelper.getAllKeys();
      final collaborativeCount = (await loadCachedCollaborativeRecipes()).length;
      
      return {
        'total_cached': cachedKeys.length,
        'collaborative_cached': collaborativeCount,
      };
    } catch (e) {
      AppLogger.error('Failed to get cache stats: $e');
      return {'total_cached': 0, 'collaborative_cached': 0};
    }
  }
  
  /// Create default service adapter using ServiceLocator
  static RecipeServiceAdapter _createDefaultServiceAdapter() {
    return RecipeServiceAdapter(
      recipeRepository: ServiceLocator.get(),
      commentsRepository: ServiceLocator.get(),
      ratingsRepository: ServiceLocator.get(),
      notificationsRepository: ServiceLocator.get(),
    );
  }
}