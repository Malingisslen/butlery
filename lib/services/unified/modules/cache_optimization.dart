// lib/services/unified/modules/cache_optimization.dart

import 'dart:async';
import '../../../models/recipe_unified.dart';
import '../../../core/utils/logger.dart';
import '../../../core/cache/json_cache_helper.dart';

/// Focused module for cache optimization and cleanup
/// 
/// This module handles ONLY cache optimization operations:
/// - Periodic cache cleanup and maintenance
/// - Old recipe detection and removal
/// - Cache validation and integrity checks
/// - User permission-based cleanup
/// 
/// ❌ DOES NOT CONTAIN: Basic cache operations, Firebase sync, statistics, auth handling
class CacheOptimization {

  // ===== CACHE CLEANUP SCHEDULING =====

  /// Start periodic cache cleanup
  static Timer startPeriodicCleanup({
    required Duration cleanupInterval,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
  }) {
    return Timer.periodic(cleanupInterval, (_) {
      _performCacheCleanup(
        cacheHelper: cacheHelper,
        getCurrentUserId: getCurrentUserId,
      );
    });
  }

  /// Stop periodic cache cleanup
  static void stopPeriodicCleanup(Timer? cleanupTimer) {
    cleanupTimer?.cancel();
    AppLogger.debug('Periodic cache cleanup stopped');
  }

  // ===== CACHE CLEANUP OPERATIONS =====

  /// Perform comprehensive cache cleanup
  static Future<Map<String, int>> _performCacheCleanup({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
  }) async {
    try {
      AppLogger.debug('Performing cache cleanup...');

      final allKeys = await cacheHelper.getAllKeys();
      final cleanupResults = {
        'total_scanned': allKeys.length,
        'null_entries_removed': 0,
        'corrupted_entries_removed': 0,
        'permission_invalid_removed': 0,
        'old_recipes_removed': 0,
        'total_removed': 0,
      };

      for (final key in allKeys) {
        final cleanupResult = await _cleanupSingleCacheEntry(
          key: key,
          cacheHelper: cacheHelper,
          getCurrentUserId: getCurrentUserId,
        );

        // Aggregate results
        cleanupResults['null_entries_removed'] = 
            (cleanupResults['null_entries_removed'] ?? 0) + (cleanupResult['null'] ?? 0);
        cleanupResults['corrupted_entries_removed'] = 
            (cleanupResults['corrupted_entries_removed'] ?? 0) + (cleanupResult['corrupted'] ?? 0);
        cleanupResults['permission_invalid_removed'] = 
            (cleanupResults['permission_invalid_removed'] ?? 0) + (cleanupResult['permission'] ?? 0);
        cleanupResults['old_recipes_removed'] = 
            (cleanupResults['old_recipes_removed'] ?? 0) + (cleanupResult['old'] ?? 0);
      }

      cleanupResults['total_removed'] = 
          (cleanupResults['null_entries_removed'] ?? 0) +
          (cleanupResults['corrupted_entries_removed'] ?? 0) +
          (cleanupResults['permission_invalid_removed'] ?? 0) +
          (cleanupResults['old_recipes_removed'] ?? 0);

      final totalRemoved = cleanupResults['total_removed'] ?? 0;
      if (totalRemoved > 0) {
        AppLogger.info('Cache cleanup completed: removed $totalRemoved items');
      } else {
        AppLogger.debug('Cache cleanup completed: no items removed');
      }

      return cleanupResults;
    } catch (e) {
      AppLogger.error('Cache cleanup error: $e');
      return {'error': 1};
    }
  }

