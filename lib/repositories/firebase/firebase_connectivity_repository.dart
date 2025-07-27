// lib/repositories/firebase/firebase_connectivity_repository.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../interfaces/connectivity_repository.dart';
import '../interfaces/auth_repository.dart';
import '../../core/utils/logger.dart';

/// Firebase implementation of ConnectivityRepository
/// 
/// Monitors both network connectivity and Firebase connection status
class FirebaseConnectivityRepository implements ConnectivityRepository {
  final FirebaseFirestore _firestore;
  // final AuthRepository _authRepository; // Currently unused
  final Connectivity _connectivity;
  
  StreamController<bool>? _connectionController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _firebaseCheckTimer;

  FirebaseConnectivityRepository({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository, // Made optional since not used
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
      final testRef = _firestore.collection('.info').doc('connected');
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
        .collection('.info')
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
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
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

  void _checkFirebaseConnection() async {
    final isConnected = await checkFirebaseConnection();
    _connectionController?.add(isConnected);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseCheckTimer?.cancel();
    _connectionController?.close();
  }
}