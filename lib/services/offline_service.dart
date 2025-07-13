// lib/services/offline_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import '../models/recipe.dart';
import '../core/utils/logger.dart';
import '../repositories/firestore_repository.dart';

/// Service för offline-funktionalitet med Hive - USER-SPECIFIC VERSION
class OfflineService extends ChangeNotifier {
  // Singleton pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService({FirestoreRepository? firestoreRepository}) {
    _instance._firestoreRepository =
        firestoreRepository ?? _instance._firestoreRepository;
    return _instance;
  }
  OfflineService._internal() {
    _firestoreRepository = FirestoreRepository();
  }

  // Hive boxes
  static const String _recipeBoxName = 'recipes_offline';
  static const String _syncQueueBoxName = 'sync_queue';
  late Box<Recipe> _recipeBox;
  late Box<String> _syncQueueBox;

  late FirestoreRepository _firestoreRepository;

  // Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  // NEW: User-specific storage state
  String? _currentUserId;

  // 🔄 SYNC STATE
  bool _isSyncing = false;

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  Box<Recipe> get recipeBox => _recipeBox;
  String? get currentUserId => _currentUserId;

  /// VIKTIGA getters för offline_status_icon.dart
  bool get hasQueuedChanges => _isInitialized && _syncQueueBox.isNotEmpty;
  int get queuedChangesCount => _isInitialized ? _syncQueueBox.length : 0;

  /// Set current user for offline storage
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      AppLogger.info(
          '👤 Offline service använder nu user: ${userId ?? "INGEN"}');
      notifyListeners();
    }
  }

  /// Initialisera Hive och offline-service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('🗄️ Initialiserar Hive för offline-stöd...');

    try {
      // Initialisera Hive
      await Hive.initFlutter();

      // Registrera adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecipeAdapter());
      }

      // Öppna boxes
      _recipeBox = await Hive.openBox<Recipe>(_recipeBoxName);
      _syncQueueBox = await Hive.openBox<String>(_syncQueueBoxName);

      // Starta connectivity monitoring
      await _initConnectivityMonitoring();

      _isInitialized = true;
      AppLogger.success(
        '✅ Hive initialiserad med ${_recipeBox.length} offline recept',
      );
    } catch (e) {
      AppLogger.error('❌ Fel vid Hive-initialisering: $e');
      rethrow;
    }
  }

  /// Initiera connectivity monitoring
  Future<void> _initConnectivityMonitoring() async {
    // Kolla initial status
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    // Lyssna på ändringar
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        AppLogger.error('❌ Connectivity stream error: $error');
      },
    );
  }

  /// Uppdatera connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;

    AppLogger.info('📶 Connection status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    if (!wasOnline && _isOnline) {
      AppLogger.info('🔄 Återansluten - startar synkronisering...');
      _syncPendingChanges();
    }

    notifyListeners();
  }

  // ===== USER-SPECIFIC METHODS - PERMANENT SOLUTION =====

  /// Get recipes for specific user
  List<Recipe> getRecipesForUser(String userId) {
    if (!_isInitialized) return [];

    try {
      final userPrefix = '${userId}_';
      final userRecipes = <Recipe>[];

      // Find all recipes that belong to this user
      for (final key in _recipeBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          final recipe = _recipeBox.get(key);
          if (recipe != null) {
            userRecipes.add(recipe);
          }
        }
      }

      AppLogger.info(
          '📦 Hittade ${userRecipes.length} offline recept för användare: $userId');
      return userRecipes;
    } catch (e) {
      AppLogger.error('❌ Error getting user recipes: $e');
      return [];
    }
  }

  /// Save recipe with user-specific key
  Future<void> saveRecipeOfflineForUser(Recipe recipe, String userId) async {
    try {
      // Create user-specific key: "userId_recipeId"
      final userSpecificKey = '${userId}_${recipe.id}';

      // Save with user-specific key
      await _recipeBox.put(userSpecificKey, recipe);

      // Handle sync queue with user-specific key
      if (!_isOnline) {
        await _syncQueueBox.put(userSpecificKey, userSpecificKey);
      }

      AppLogger.info(
          '💾 Recept sparat offline för användare $userId: ${recipe.title}');
    } catch (e) {
      AppLogger.error('❌ Fel vid user-specific offline-sparning: $e');
      rethrow;
    }
  }

  /// Get specific offline recipe for user
  Recipe? getOfflineRecipeForUser(String recipeId, String userId) {
    if (!_isInitialized) return null;

    final userSpecificKey = '${userId}_$recipeId';
    return _recipeBox.get(userSpecificKey);
  }

  /// Delete recipe for specific user
  Future<void> deleteRecipeOfflineForUser(
      String recipeId, String userId) async {
    final userSpecificKey = '${userId}_$recipeId';
    await _recipeBox.delete(userSpecificKey);
    await _syncQueueBox.delete(userSpecificKey);
    AppLogger.info(
        '🗑️ Recept borttaget offline för användare $userId: $recipeId');
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    if (!_isInitialized) {
      AppLogger.warning(
          '⚠️ OfflineService inte initialiserad, kan inte rensa user data');
      return;
    }

    try {
      final userPrefix = '${userId}_';
      final keysToDelete = <dynamic>[];

      // Find all keys that belong to this user
      for (final key in _recipeBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          keysToDelete.add(key);
        }
      }

      // Delete user-specific recipes
      for (final key in keysToDelete) {
        await _recipeBox.delete(key);
      }

      // Clear sync queue for this user
      final syncKeysToDelete = <dynamic>[];
      for (final key in _syncQueueBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          syncKeysToDelete.add(key);
        }
      }

      for (final key in syncKeysToDelete) {
        await _syncQueueBox.delete(key);
      }

      AppLogger.success(
          '✅ Rensade offline data för användare: $userId (${keysToDelete.length} recept)');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Fel vid rensning av user data: $e');
    }
  }

  /// Get all users who have offline data
  List<String> getUsersWithOfflineData() {
    if (!_isInitialized) return [];

    final users = <String>{};

    for (final key in _recipeBox.keys) {
      final keyStr = key.toString();
      if (keyStr.contains('_')) {
        final userId = keyStr.split('_').first;
        users.add(userId);
      }
    }

    return users.toList();
  }

  // ===== UPDATED LEGACY METHODS - BACKWARD COMPATIBLE =====

  /// Spara recept offline - UPPDATERAD för user support
  Future<void> saveRecipeOffline(Recipe recipe) async {
    if (_currentUserId != null) {
      // Use user-specific storage if user is set
      await saveRecipeOfflineForUser(recipe, _currentUserId!);
    } else {
      // Fallback to old behavior for backward compatibility
      try {
        // Spara i Hive FÖRST (så objektet är i en box)
        await _recipeBox.put(recipe.id, recipe);

        // Nu kan vi säkert markera som modifierad
        if (_isOnline && recipe.isInBox) {
          recipe.isModifiedOffline = true;
          await recipe
              .save(); // Nu fungerar save() eftersom objektet är i boxen
        }

        // Lägg till i synk-kö om offline
        if (!_isOnline) {
          await _syncQueueBox.put(recipe.id, recipe.id);
        }

        AppLogger.info('💾 Recept sparat offline (legacy): ${recipe.title}');
      } catch (e) {
        AppLogger.error('❌ Fel vid offline-sparning: $e');
        rethrow;
      }
    }
  }

  /// Hämta alla offline recept - UPPDATERAD för user support
  List<Recipe> getAllOfflineRecipes() {
    if (_currentUserId != null) {
      // Return user-specific recipes if user is set
      return getRecipesForUser(_currentUserId!);
    } else {
      // Fallback to all recipes for backward compatibility
      return _recipeBox.values.toList();
    }
  }

  /// Hämta specifikt offline recept - UPPDATERAD för user support
  Recipe? getOfflineRecipe(String id) {
    if (_currentUserId != null) {
      // Use user-specific lookup if user is set
      return getOfflineRecipeForUser(id, _currentUserId!);
    } else {
      // Fallback to old behavior
      return _recipeBox.get(id);
    }
  }

  /// Ta bort recept offline - UPPDATERAD för user support
  Future<void> deleteRecipeOffline(String id) async {
    if (_currentUserId != null) {
      // Use user-specific deletion if user is set
      await deleteRecipeOfflineForUser(id, _currentUserId!);
    } else {
      // Fallback to old behavior
      await _recipeBox.delete(id);
      await _syncQueueBox.delete(id);
      AppLogger.info('🗑️ Recept borttaget offline (legacy): $id');
    }
  }

  /// Rensa all offline data - UPPDATERAD för user support
  Future<void> clearOfflineData() async {
    if (_currentUserId != null) {
      // Clear only current user's data if user is set
      await clearUserData(_currentUserId!);
    } else {
      // Clear all data (old behavior)
      await _recipeBox.clear();
      await _syncQueueBox.clear();
      AppLogger.info('🧹 All offline data rensad');
    }
  }

  /// 🔄 SÄKER: Synkronisera väntande ändringar utan circular dependencies
  Future<void> _syncPendingChanges() async {
    if (!_isOnline || _syncQueueBox.isEmpty || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    AppLogger.info(
      '🔄 Synkroniserar ${_syncQueueBox.length} väntande ändringar...',
    );

    try {
      final userId = _firestoreRepository.currentUserId;
      if (userId == null) {
        AppLogger.warning('⚠️ Ingen användare inloggad - hoppar över sync');
        return;
      }

      final userRecipesRef =
          _firestoreRepository.userRecipesCollection(userId);

      final pendingIds = _syncQueueBox.values.toList();
      int successCount = 0;
      int failureCount = 0;
      final List<String> failedRecipes = [];

      for (final id in pendingIds) {
        Recipe? recipe;
        try {
          recipe = _recipeBox.get(id);
          if (recipe != null && recipe.needsSync) {
            AppLogger.info('📤 Synkar recept: ${recipe.title}');

            await _firestoreRepository.setDocument(
              userRecipesRef.doc(recipe.id),
              recipe.toFirestore(),
            );

            // ✅ SÄKER: Synkningen lyckades
            recipe.isModifiedOffline = false;
            recipe.lastSyncedAt = DateTime.now();

            // Spara uppdaterat recept offline
            if (recipe.isInBox) {
              await recipe.save();
            } else {
              await _recipeBox.put(id, recipe);
            }

            // Ta bort från sync queue
            await _syncQueueBox.delete(id);
            successCount++;
            AppLogger.success('✅ Synkade recept: ${recipe.title}');
          } else if (recipe == null) {
            // ✅ CLEANUP: Ta bort invalid entries från kön
            await _syncQueueBox.delete(id);
            AppLogger.info('🗑️ Tog bort invalid sync entry: $id');
          } else {
            // Recept behöver inte synkas längre - ta bort från kö
            await _syncQueueBox.delete(id);
            AppLogger.info('✅ Recept $id behöver inte synkas längre');
          }
        } catch (e) {
          failureCount++;
          final recipeTitle = recipe?.title ?? id;
          failedRecipes.add('$recipeTitle: ${e.toString()}');
          AppLogger.error('❌ Fel vid synk av $id: $e');

          // ROBUST ERROR HANDLING: Fortsätt med nästa recept
          continue;
        }
      }

      // ✅ DETALJERAD RAPPORTERING
      if (successCount > 0) {
        AppLogger.success('🎉 Synkade $successCount recept framgångsrikt!');
      }

      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount recept kunde inte synkas:');
        for (final failure in failedRecipes.take(3)) {
          AppLogger.warning('  • $failure');
        }
        if (failedRecipes.length > 3) {
          AppLogger.warning('  • ... och ${failedRecipes.length - 3} till');
        }
      }

      // ✅ SMART RETRY: Om alla misslyckades, vänta innan nästa försök
      if (successCount == 0 && failureCount > 0) {
        AppLogger.info(
            '⏰ Alla sync-försök misslyckades, väntar 30s innan retry...');
        // Schedule retry efter 30 sekunder
        Timer(const Duration(seconds: 30), () {
          if (_isOnline && _syncQueueBox.isNotEmpty) {
            AppLogger.info('🔄 Retry-försök startar...');
            _syncPendingChanges();
          }
        });
      }
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid synkronisering: $e');

      // ✅ GRACEFUL DEGRADATION: Logga fel men krascha inte appen
      AppLogger.info(
          '🛡️ Synkronisering hoppar över denna omgång, försöker igen senare');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// ✅ FÖRBÄTTRAD: Manuell synkronisering med user feedback
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      AppLogger.info('🔄 Synkronisering pågår redan...');
      return SyncResult(
        success: false,
        message: 'Synkronisering pågår redan',
        isRetry: false,
      );
    }

    if (!_isOnline) {
      AppLogger.warning('⚠️ Kan inte synka offline');
      return SyncResult(
        success: false,
        message: 'Du måste vara online för att synkronisera',
        isRetry: false,
      );
    }

    if (_syncQueueBox.isEmpty) {
      AppLogger.info('✅ Inga ändringar att synkronisera');
      return SyncResult(
        success: true,
        message: 'Inga väntande ändringar',
        isRetry: false,
      );
    }

    AppLogger.info('🔄 Manuell synkronisering startad...');
    final itemsToSync = _syncQueueBox.length;

    await _syncPendingChanges();

    final remainingItems = _syncQueueBox.length;
    final syncedItems = itemsToSync - remainingItems;

    if (remainingItems == 0) {
      return SyncResult(
        success: true,
        message: 'Alla $syncedItems ändringar synkade!',
        isRetry: false,
      );
    } else if (syncedItems > 0) {
      return SyncResult(
        success: true,
        message: '$syncedItems av $itemsToSync synkade, $remainingItems kvar',
        isRetry: remainingItems > 0,
      );
    } else {
      return SyncResult(
        success: false,
        message: 'Synkronisering misslyckades, försöker igen senare',
        isRetry: true,
      );
    }
  }

  /// Städa upp resurser
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Stäng Hive boxes
  Future<void> close() async {
    await _recipeBox.close();
    await _syncQueueBox.close();
    await Hive.close();
    _isInitialized = false;
  }
}

/// Resultat av synkronisering operation
class SyncResult {
  final bool success;
  final String message;
  final bool isRetry; // Om fler försök behövs
  final int? syncedCount;
  final int? failedCount;

  const SyncResult({
    required this.success,
    required this.message,
    required this.isRetry,
    this.syncedCount,
    this.failedCount,
  });

  factory SyncResult.success(String message, {int? syncedCount}) {
    return SyncResult(
      success: true,
      message: message,
      isRetry: false,
      syncedCount: syncedCount,
    );
  }

  factory SyncResult.partialSuccess(
    String message, {
    required int syncedCount,
    required int failedCount,
  }) {
    return SyncResult(
      success: true,
      message: message,
      isRetry: failedCount > 0,
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }

  factory SyncResult.failure(String message, {bool willRetry = false}) {
    return SyncResult(
      success: false,
      message: message,
      isRetry: willRetry,
    );
  }
}
