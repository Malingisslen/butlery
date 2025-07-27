// lib/services/connectivity_monitoring_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/connectivity_check.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';

/// Service for monitoring Firebase and internet connectivity in realtime
/// 
/// Provides both one-time checks and continuous monitoring streams
/// for ViewModels that need to display connection status.
class ConnectivityMonitoringService extends ChangeNotifier {
  final ConnectivityRepository _connectivityRepository;
  
  // For backwards compatibility, maintain singleton pattern
  static ConnectivityMonitoringService? _instance;
  
  factory ConnectivityMonitoringService({ConnectivityRepository? connectivityRepository}) {
    if (connectivityRepository != null) {
      _instance = ConnectivityMonitoringService._internal(connectivityRepository);
    }
    return _instance!;
  }
  
  ConnectivityMonitoringService._internal(this._connectivityRepository);

  // State
  bool _isConnectedToInternet = true;
  bool _isConnectedToFirebase = true;
  String _connectionStatusText = 'Ansluten';
  
  // Subscriptions
  StreamSubscription<bool>? _firebaseConnectionSubscription;
  Timer? _internetCheckTimer;
  
  // Getters
  bool get isConnectedToInternet => _isConnectedToInternet;
  bool get isConnectedToFirebase => _isConnectedToFirebase;
  bool get isFullyConnected => _isConnectedToInternet && _isConnectedToFirebase;
  String get connectionStatusText => _connectionStatusText;

  /// Start monitoring connectivity
  void startMonitoring() {
    AppLogger.info('🌐 Starting connectivity monitoring');
    
    // Start Firebase connection monitoring
    _startFirebaseConnectionMonitoring();
    
    // Start periodic internet connectivity checks
    _startInternetConnectivityMonitoring();
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    AppLogger.info('🌐 Stopping connectivity monitoring');
    
    _firebaseConnectionSubscription?.cancel();
    _internetCheckTimer?.cancel();
  }

  /// Get current connectivity status as a one-time check
  Future<ConnectivityResult> getCurrentConnectivity() async {
    return await ConnectivityCheck.checkConnectivity();
  }

  /// Test Firebase connectivity specifically
  Future<bool> testFirebaseConnectivity() async {
    try {
      return await _connectivityRepository.checkFirebaseConnection();
    } catch (e) {
      AppLogger.warning('🌐 Firebase connectivity test failed: $e');
      return false;
    }
  }

  // ===== PRIVATE METHODS =====

  void _startFirebaseConnectionMonitoring() {
    _firebaseConnectionSubscription = _connectivityRepository
        .monitorFirebaseConnection()
        .listen(
      (isConnected) {
        final wasConnected = _isConnectedToFirebase;
        _isConnectedToFirebase = isConnected;
        
        if (wasConnected != _isConnectedToFirebase) {
          AppLogger.info('🌐 Firebase connection changed: $_isConnectedToFirebase');
          _updateConnectionStatus();
          notifyListeners();
        }
      },
      onError: (error) {
        AppLogger.warning('🌐 Firebase connection monitoring error: $error');
        _isConnectedToFirebase = false;
        _updateConnectionStatus();
        notifyListeners();
      },
    );
  }

  void _startInternetConnectivityMonitoring() {
    // Check immediately
    _checkInternetConnectivity();
    
    // Then check every 30 seconds
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkInternetConnectivity(),
    );
  }

  Future<void> _checkInternetConnectivity() async {
    try {
      final wasConnected = _isConnectedToInternet;
      _isConnectedToInternet = await ConnectivityCheck.hasRobustInternetConnection();
      
      if (wasConnected != _isConnectedToInternet) {
        AppLogger.info('🌐 Internet connection changed: $_isConnectedToInternet');
        _updateConnectionStatus();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('🌐 Internet connectivity check failed: $e');
      _isConnectedToInternet = false;
      _updateConnectionStatus();
      notifyListeners();
    }
  }

  void _updateConnectionStatus() {
    if (_isConnectedToInternet && _isConnectedToFirebase) {
      _connectionStatusText = 'Ansluten';
    } else if (_isConnectedToInternet && !_isConnectedToFirebase) {
      _connectionStatusText = 'Firebase otillgänglig';
    } else if (!_isConnectedToInternet && _isConnectedToFirebase) {
      _connectionStatusText = 'Ingen internetanslutning';
    } else {
      _connectionStatusText = 'Frånkopplad';
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

