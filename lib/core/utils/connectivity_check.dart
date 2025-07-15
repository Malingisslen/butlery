// lib/core/utils/connectivity_check.dart

import 'dart:io';
import '../../theme/app_theme.dart';

class ConnectivityCheck {
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(AppTheme.wait3s);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
