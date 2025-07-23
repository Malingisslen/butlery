// lib/services/offline_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe_unified.dart';
import '../core/utils/logger.dart';
import '../repositories/firestore_repository.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import 'offline/offline_initialization.dart';
import 'offline/offline_user_storage.dart';
import 'offline/offline_legacy_storage.dart';
import 'offline/offline_sync_manager.dart';
import 'offline/sync_result.dart';

// Export focused components for external usage
export 'offline/sync_result.dart';

/// Offline Service - Facade using focused offline modules
/// 
/// This service has been refactored to use focused components:
/// - offline_initialization.dart - Hive setup and connectivity monitoring
/// - offline_user_storage.dart - User-specific storage operations
/// - offline_legacy_storage.dart - Backward compatibility methods
/// - offline_sync_manager.dart - Sync operations and retry handling
/// - sync_result.dart - Result type definitions
class OfflineService extends ChangeNotifier {
  // Singleton pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService({
    FirestoreRepository? firestoreRepository,
    AuthRepository? authRepository,
  }) {
    _instance._firestoreRepository =
        firestoreRepository ?? _instance._firestoreRepository;
    _instance._authRepository = authRepository ?? _instance._authRepository;
    return _instance;
  }
  OfflineService._internal() {
    _firestoreRepository = FirestoreRepository();
    _authRepository = FirebaseAuthRepository();
  }

  late FirestoreRepository _firestoreRepository;
  late AuthRepository _authRepository;

  // Focused components
  late OfflineInitialization _initialization;
  late OfflineUserStorage _userStorage;
  late OfflineLegacyStorage _legacyStorage;
  late OfflineSyncManager _syncManager;

  // User-specific storage state
  String? _currentUserId;

  // Getters (safe to call before initialization)
  bool get isOnline => _isInitializationReady ? _initialization.isOnline : true; // Default to online
  bool get isInitialized => _isInitializationReady ? _initialization.isInitialized : false;
  bool get isSyncing => _isSyncManagerReady ? _syncManager.isSyncing : false;
  Box<Recipe> get recipeBox {
    if (!_isInitializationReady) {
      throw StateError('OfflineService not initialized - call initialize() first');
    }
    return _initialization.recipeBox;
  }
  String? get currentUserId => _currentUserId;

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

  /// Important getters for offline_status_icon.dart
  bool get hasQueuedChanges => isInitialized && _isSyncManagerReady && _syncManager.hasQueuedChanges;
  int get queuedChangesCount => (isInitialized && _isSyncManagerReady) ? _syncManager.queuedChangesCount : 0;

  /// Set current user for offline storage
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _legacyStorage.setCurrentUser(userId);
      AppLogger.info(
          '👤 Offline service använder nu user: ${userId ?? "INGEN"}');
      notifyListeners();
    }
  }

  /// Initialize Hive and offline service
  Future<void> initialize() async {
    if (isInitialized) return;

    // Initialize components
    _initialization = OfflineInitialization(
      onConnectivityChanged: () => notifyListeners(),
      onReconnected: () => _syncManager.syncPendingChanges(isOnline: isOnline),
    );

    await _initialization.initialize();

    _userStorage = OfflineUserStorage(
      recipeBox: _initialization.recipeBox,
      syncQueueBox: _initialization.syncQueueBox,
    );

    _legacyStorage = OfflineLegacyStorage(
      recipeBox: _initialization.recipeBox,
      syncQueueBox: _initialization.syncQueueBox,
      userStorage: _userStorage,
    );

    _syncManager = OfflineSyncManager(
      recipeBox: _initialization.recipeBox,
      syncQueueBox: _initialization.syncQueueBox,
      firestoreRepository: _firestoreRepository,
      authRepository: _authRepository,
      onSyncStateChanged: () => notifyListeners(),
    );
  }

  // ===== USER-SPECIFIC METHODS =====

  /// Get recipes for specific user
  List<Recipe> getRecipesForUser(String userId) {
    if (!isInitialized) return [];
    return _userStorage.getRecipesForUser(userId);
  }

  /// Save recipe with user-specific key
  Future<void> saveRecipeOfflineForUser(Recipe recipe, String userId) async {
    return _userStorage.saveRecipeForUser(recipe, userId, isOnline: isOnline);
  }

  /// Get specific offline recipe for user
  Recipe? getOfflineRecipeForUser(String recipeId, String userId) {
    if (!isInitialized) return null;
    return _userStorage.getRecipeForUser(recipeId, userId);
  }

  /// Delete recipe for specific user
  Future<void> deleteRecipeOfflineForUser(String recipeId, String userId) async {
    return _userStorage.deleteRecipeForUser(recipeId, userId);
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    if (!isInitialized) {
      AppLogger.warning(
          '⚠️ OfflineService inte initialiserad, kan inte rensa user data');
      return;
    }

    await _userStorage.clearUserData(userId);
    notifyListeners();
  }

  /// Get all users who have offline data
  List<String> getUsersWithOfflineData() {
    if (!isInitialized) return [];
    return _userStorage.getUsersWithOfflineData();
  }

  // ===== LEGACY METHODS - BACKWARD COMPATIBLE =====

  /// Save recipe offline - with user support
  Future<void> saveRecipeOffline(Recipe recipe) async {
    return _legacyStorage.saveRecipe(recipe, isOnline: isOnline);
  }

  /// Get all offline recipes - with user support
  List<Recipe> getAllOfflineRecipes() {
    return _legacyStorage.getAllRecipes();
  }

  /// Get specific offline recipe - with user support
  Recipe? getOfflineRecipe(String id) {
    return _legacyStorage.getRecipe(id);
  }

  /// Delete recipe offline - with user support
  Future<void> deleteRecipeOffline(String id) async {
    return _legacyStorage.deleteRecipe(id);
  }

  /// Clear all offline data - with user support
  Future<void> clearOfflineData() async {
    return _legacyStorage.clearAllData();
  }

  // ===== SYNC METHODS =====

  /// Manual synchronization with user feedback
  Future<SyncResult> syncNow() async {
    return _syncManager.syncNow(isOnline: isOnline);
  }

  // ===== RESOURCE MANAGEMENT =====

  /// Clean up resources
  @override
  void dispose() {
    _initialization.dispose();
    super.dispose();
  }

  /// Close Hive boxes
  Future<void> close() async {
    await _initialization.close();
  }
}
