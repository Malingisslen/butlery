// lib/services/unified/modules/recipe_cache_module.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

// Focused modules
import 'package:butlery/services/unified/modules/cache_operations.dart';
import 'package:butlery/services/unified/modules/firebase_sync_manager.dart';
import 'package:butlery/services/unified/modules/debounced_sync_operations.dart';
import 'package:butlery/services/unified/modules/cache_optimization.dart';

/// Clean facade for recipe cache management using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - CacheOperations: Local cache save/load/remove operations  
/// - FirebaseSyncManager: Real-time Firebase synchronization
/// - DebouncedSyncOperations: Debounced Firebase writes
/// - CacheOptimization: Cache cleanup and optimization
///
/// ❌ DOES NOT CONTAIN: Complex implementation details, direct Firebase/cache logic
class RecipeCacheModule {
  final FirebaseFirestore _firestore;
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final void Function(String) _setError;
  final void Function() _notifyListeners;

  /// Sync subscriptions (delegated to FirebaseSyncManager)
  final Map<String, StreamSubscription<QuerySnapshot>> _syncSubscriptions = {};
  
  /// Pending sync items (delegated to DebouncedSyncOperations)
  final Set<String> _pendingSyncIds = {};
  
  /// Sync debounce timer
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounce = Duration(seconds: 2);

  /// Cache cleanup timer (delegated to CacheOptimization)
  Timer? _cacheCleanupTimer;
  static const Duration _cacheCleanupInterval = Duration(hours: 24);

  RecipeCacheModule({
    required FirebaseFirestore firestore,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required void Function(String) setError,
    required void Function() notifyListeners,
  })  : _firestore = firestore,
        _cacheHelper = cacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _setError = setError,
        _notifyListeners = notifyListeners {
    
    // Set current user for cache helper
    _cacheHelper.setCurrentUser(_getCurrentUserId());
    
    // Start periodic cache cleanup
    _startCacheCleanup();
  }

  // ===== CACHE INITIALIZATION (DELEGATE TO CACHE_OPERATIONS) =====

  /// Initialize cache and load cached recipes
  Future<List<Recipe>> initializeCache() async {
    return CacheOperations.initializeCache(
      cacheHelper: _cacheHelper,
      currentUserId: _getCurrentUserId(),
      setError: _setError,
    );
  }

  // ===== CACHE OPERATIONS (DELEGATE TO CACHE_OPERATIONS) =====

  /// Save recipe to local cache
  Future<void> saveRecipeToCache(Recipe recipe) async {
    return CacheOperations.saveRecipeToCache(
      cacheHelper: _cacheHelper,
      recipe: recipe,
    );
  }

  /// Load recipe from cache by ID
  Future<Recipe?> loadRecipeFromCache(String recipeId) async {
    return CacheOperations.loadRecipeFromCache(
      cacheHelper: _cacheHelper,
      recipeId: recipeId,
    );
  }

  /// Remove recipe from cache
  Future<void> removeRecipeFromCache(String recipeId) async {
    return CacheOperations.removeRecipeFromCache(
      cacheHelper: _cacheHelper,
      recipeId: recipeId,
    );
  }

  /// Get cached recipe count
  Future<int> getCachedRecipeCount() async {
    return CacheOperations.getCachedRecipeCount(_cacheHelper);
  }

  /// Clear all cached recipes
  Future<void> clearCache() async {
    return CacheOperations.clearCache(_cacheHelper);
  }

  // ===== FIREBASE SYNCHRONIZATION (DELEGATE TO FIREBASE_SYNC_MANAGER) =====

