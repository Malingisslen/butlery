/// Comprehensive offline data management service providing multi-user storage, synchronization, and connectivity management.
/// This service implements sophisticated offline functionality using a modular architecture with focused
/// components for initialization, user-specific storage, legacy compatibility, and synchronization management.
/// It provides comprehensive offline support including multi-user data isolation, intelligent sync strategies,
/// connectivity monitoring, and seamless online/offline transitions for optimal user experience.
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with offline state changes
/// - Uses modular component architecture with specialized offline modules
/// - Integrates with [Drift] for high-performance SQL-based local data persistence (replacing Hive)
/// - Coordinates with [FirestoreRepository] for cloud data synchronization
/// - Implements [AuthRepository] integration for user-specific data isolation
/// **Offline Storage Features:**
/// - **Multi-User Storage**: Isolated data storage for different authenticated users
/// - **Recipe Persistence**: Complete recipe data with images and metadata preservation
/// - **Sync Queue Management**: Intelligent queuing of offline changes for online synchronization
/// - **Legacy Compatibility**: Backward-compatible API surface for existing offline implementations
/// - **Resource Management**: Comprehensive cleanup and disposal of offline resources
/// - **Performance Optimization**: Efficient Drift-based storage with SQL performance
/// **Synchronization and Connectivity:**
/// - **Intelligent Sync**: Smart synchronization with conflict resolution and retry mechanisms
/// - **Connectivity Monitoring**: Real-time network status monitoring with automatic sync triggers
/// - **Queue Management**: Persistent queue of offline changes with priority-based processing
/// - **Background Sync**: Automatic synchronization when connectivity is restored
/// - **Manual Sync**: User-initiated synchronization with detailed progress reporting

import 'package:flutter/foundation.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/offline/offline_initialization.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/sync_result.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Export focused components for external usage
export 'offline/sync_result.dart';

/// Offline data management service providing comprehensive multi-user storage and synchronization capabilities.
/// This service serves as the primary facade for offline functionality, coordinating specialized components
/// to provide seamless offline/online transitions, user-specific data isolation, and intelligent synchronization.
/// Now uses Drift database instead of Hive for improved security and maintainability.
class OfflineService extends ChangeNotifier with ErrorHandlingMixin {
  // Singleton pattern using SingletonServiceMixin approach
  static OfflineService? _instance;

  // Private constructor for singleton
  OfflineService._internal({
    FirestoreRepository? firestoreRepository,
    auth_repo.AuthRepository? authRepository,
  }) {
    _firestoreRepository = firestoreRepository ?? FirestoreRepository();
    _authRepository = authRepository ?? FirebaseAuthRepository();
  }

  // Factory constructor with dependency injection
  factory OfflineService({
    FirestoreRepository? firestoreRepository,
    auth_repo.AuthRepository? authRepository,
  }) {
    _instance ??= OfflineService._internal(
      firestoreRepository: firestoreRepository,
      authRepository: authRepository,
    );

    // Update dependencies if provided on subsequent calls
    if (firestoreRepository != null) {
      _instance!._firestoreRepository = firestoreRepository;
    }
    if (authRepository != null) _instance!._authRepository = authRepository;

    return _instance!;
  }

  /// Reset singleton for testing
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  late FirestoreRepository _firestoreRepository;
  late auth_repo.AuthRepository _authRepository;

  // Focused components
  late OfflineInitialization _initialization;
  late OfflineUserStorage _userStorage;
  late OfflineSyncManager _syncManager;

  // User-specific storage state
  String? _currentUserId;

  // Cached sync state for synchronous access
  bool _cachedHasQueuedChanges = false;
  int _cachedQueuedChangesCount = 0;

  // Getters (safe to call before initialization)
  bool get isOnline => _isInitializationReady ? _initialization.isOnline : true;
  bool get isInitialized =>
      _isInitializationReady ? _initialization.isInitialized : false;
  bool get isSyncing => _isSyncManagerReady ? _syncManager.isSyncing : false;
  String? get currentUserId => _currentUserId;

