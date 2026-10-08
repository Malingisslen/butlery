/// Comprehensive offline data management service providing multi-user storage, synchronization, and connectivity management.
/// This service implements sophisticated offline functionality using a modular architecture with focused
/// components for initialization, user-specific storage, legacy compatibility, and synchronization management.
/// It provides comprehensive offline support including multi-user data isolation, intelligent sync strategies,
/// connectivity monitoring, and seamless online/offline transitions for optimal user experience.
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with offline state changes
/// - Uses modular component architecture with specialized offline modules
/// - Integrates with [Drift] for high-performance SQL-based local data persistence (replacing Hive)
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

// Use conditional imports for platform-specific offline storage
import 'package:butlery/core/storage/drift/app_database.dart'
    if (dart.library.html) 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/offline/offline_initialization.dart'
    if (dart.library.html) 'package:butlery/services/offline/offline_initialization_stub.dart';
import 'package:butlery/services/offline/offline_user_storage.dart'
    if (dart.library.html) 'package:butlery/services/offline/offline_user_storage_stub.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart'
    if (dart.library.html) 'package:butlery/services/offline/offline_sync_manager_stub.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/offline/sync_result.dart';
import 'package:butlery/services/realtime_sync_service.dart';
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
    auth_repo.AuthRepository? authRepository,
  }) {
    _authRepository = authRepository ?? FirebaseAuthRepository();
  }

  // Factory constructor with dependency injection
  factory OfflineService({auth_repo.AuthRepository? authRepository}) {
    _instance ??= OfflineService._internal(authRepository: authRepository);

    // Update dependencies if provided on subsequent calls
    if (authRepository != null) _instance!._authRepository = authRepository;

    return _instance!;
  }

  /// Reset singleton for testing
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  late auth_repo.AuthRepository _authRepository;

  // Focused components
  late OfflineInitialization _initialization;
  late OfflineUserStorage _userStorage;
  late OfflineSyncManager _syncManager;
  bool _isDisposed = false;
  StreamSubscription<Object?>? _authSubscription;

  final StreamController<String> _recipeSent =
      StreamController<String>.broadcast();

  /// The id of each recipe whose write or deletion has just left the queue.
  /// The server's copy is then the one to show.
  Stream<String> get recipesSent => _recipeSent.stream;

  final StreamController<String> _recipeDropped =
      StreamController<String>.broadcast();

  /// The id of each phone-only recipe thrown away under Väntar på dig.
  Stream<String> get recipesDropped => _recipeDropped.stream;
  QueuedRecipeWriter? _recipeWriter;

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
        'OfflineService not initialized - call initialize() first',
      );
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

  void resetForLogout() {
    setCurrentUser(null);
  }

  /// Set current user for offline storage
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      AppLogger.info(
        '👤 Offline service använder nu user: ${userId ?? "INGEN"}',
      );
      // Always notify listeners so UI reacts to user change
      notifyListeners();
      // Refresh sync state for new user (also notifies when initialized)
      refreshSyncState();
    }
  }

  /// Whether recipe writes can go through the queue: a device database is
  /// open. On the web the database is a stub and writes go straight to the
  /// server.
  bool get isQueueReady => !kIsWeb && isInitialized && _isSyncManagerReady;

  /// Attaches what sends queued recipe writes to the server (BUT-2162), and
  /// sends what is waiting. Until then recipe entries stay in the queue.
  void attachRecipeWriter(QueuedRecipeWriter writer) {
    _recipeWriter = writer;
    if (!_isSyncManagerReady) return;
    _syncManager.recipeWriter = writer;
    _sendWhenOnline();
  }

  /// Keeps [recipe] on the device and queues its write; the queue sends it at
  /// once when the device is online. Returns the write's opId.
  Future<String> queueRecipeWrite(
    Recipe recipe,
    String userId, {
    required SyncOperation operation,
    bool queueTagging = false,
  }) async {
    final opId = await _userStorage.saveRecipeForUser(
      recipe,
      userId,
      operation: operation,
      queueTagging: queueTagging,
    );
    await refreshSyncState();
    _sendWhenOnline();
    return opId;
  }

  /// Removes the recipe from the device and queues its deletion.
  /// Returns false when its deletion was already queued.
  Future<bool> queueRecipeDelete(String recipeId, String userId) async {
    final queued = await _userStorage.queueDeleteForUser(recipeId, userId);
    await refreshSyncState();
    _sendWhenOnline();
    return queued;
  }

  /// Keeps the image at [imagePath] on the device and queues it as an image
  /// of the recipe [recipeId]; the queue adds its address to the recipe once
  /// it is on the server. For an image the device could not upload now.
  Future<void> queueRecipeImage(
    String imagePath,
    String recipeId,
    String userId,
  ) async {
    await _userStorage.queueRecipeImageForUser(imagePath, recipeId, userId);
    await refreshSyncState();
    _sendWhenOnline();
  }

  Future<UploadedImage> _uploadQueuedImage(
    String localPath,
    String userId,
  ) async {
    final result = await ServiceLocator.get<StorageService>().uploadImageFile(
      File(localPath),
      userId,
    );
    // uploadImageFile returns null for a failure it has no code for.
    if (result == null) throw StateError('Image upload failed');
    return (url: result.imageUrl, thumbnailUrl: result.thumbnailUrl);
  }

  /// A queued write thrown away under Väntar på dig leaves the queue unsent,
  /// and the recipe screens still show it until they hear about it.
  void announceRecipeLeftQueue(String recipeId) {
    if (!_recipeSent.isClosed) _recipeSent.add(recipeId);
  }

  /// A recipe the server never had, thrown away with its create. Offline the
  /// server cannot be asked whether it exists, so the screens drop it on
  /// this word alone.
  void announceRecipeDropped(String recipeId) {
    if (!_recipeDropped.isClosed) _recipeDropped.add(recipeId);
  }

  /// Whether the device holds a write of the recipe the server has not
  /// confirmed. A server copy of such a recipe is older than the device's.
  Future<bool> hasUnsentRecipeWrite(String recipeId, String userId) async {
    if (!isQueueReady) return false;
    return _userStorage.hasUnsentWrite(recipeId, userId);
  }

  void _sendWhenOnline() {
    if (_isSyncManagerReady && isOnline) {
      unawaited(_syncManager.syncPendingChanges(isOnline: true));
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
      onReconnected: () {
        if (_isSyncManagerReady) {
          _syncManager.syncPendingChanges(isOnline: isOnline);
        }
      },
    );

    await _initialization.initialize();

    _userStorage = OfflineUserStorage(
      database: _initialization.database,
    );

    _syncManager = OfflineSyncManager(
      database: _initialization.database,
      authRepository: _authRepository,
      onSyncStateChanged: () {
        refreshSyncState();
      },
      // H9: Callback for retagging recipes when connectivity restores
      onTagRecipe: _retagRecipe,
      onRecipeSent: (recipeId) {
        if (!_recipeSent.isClosed) _recipeSent.add(recipeId);
      },
      // BUT-2213: a queued edit the server's newer version stopped becomes
      // the conflict banner, through the gate that holds it until the queue
      // has emptied (produktregler.md:189).
      onRecipeConflict: (local, remote) => ServiceLocator.tryGet<
        RealtimeSyncService
      >()?.announceQueuedRecipeConflict(local, remote),
      uploadImage: _uploadQueuedImage,
      userStorage: _userStorage,
      // A retry timer that fires offline waits for the reconnect pass.
      isOnlineNow: () => isOnline,
      recipeWriter: _recipeWriter,
    );

    // The queue belongs to whoever is signed in: their entries are counted
    // and sent, and a sign-in sends what an earlier session left (produkt-
    // regler.md § 16 keeps the queue over a timeout sign-out).
    _authSubscription = _authRepository.authStateChanges().listen((user) {
      setCurrentUser(user?.uid);
      if (user != null) _sendWhenOnline();
    });

    // Initial sync state refresh
    await refreshSyncState();
  }

  /// Get recipes for specific user
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    if (!isInitialized) return [];
    return _userStorage.getRecipesForUser(userId);
  }

  /// Get specific offline recipe for user
  Future<Recipe?> getOfflineRecipeForUser(
    String recipeId,
    String userId,
  ) async {
    if (!isInitialized) return null;
    return _userStorage.getRecipeForUser(recipeId, userId);
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    if (!isInitialized) {
      AppLogger.warning(
        '⚠️ OfflineService inte initialiserad, kan inte rensa user data',
      );
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

  /// H9: Retag a recipe when connectivity is restored.
  /// Called by OfflineSyncManager for pending tag operations.
  Future<void> _retagRecipe(String recipeId, String userId) async {
    try {
      // CRIT-8: Get TaggingService with defensive error handling
      // Service might not be available during early startup or on web platform
      TaggingService? taggingService;
      try {
        taggingService = ServiceLocator.get<TaggingService>();
      } catch (e) {
        AppLogger.warning(
          '⚠️ CRIT-8: TaggingService not available, cannot retag recipe. '
          'Will retry on next sync: $e',
        );
        rethrow; // Propagate to trigger retry
      }

      final retagged = await _userStorage.retagRecipeForUser(
        recipeId,
        userId,
        taggingService.generateTags,
      );
      if (!retagged) {
        AppLogger.warning('⚠️ Recipe $recipeId was not retagged');
        return;
      }
      await refreshSyncState();
      _sendWhenOnline();
      AppLogger.success('✅ Retagged recipe $recipeId');
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

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_authSubscription?.cancel());
    unawaited(_recipeSent.close());
    unawaited(_recipeDropped.close());
    if (_isInitializationReady) {
      _initialization.dispose();
    }
    if (_isSyncManagerReady) {
      _syncManager.dispose();
    }
    super.dispose();
  }

  /// Close Drift database
  Future<void> close() async {
    if (_isInitializationReady) {
      await _initialization.close();
    }
  }
}
