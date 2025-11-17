/// Comprehensive connectivity monitoring service providing real-time network and Firebase status management.
///
/// This service provides sophisticated connectivity monitoring capabilities including real-time internet
/// connection status, Firebase connectivity monitoring, and comprehensive status reporting for optimal
/// user experience. It implements intelligent monitoring strategies, automatic reconnection detection,
/// and localized status messages to keep users informed of connection state throughout the application.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with real-time connectivity state changes
/// - Uses [ConnectivityRepository] interface for testable and flexible connectivity backends
/// - Integrates with [ConnectivityCheck] utilities for robust internet connection validation
/// - Implements singleton pattern with dependency injection support for consistent monitoring
/// - Coordinates with application services requiring network connectivity awareness
///
/// **Connectivity Monitoring Features:**
/// - **Real-time Internet Monitoring**: Continuous internet connectivity monitoring with periodic validation
/// - **Firebase Connection Tracking**: Real-time Firebase database connectivity status monitoring
/// - **Dual Status Management**: Independent tracking of internet and Firebase connectivity states
/// - **Automatic Recovery Detection**: Intelligent reconnection detection with status updates
/// - **Swedish Localization**: Localized connection status messages for authentic user experience
/// - **Performance Optimization**: Efficient monitoring with configurable check intervals
///
/// **Status Reporting and UI Integration:**
/// - **Reactive Updates**: Automatic UI notification through ChangeNotifier pattern
/// - **Comprehensive Status Text**: User-friendly status messages describing connection state
/// - **Boolean State Flags**: Simple boolean flags for conditional UI behavior
/// - **Full Connection Status**: Combined connectivity status for comprehensive validation
/// - **Error Handling**: Graceful error handling with automatic fallback strategies

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/connectivity_check.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// Real-time connectivity monitoring service with comprehensive network and Firebase status management.
///
/// This service provides complete connectivity monitoring functionality using sophisticated real-time
/// monitoring strategies for both internet connectivity and Firebase database connections. It implements
/// automatic status detection, intelligent recovery monitoring, and comprehensive user feedback through
/// reactive state management and localized status reporting.
///
/// **Monitoring Architecture:**
/// Uses dual-layer monitoring approach with independent status tracking:
/// - Internet connectivity monitoring through periodic robust connection validation
/// - Firebase connectivity monitoring through real-time database connection streams
/// - Combined status reporting with intelligent status text generation
///
/// **Singleton Pattern with Dependency Injection:**
/// Implements flexible singleton pattern supporting both default and injected repositories:
/// - Maintains backwards compatibility with existing singleton usage
/// - Supports dependency injection for testing and flexible connectivity backends
/// - Ensures consistent monitoring instance across the entire application
///
/// **Usage Examples:**
/// ```dart
/// final connectivityService = ConnectivityMonitoringService();
///
/// // Start comprehensive connectivity monitoring
/// connectivityService.startMonitoring();
///
/// // Listen to connectivity state changes
/// connectivityService.addListener(() {
///   if (connectivityService.isFullyConnected) {
///     enableOnlineFeatures();
///   } else {
///     showOfflineMode();
///   }
/// });
///
/// // Check current connectivity status
/// final status = await connectivityService.getCurrentConnectivity();
/// ```
class ConnectivityMonitoringService extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  final ConnectivityRepository _connectivityRepository;

  // For backwards compatibility, maintain singleton pattern
  static ConnectivityMonitoringService? _instance;

  factory ConnectivityMonitoringService({
    ConnectivityRepository? connectivityRepository,
  }) {
    if (connectivityRepository != null) {
      _instance = ConnectivityMonitoringService._internal(
        connectivityRepository,
      );
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

  /// Initiates comprehensive connectivity monitoring for both internet and Firebase connections.
  ///
  /// This method starts the dual-layer connectivity monitoring system, establishing both periodic
  /// internet connectivity validation and real-time Firebase database connection monitoring.
  /// It ensures immediate status detection and continuous monitoring for optimal user experience.
  ///
  /// **Monitoring Components Started:**
  /// - Firebase connection monitoring through real-time database streams
  /// - Periodic internet connectivity validation (30-second intervals)
  /// - Automatic status text generation and UI notifications
  /// - Error recovery and reconnection detection
  ///
  /// **Performance Considerations:**
  /// - Internet checks are performed every 30 seconds to balance accuracy with performance
  /// - Firebase monitoring uses efficient stream subscriptions for real-time updates
  /// - All monitoring operations are non-blocking and handle errors gracefully
  void startMonitoring() {
    AppLogger.info('🌐 Starting connectivity monitoring');

    // Start Firebase connection monitoring
    _startFirebaseConnectionMonitoring();

    // Start periodic internet connectivity checks
    _startInternetConnectivityMonitoring();
  }

  /// Stops all connectivity monitoring and cleans up resources.
  ///
  /// This method gracefully terminates both internet and Firebase connectivity monitoring,
  /// cancelling all active subscriptions and timers to prevent memory leaks and unnecessary
  /// background operations. Should be called when connectivity monitoring is no longer needed.
  ///
  /// **Resources Cleaned Up:**
  /// - Firebase connection stream subscription cancellation
  /// - Internet connectivity periodic timer cancellation
  /// - All active monitoring state cleanup
  void stopMonitoring() {
    AppLogger.info('🌐 Stopping connectivity monitoring');

    _firebaseConnectionSubscription?.cancel();
    _internetCheckTimer?.cancel();
  }

  /// Performs a one-time comprehensive connectivity check returning detailed status information.
  ///
  /// This method executes an immediate connectivity validation without affecting the ongoing
  /// monitoring system. It provides detailed connectivity information including internet access,
  /// network type, and connection quality for applications requiring immediate status validation.
  ///
  /// Returns [ConnectivityResult] containing comprehensive connectivity information including:
  /// - Internet connectivity status and validation results
  /// - Network type and connection quality metrics
  /// - Detailed connectivity analysis for troubleshooting
  ///
  /// **Use Cases:**
  /// - Initial connectivity validation before starting network operations
  /// - Manual connectivity testing for troubleshooting purposes
  /// - Validation of connectivity state before critical operations
  Future<ConnectivityResult> getCurrentConnectivity() async {
    return await ConnectivityCheck.checkConnectivity();
  }

  /// Performs a dedicated Firebase connectivity test with comprehensive error handling.
  ///
  /// This method executes a specific Firebase database connectivity validation independent
  /// of the ongoing monitoring system. It provides immediate Firebase connection status
  /// validation with detailed error handling and logging for troubleshooting purposes.
  ///
  /// Returns boolean indicating Firebase database connectivity status:
  /// - `true` if Firebase database connection is successful and responsive
  /// - `false` if Firebase database is unreachable or connection fails
  ///
  /// **Error Handling:**
  /// - Comprehensive exception handling with detailed logging
  /// - Graceful failure with informative warning messages
  /// - No impact on ongoing connectivity monitoring operations
  ///
  /// **Use Cases:**
  /// - Pre-operation Firebase connectivity validation
  /// - Troubleshooting Firebase-specific connection issues
  /// - Manual Firebase connection testing for diagnostics
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
    _firebaseConnectionSubscription =
        _connectivityRepository.monitorFirebaseConnection().listen(
      (isConnected) {
        final wasConnected = _isConnectedToFirebase;
        _isConnectedToFirebase = isConnected;

        if (wasConnected != _isConnectedToFirebase) {
          AppLogger.info(
            '🌐 Firebase connection changed: $_isConnectedToFirebase',
          );
          _updateConnectionStatus();
          notifyListeners();
        }
      },
      onError: (error) {
        AppLogger.warning(
          '🌐 Firebase connection monitoring error: $error',
        );
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
      _isConnectedToInternet =
          await ConnectivityCheck.hasRobustInternetConnection();

      if (wasConnected != _isConnectedToInternet) {
        AppLogger.info(
          '🌐 Internet connection changed: $_isConnectedToInternet',
        );
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
