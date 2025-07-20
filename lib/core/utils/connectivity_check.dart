// lib/core/utils/connectivity_check.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger.dart';

class ConnectivityCheck {
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Enhanced connectivity check with multiple DNS servers
  static Future<bool> hasRobustInternetConnection() async {
    final dnsServers = [
      'google.com',
      'cloudflare.com',
      '1.1.1.1',
      '8.8.8.8',
    ];

    for (final server in dnsServers) {
      try {
        final result = await InternetAddress.lookup(server)
            .timeout(const Duration(seconds: 5));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException catch (_) {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Test Firebase connectivity specifically
  static Future<bool> hasFirebaseConnectivity() async {
    try {
      // Test basic Firestore connectivity
      await FirebaseFirestore.instance
          .collection('connectivity_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      AppLogger.debug('Firebase connectivity test failed: $e');
      return false;
    }
  }

  /// Comprehensive connectivity check
  static Future<ConnectivityResult> checkConnectivity() async {
    try {
      // Check basic internet connectivity
      final hasInternet = await hasRobustInternetConnection();
      if (!hasInternet) {
        return ConnectivityResult.none;
      }

      // Check Firebase connectivity
      final hasFirebase = await hasFirebaseConnectivity();
      if (!hasFirebase) {
        return ConnectivityResult.limited;
      }

      return ConnectivityResult.full;
    } catch (e) {
      AppLogger.error('Connectivity check failed: $e');
      return ConnectivityResult.unknown;
    }
  }
}

enum ConnectivityResult {
  none,      // No internet connection
  limited,   // Internet but no Firebase
  full,      // Full connectivity
  unknown,   // Unable to determine
}
