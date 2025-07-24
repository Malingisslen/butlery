// lib/services/unified/modules/recipe_cache_module.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/recipe_unified.dart';
import '../../../core/utils/logger.dart';
import '../../../core/cache/json_cache_helper.dart';

/// Recipe caching and synchronization module
/// 
/// This module contains ONLY:
/// - Local cache management for recipes
/// - Firebase synchronization logic
/// - Offline/online state handling
/// - Cache optimization and cleanup
/// 
/// ❌ DOES NOT CONTAIN: Recipe operations, UI concerns, business logic, authentication
class RecipeCacheModule {
  final FirebaseFirestore _firestore;
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final void Function(String) _setError;
  final void Function() _notifyListeners;

  /// Sync subscriptions by collection name
  final Map<String, StreamSubscription<QuerySnapshot>> _syncSubscriptions = {};
  
  /// Pending sync items (recipe IDs waiting to be synced)
  final Set<String> _pendingSyncIds = {};
  
  /// Sync debounce timer
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounce = Duration(seconds: 2);

  /// Cache cleanup timer
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

  // ===== CACHE INITIALIZATION =====

  /// Initialize cache and load cached recipes
  Future<List<Recipe>> initializeCache() async {
    try {
      AppLogger.info('🔄 Initializing recipe cache...');

      // Set current user for cache scoping
      _cacheHelper.setCurrentUser(_getCurrentUserId());

      // Load cached recipes
      final cachedRecipes = await _loadAllCachedRecipes();

      AppLogger.success('✅ Recipe cache initialized with ${cachedRecipes.length} recipes');
      return cachedRecipes;
    } catch (e) {
      AppLogger.error('❌ Cache initialization error: $e');
      _setError('Kunde inte ladda recept: $e');
      return [];
    }
  }

  // ===== CACHE OPERATIONS =====

  /// Save recipe to local cache
  Future<void> saveRecipeToCache(Recipe recipe) async {
    try {
      final recipeData = recipe.toJson();
      await _cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Cache save error for recipe ${recipe.id}: $e');
    }
  }

