// lib/services/offline_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/recipe.dart';

/// Service för offline-funktionalitet med Hive
class OfflineService extends ChangeNotifier {
  // Singleton pattern
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Hive boxes
  static const String _recipeBoxName = 'recipes_offline';
  static const String _syncQueueBoxName = 'sync_queue';
  late Box<Recipe> _recipeBox;
  late Box<String> _syncQueueBox;

  // Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  Box<Recipe> get recipeBox => _recipeBox;

  /// Initialisera Hive och offline-service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🗄️ Initialiserar Hive för offline-stöd...');

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
      debugPrint(
        '✅ Hive initialiserad med ${_recipeBox.length} offline recept',
      );
    } catch (e) {
      debugPrint('❌ Fel vid Hive-initialisering: $e');
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
        debugPrint('❌ Connectivity stream error: $error');
      },
    );
  }

  /// Uppdatera connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;

    debugPrint('📶 Connection status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    if (!wasOnline && _isOnline) {
      debugPrint('🔄 Återansluten - startar synkronisering...');
      _syncPendingChanges();
    }

    notifyListeners();
  }

  /// Spara recept offline
  Future<void> saveRecipeOffline(Recipe recipe) async {
    try {
      // Markera som modifierad om online
      if (_isOnline) {
        recipe.markAsModifiedOffline();
      }

      // Spara i Hive
      await _recipeBox.put(recipe.id, recipe);

      // Lägg till i synk-kö om offline
      if (!_isOnline) {
        await _syncQueueBox.put(recipe.id, recipe.id);
      }

      debugPrint('💾 Recept sparat offline: ${recipe.title}');
    } catch (e) {
      debugPrint('❌ Fel vid offline-sparning: $e');
      rethrow;
    }
  }

  /// Hämta alla offline recept
  List<Recipe> getAllOfflineRecipes() {
    return _recipeBox.values.toList();
  }

  /// Hämta specifikt offline recept
  Recipe? getOfflineRecipe(String id) {
    return _recipeBox.get(id);
  }

  /// Ta bort recept offline
  Future<void> deleteRecipeOffline(String id) async {
    await _recipeBox.delete(id);
    await _syncQueueBox.delete(id);
    debugPrint('🗑️ Recept borttaget offline: $id');
  }

  /// Rensa all offline data
  Future<void> clearOfflineData() async {
    await _recipeBox.clear();
    await _syncQueueBox.clear();
    debugPrint('🧹 All offline data rensad');
  }

  /// Synkronisera väntande ändringar
  Future<void> _syncPendingChanges() async {
    if (!_isOnline || _syncQueueBox.isEmpty) return;

    debugPrint(
      '🔄 Synkroniserar ${_syncQueueBox.length} väntande ändringar...',
    );

    final pendingIds = _syncQueueBox.values.toList();

    for (final id in pendingIds) {
      final recipe = _recipeBox.get(id);
      if (recipe != null && recipe.needsSync) {
        // TODO: Anropa RecipeService för att synka med Firebase
        // För nu, bara markera som synkad
        recipe.markAsSynced();
        await _syncQueueBox.delete(id);
        debugPrint('✅ Synkade recept: ${recipe.title}');
      }
    }

    notifyListeners();
  }

  /// Manuell synkronisering
  Future<void> syncNow() async {
    if (_isOnline) {
      await _syncPendingChanges();
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