  /// Cleanup single cache entry
  static Future<Map<String, int>> _cleanupSingleCacheEntry({
    required String key,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
  }) async {
    final result = <String, int>{};
    
    try {
      final recipeData = await cacheHelper.loadJson(key);
      if (recipeData == null) {
        // Remove null entries
        await cacheHelper.delete(key);
        result['null'] = 1;
        return result;
      }

      // Check if recipe is valid and should be kept
      final recipe = Recipe.fromJson(recipeData);
      if (_shouldRemoveFromCache(recipe, getCurrentUserId())) {
        final removalReason = _getRemovalReason(recipe, getCurrentUserId());
        await cacheHelper.delete(key);
        result[removalReason] = 1;
      }
    } catch (e) {
      // Remove corrupted entries
      await cacheHelper.delete(key);
      result['corrupted'] = 1;
    }

    return result;
  }

  // ===== CACHE VALIDATION LOGIC =====

  /// Check if recipe should be removed from cache
  static bool _shouldRemoveFromCache(Recipe recipe, String? currentUserId) {
    if (currentUserId == null) return false;

    // Remove recipes that don't belong to current user
    if (recipe.isPersonal && recipe.core.createdBy != currentUserId) {
      return true;
    }

    // Remove collaborative recipes where user is no longer a member
    if (recipe.isCollaborative) {
      final memberPermissions = recipe.socialData?.memberPermissions ?? {};
      if (!memberPermissions.containsKey(currentUserId)) {
        return true;
      }
    }

    // Keep recipes that are recently accessed or modified
    final now = DateTime.now();
    final daysSinceUpdate = now.difference(recipe.core.updatedAt).inDays;
    
    // Remove very old personal recipes that haven't been updated
    if (recipe.isPersonal && daysSinceUpdate > 365) {
      return true;
    }

    return false;
  }

  /// Get reason for cache removal
  static String _getRemovalReason(Recipe recipe, String? currentUserId) {
    if (currentUserId == null) return 'permission';

    // Check permission issues
    if (recipe.isPersonal && recipe.core.createdBy != currentUserId) {
      return 'permission';
    }

    if (recipe.isCollaborative) {
      final memberPermissions = recipe.socialData?.memberPermissions ?? {};
      if (!memberPermissions.containsKey(currentUserId)) {
        return 'permission';
      }
    }

    // Check age
    final now = DateTime.now();
    final daysSinceUpdate = now.difference(recipe.core.updatedAt).inDays;
    if (recipe.isPersonal && daysSinceUpdate > 365) {
      return 'old';
    }

    return 'unknown';
  }

  // ===== TARGETED CLEANUP OPERATIONS =====

