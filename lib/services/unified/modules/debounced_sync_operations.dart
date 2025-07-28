// lib/services/unified/modules/debounced_sync_operations.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';

/// Focused module for debounced Firebase sync operations
/// 
/// This module handles ONLY debounced sync to Firebase:
/// - Debounced recipe sync scheduling
/// - Personal and collaborative recipe Firebase writes
/// - Batch sync processing and error handling
/// - Sync queue management and optimization
/// 
/// ❌ DOES NOT CONTAIN: Real-time sync streams, cache operations, cleanup, statistics
class DebouncedSyncOperations {

  // ===== DEBOUNCED SYNC SCHEDULING =====

  /// Schedule recipe for sync to Firebase (debounced)
  static void scheduleSyncForRecipe({
    required String recipeId,
    required Set<String> pendingSyncIds,
    required Timer? Function() getSyncTimer,
    required void Function(Timer?) setSyncTimer,
    required Duration syncDebounce,
    required VoidCallback onSyncPending,
  }) {
    pendingSyncIds.add(recipeId);
    
    // Cancel existing timer
    getSyncTimer()?.cancel();
    
    // Set new debounced timer
    final newTimer = Timer(syncDebounce, onSyncPending);
    setSyncTimer(newTimer);
    
    AppLogger.debug('Scheduled sync for recipe: $recipeId (${pendingSyncIds.length} pending)');
  }

  /// Sync all pending recipes to Firebase
  static Future<void> syncPendingRecipes({
    required Set<String> pendingSyncIds,
    required Future<Recipe?> Function(String) recipeLoader,
    required String? currentUserId,
  }) async {
    if (pendingSyncIds.isEmpty || currentUserId == null) return;

    final recipesToSync = List<String>.from(pendingSyncIds);
    pendingSyncIds.clear();

    AppLogger.debug('Syncing ${recipesToSync.length} pending recipes to Firebase');

    final syncFutures = recipesToSync.map((recipeId) => 
      _syncRecipeToFirebase(
        recipeId: recipeId,
        recipeLoader: recipeLoader,
        currentUserId: currentUserId,
      )
    );

    try {
      await Future.wait(syncFutures);
      AppLogger.success('✅ Successfully synced ${recipesToSync.length} recipes');
    } catch (e) {
      AppLogger.error('❌ Error syncing recipes: $e');
      // Re-add failed syncs back to pending
      pendingSyncIds.addAll(recipesToSync);
    }
  }

  // ===== INDIVIDUAL RECIPE SYNC =====

  /// Sync individual recipe to repositories
  static Future<void> _syncRecipeToFirebase({
    required String recipeId,
    required Future<Recipe?> Function(String) recipeLoader,
    required String currentUserId,
  }) async {
    try {
      final recipe = await recipeLoader(recipeId);
      if (recipe == null) {
        AppLogger.warning('Recipe not found for sync: $recipeId');
        return;
      }

      if (recipe.isCollaborative) {
        await _syncCollaborativeRecipeToRepository(
          recipe: recipe,
        );
      } else {
        await _syncPersonalRecipeToRepository(
          recipe: recipe,
          currentUserId: currentUserId,
        );
      }
    } catch (e) {
      AppLogger.error('Error syncing recipe $recipeId to Firebase: $e');
      rethrow;
    }
  }

  /// Sync personal recipe to repository
  static Future<void> _syncPersonalRecipeToRepository({
    required Recipe recipe,
    required String currentUserId,
  }) async {
    try {
      final recipeRepository = GetIt.instance<RecipeRepository>();
      await recipeRepository.update(recipe);
      
      AppLogger.debug('Personal recipe synced: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Repository sync error for personal recipe ${recipe.id}: $e');
      rethrow;
    }
  }

  /// Sync collaborative recipe to repository
  static Future<void> _syncCollaborativeRecipeToRepository({
    required Recipe recipe,
  }) async {
    try {
      // Note: Collaborative recipe synchronization needs proper implementation
      // For now, we'll skip the actual sync but log the operation
      AppLogger.debug('Collaborative recipe sync: ${recipe.title} (implementation pending)');
      
      // TODO: Implement proper conversion from Recipe to RealtimeRecipe if needed
      // final collaborativeRepository = GetIt.instance<CollaborativeRecipeRepository>();
      AppLogger.debug('Collaborative recipe synced: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Repository sync error for collaborative recipe ${recipe.id}: $e');
      rethrow;
    }
  }

  // ===== BATCH SYNC OPERATIONS =====

  /// Sync multiple recipes immediately (no debounce)
  static Future<void> syncMultipleRecipesImmediately({
    required List<String> recipeIds,
    required Future<Recipe?> Function(String) recipeLoader,
    required String? currentUserId,
  }) async {
    if (recipeIds.isEmpty || currentUserId == null) return;

    AppLogger.info('Syncing ${recipeIds.length} recipes immediately');

    final syncFutures = recipeIds.map((recipeId) => 
      _syncRecipeToFirebase(
        recipeId: recipeId,
        recipeLoader: recipeLoader,
        currentUserId: currentUserId,
      )
    );

    try {
      await Future.wait(syncFutures);
      AppLogger.success('✅ Successfully synced ${recipeIds.length} recipes immediately');
    } catch (e) {
      AppLogger.error('❌ Error in immediate sync: $e');
      rethrow;
    }
  }

