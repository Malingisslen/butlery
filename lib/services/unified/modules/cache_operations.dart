// lib/services/unified/modules/cache_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

/// Specialized cache operations module providing focused local storage management for recipe data.
///
/// This module implements comprehensive local cache management following Single Responsibility Principle,
/// handling all aspects of recipe cache operations including save/load/remove operations, batch processing,
/// cache validation, and integrity management. It provides high-performance local storage capabilities
/// while maintaining clean separation from synchronization and optimization concerns.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles local cache operations:
/// - **Recipe CRUD Operations**: Complete create, read, update, delete operations for cached recipe data
/// - **Batch Processing**: Efficient batch save/load/remove operations for multiple recipes simultaneously
/// - **Cache Validation**: Comprehensive integrity checks with corruption detection and automatic repair
/// - **Data Management**: Cache size analysis, compaction detection, and user-specific cache operations
///
/// **What This Module Does NOT Handle:**
/// - Firebase synchronization and real-time updates (handled by FirebaseSyncManager)
/// - Cache cleanup and optimization scheduling (handled by CacheOptimization)
/// - Debounced write operations (handled by DebouncedSyncOperations)
/// - Authentication and user management (handled by parent services)
///
/// **Cache Operation Features:**
/// - **High Performance**: Optimized JSON serialization with batch processing capabilities
/// - **Data Integrity**: Comprehensive validation with automatic corruption detection and repair
/// - **Batch Support**: Efficient multi-recipe operations for bulk data management
/// - **Size Management**: Cache size analysis and compaction detection for optimal storage
/// - **User Isolation**: User-specific cache operations ensuring secure data separation
///
/// **Usage Examples:**
/// ```dart
/// // Initialize cache and load all recipes
/// final recipes = await CacheOperations.initializeCache(
///   cacheHelper: cacheHelper,
///   currentUserId: userId,
///   setError: errorHandler,
/// );
/// 
/// // Individual recipe operations
/// await CacheOperations.saveRecipeToCache(cacheHelper: helper, recipe: recipe);
/// final recipe = await CacheOperations.loadRecipeFromCache(helper, recipeId);
/// 
/// // Batch operations for performance
/// await CacheOperations.saveMultipleRecipesToCache(helper, recipes);
/// 
/// // Cache validation and maintenance
/// final stats = await CacheOperations.validateCacheIntegrity(helper);
/// await CacheOperations.fixCacheCorruption(helper);
/// ```
class CacheOperations {

  // ===== CACHE INITIALIZATION =====

  /// Initialize cache and load all cached recipes
  static Future<List<Recipe>> initializeCache({
    required JsonCacheHelper cacheHelper,
    required String? currentUserId,
    required void Function(String) setError,
  }) async {
    try {
      AppLogger.info('🔄 Initializing recipe cache...');

      // Set current user for cache scoping
      cacheHelper.setCurrentUser(currentUserId);

      // Load cached recipes
      final cachedRecipes = await loadAllCachedRecipes(cacheHelper);

      AppLogger.success('✅ Recipe cache initialized with ${cachedRecipes.length} recipes');
      return cachedRecipes;
    } catch (e) {
      AppLogger.error('❌ Cache initialization error: $e');
      setError('Kunde inte ladda recept: $e');
      return [];
    }
  }

  // ===== BASIC CACHE OPERATIONS =====

  /// Save recipe to local cache
  static Future<void> saveRecipeToCache({
    required JsonCacheHelper cacheHelper,
    required Recipe recipe,
  }) async {
    try {
      final recipeData = recipe.toJson();
      await cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Cache save error for recipe ${recipe.id}: $e');
      rethrow;
    }
  }

  /// Load recipe from cache by ID
  static Future<Recipe?> loadRecipeFromCache({
    required JsonCacheHelper cacheHelper,
    required String recipeId,
  }) async {
    try {
      final recipeData = await cacheHelper.loadJson(recipeId);
      if (recipeData != null) {
        final recipe = Recipe.fromJson(recipeData);
        AppLogger.debug('Recipe loaded from cache: ${recipe.title}');
        return recipe;
      }
      return null;
    } catch (e) {
      AppLogger.error('Cache load error for recipe $recipeId: $e');
      return null;
    }
  }

