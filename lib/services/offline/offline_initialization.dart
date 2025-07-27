// lib/services/offline/offline_initialization.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles initialization and connectivity monitoring for offline service
class OfflineInitialization {
  
  // Hive box names
  static const String recipeBoxName = 'recipes_offline';
  static const String syncQueueBoxName = 'sync_queue';
  
  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;
  
  // Boxes
  late Box<Recipe> _recipeBox;
  late Box<String> _syncQueueBox;
  
  // Callbacks
  final VoidCallback? _onConnectivityChanged;
  final VoidCallback? _onReconnected;
  
  OfflineInitialization({
    VoidCallback? onConnectivityChanged,
    VoidCallback? onReconnected,
  }) : _onConnectivityChanged = onConnectivityChanged,
       _onReconnected = onReconnected;
  
  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  Box<Recipe> get recipeBox => _recipeBox;
  Box<String> get syncQueueBox => _syncQueueBox;
  
  /// Initialize Hive and offline service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('🗄️ Initialiserar Hive för offline-stöd...');

    try {
      // Initialize Hive with explicit path
      await Hive.initFlutter('butlery_cache');

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RecipeCoreAdapter());
      }

      // Open boxes
      _recipeBox = await Hive.openBox<Recipe>(recipeBoxName);
      _syncQueueBox = await Hive.openBox<String>(syncQueueBoxName);

      // Start connectivity monitoring
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
  
  /// Initialize connectivity monitoring
  Future<void> _initConnectivityMonitoring() async {
    // Check initial status
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    // Listen to changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        AppLogger.error('❌ Connectivity stream error: $error');
      },
    );
  }

  /// Update connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;

    AppLogger.info('📶 Connection status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    if (!wasOnline && _isOnline) {
      AppLogger.info('🔄 Återansluten - startar synkronisering...');
      _onReconnected?.call();
    }

    _onConnectivityChanged?.call();
  }
  
  /// Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Close Hive boxes
  Future<void> close() async {
    await _recipeBox.close();
    await _syncQueueBox.close();
    await Hive.close();
    _isInitialized = false;
  }
}