  /// Load recipe from cache by ID
  Future<Recipe?> loadRecipeFromCache(String recipeId) async {
    try {
      final recipeData = await _cacheHelper.loadJson(recipeId);
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
  Future<void> removeRecipeFromCache(String recipeId) async {
    try {
      await _cacheHelper.delete(recipeId);
      AppLogger.debug('Recipe removed from cache: $recipeId');
    } catch (e) {
      AppLogger.error('Cache removal error for recipe $recipeId: $e');
    }
  }

  /// Load all cached recipes
  Future<List<Recipe>> _loadAllCachedRecipes() async {
    try {
      final cachedRecipeIds = await _cacheHelper.getAllKeys();
      final recipes = <Recipe>[];

      for (final recipeId in cachedRecipeIds) {
        final recipe = await loadRecipeFromCache(recipeId);
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

  /// Get cached recipe count
  Future<int> getCachedRecipeCount() async {
    try {
      final keys = await _cacheHelper.getAllKeys();
      return keys.length;
    } catch (e) {
      AppLogger.error('Error getting cached recipe count: $e');
      return 0;
    }
  }

  /// Clear all cached recipes
  Future<void> clearCache() async {
    try {
      final keys = await _cacheHelper.getAllKeys();
      for (final key in keys) {
        await _cacheHelper.delete(key);
      }
      AppLogger.success('✅ Recipe cache cleared');
    } catch (e) {
      AppLogger.error('Error clearing cache: $e');
    }
  }

  // ===== FIREBASE SYNCHRONIZATION =====

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

      // Start syncing personal recipes
      await _startPersonalRecipesSync();

      // Start syncing collaborative recipes
      await _startCollaborativeRecipesSync();

      AppLogger.success('✅ Firebase sync started');
    } catch (e) {
      AppLogger.error('❌ Error starting Firebase sync: $e');
      _setError('Kunde inte starta synkronisering: $e');
    }
  }

  /// Stop all Firebase synchronization
  Future<void> stopFirebaseSync() async {
    try {
      // Cancel all active subscriptions
      for (final subscription in _syncSubscriptions.values) {
        await subscription.cancel();
      }
      _syncSubscriptions.clear();

      // Cancel sync timer
      _syncDebounceTimer?.cancel();
      _syncDebounceTimer = null;

      // Clear pending sync items
      _pendingSyncIds.clear();

      AppLogger.info('Firebase sync stopped');
    } catch (e) {
      AppLogger.error('Error stopping Firebase sync: $e');
    }
  }

  /// Start syncing personal recipes
  Future<void> _startPersonalRecipesSync() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      final subscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_recipes')
          .snapshots()
          .listen(
            (snapshot) => _handlePersonalRecipesSnapshot(snapshot),
            onError: (error) => _handleSyncError('personal_recipes', error),
          );

      _syncSubscriptions['personal_recipes'] = subscription;
      AppLogger.debug('Personal recipes sync started');
    } catch (e) {
      AppLogger.error('Error starting personal recipes sync: $e');
    }
  }

  /// Start syncing collaborative recipes
  Future<void> _startCollaborativeRecipesSync() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      final subscription = _firestore
          .collection('unified_collaborative_recipes')
          .where('memberPermissions.$currentUserId', isNotEqualTo: null)
          .snapshots()
          .listen(
            (snapshot) => _handleCollaborativeRecipesSnapshot(snapshot),
            onError: (error) => _handleSyncError('collaborative_recipes', error),
          );

      _syncSubscriptions['collaborative_recipes'] = subscription;
      AppLogger.debug('Collaborative recipes sync started');
    } catch (e) {
      AppLogger.error('Error starting collaborative recipes sync: $e');
    }
  }

  /// Handle personal recipes snapshot changes
  void _handlePersonalRecipesSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        _handleRecipeDocumentChange(change, 'personal');
      }
    } catch (e) {
      AppLogger.error('Error handling personal recipes snapshot: $e');
    }
  }

  /// Handle collaborative recipes snapshot changes
  void _handleCollaborativeRecipesSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        _handleRecipeDocumentChange(change, 'collaborative');
      }
    } catch (e) {
      AppLogger.error('Error handling collaborative recipes snapshot: $e');
    }
  }

  /// Handle individual recipe document changes
  void _handleRecipeDocumentChange(DocumentChange change, String source) {
    try {
      final doc = change.doc;
      final recipe = Recipe.fromFirestore(doc);

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateCachedRecipe(recipe, source);
          break;
        case DocumentChangeType.removed:
          _removeCachedRecipe(recipe.id, source);
          break;
      }
    } catch (e) {
      AppLogger.error('Error handling recipe document change: $e');
    }
  }

  /// Update cached recipe from Firebase change
  void _updateCachedRecipe(Recipe recipe, String source) {
    try {
      // Save to cache
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
      // Remove from cache
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

  // ===== DEBOUNCED SYNC TO FIREBASE =====

  /// Schedule recipe for sync to Firebase (debounced)
  void scheduleSyncForRecipe(String recipeId) {
    _pendingSyncIds.add(recipeId);
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      _syncPendingRecipes();
    });
  }

  /// Sync all pending recipes to Firebase
  Future<void> _syncPendingRecipes() async {
    if (_pendingSyncIds.isEmpty) return;

    final recipesToSync = List<String>.from(_pendingSyncIds);
    _pendingSyncIds.clear();

    AppLogger.debug('Syncing ${recipesToSync.length} pending recipes to Firebase');

    for (final recipeId in recipesToSync) {
      await _syncRecipeToFirebase(recipeId);
    }
  }

  /// Sync individual recipe to Firebase
  Future<void> _syncRecipeToFirebase(String recipeId) async {
    try {
      final recipe = await loadRecipeFromCache(recipeId);
      if (recipe == null) {
        AppLogger.warning('Recipe not found in cache for sync: $recipeId');
        return;
      }

      if (recipe.isCollaborative) {
        await _syncCollaborativeRecipeToFirebase(recipe);
      } else {
        await _syncPersonalRecipeToFirebase(recipe);
      }
    } catch (e) {
      AppLogger.error('Error syncing recipe $recipeId to Firebase: $e');
    }
  }

  /// Sync personal recipe to Firebase
  Future<void> _syncPersonalRecipeToFirebase(Recipe recipe) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_recipes')
          .doc(recipe.id)
          .set(recipe.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Personal recipe synced: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Firebase sync error for personal recipe ${recipe.id}: $e');
      rethrow;
    }
  }

  /// Sync collaborative recipe to Firebase
  Future<void> _syncCollaborativeRecipeToFirebase(Recipe recipe) async {
    try {
      await _firestore
          .collection('unified_collaborative_recipes')
          .doc(recipe.id)
          .set(recipe.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Collaborative recipe synced: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Firebase sync error for collaborative recipe ${recipe.id}: $e');
      rethrow;
    }
  }

  // ===== CACHE OPTIMIZATION =====

  /// Start periodic cache cleanup
  void _startCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _performCacheCleanup();
    });
  }

  /// Perform cache cleanup to remove old/unused data
  Future<void> _performCacheCleanup() async {
    try {
      AppLogger.debug('Performing cache cleanup...');

      final allKeys = await _cacheHelper.getAllKeys();
      int removedCount = 0;

      for (final key in allKeys) {
        try {
          final recipeData = await _cacheHelper.loadJson(key);
          if (recipeData == null) {
            // Remove null entries
            await _cacheHelper.delete(key);
            removedCount++;
            continue;
          }

          // Check if recipe is old or invalid
          final recipe = Recipe.fromJson(recipeData);
          if (_shouldRemoveFromCache(recipe)) {
            await _cacheHelper.delete(key);
            removedCount++;
          }
        } catch (e) {
          // Remove corrupted entries
          await _cacheHelper.delete(key);
          removedCount++;
        }
      }

      if (removedCount > 0) {
        AppLogger.info('Cache cleanup removed $removedCount items');
      }
    } catch (e) {
      AppLogger.error('Cache cleanup error: $e');
    }
  }

  /// Check if recipe should be removed from cache
  bool _shouldRemoveFromCache(Recipe recipe) {
    final currentUserId = _getCurrentUserId();
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

  // ===== CACHE STATISTICS =====

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final allKeys = await _cacheHelper.getAllKeys();
      final personalCount = <String>[];
      final collaborativeCount = <String>[];
      final corruptedCount = <String>[];

      for (final key in allKeys) {
        try {
          final recipeData = await _cacheHelper.loadJson(key);
          if (recipeData == null) {
            corruptedCount.add(key);
            continue;
          }

          final recipe = Recipe.fromJson(recipeData);
          if (recipe.isPersonal) {
            personalCount.add(key);
          } else if (recipe.isCollaborative) {
            collaborativeCount.add(key);
          }
        } catch (e) {
          corruptedCount.add(key);
        }
      }

      return {
        'totalRecipes': allKeys.length,
        'personalRecipes': personalCount.length,
        'collaborativeRecipes': collaborativeCount.length,
        'corruptedEntries': corruptedCount.length,
        'pendingSyncCount': _pendingSyncIds.length,
        'activeSyncSubscriptions': _syncSubscriptions.length,
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
      _cacheCleanupTimer?.cancel();
      _cacheCleanupTimer = null;

      AppLogger.info('Recipe cache module disposed');
    } catch (e) {
      AppLogger.error('Error disposing cache module: $e');
    }
  }

  // ===== STATUS AND DIAGNOSTICS =====

  /// Get sync status for debugging
  Map<String, dynamic> getSyncStatus() {
    return {
      'activeSubscriptions': _syncSubscriptions.keys.toList(),
      'pendingSyncCount': _pendingSyncIds.length,
      'syncDebounceActive': _syncDebounceTimer?.isActive ?? false,
      'currentUserId': _getCurrentUserId(),
    };
  }

  /// Check if currently syncing
  bool get isSyncing => _syncSubscriptions.isNotEmpty;

  /// Check if has pending syncs
  bool get hasPendingSync => _pendingSyncIds.isNotEmpty;

  /// Get pending sync count
  int get pendingSyncCount => _pendingSyncIds.length;
}