  /// Access to the Drift database for direct DAO operations
  AppDatabase get database {
    if (!_isInitializationReady) {
      throw StateError(
          'OfflineService not initialized - call initialize() first');
    }
    return _initialization.database;
  }

  // Helper getters to check if components are ready
  bool get _isInitializationReady {
    try {
      return _initialization.isInitialized;
    } catch (e) {
      return false; // _initialization not set yet
    }
  }

  bool get _isSyncManagerReady {
    try {
      // Test if _syncManager field is initialized by accessing isSyncing
      _syncManager.isSyncing;
      return true;
    } catch (e) {
      return false; // _syncManager not set yet
    }
  }

  /// Cached sync state for synchronous UI access
  /// Call refreshSyncState() to update from database
  bool get hasQueuedChanges => _cachedHasQueuedChanges;
  int get queuedChangesCount => _cachedQueuedChangesCount;

  /// Refresh sync state from database (async)
  Future<void> refreshSyncState() async {
    if (!isInitialized || !_isSyncManagerReady) {
      _cachedHasQueuedChanges = false;
      _cachedQueuedChangesCount = 0;
      return;
    }

    _cachedHasQueuedChanges = await _syncManager.hasQueuedChanges;
    _cachedQueuedChangesCount = await _syncManager.queuedChangesCount;
    notifyListeners();
  }

