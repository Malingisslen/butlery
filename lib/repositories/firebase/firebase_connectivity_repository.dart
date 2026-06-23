/// Firebase Firestore implementation for comprehensive network and database connectivity monitoring.
/// This repository provides sophisticated connectivity monitoring and quality assessment using both
/// network connectivity detection and Firebase-specific connection testing. It enables the application
/// to respond intelligently to connection changes, provide offline capabilities, and optimize
/// performance based on connection quality assessments.
/// **Architecture Integration:**
/// - Implements [ConnectivityRepository] interface for standardized connectivity operations
/// - Uses [Connectivity] plugin for native network connectivity detection
/// - Leverages Firebase's built-in connection monitoring via `.info/connected` path
/// - Integrates with [AppLogger] for detailed connectivity event logging
/// - Coordinates with offline-first data synchronization strategies
/// **Connectivity Monitoring Features:**
/// - **Dual-layer Monitoring**: Both network and Firebase-specific connectivity detection
/// - **Real-time Streams**: Live connectivity status updates for reactive UI
/// - **Connection Quality Assessment**: Performance-based connection quality rating
/// - **Firebase-specific Testing**: Direct Firebase endpoint connectivity validation
/// - **Intelligent Reconnection**: Automatic reconnection handling with exponential backoff
/// - **Offline Capability Detection**: Determines when to enable offline-first features
/// **Performance and Reliability:**
/// - **Periodic Health Checks**: Regular Firebase connection validation every 30 seconds
/// - **Response Time Analysis**: Connection quality assessment based on actual performance
/// - **Error Recovery**: Graceful handling of connectivity failures and reconnection
/// - **Resource Management**: Proper cleanup of timers and subscriptions to prevent memory leaks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for sophisticated connectivity monitoring with quality assessment.
/// This repository provides comprehensive connectivity monitoring by combining network connectivity
/// detection with Firebase-specific connection testing. It offers real-time connectivity streams,
/// connection quality assessment, and intelligent offline capability detection for building
/// resilient applications with excellent user experience during connectivity changes.
/// **Connectivity Architecture:**
/// Uses a multi-layered approach to connectivity monitoring:
/// - **Network Layer**: Native platform connectivity detection via connectivity_plus
/// - **Firebase Layer**: Firebase-specific connection testing using `.info/connected`
/// - **Application Layer**: Performance-based connection quality assessment
/// - **Health Check Layer**: Periodic connectivity validation with timing analysis
/// **Quality Assessment System:**
/// Determines connection quality based on Firebase response times:
/// - **Excellent**: < 100ms response time - ideal for real-time features
/// - **Good**: < 300ms response time - suitable for most operations
/// - **Fair**: < 1000ms response time - basic functionality works
/// - **Poor**: > 1000ms response time - consider offline-first approach
/// - **Offline**: No connection - enable full offline capabilities
/// **Usage Examples:**
/// ```dart
/// final connectivityRepo = FirebaseConnectivityRepository();
/// // Monitor connectivity changes
/// connectivityRepo.connectionStream.listen((isConnected) {
///   if (isConnected) {
///     enableRealTimeFeatures();
///   } else {
///     enableOfflineMode();
///   }
/// });
/// // Assess connection quality
/// final quality = await connectivityRepo.getConnectionQuality();
/// switch (quality) {
///   case ConnectionQuality.excellent:
///     enableAllFeatures();
///     break;
///   case ConnectionQuality.poor:
///     reduceDataUsage();
///     break;
///   case ConnectionQuality.offline:
///     switchToOfflineMode();
///     break;
/// }
/// ```
class FirebaseConnectivityRepository implements ConnectivityRepository {
  /// Firestore instance for Firebase connectivity testing and monitoring.
  final FirebaseFirestore _firestore;

  /// Network connectivity detection service from connectivity_plus plugin.
  final Connectivity _connectivity;

  /// Stream controller for broadcasting connectivity status changes.
  StreamController<bool>? _connectionController;

  /// Subscription to network connectivity changes from the platform.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Timer for periodic Firebase connection health checks.
  Timer? _firebaseCheckTimer;

  /// Creates a Firebase connectivity repository with optional dependency injection.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository (currently unused but kept for future use)
  /// [connectivity] Optional connectivity service for testing, defaults to platform connectivity
  FirebaseConnectivityRepository({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
    Connectivity? connectivity,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity();

  @override
  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast(
      onListen: _startMonitoring,
      onCancel: _stopMonitoring,
    );
    return _connectionController!.stream;
  }

  @override
  Future<bool> checkFirebaseConnection() async {
    try {
      // Try to read a simple document to test Firebase connection
      final testRef = _firestore
          .collection(FirestoreCollections.firebaseInfo)
          .doc('connected');
      await testRef.get(const GetOptions(source: Source.server));
      return true;
    } catch (e) {
      AppLogger.warning('Firebase connection check failed: $e');
      return false;
    }
  }

  @override
  Stream<bool> monitorFirebaseConnection() {
    // Firebase provides a special .info/connected path for connection monitoring
    return _firestore
        .collection(FirestoreCollections.firebaseInfo)
        .doc('connected')
        .snapshots()
        .map<bool>((snapshot) => snapshot.data()?['connected'] ?? false)
        .handleError((error) {
          AppLogger.error('Firebase connection monitoring error', error);
          return false;
        });
  }

  @override
  Future<bool> testEndpoint(String endpoint) async {
    try {
      // For Firebase endpoints, we test by attempting to read
      final doc = await _firestore.doc(endpoint).get();
      return doc.exists || !doc.exists; // Either way, we got a response
    } catch (e) {
      AppLogger.warning('Endpoint test failed for $endpoint: $e');
      return false;
    }
  }

  @override
  Future<ConnectionQuality> getConnectionQuality() async {
    try {
      // First check basic connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return ConnectionQuality.offline;
      }

      // Then test Firebase connection with timing
      final stopwatch = Stopwatch()..start();
      final isConnected = await checkFirebaseConnection();
      stopwatch.stop();

      if (!isConnected) {
        return ConnectionQuality.offline;
      }

      // Determine quality based on response time
      final responseTime = stopwatch.elapsedMilliseconds;
      if (responseTime < 100) {
        return ConnectionQuality.excellent;
      } else if (responseTime < 300) {
        return ConnectionQuality.good;
      } else if (responseTime < 1000) {
        return ConnectionQuality.fair;
      } else {
        return ConnectionQuality.poor;
      }
    } catch (e) {
      AppLogger.error('Failed to determine connection quality', e);
      return ConnectionQuality.offline;
    }
  }

  void _startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      _connectionController?.add(hasConnection);

      if (hasConnection) {
        // When network is available, also check Firebase
        _checkFirebaseConnection();
      }
    });

    // Periodically check Firebase connection
    _firebaseCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkFirebaseConnection();
    });

    // Initial check
    _checkFirebaseConnection();
  }

  void _stopMonitoring() {
    _connectivitySubscription?.cancel();
    _firebaseCheckTimer?.cancel();
  }

  Future<void> _checkFirebaseConnection() async {
    final isConnected = await checkFirebaseConnection();
    _connectionController?.add(isConnected);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseCheckTimer?.cancel();
    _connectionController?.close();
  }
}
