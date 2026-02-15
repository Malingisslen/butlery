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
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive recipe cache management module providing unified caching functionality with real-time synchronization.
/// This module implements sophisticated recipe caching using facade pattern with focused specialized modules
/// for local storage operations, Firebase synchronization, debounced writes, and cache optimization. It provides
/// comprehensive caching capabilities ensuring optimal performance and data consistency across all recipe
/// operations while maintaining clean separation between different caching concerns.
/// **Facade Pattern Architecture:**
/// This module orchestrates recipe caching through focused specialized modules:
/// - **[CacheOperations]**: Local cache save/load/remove operations with validation and integrity checks
/// - **[FirebaseSyncManager]**: Real-time Firebase synchronization with automatic conflict resolution
/// - **[DebouncedSyncOperations]**: Intelligent debounced Firebase writes with batch processing optimization
/// - **[CacheOptimization]**: Cache cleanup, optimization, and performance monitoring
/// **Single Responsibility Orchestration:**
/// This module exclusively coordinates recipe caching concerns while delegating specific functionality
/// to focused modules, ensuring clean separation of responsibilities and maintainable architecture
/// for complex caching scenarios and real-time synchronization requirements.
/// **Recipe Caching Features:**
/// - **Local Storage**: High-performance local caching with JSON serialization and integrity validation
/// - **Real-time Sync**: Automatic Firebase synchronization with conflict resolution and offline support
/// - **Debounced Writes**: Intelligent write batching to minimize Firebase operations and improve performance
/// - **Cache Optimization**: Automatic cleanup, memory management, and performance optimization
/// - **Multi-user Support**: User-specific cache isolation with secure data separation
/// **Usage Examples:**
/// ```dart
/// final cacheModule = RecipeCacheModule(
///   cacheHelper: cacheHelper,
///   getCurrentUserId: () => authService.currentUserId,
///   setError: errorHandler,
///   notifyListeners: stateNotifier,
/// );
/// // Initialize and load cached recipes
/// final cachedRecipes = await cacheModule.initializeCache();
/// // Real-time Firebase synchronization
/// await cacheModule.startFirebaseSync();
/// // Cache recipe with debounced sync
/// await cacheModule.saveRecipeToCache(recipe);
/// cacheModule.scheduleSyncForRecipe(recipe.id);
/// // Cache statistics and monitoring
/// final stats = await cacheModule.getCacheStatistics();
/// ```
class RecipeCacheModule {
  // Firebase instance for synchronization
  final FirebaseFirestore? _firestore;
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final void Function(String) _setError;
  final void Function() _notifyListeners;

  /// BUG-003: Callback for direct recipe updates (used on web where cache is stubbed)
  final void Function(Recipe recipe)? _onRecipeUpdated;

  /// BUG-003: Callback for direct recipe removals (used on web where cache is stubbed)
  final void Function(String recipeId)? _onRecipeRemoved;

  /// Sync subscriptions (delegated to FirebaseSyncManager)
  final Map<String, StreamSubscription> _syncSubscriptions = {};

  /// Pending sync items (delegated to DebouncedSyncOperations)
  final Set<String> _pendingSyncIds = {};

  /// Sync debounce timer
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounce = Duration(seconds: 2);

  /// Cache cleanup timer (delegated to CacheOptimization)
  Timer? _cacheCleanupTimer;
  static const Duration _cacheCleanupInterval = Duration(hours: 24);

  RecipeCacheModule({
    FirebaseFirestore? firestore,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required void Function(String) setError,
    required void Function() notifyListeners,
    void Function(Recipe recipe)? onRecipeUpdated,
    void Function(String recipeId)? onRecipeRemoved,
  })  : _firestore = firestore,
        _cacheHelper = cacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _setError = setError,
        _notifyListeners = notifyListeners,
        _onRecipeUpdated = onRecipeUpdated,
        _onRecipeRemoved = onRecipeRemoved {
    // Set current user for cache helper
    _cacheHelper.setCurrentUser(_getCurrentUserId());

    // Start periodic cache cleanup
    _startCacheCleanup();
  }

  /// Initialize cache and load cached recipes
  Future<List<Recipe>> initializeCache() async {
    return CacheOperations.initializeCache(
      cacheHelper: _cacheHelper,
      currentUserId: _getCurrentUserId(),
      setError: _setError,
    );
  }

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
        currentUserId: currentUserId,
        onRecipeUpdated: (recipe, source) {
          // Call async method without awaiting (fire-and-forget)
          _updateCachedRecipe(recipe, source);
        },
        onRecipeRemoved: _removeCachedRecipe,
        onSyncError: _handleSyncError,
        firestore: _firestore,
      );

      _syncSubscriptions.addAll(subscriptions);

      AppLogger.success('✅ Firebase sync started');
    } catch (e) {
      AppLogger.error('❌ Error starting Firebase sync: $e');
      _setError(AppLocale.current.errorCouldNotStartSync);
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
  Future<void> _updateCachedRecipe(Recipe recipe, String source) async {
    try {
      // Save to cache using CacheOperations
      await saveRecipeToCache(recipe);

      // BUG-003: Call direct update callback (for web where cache is stubbed)
      _onRecipeUpdated?.call(recipe);

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

      // BUG-003: Call direct removal callback (for web where cache is stubbed)
      _onRecipeRemoved?.call(recipeId);

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
    _setError(AppLocale.current.errorSyncErrorFor(syncType));
  }

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
      currentUserId: _getCurrentUserId(),
    );
  }

  /// Start periodic cache cleanup
  void _startCacheCleanup() {
    _cacheCleanupTimer = CacheOptimization.startPeriodicCleanup(
      cleanupInterval: _cacheCleanupInterval,
      cacheHelper: _cacheHelper,
      getCurrentUserId: _getCurrentUserId,
    );
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final baseStats = await CacheOperations.validateCacheIntegrity(
        _cacheHelper,
      );
      final syncStats = DebouncedSyncOperations.getPendingSyncStatus(
        _pendingSyncIds,
      );
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