  /// Set current user for offline storage
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      AppLogger.info(
          '👤 Offline service använder nu user: ${userId ?? "INGEN"}');
      // Refresh sync state for new user
      refreshSyncState();
    }
  }

  /// Initialize Drift database and offline service
  Future<void> initialize() async {
    if (isInitialized) return;

    // Initialize components with Drift database
    _initialization = OfflineInitialization(
      onConnectivityChanged: () {
        refreshSyncState();
      },
      onReconnected: () => _syncManager.syncPendingChanges(isOnline: isOnline),
    );

    await _initialization.initialize();

    _userStorage = OfflineUserStorage(
      database: _initialization.database,
    );

    _syncManager = OfflineSyncManager(
      database: _initialization.database,
      firestoreRepository: _firestoreRepository,
      authRepository: _authRepository,
      onSyncStateChanged: () {
        refreshSyncState();
      },
      // H9: Callback for retagging recipes when connectivity restores
      onTagRecipe: _retagRecipe,
    );

    // Initial sync state refresh
    await refreshSyncState();
  }

  /// Get recipes for specific user
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    if (!isInitialized) return [];
    return _userStorage.getRecipesForUser(userId);
  }

  /// Save recipe with user-specific key
  Future<void> saveRecipeOfflineForUser(Recipe recipe, String userId) async {
    await _userStorage.saveRecipeForUser(recipe, userId, isOnline: isOnline);
    await refreshSyncState();
  }

  /// Get specific offline recipe for user
  Future<Recipe?> getOfflineRecipeForUser(
      String recipeId, String userId) async {
    if (!isInitialized) return null;
    return _userStorage.getRecipeForUser(recipeId, userId);
  }

  /// Delete recipe for specific user
  Future<void> deleteRecipeOfflineForUser(
      String recipeId, String userId) async {
    await _userStorage.deleteRecipeForUser(recipeId, userId);
    await refreshSyncState();
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    if (!isInitialized) {
      AppLogger.warning(
          '⚠️ OfflineService inte initialiserad, kan inte rensa user data');
      return;
    }

    await _userStorage.clearUserData(userId);
    await refreshSyncState();
  }

  /// Get count of offline recipes for user
  Future<int> getRecipeCountForUser(String userId) async {
    if (!isInitialized) return 0;
    return _userStorage.getRecipeCountForUser(userId);
  }

  /// Watch recipes for a user (reactive stream)
  Stream<List<Recipe>> watchRecipesForUser(String userId) {
    if (!isInitialized) return Stream.value([]);
    return _userStorage.watchRecipesForUser(userId);
  }

  /// Save recipe offline - with user support
  Future<void> saveRecipeOffline(Recipe recipe) async {
    AppLogger.debug('Recipe offline save request: ${recipe.title}');
    // Use current user if available
    if (_currentUserId != null) {
      await saveRecipeOfflineForUser(recipe, _currentUserId!);
    }
  }

  /// Queue a tagging operation for when connectivity is restored.
  /// Used for recipes saved offline that need tags generated.
  Future<void> queueTaggingOperation(String recipeId) async {
    if (!isInitialized || _currentUserId == null) return;

    await _syncManager.queueTagging(
      userId: _currentUserId!,
      recipeId: recipeId,
    );
    await refreshSyncState();
    AppLogger.info('📋 Queued tagging for recipe: $recipeId');
  }

  /// H9: Retag a recipe when connectivity is restored.
  /// Called by OfflineSyncManager for pending tag operations.
  Future<void> _retagRecipe(String recipeId) async {
    if (_currentUserId == null) {
      AppLogger.warning('⚠️ No user logged in, cannot retag recipe');
      return;
    }

    try {
      // Get the recipe from local storage
      final recipe =
          await _userStorage.getRecipeForUser(recipeId, _currentUserId!);
      if (recipe == null) {
        AppLogger.warning('⚠️ Recipe $recipeId not found in offline storage');
        return;
      }

      // Get TaggingService via ServiceLocator
      final taggingService = ServiceLocator.get<TaggingService>();

      // Generate tags
      final tagResult = await taggingService.generateTags(recipe);
      if (tagResult == null) {
        AppLogger.warning(
            '⚠️ Tagging returned null for recipe: ${recipe.title}');
        return;
      }

      // Update recipe with new tags
      final updatedRecipe = Recipe(
        core: recipe.core.copyWith(tagResult: tagResult),
        type: recipe.type,
        socialData: recipe.socialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      // Save updated recipe back to local storage (will also sync to Firebase)
      await _userStorage.saveRecipeForUser(updatedRecipe, _currentUserId!,
          isOnline: isOnline);

      AppLogger.success(
        '✅ Retagged recipe "${recipe.title}" with ${tagResult.tags.length} tags '
        '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to retag recipe $recipeId: $e');
      rethrow; // Let sync manager handle retry
    }
  }

  /// Get all offline recipes - with user support
  Future<List<Recipe>> getAllOfflineRecipes() async {
    if (_currentUserId != null) {
      return getRecipesForUser(_currentUserId!);
    }
    return [];
  }

  /// Get specific offline recipe - with user support
  Future<Recipe?> getOfflineRecipe(String id) async {
    if (_currentUserId != null) {
      return getOfflineRecipeForUser(id, _currentUserId!);
    }
    return null;
  }

  /// Delete recipe offline - with user support
  Future<void> deleteRecipeOffline(String id) async {
    AppLogger.debug('Recipe offline delete request: $id');
    if (_currentUserId != null) {
      await deleteRecipeOfflineForUser(id, _currentUserId!);
    }
  }

  /// Clear all offline data - with user support
  Future<void> clearOfflineData() async {
    AppLogger.debug('Offline data clear request');
    if (_currentUserId != null) {
      await clearUserData(_currentUserId!);
    }
  }

  /// Manual synchronization with user feedback
  Future<SyncResult> syncNow() async {
    final result = await _syncManager.syncNow(isOnline: isOnline);
    await refreshSyncState();
    return result;
  }

  /// Clean up resources
  @override
  void dispose() {
    if (_isInitializationReady) {
      _initialization.dispose();
    }
    super.dispose(); // Call ChangeNotifier dispose
  }

  /// Close Drift database
  Future<void> close() async {
    if (_isInitializationReady) {
      await _initialization.close();
    }
  }
}
