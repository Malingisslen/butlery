// lib/services/unified/modules/realtime_cache_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

/// Focused module for real-time cache management and cleanup
/// This module handles ONLY cache and cleanup operations:
/// - Real-time recipe cache management
/// - Session cleanup and resource disposal
/// - Memory management for real-time operations
/// - Cache synchronization during real-time editing
/// ❌ DOES NOT CONTAIN: Session management, content operations, conflict resolution, editor tracking
class RealtimeCacheManager {
  /// Save recipe to cache during real-time editing
  static Future<void> saveToCache({
    required Recipe recipe,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      final recipeData = recipe.toJson();
      await cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('✅ Real-time recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('❌ Real-time cache save error: $e');
      rethrow;
    }
  }

  /// Load recipe from cache for real-time operations
  static Future<Recipe?> loadFromCache({
    required String recipeId,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      final cachedData = await cacheHelper.loadJson(recipeId);
      if (cachedData != null) {
        final recipe = Recipe.fromJson(cachedData);
        AppLogger.debug(
          '✅ Real-time recipe loaded from cache: ${recipe.title}',
        );
        return recipe;
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Real-time cache load error: $e');
      return null;
    }
  }

  /// Update cached recipe with real-time changes
  static Future<void> updateCacheWithEdit({
    required String recipeId,
    required Map<String, dynamic> editData,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      // Load existing cached recipe
      final existingData = await cacheHelper.loadJson(recipeId);
      if (existingData == null) {
        AppLogger.warning(
          'No cached recipe found for real-time update: $recipeId',
        );
        return;
      }

      // Apply edit to cached data
      final updatedData = Map<String, dynamic>.from(existingData);
      _applyEditToData(updatedData, editData);

      // Save updated data back to cache
      await cacheHelper.saveJson(recipeId, updatedData);
      AppLogger.debug(
        '✅ Cache updated with real-time edit for recipe $recipeId',
      );
    } catch (e) {
      AppLogger.error('❌ Error updating cache with real-time edit: $e');
    }
  }

  /// Apply edit data to cached recipe data
  static void _applyEditToData(
    Map<String, dynamic> recipeData,
    Map<String, dynamic> editData,
  ) {
    // Update basic fields
    for (final entry in editData.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip metadata fields
      if (_isMetadataField(key)) continue;

      // Apply field update
      recipeData[key] = value;
    }

    // Update last edited metadata
    recipeData['editedAt'] = editData['editedAt'];
    recipeData['editedBy'] = editData['editedBy'];
    recipeData['editedByDisplayName'] = editData['editedByDisplayName'];
  }

  /// Check if field is metadata that shouldn't be cached
  static bool _isMetadataField(String fieldName) {
    const metadataFields = {
      'operation',
      'field',
      'editType',
      'index',
      'fromIndex',
      'toIndex',
    };

    return metadataFields.contains(fieldName);
  }

  /// Clear cache for specific recipe
  static Future<void> clearRecipeCache({
    required String recipeId,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      // Use delete instead of clearJson
      await cacheHelper.delete(recipeId);
      AppLogger.debug('✅ Cache cleared for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error clearing cache for recipe $recipeId: $e');
    }
  }

  /// Preload recipes into cache for real-time editing
  static Future<void> preloadRecipesForRealtimeEditing({
    required List<String> recipeIds,
    required JsonCacheHelper cacheHelper,
    required Future<Recipe?> Function(String) loadRecipeFromFirestore,
  }) async {
    try {
      AppLogger.info(
        '🔄 Preloading ${recipeIds.length} recipes for real-time editing',
      );

      final futures = recipeIds.map((recipeId) async {
        // Check if already cached
        final cached = await cacheHelper.loadJson(recipeId);
        if (cached != null) {
          AppLogger.debug('Recipe $recipeId already cached');
          return;
        }

        // Load from Firestore and cache
        final recipe = await loadRecipeFromFirestore(recipeId);
        if (recipe != null) {
          await saveToCache(recipe: recipe, cacheHelper: cacheHelper);
        }
      });

      await Future.wait(futures);
      AppLogger.success('✅ Preloading completed for real-time editing');
    } catch (e) {
      AppLogger.error('❌ Error preloading recipes for real-time editing: $e');
    }
  }

  /// Sync cache with Firestore during real-time editing
  static Future<void> syncCacheWithFirestore({
    required String recipeId,
    required Recipe latestRecipe,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      await saveToCache(recipe: latestRecipe, cacheHelper: cacheHelper);
      AppLogger.debug('✅ Cache synced with Firestore for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error syncing cache with Firestore: $e');
    }
  }

  /// Check if cached recipe is stale
  static Future<bool> isCacheStale({
    required String recipeId,
    required DateTime lastFirestoreUpdate,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      final cachedData = await cacheHelper.loadJson(recipeId);
      if (cachedData == null) return true;

      final cacheTimestamp = cachedData['editedAt'];
      if (cacheTimestamp == null) return true;

      final cacheTime = SerializationUtils.parseRequiredDateTimeValue(
        cacheTimestamp,
      );

      return lastFirestoreUpdate.isAfter(cacheTime);
    } catch (e) {
      AppLogger.error('❌ Error checking cache staleness: $e');
      return true; // Assume stale on error
    }
  }

  /// Force refresh cache from Firestore
  static Future<void> forceRefreshCache({
    required String recipeId,
    required JsonCacheHelper cacheHelper,
    required Future<Recipe?> Function(String) loadRecipeFromFirestore,
  }) async {
    try {
      AppLogger.info('🔄 Force refreshing cache for recipe $recipeId');

      // Clear existing cache
      await clearRecipeCache(recipeId: recipeId, cacheHelper: cacheHelper);

      // Load fresh data from Firestore
      final recipe = await loadRecipeFromFirestore(recipeId);
      if (recipe != null) {
        await saveToCache(recipe: recipe, cacheHelper: cacheHelper);
        AppLogger.success('✅ Cache force refreshed for recipe $recipeId');
      } else {
        AppLogger.warning('⚠️ No recipe found in Firestore for $recipeId');
      }
    } catch (e) {
      AppLogger.error('❌ Error force refreshing cache: $e');
    }
  }

  /// Dispose of all real-time resources
  static Future<void> dispose({
    required Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required Future<bool> Function(String) stopRealtimeEditing,
  }) async {
    try {
      AppLogger.info('🧹 Disposing real-time resources...');

      // Cancel all active editing sessions
      final sessionCleanup = _cleanupActiveSessions(
        activeEditingSessions: activeEditingSessions,
        stopRealtimeEditing: stopRealtimeEditing,
      );

      // Cancel all conflict resolution timers
      final timerCleanup = _cleanupConflictTimers(conflictResolutionTimers);

      // Clear pending edits
      final editsCleanup = _cleanupPendingEdits(pendingRealtimeEdits);

      // Wait for all cleanup to complete
      await Future.wait([sessionCleanup, timerCleanup, editsCleanup]);

      AppLogger.success('✅ Real-time resources disposed successfully');
    } catch (e) {
      AppLogger.error('❌ Error disposing real-time resources: $e');
    }
  }

  /// Cleanup active editing sessions
  static Future<void> _cleanupActiveSessions({
    required Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions,
    required Future<bool> Function(String) stopRealtimeEditing,
  }) async {
    AppLogger.info(
      '🛑 Stopping ${activeEditingSessions.length} active real-time sessions',
    );

    final futures = activeEditingSessions.keys.toList().map(
      (recipeId) => stopRealtimeEditing(recipeId),
    );

    await Future.wait(futures);
    activeEditingSessions.clear();
  }

  /// Cleanup conflict resolution timers
  static Future<void> _cleanupConflictTimers(
    Map<String, Timer> conflictResolutionTimers,
  ) async {
    AppLogger.info(
      '⏰ Cancelling ${conflictResolutionTimers.length} conflict timers',
    );

    for (final timer in conflictResolutionTimers.values) {
      timer.cancel();
    }
    conflictResolutionTimers.clear();
  }

  /// Cleanup pending edits
  static Future<void> _cleanupPendingEdits(
    Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
  ) async {
    final totalPendingEdits = pendingRealtimeEdits.values.fold<int>(
      0,
      (total, edits) => total + edits.length,
    );

    AppLogger.info('📝 Clearing $totalPendingEdits pending real-time edits');
    pendingRealtimeEdits.clear();
  }

  /// Cleanup resources for specific recipe
  static Future<void> cleanupRecipeResources({
    required String recipeId,
    required Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required JsonCacheHelper cacheHelper,
  }) async {
    try {
      AppLogger.info('🧹 Cleaning up resources for recipe $recipeId');

      // Cancel subscription
      final subscription = activeEditingSessions.remove(recipeId);
      await subscription?.cancel();

      // Clear pending edits
      pendingRealtimeEdits.remove(recipeId);

      // Cancel conflict timer
      conflictResolutionTimers[recipeId]?.cancel();
      conflictResolutionTimers.remove(recipeId);

      // Optionally clear cache (commented out to preserve data)
      // await clearRecipeCache(recipeId: recipeId, cacheHelper: cacheHelper);

      AppLogger.success('✅ Resources cleaned up for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error cleaning up resources for recipe $recipeId: $e');
    }
  }

  /// Check memory usage of real-time operations
  static Map<String, dynamic> getMemoryUsage({
    required Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    final totalPendingEdits = pendingRealtimeEdits.values.fold<int>(
      0,
      (total, edits) => total + edits.length,
    );

    return {
      'active_sessions': activeEditingSessions.length,
      'pending_edits_count': totalPendingEdits,
      'conflict_timers_count': conflictResolutionTimers.length,
      'estimated_memory_kb': _estimateMemoryUsage(
        activeEditingSessions.length,
        totalPendingEdits,
        conflictResolutionTimers.length,
      ),
    };
  }

  /// Estimate memory usage in KB
  static int _estimateMemoryUsage(
    int activeSessions,
    int pendingEdits,
    int conflictTimers,
  ) {
    // Rough estimates:
    // - Each active session: ~2KB (StreamSubscription overhead)
    // - Each pending edit: ~1KB (edit data)
    // - Each conflict timer: ~0.5KB (Timer overhead)

    final sessionMemory = activeSessions * 2;
    final editsMemory = pendingEdits * 1;
    final timersMemory = (conflictTimers * 0.5).round();

    return sessionMemory + editsMemory + timersMemory;
  }

  /// Cleanup memory when thresholds are exceeded
  static Future<void> cleanupExcessMemory({
    required Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    int maxActiveSessions = 10,
    int maxPendingEdits = 100,
  }) async {
    try {
      final memoryUsage = getMemoryUsage(
        activeEditingSessions: activeEditingSessions,
        pendingRealtimeEdits: pendingRealtimeEdits,
        conflictResolutionTimers: conflictResolutionTimers,
      );

      final estimatedMemory = memoryUsage['estimated_memory_kb'] as int;

      if (estimatedMemory > 1024) {
        // If over 1MB
        AppLogger.warning(
          '⚠️ High memory usage detected: ${estimatedMemory}KB',
        );

        // Cleanup oldest pending edits
        await _cleanupOldestPendingEdits(pendingRealtimeEdits, maxPendingEdits);

        AppLogger.info('🧹 Memory cleanup completed');
      }
    } catch (e) {
      AppLogger.error('❌ Error during memory cleanup: $e');
    }
  }

  /// Cleanup oldest pending edits to free memory
  static Future<void> _cleanupOldestPendingEdits(
    Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    int maxPendingEdits,
  ) async {
    final totalEdits = pendingRealtimeEdits.values.fold<int>(
      0,
      (total, edits) => total + edits.length,
    );

    if (totalEdits <= maxPendingEdits) return;

    // Remove oldest edits from each recipe
    for (final entry in pendingRealtimeEdits.entries) {
      final recipeEdits = entry.value;
      if (recipeEdits.length > 10) {
        // Keep only 10 most recent edits per recipe
        recipeEdits.removeRange(0, recipeEdits.length - 10);
      }
    }

    AppLogger.info('🧹 Cleaned up oldest pending edits');
  }
}
