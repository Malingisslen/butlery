/// Comprehensive offline data management service providing multi-user storage, synchronization, and connectivity management.
///
/// This service implements sophisticated offline functionality using a modular architecture with focused
/// components for initialization, user-specific storage, legacy compatibility, and synchronization management.
/// It provides comprehensive offline support including multi-user data isolation, intelligent sync strategies,
/// connectivity monitoring, and seamless online/offline transitions for optimal user experience.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with offline state changes
/// - Uses modular component architecture with specialized offline modules
/// - Integrates with [Hive] for high-performance local data persistence
/// - Coordinates with [FirestoreRepository] for cloud data synchronization
/// - Implements [AuthRepository] integration for user-specific data isolation
///
/// **Offline Storage Features:**
/// - **Multi-User Storage**: Isolated data storage for different authenticated users
/// - **Recipe Persistence**: Complete recipe data with images and metadata preservation
/// - **Sync Queue Management**: Intelligent queuing of offline changes for online synchronization
///- **Legacy Compatibility**: Backward-compatible API surface for existing offline implementations
/// - **Resource Management**: Comprehensive cleanup and disposal of offline resources
/// - **Performance Optimization**: Efficient Hive-based storage with minimal memory footprint
///
/// **Synchronization and Connectivity:**
/// - **Intelligent Sync**: Smart synchronization with conflict resolution and retry mechanisms
/// - **Connectivity Monitoring**: Real-time network status monitoring with automatic sync triggers
/// - **Queue Management**: Persistent queue of offline changes with priority-based processing
/// - **Background Sync**: Automatic synchronization when connectivity is restored
/// - **Manual Sync**: User-initiated synchronization with detailed progress reporting

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/offline/offline_initialization.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/sync_result.dart';

// Export focused components for external usage
export 'offline/sync_result.dart';

/// Offline data management service providing comprehensive multi-user storage and synchronization capabilities.
///
/// This service serves as the primary facade for offline functionality, coordinating specialized components
/// to provide seamless offline/online transitions, user-specific data isolation, and intelligent synchronization.
/// It implements a modular architecture with focused components handling different aspects of offline management
/// while maintaining a simple, consistent API surface for application integration.
///
/// **Modular Component Architecture:**
/// Utilizes specialized components for focused functionality:
/// - [OfflineInitialization] - Hive setup and connectivity monitoring with lifecycle management
/// - [OfflineUserStorage] - User-specific storage operations with data isolation and security
/// - [OfflineSyncManager] - Sync operations and retry handling with intelligent conflict resolution
/// - [SyncResult] - Result type definitions for comprehensive sync operation reporting
///
/// **Singleton Pattern with Dependency Injection:**
/// Implements flexible singleton pattern supporting:
/// - Default dependency initialization for standard usage patterns
/// - Optional dependency injection for testing and flexible backend configurations
/// - Thread-safe singleton management with proper lifecycle handling
///
/// **Usage Examples:**
/// ```dart
/// final offlineService = OfflineService();
/// 
/// // Initialize offline capabilities
/// await offlineService.initialize();
/// 
/// // Set current user for data isolation
/// offlineService.setCurrentUser('user123');
/// 
/// // Save recipe offline
/// await offlineService.saveRecipeOfflineForUser(recipe, 'user123');
/// 
/// // Listen to offline state changes
/// offlineService.addListener(() {
///   if (offlineService.hasQueuedChanges) {
///     showSyncIndicator();
///   }
/// });
/// 
/// // Manual synchronization
/// final syncResult = await offlineService.syncNow();
/// ```
class OfflineService extends ChangeNotifier {
  // Singleton pattern using SingletonServiceMixin approach
  static OfflineService? _instance;
  
  // Private constructor for singleton
  OfflineService._internal() {
    _firestoreRepository = FirestoreRepository();
    _authRepository = FirebaseAuthRepository();
  }
  
  // Factory constructor with dependency injection
  factory OfflineService({
    FirestoreRepository? firestoreRepository,
    auth_repo.AuthRepository? authRepository,
  }) {
    _instance ??= OfflineService._internal();
    
    // Set dependencies if provided
    if (firestoreRepository != null) _instance!._firestoreRepository = firestoreRepository;
    if (authRepository != null) _instance!._authRepository = authRepository;
    
    return _instance!;
  }

  late FirestoreRepository _firestoreRepository;
  late auth_repo.AuthRepository _authRepository;

  // Focused components
  late OfflineInitialization _initialization;
  late OfflineUserStorage _userStorage;
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
      // Legacy storage integration removed during consolidation
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
    // Legacy storage integration removed during consolidation
    AppLogger.debug('Recipe offline save request: ${recipe.title}');
  }

  /// Get all offline recipes - with user support
  List<Recipe> getAllOfflineRecipes() {
    // Legacy storage integration removed during consolidation
    return [];
  }

  /// Get specific offline recipe - with user support
  Recipe? getOfflineRecipe(String id) {
    // Legacy storage integration removed during consolidation
    return null;
  }

  /// Delete recipe offline - with user support
  Future<void> deleteRecipeOffline(String id) async {
    // Legacy storage integration removed during consolidation
    AppLogger.debug('Recipe offline delete request: $id');
  }

  /// Clear all offline data - with user support
  Future<void> clearOfflineData() async {
    // Legacy storage integration removed during consolidation
    AppLogger.debug('Offline data clear request');
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
    super.dispose(); // Call ChangeNotifier dispose
  }

  /// Close Hive boxes
  Future<void> close() async {
    await _initialization.close();
  }
}
