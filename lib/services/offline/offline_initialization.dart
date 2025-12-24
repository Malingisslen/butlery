import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles initialization and connectivity monitoring for offline service
/// Uses Drift database for local storage
class OfflineInitialization {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  late AppDatabase _database;

  final VoidCallback? _onConnectivityChanged;
  final VoidCallback? _onReconnected;

  OfflineInitialization({
    VoidCallback? onConnectivityChanged,
    VoidCallback? onReconnected,
  })  : _onConnectivityChanged = onConnectivityChanged,
        _onReconnected = onReconnected;

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  AppDatabase get database => _database;

  /// Initialize Drift database and offline service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('🗄️ Initializing Drift database for offline support...');

    try {
      // Initialize Drift database
      _database = AppDatabase();

      // Start connectivity monitoring
      await _initConnectivityMonitoring();

      // Get initial stats
      final stats = await _database.getStats();
      final recipeCount = stats['offlineRecipes'] ?? 0;

      _isInitialized = true;
      AppLogger.success(
        '✅ Drift database initialized with $recipeCount offline recipes',
      );
    } catch (e) {
      AppLogger.error('❌ Error initializing Drift database: $e');
      rethrow;
    }
  }

  Future<void> _initConnectivityMonitoring() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        AppLogger.error('❌ Connectivity stream error: $error');
      },
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;

    AppLogger.info('📶 Connection status: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    if (!wasOnline && _isOnline) {
      AppLogger.info('🔄 Reconnected - starting sync...');
      _onReconnected?.call();
    }

    _onConnectivityChanged?.call();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> close() async {
    await _database.close();
    _isInitialized = false;
  }
}