  /// Remove recipe from cache
  static Future<void> removeRecipeFromCache({
    required JsonCacheHelper cacheHelper,
    required String recipeId,
  }) async {
    try {
      await cacheHelper.delete(recipeId);
      AppLogger.debug('Recipe removed from cache: $recipeId');
    } catch (e) {
      AppLogger.error('Cache removal error for recipe $recipeId: $e');
      rethrow;
    }
  }

  /// Load all cached recipes
  static Future<List<Recipe>> loadAllCachedRecipes(JsonCacheHelper cacheHelper) async {
    try {
      final cachedRecipeIds = await cacheHelper.getAllKeys();
      final recipes = <Recipe>[];

      for (final recipeId in cachedRecipeIds) {
        final recipe = await loadRecipeFromCache(
          cacheHelper: cacheHelper,
          recipeId: recipeId,
        );
        if (recipe != null) {
          recipes.add(recipe);
        }
      }

      AppLogger.debug('✅ ${recipes.length} cached recipes loaded');
      return recipes;
    } catch (e) {
      AppLogger.error('Error loading cached recipes: $e');
      return [];
    }
  }

  // ===== CACHE QUERIES =====

  /// Get cached recipe count
  static Future<int> getCachedRecipeCount(JsonCacheHelper cacheHelper) async {
    try {
      final keys = await cacheHelper.getAllKeys();
      return keys.length;
    } catch (e) {
      AppLogger.error('Error getting cached recipe count: $e');
      return 0;
    }
  }

  /// Get all cached recipe IDs
  static Future<List<String>> getCachedRecipeIds(JsonCacheHelper cacheHelper) async {
    try {
      return await cacheHelper.getAllKeys();
    } catch (e) {
      AppLogger.error('Error getting cached recipe IDs: $e');
      return [];
    }
  }

  /// Check if recipe exists in cache
  static Future<bool> isRecipeCached({
    required JsonCacheHelper cacheHelper,
    required String recipeId,
  }) async {
    try {
      final recipeData = await cacheHelper.loadJson(recipeId);
      return recipeData != null;
    } catch (e) {
      AppLogger.error('Error checking if recipe is cached: $e');
      return false;
    }
  }

  /// Get cached recipe data without deserializing
  static Future<Map<String, dynamic>?> getCachedRecipeData({
    required JsonCacheHelper cacheHelper,
    required String recipeId,
  }) async {
    try {
      return await cacheHelper.loadJson(recipeId);
    } catch (e) {
      AppLogger.error('Error getting cached recipe data: $e');
      return null;
    }
  }

  // ===== BATCH OPERATIONS =====

  /// Save multiple recipes to cache
  static Future<void> saveMultipleRecipesToCache({
    required JsonCacheHelper cacheHelper,
    required List<Recipe> recipes,
  }) async {
    final futures = recipes.map((recipe) => saveRecipeToCache(
      cacheHelper: cacheHelper,
      recipe: recipe,
    ));

    await Future.wait(futures);
    AppLogger.debug('✅ ${recipes.length} recipes saved to cache');
  }

  /// Load multiple recipes from cache by IDs
  static Future<List<Recipe>> loadMultipleRecipesFromCache({
    required JsonCacheHelper cacheHelper,
    required List<String> recipeIds,
  }) async {
    final futures = recipeIds.map((id) => loadRecipeFromCache(
      cacheHelper: cacheHelper,
      recipeId: id,
    ));

    final results = await Future.wait(futures);
    final recipes = results.where((recipe) => recipe != null).cast<Recipe>().toList();
    
    AppLogger.debug('✅ ${recipes.length}/${recipeIds.length} recipes loaded from cache');
    return recipes;
  }

  /// Remove multiple recipes from cache
  static Future<void> removeMultipleRecipesFromCache({
    required JsonCacheHelper cacheHelper,
    required List<String> recipeIds,
  }) async {
    final futures = recipeIds.map((id) => removeRecipeFromCache(
      cacheHelper: cacheHelper,
      recipeId: id,
    ));

    await Future.wait(futures);
    AppLogger.debug('✅ ${recipeIds.length} recipes removed from cache');
  }

  // ===== CACHE MANAGEMENT =====

  /// Clear all cached recipes
  static Future<void> clearCache(JsonCacheHelper cacheHelper) async {
    try {
      final keys = await cacheHelper.getAllKeys();
      for (final key in keys) {
        await cacheHelper.delete(key);
      }
      AppLogger.success('✅ Recipe cache cleared (${keys.length} items removed)');
    } catch (e) {
      AppLogger.error('Error clearing cache: $e');
      rethrow;
    }
  }

