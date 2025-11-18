// lib/services/realtime/connection_state_module.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling connection state management and notifications for realtime sync.
/// Provides connection monitoring, auth state handling, and notification system.
class ConnectionStateModule {
  final FirestoreRepository firestoreRepository;
  final auth.AuthRepository authRepository;
  final StreamController<bool> connectionController;
  final void Function(bool) onConnectionStateChanged;
  final VoidCallback notifyListeners;
  final VoidCallback onUserLoggedOut;

  /// Connection state
  bool _isConnected = false;

  /// Notification listeners
  final List<VoidCallback> _listeners = [];

  ConnectionStateModule({
    required this.firestoreRepository,
    required this.authRepository,
    required this.connectionController,
    required this.onConnectionStateChanged,
    required this.notifyListeners,
    required this.onUserLoggedOut,
  });

  /// Current connection state
  bool get isConnected => _isConnected;

  /// Add listener for state changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener for state changes
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of state changes
  void notifyAllListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Start monitoring Firebase connection state
  void startConnectionMonitoring(
      Function(SyncErrorType, String, {dynamic originalError}) handleError) {
    // Listen to Firebase connection state via Firestore connectivity
    firestoreRepository.connectivityStream().listen(
      (snapshot) {
        setConnectionState(true);
      },
      onError: (error) {
        setConnectionState(false);
        handleError(
          SyncErrorType.connectionLost,
          'Firebase-anslutning förlorad',
          originalError: error,
        );
      },
    );
  }

  /// Setup auth state change listener
  void setupAuthStateListener() {
    authRepository.authStateChanges().listen(onAuthStateChanged);
  }

  /// Handle auth state changes
  void onAuthStateChanged(User? user) {
    if (user == null) {
      // User logged out - trigger cleanup
      onUserLoggedOut();
      AppLogger.info('🔓 Användare utloggad - alla listeners stängda');
    } else {
      AppLogger.info('🔐 Användare inloggad - RealtimeSyncService redo');
    }
  }

  /// Set connection state and notify listeners
  void setConnectionState(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      connectionController.add(_isConnected);
      AppLogger.info(
          '🌐 Connection state: ${_isConnected ? "ONLINE" : "OFFLINE"}');
      onConnectionStateChanged(connected);
      notifyListeners();
    }
  }

  /// Cleanup
  void dispose() {
    _listeners.clear();
  }
}
