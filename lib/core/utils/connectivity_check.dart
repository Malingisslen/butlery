// lib/core/utils/connectivity_check.dart

import 'dart:io';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/core/injection.dart';

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
      // Use connectivity repository instead of direct Firebase access
      final connectivityRepo = sl<ConnectivityRepository>();
      return await connectivityRepo.checkFirebaseConnection();
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