  /// Start Firebase synchronization for user's recipes
  Future<void> startFirebaseSync() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning('Cannot start Firebase sync: No authenticated user');
      return;
    }

    try {
      AppLogger.info('🔄 Starting Firebase sync...');

      // Stop any existing sync
      await stopFirebaseSync();

      // Start sync using FirebaseSyncManager
      final subscriptions = await FirebaseSyncManager.startFirebaseSync(
        firestore: _firestore,
        currentUserId: currentUserId,
        onRecipeUpdated: _updateCachedRecipe,
        onRecipeRemoved: _removeCachedRecipe,
        onSyncError: _handleSyncError,
      );

      _syncSubscriptions.addAll(subscriptions);

      AppLogger.success('✅ Firebase sync started');
    } catch (e) {
      AppLogger.error('❌ Error starting Firebase sync: $e');
      _setError('Kunde inte starta synkronisering: $e');
    }
  }

  /// Stop all Firebase synchronization
  Future<void> stopFirebaseSync() async {
    await FirebaseSyncManager.stopFirebaseSync(
      subscriptions: _syncSubscriptions,
    );

    // Cancel sync timer
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;

    // Clear pending sync items
    DebouncedSyncOperations.clearPendingSync(_pendingSyncIds);
  }

  /// Update cached recipe from Firebase change
  void _updateCachedRecipe(Recipe recipe, String source) {
    try {
      // Save to cache using CacheOperations
      saveRecipeToCache(recipe);

      // Notify listeners of change
      _notifyListeners();

      AppLogger.debug('Recipe updated from $source: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Error updating cached recipe: $e');
    }
  }

  /// Remove cached recipe from Firebase change
  void _removeCachedRecipe(String recipeId, String source) {
    try {
      // Remove from cache using CacheOperations
      removeRecipeFromCache(recipeId);

      // Notify listeners of change
      _notifyListeners();

      AppLogger.debug('Recipe removed from $source cache: $recipeId');
    } catch (e) {
      AppLogger.error('Error removing cached recipe: $e');
    }
  }

  /// Handle sync errors
  void _handleSyncError(String syncType, dynamic error) {
    AppLogger.error('$syncType sync error: $error');
    _setError('Synkroniseringsfel för $syncType: $error');
  }

  // ===== DEBOUNCED SYNC TO FIREBASE (DELEGATE TO DEBOUNCED_SYNC_OPERATIONS) =====

  /// Schedule recipe for sync to Firebase (debounced)
  void scheduleSyncForRecipe(String recipeId) {
    DebouncedSyncOperations.scheduleSyncForRecipe(
      recipeId: recipeId,
      pendingSyncIds: _pendingSyncIds,
      getSyncTimer: () => _syncDebounceTimer,
      setSyncTimer: (timer) => _syncDebounceTimer = timer,
      syncDebounce: _syncDebounce,
      onSyncPending: _syncPendingRecipes,
    );
  }

  /// Sync all pending recipes to Firebase
  Future<void> _syncPendingRecipes() async {
    await DebouncedSyncOperations.syncPendingRecipes(
      pendingSyncIds: _pendingSyncIds,
      recipeLoader: loadRecipeFromCache,
      firestore: _firestore,
      currentUserId: _getCurrentUserId(),
    );
  }

  // ===== CACHE OPTIMIZATION (DELEGATE TO CACHE_OPTIMIZATION) =====

  /// Start periodic cache cleanup
  void _startCacheCleanup() {
    _cacheCleanupTimer = CacheOptimization.startPeriodicCleanup(
      cleanupInterval: _cacheCleanupInterval,
      cacheHelper: _cacheHelper,
      getCurrentUserId: _getCurrentUserId,
    );
  }

  // ===== CACHE STATISTICS (DELEGATE TO CACHE_OPERATIONS & DEBOUNCED_SYNC) =====

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final baseStats = await CacheOperations.validateCacheIntegrity(_cacheHelper);
      final syncStats = DebouncedSyncOperations.getPendingSyncStatus(_pendingSyncIds);
      final syncManagerStats = FirebaseSyncManager.getSyncStatus(
        subscriptions: _syncSubscriptions,
        currentUserId: _getCurrentUserId(),
      );

      return {
        ...baseStats,
        ...syncStats,
        'active_sync_subscriptions': syncManagerStats['subscriptionCount'],
        'is_syncing': syncManagerStats['isSyncing'],
      };
    } catch (e) {
      AppLogger.error('Error getting cache statistics: $e');
      return <String, dynamic>{};
    }
  }

  // ===== AUTH STATE HANDLING =====

  /// Handle user authentication state changes
  void onAuthStateChanged(String? userId) {
    try {
      // Update cache helper with new user
      _cacheHelper.setCurrentUser(userId);

      if (userId == null) {
        // User logged out - stop sync and clear cache
        stopFirebaseSync();
        clearCache();
        AppLogger.info('User logged out - cache cleared');
      } else {
        // User logged in - start sync
        startFirebaseSync();
        AppLogger.info('User logged in - sync started');
      }
    } catch (e) {
      AppLogger.error('Error handling auth state change: $e');
    }
  }

  // ===== DISPOSAL =====

  /// Dispose of all resources
  Future<void> dispose() async {
    try {
      // Stop Firebase sync
      await stopFirebaseSync();

      // Cancel cache cleanup timer
      CacheOptimization.stopPeriodicCleanup(_cacheCleanupTimer);
      _cacheCleanupTimer = null;

      AppLogger.info('Recipe cache module disposed');
    } catch (e) {
      AppLogger.error('Error disposing cache module: $e');
    }
  }

  // ===== STATUS AND DIAGNOSTICS =====

  /// Get sync status for debugging
  Map<String, dynamic> getSyncStatus() {
    return FirebaseSyncManager.getSyncStatus(
      subscriptions: _syncSubscriptions,
      currentUserId: _getCurrentUserId(),
    );
  }

  /// Check if currently syncing
  bool get isSyncing => FirebaseSyncManager.isSyncing(_syncSubscriptions);

  /// Check if has pending syncs
  bool get hasPendingSync => _pendingSyncIds.isNotEmpty;

  /// Get pending sync count
  int get pendingSyncCount => _pendingSyncIds.length;
}