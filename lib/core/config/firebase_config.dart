// lib/core/config/firebase_config.dart

import 'package:flutter/foundation.dart';

/// Centralized Firebase configuration using compile-time --dart-define constants.
/// Keys are injected at build time via `--dart-define-from-file=.env` and never
/// bundled as assets in the app binary.
class FirebaseConfig {
  FirebaseConfig._();

  // API Keys for different platforms
  static String get apiKeyWeb => _env('FIREBASE_API_KEY_WEB');

  static String get apiKeyAndroid => _env('FIREBASE_API_KEY_ANDROID');

  static String get apiKeyIOS => _env('FIREBASE_API_KEY_IOS');

  static String get apiKeyMacOS => _env('FIREBASE_API_KEY_MACOS');

  static String get apiKeyWindows => _env('FIREBASE_API_KEY_WINDOWS');

  // App IDs for different platforms
  static String get appIdWeb => _env('FIREBASE_APP_ID_WEB');

  static String get appIdAndroid => _env('FIREBASE_APP_ID_ANDROID');

  static String get appIdIOS => _env('FIREBASE_APP_ID_IOS');

  static String get appIdMacOS => _env('FIREBASE_APP_ID_MACOS');

  static String get appIdWindows => _env('FIREBASE_APP_ID_WINDOWS');

  // Common configuration values
  static String get messagingSenderId => _env('FIREBASE_MESSAGING_SENDER_ID');

  static String get projectId => _env('FIREBASE_PROJECT_ID');

  static String get authDomain => _env('FIREBASE_AUTH_DOMAIN');

  static String get storageBucket => _env('FIREBASE_STORAGE_BUCKET');

  // Measurement IDs (optional — empty string is acceptable)
  static String get measurementIdWeb =>
      const String.fromEnvironment('FIREBASE_MEASUREMENT_ID_WEB');

  static String get measurementIdWindows =>
      const String.fromEnvironment('FIREBASE_MEASUREMENT_ID_WINDOWS');

  // iOS Bundle ID
  static String get iosBundleId => _env('IOS_BUNDLE_ID');

  // Environment
  static String get environment =>
      const String.fromEnvironment('ENV', defaultValue: 'development');

  /// Read a compile-time constant; throw in debug if missing.
  static String _env(String key) {
    final resolved = _envMap[key] ?? '';
    if (resolved.isEmpty) {
      return _throwMissingKey(key);
    }
    return resolved;
  }

  /// Compile-time environment variable map.
  /// Each entry uses const String.fromEnvironment so values are baked in at build time.
  static final Map<String, String> _envMap = {
    'FIREBASE_API_KEY_WEB':
        const String.fromEnvironment('FIREBASE_API_KEY_WEB'),
    'FIREBASE_API_KEY_ANDROID':
        const String.fromEnvironment('FIREBASE_API_KEY_ANDROID'),
    'FIREBASE_API_KEY_IOS':
        const String.fromEnvironment('FIREBASE_API_KEY_IOS'),
    'FIREBASE_API_KEY_MACOS':
        const String.fromEnvironment('FIREBASE_API_KEY_MACOS'),
    'FIREBASE_API_KEY_WINDOWS':
        const String.fromEnvironment('FIREBASE_API_KEY_WINDOWS'),
    'FIREBASE_APP_ID_WEB': const String.fromEnvironment('FIREBASE_APP_ID_WEB'),
    'FIREBASE_APP_ID_ANDROID':
        const String.fromEnvironment('FIREBASE_APP_ID_ANDROID'),
    'FIREBASE_APP_ID_IOS': const String.fromEnvironment('FIREBASE_APP_ID_IOS'),
    'FIREBASE_APP_ID_MACOS':
        const String.fromEnvironment('FIREBASE_APP_ID_MACOS'),
    'FIREBASE_APP_ID_WINDOWS':
        const String.fromEnvironment('FIREBASE_APP_ID_WINDOWS'),
    'FIREBASE_MESSAGING_SENDER_ID':
        const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    'FIREBASE_PROJECT_ID': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    'FIREBASE_AUTH_DOMAIN':
        const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    'FIREBASE_STORAGE_BUCKET':
        const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    'IOS_BUNDLE_ID': const String.fromEnvironment('IOS_BUNDLE_ID'),
  };

  static String _throwMissingKey(String key) {
    if (kDebugMode) {
      throw Exception('Missing required compile-time variable: $key\n'
          'Build with: flutter run --dart-define-from-file=.env');
    }
    return '';
  }

  static bool get isConfigured {
    try {
      final _ = [
        apiKeyWeb,
        apiKeyAndroid,
        apiKeyIOS,
        appIdWeb,
        appIdAndroid,
        appIdIOS,
        messagingSenderId,
        projectId,
        authDomain,
        storageBucket,
      ];
      return true;
    } catch (e) {
      return false;
    }
  }
}