  /// Remove recipes that user no longer has access to
  static Future<int> cleanupInvalidPermissions({
    required JsonCacheHelper cacheHelper,
    required String currentUserId,
  }) async {
    try {
      AppLogger.debug('Cleaning up invalid permissions for user: $currentUserId');

      final allKeys = await cacheHelper.getAllKeys();
      int removedCount = 0;

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData == null) continue;

          final recipe = Recipe.fromJson(recipeData);

          // Check if user should have access
          bool hasAccess = false;

          if (recipe.isPersonal) {
            hasAccess = recipe.core.createdBy == currentUserId;
          } else if (recipe.isCollaborative) {
            final memberPermissions = recipe.socialData?.memberPermissions ?? {};
            hasAccess = memberPermissions.containsKey(currentUserId);
          }

          if (!hasAccess) {
            await cacheHelper.delete(key);
            removedCount++;
            AppLogger.debug('Removed recipe without access: ${recipe.title}');
          }
        } catch (e) {
          // Remove corrupted entries
          await cacheHelper.delete(key);
          removedCount++;
        }
      }

      if (removedCount > 0) {
        AppLogger.info('Permission cleanup: removed $removedCount recipes');
      }

      return removedCount;
    } catch (e) {
      AppLogger.error('Error cleaning up invalid permissions: $e');
      return 0;
    }
  }

  /// Remove old recipes that haven't been updated recently
  static Future<int> cleanupOldRecipes({
    required JsonCacheHelper cacheHelper,
    required Duration maxAge,
    required String? currentUserId,
  }) async {
    try {
      AppLogger.debug('Cleaning up old recipes (max age: ${maxAge.inDays} days)');

      final allKeys = await cacheHelper.getAllKeys();
      int removedCount = 0;
      final now = DateTime.now();

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData == null) continue;

          final recipe = Recipe.fromJson(recipeData);
          final daysSinceUpdate = now.difference(recipe.core.updatedAt).inDays;

          // Only remove personal recipes that are old
          // Keep collaborative recipes regardless of age
          if (recipe.isPersonal && daysSinceUpdate > maxAge.inDays) {
            await cacheHelper.delete(key);
            removedCount++;
            AppLogger.debug('Removed old recipe: ${recipe.title} ($daysSinceUpdate days old)');
          }
        } catch (e) {
          // Remove corrupted entries
          await cacheHelper.delete(key);
          removedCount++;
        }
      }

      if (removedCount > 0) {
        AppLogger.info('Old recipe cleanup: removed $removedCount recipes');
      }

      return removedCount;
    } catch (e) {
      AppLogger.error('Error cleaning up old recipes: $e');
      return 0;
    }
  }

  /// Remove corrupted cache entries
  static Future<int> cleanupCorruptedEntries(JsonCacheHelper cacheHelper) async {
    try {
      AppLogger.debug('Cleaning up corrupted cache entries');

      final allKeys = await cacheHelper.getAllKeys();
      int removedCount = 0;

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData == null) {
            await cacheHelper.delete(key);
            removedCount++;
            continue;
          }

          // Try to deserialize to check validity
          Recipe.fromJson(recipeData);
        } catch (e) {
          // Remove corrupted entries
          await cacheHelper.delete(key);
          removedCount++;
          AppLogger.debug('Removed corrupted entry: $key');
        }
      }

      if (removedCount > 0) {
        AppLogger.info('Corrupted entry cleanup: removed $removedCount entries');
      }

      return removedCount;
    } catch (e) {
      AppLogger.error('Error cleaning up corrupted entries: $e');
      return 0;
    }
  }

  // ===== CACHE OPTIMIZATION STRATEGIES =====

  /// Optimize cache by removing least recently used recipes
  static Future<int> optimizeCacheByLRU({
    required JsonCacheHelper cacheHelper,
    required int maxCacheSize,
  }) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      if (allKeys.length <= maxCacheSize) return 0;

      AppLogger.debug('Optimizing cache by LRU (current: ${allKeys.length}, max: $maxCacheSize)');

      final recipesByAge = <String, DateTime>{};

      // Get last update time for each recipe
      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData != null) {
            final recipe = Recipe.fromJson(recipeData);
            recipesByAge[key] = recipe.core.updatedAt;
          }
        } catch (e) {
          // Mark corrupted entries with very old date for removal
          recipesByAge[key] = DateTime(2000);
        }
      }

      // Sort by age (oldest first)
      final sortedKeys = recipesByAge.keys.toList()
        ..sort((a, b) => recipesByAge[a]!.compareTo(recipesByAge[b]!));

      // Remove oldest entries to reach target size
      final keysToRemove = sortedKeys.take(allKeys.length - maxCacheSize);
      int removedCount = 0;

      for (final key in keysToRemove) {
        await cacheHelper.delete(key);
        removedCount++;
      }

      AppLogger.info('LRU optimization: removed $removedCount old recipes');
      return removedCount;
    } catch (e) {
      AppLogger.error('Error optimizing cache by LRU: $e');
      return 0;
    }
  }

  /// Optimize cache by recipe type priority
  static Future<int> optimizeCacheByPriority({
    required JsonCacheHelper cacheHelper,
    required String currentUserId,
    required int maxCacheSize,
  }) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      if (allKeys.length <= maxCacheSize) return 0;

      AppLogger.debug('Optimizing cache by priority (current: ${allKeys.length}, max: $maxCacheSize)');

      final recipesByPriority = <String, int>{};

      // Assign priority scores
      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData != null) {
            final recipe = Recipe.fromJson(recipeData);
            recipesByPriority[key] = _getRecipePriority(recipe, currentUserId);
          }
        } catch (e) {
          // Corrupted entries get lowest priority
          recipesByPriority[key] = 0;
        }
      }

      // Sort by priority (lowest first for removal)
      final sortedKeys = recipesByPriority.keys.toList()
        ..sort((a, b) => recipesByPriority[a]!.compareTo(recipesByPriority[b]!));

      // Remove lowest priority entries
      final keysToRemove = sortedKeys.take(allKeys.length - maxCacheSize);
      int removedCount = 0;

      for (final key in keysToRemove) {
        await cacheHelper.delete(key);
        removedCount++;
      }

      AppLogger.info('Priority optimization: removed $removedCount low-priority recipes');
      return removedCount;
    } catch (e) {
      AppLogger.error('Error optimizing cache by priority: $e');
      return 0;
    }
  }

  /// Get recipe priority score for cache optimization
  static int _getRecipePriority(Recipe recipe, String currentUserId) {
    int priority = 0;

    // Collaborative recipes get higher priority
    if (recipe.isCollaborative) {
      priority += 100;
    }

    // Recipes owned by current user get higher priority
    if (recipe.core.createdBy == currentUserId) {
      priority += 50;
    }

    // Recently updated recipes get higher priority
    final daysSinceUpdate = DateTime.now().difference(recipe.core.updatedAt).inDays;
    if (daysSinceUpdate < 7) {
      priority += 30;
    } else if (daysSinceUpdate < 30) {
      priority += 20;
    } else if (daysSinceUpdate < 90) {
      priority += 10;
    }

    // Recipes with more content get slightly higher priority
    final contentScore = (recipe.core.ingredients.length * 2) + 
                        (recipe.core.instructions.length * 3);
    priority += (contentScore / 10).round().clamp(0, 20);

    return priority;
  }

  // ===== CACHE HEALTH MONITORING =====

  /// Check cache health and recommend optimizations
  static Future<Map<String, dynamic>> assessCacheHealth({
    required JsonCacheHelper cacheHelper,
    required String? currentUserId,
  }) async {
    try {
      final allKeys = await cacheHelper.getAllKeys();
      final assessment = {
        'total_entries': allKeys.length,
        'corrupted_entries': 0,
        'permission_issues': 0,
        'old_entries': 0,
        'recommendations': <String>[],
      };

      final now = DateTime.now();

      for (final key in allKeys) {
        try {
          final recipeData = await cacheHelper.loadJson(key);
          if (recipeData == null) {
            assessment['corrupted_entries'] = (assessment['corrupted_entries'] as int) + 1;
            continue;
          }

          final recipe = Recipe.fromJson(recipeData);

          // Check permissions
          if (_shouldRemoveFromCache(recipe, currentUserId)) {
            assessment['permission_issues'] = (assessment['permission_issues'] as int) + 1;
          }

          // Check age
          final daysSinceUpdate = now.difference(recipe.core.updatedAt).inDays;
          if (daysSinceUpdate > 180) {
            assessment['old_entries'] = (assessment['old_entries'] as int) + 1;
          }
        } catch (e) {
          assessment['corrupted_entries'] = (assessment['corrupted_entries'] as int) + 1;
        }
      }

      // Generate recommendations
      final recommendations = assessment['recommendations'] as List<String>;
      
      if ((assessment['corrupted_entries'] as int) > 0) {
        recommendations.add('Clean up ${assessment['corrupted_entries']} corrupted entries');
      }
      
      if ((assessment['permission_issues'] as int) > 0) {
        recommendations.add('Remove ${assessment['permission_issues']} recipes with permission issues');
      }
      
      if ((assessment['old_entries'] as int) > 10) {
        recommendations.add('Consider removing ${assessment['old_entries']} old entries');
      }
      
      if (allKeys.length > 1000) {
        recommendations.add('Cache size is large (${allKeys.length} entries), consider optimization');
      }

      return assessment;
    } catch (e) {
      AppLogger.error('Error assessing cache health: $e');
      return {'error': 'Assessment failed'};
    }
  }
}