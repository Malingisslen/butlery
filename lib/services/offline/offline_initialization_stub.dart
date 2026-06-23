/// Web stub for OfflineInitialization - no-op implementation for web platform
library;

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/core/utils/logger.dart';

/// Stub implementation of OfflineInitialization for web platform.
class OfflineInitialization {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  final AppDatabase _database = AppDatabase();

  final VoidCallback? _onConnectivityChanged;
  final VoidCallback? _onReconnected;

  OfflineInitialization({
    VoidCallback? onConnectivityChanged,
    VoidCallback? onReconnected,
  }) : _onConnectivityChanged = onConnectivityChanged,
       _onReconnected = onReconnected;

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  AppDatabase get database => _database;

  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info(
      '🌐 Web platform detected - using stub offline storage (no SQLite)',
    );

    try {
      await _initConnectivityMonitoring();
      _isInitialized = true;
      AppLogger.success('✅ Web offline initialization complete (stub mode)');
    } catch (e) {
      AppLogger.error('❌ Error initializing web offline stub: $e');
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
      AppLogger.info('🔄 Reconnected');
      _onReconnected?.call();
    }

    _onConnectivityChanged?.call();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> close() async {
    _isInitialized = false;
  }
}
