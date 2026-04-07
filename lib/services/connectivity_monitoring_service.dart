import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/connectivity_check.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Monitors internet and Firebase connectivity with real-time status updates.
///
/// Singleton lifecycle managed by GetIt (registerLazySingleton in SocialModule).
/// Do NOT use a manual singleton pattern here — it races with GetIt.
class ConnectivityMonitoringService extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  final ConnectivityRepository _connectivityRepository;

  ConnectivityMonitoringService(this._connectivityRepository);

  bool _isConnectedToInternet = true;
  bool _isConnectedToFirebase = true;
  String _connectionStatusText = '';
  StreamSubscription<bool>? _firebaseConnectionSubscription;
  Timer? _internetCheckTimer;

  bool get isConnectedToInternet => _isConnectedToInternet;
  bool get isConnectedToFirebase => _isConnectedToFirebase;
  bool get isFullyConnected => _isConnectedToInternet && _isConnectedToFirebase;
  String get connectionStatusText => _connectionStatusText;

  void startMonitoring() {
    AppLogger.info('Starting connectivity monitoring');
    _startFirebaseConnectionMonitoring();
    _startInternetConnectivityMonitoring();
  }

  void stopMonitoring() {
    AppLogger.info('Stopping connectivity monitoring');
    _firebaseConnectionSubscription?.cancel();
    _internetCheckTimer?.cancel();
  }

  Future<ConnectivityResult> getCurrentConnectivity() async {
    return await ConnectivityCheck.checkConnectivity();
  }

  Future<bool> testFirebaseConnectivity() async {
    try {
      return await _connectivityRepository.checkFirebaseConnection();
    } catch (e) {
      AppLogger.warning('Firebase connectivity test failed: $e');
      return false;
    }
  }

  void _startFirebaseConnectionMonitoring() {
    _firebaseConnectionSubscription =
        _connectivityRepository.monitorFirebaseConnection().listen(
      (isConnected) {
        final wasConnected = _isConnectedToFirebase;
        _isConnectedToFirebase = isConnected;

        if (wasConnected != _isConnectedToFirebase) {
          AppLogger.info(
              'Firebase connection changed: $_isConnectedToFirebase');
          _updateConnectionStatus();
          notifyListeners();
        }
      },
      onError: (error) {
        AppLogger.warning('Firebase connection monitoring error: $error');
        _isConnectedToFirebase = false;
        _updateConnectionStatus();
        notifyListeners();
      },
    );
  }

  void _startInternetConnectivityMonitoring() {
    _checkInternetConnectivity();
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkInternetConnectivity(),
    );
  }

  Future<void> _checkInternetConnectivity() async {
    try {
      final wasConnected = _isConnectedToInternet;
      _isConnectedToInternet =
          await ConnectivityCheck.hasRobustInternetConnection();

      if (wasConnected != _isConnectedToInternet) {
        AppLogger.info('Internet connection changed: $_isConnectedToInternet');
        _updateConnectionStatus();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Internet connectivity check failed: $e');
      _isConnectedToInternet = false;
      _updateConnectionStatus();
      notifyListeners();
    }
  }

  void _updateConnectionStatus() {
    final l = AppLocale.current;
    if (_isConnectedToInternet && _isConnectedToFirebase) {
      _connectionStatusText = l.statusConnected;
    } else if (_isConnectedToInternet && !_isConnectedToFirebase) {
      _connectionStatusText = l.statusFirebaseUnavailable;
    } else if (!_isConnectedToInternet && _isConnectedToFirebase) {
      _connectionStatusText = l.statusNoInternet;
    } else {
      _connectionStatusText = l.statusDisconnected;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