  /// Clear cache for specific user
  static Future<void> clearCacheForUser({
    required JsonCacheHelper cacheHelper,
    required String userId,
  }) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      int removedCount = 0;

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData != null) {
            final recipe = Recipe.fromJson(recipeData);
            
            // Remove if it belongs to the specified user
            if (recipe.core.createdBy == userId) {
              await cacheHelper.delete(key);
              removedCount++;
            }
          }
        } catch (e) {
          // Remove corrupted entries
          await cacheHelper.delete(key);
          removedCount++;
        }
      }

      AppLogger.info('✅ Cleared cache for user $userId ($removedCount items removed)');
    } catch (e) {
      AppLogger.error('Error clearing cache for user: $e');
      rethrow;
    }
  }

  // ===== CACHE VALIDATION =====

  /// Validate cache integrity
  static Future<Map<String, dynamic>> validateCacheIntegrity(JsonCacheHelper cacheHelper) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      final validRecipes = <String>[];
      final corruptedEntries = <String>[];
      final nullEntries = <String>[];

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData == null) {
            nullEntries.add(key);
            continue;
          }

          // Try to deserialize
          Recipe.fromJson(recipeData);
          validRecipes.add(key);
        } catch (e) {
          corruptedEntries.add(key);
        }
      }

      final result = {
        'totalEntries': allKeys.length,
        'validRecipes': validRecipes.length,
        'corruptedEntries': corruptedEntries.length,
        'nullEntries': nullEntries.length,
        'corruptedKeys': corruptedEntries,
        'nullKeys': nullEntries,
      };

      AppLogger.debug('Cache validation: ${result['validRecipes']}/${result['totalEntries']} entries valid');
      return result;
    } catch (e) {
      AppLogger.error('Error validating cache integrity: $e');
      return {'error': 'Validation failed: $e'};
    }
  }

  /// Fix cache corruption by removing invalid entries
  static Future<int> fixCacheCorruption(JsonCacheHelper cacheHelper) async {
    try {
      final validation = await validateCacheIntegrity(cacheHelper);
      final corruptedKeys = validation['corruptedKeys'] as List<String>? ?? [];
      final nullKeys = validation['nullKeys'] as List<String>? ?? [];
      
      final allCorruptedKeys = [...corruptedKeys, ...nullKeys];

      for (final key in allCorruptedKeys) {
        await cacheHelper.delete(key);
      }

      if (allCorruptedKeys.isNotEmpty) {
        AppLogger.info('✅ Fixed cache corruption: removed ${allCorruptedKeys.length} invalid entries');
      }

      return allCorruptedKeys.length;
    } catch (e) {
      AppLogger.error('Error fixing cache corruption: $e');
      return 0;
    }
  }

  // ===== CACHE UTILITIES =====

  /// Get cache size information
  static Future<Map<String, dynamic>> getCacheSizeInfo(JsonCacheHelper cacheHelper) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      int totalDataSize = 0;
      final recipeSizes = <String, int>{};

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData != null) {
            final dataString = recipeData.toString();
            final size = dataString.length;
            totalDataSize += size;
            recipeSizes[key] = size;
          }
        } catch (e) {
          // Skip corrupted entries
        }
      }

      return {
        'totalEntries': allKeys.length,
        'totalDataSize': totalDataSize,
        'averageRecipeSize': allKeys.isNotEmpty ? (totalDataSize / allKeys.length).round() : 0,
        'recipeSizes': recipeSizes,
      };
    } catch (e) {
      AppLogger.error('Error getting cache size info: $e');
      return {'error': 'Failed to get cache size info'};
    }
  }

  /// Check if cache needs compaction
  static Future<bool> needsCacheCompaction(JsonCacheHelper cacheHelper) async {
    try {
      final validation = await validateCacheIntegrity(cacheHelper);
      final totalEntries = validation['totalEntries'] as int;
      final corruptedEntries = validation['corruptedEntries'] as int;
      final nullEntries = validation['nullEntries'] as int;

      final invalidEntries = corruptedEntries + nullEntries;
      final invalidRatio = totalEntries > 0 ? invalidEntries / totalEntries : 0;

      // Need compaction if more than 10% of entries are invalid
      return invalidRatio > 0.1;
    } catch (e) {
      AppLogger.error('Error checking if cache needs compaction: $e');
      return false;
    }
  }
}