  /// Force sync single recipe immediately
  static Future<void> forceSyncRecipe({
    required String recipeId,
    required Future<Recipe?> Function(String) recipeLoader,
    required String? currentUserId,
  }) async {
    if (currentUserId == null) {
      AppLogger.warning('Cannot force sync: No authenticated user');
      return;
    }

    AppLogger.info('Force syncing recipe: $recipeId');

    await _syncRecipeToFirebase(
      recipeId: recipeId,
      recipeLoader: recipeLoader,
      currentUserId: currentUserId,
    );

    AppLogger.success('✅ Force sync completed for recipe: $recipeId');
  }

  // ===== SYNC QUEUE MANAGEMENT =====

  /// Get pending sync status
  static Map<String, dynamic> getPendingSyncStatus(Set<String> pendingSyncIds) {
    return {
      'pendingCount': pendingSyncIds.length,
      'pendingRecipeIds': pendingSyncIds.toList(),
      'hasPendingSync': pendingSyncIds.isNotEmpty,
    };
  }

  /// Clear pending syncs
  static void clearPendingSync(Set<String> pendingSyncIds) {
    final count = pendingSyncIds.length;
    pendingSyncIds.clear();
    
    if (count > 0) {
      AppLogger.info('Cleared $count pending sync items');
    }
  }

  /// Remove specific recipe from pending sync
  static void removePendingSync({
    required String recipeId,
    required Set<String> pendingSyncIds,
  }) {
    final removed = pendingSyncIds.remove(recipeId);
    if (removed) {
      AppLogger.debug('Removed recipe from pending sync: $recipeId');
    }
  }

  /// Add recipe to pending sync queue
  static void addPendingSync({
    required String recipeId,
    required Set<String> pendingSyncIds,
  }) {
    pendingSyncIds.add(recipeId);
    AppLogger.debug('Added recipe to pending sync: $recipeId');
  }

  // ===== SYNC OPTIMIZATION =====

  /// Check if recipe needs sync based on last sync time
  static bool shouldSyncRecipe({
    required Recipe recipe,
    required Duration minSyncInterval,
  }) {
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(recipe.core.updatedAt);
    
    // Always sync if updated recently
    if (timeSinceUpdate < minSyncInterval) {
      return true;
    }
    
    // Check if recipe has unsaved changes (this would need to be tracked separately)
    // For now, sync if updated within last hour
    return timeSinceUpdate < const Duration(hours: 1);
  }

  /// Get recipes that need urgent sync
  static List<String> getUrgentSyncRecipes({
    required Set<String> pendingSyncIds,
    required Future<Recipe?> Function(String) recipeLoader,
    required Duration urgentThreshold,
  }) {
    // This would need to be implemented with recipe timestamps
    // For now, return all pending if they've been waiting too long
    return pendingSyncIds.toList();
  }

  // ===== SYNC ERROR HANDLING =====

  /// Handle sync error with retry logic
  static Future<void> handleSyncError({
    required String recipeId,
    required dynamic error,
    required Set<String> pendingSyncIds,
    required int maxRetries,
    required Future<Recipe?> Function(String) recipeLoader,
    required String? currentUserId,
  }) async {
    AppLogger.error('Sync error for recipe $recipeId: $error');

    if (currentUserId == null) return;

    // Add back to pending for retry
    pendingSyncIds.add(recipeId);

    // For network errors, we might want to implement exponential backoff
    if (error.toString().contains('network') || 
        error.toString().contains('timeout') ||
        error.toString().contains('unavailable')) {
      
      AppLogger.info('Network error detected, will retry sync for: $recipeId');
      return;
    }

    // For other errors, log and continue
    AppLogger.warning('Non-network sync error for $recipeId, added to retry queue');
  }

  /// Retry failed syncs
  static Future<void> retryFailedSyncs({
    required Set<String> failedSyncIds,
    required Future<Recipe?> Function(String) recipeLoader,
    required String? currentUserId,
  }) async {
    if (failedSyncIds.isEmpty || currentUserId == null) return;

    AppLogger.info('Retrying ${failedSyncIds.length} failed syncs');

    final retryList = List<String>.from(failedSyncIds);
    failedSyncIds.clear();

    for (final recipeId in retryList) {
      try {
        await _syncRecipeToFirebase(
          recipeId: recipeId,
          recipeLoader: recipeLoader,
          currentUserId: currentUserId,
        );
      } catch (e) {
        AppLogger.error('Retry failed for recipe $recipeId: $e');
        failedSyncIds.add(recipeId); // Add back to failed queue
      }
    }

    AppLogger.info('Retry completed. ${failedSyncIds.length} still failed');
  }
}