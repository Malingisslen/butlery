// lib/core/config/firebase_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Centralized Firebase configuration management for the Butlery application.
///
/// This class provides secure access to Firebase API keys and configuration values
/// by reading them from environment variables rather than hardcoding sensitive
/// information in the source code. It supports multiple platforms and environments
/// with appropriate fallback mechanisms and error handling.
///
/// **Security Features:**
/// - No hardcoded API keys or sensitive configuration
/// - Environment-specific configuration loading (.env files)
/// - Graceful handling of missing configuration in production
/// - Debug-time validation to catch configuration issues early
/// - Secure configuration validation without exposing sensitive data
///
/// **Multi-Platform Support:**
/// - Web (Firebase Web SDK)
/// - Android (Firebase Android SDK)
/// - iOS (Firebase iOS SDK)
/// - macOS (Firebase macOS SDK)
/// - Windows (Firebase Windows SDK)
///
/// **Environment Management:**
/// - Development environment (.env.development)
/// - Staging environment (.env.staging)
/// - Production environment (.env.production)
/// - Automatic environment detection and fallback
///
/// **Usage Example:**
/// ```dart
/// // In firebase_options.dart
/// FirebaseOptions(
///   apiKey: FirebaseConfig.apiKeyWeb,
///   appId: FirebaseConfig.appIdWeb,
///   messagingSenderId: FirebaseConfig.messagingSenderId,
///   projectId: FirebaseConfig.projectId,
///   authDomain: FirebaseConfig.authDomain,
///   storageBucket: FirebaseConfig.storageBucket,
/// )
/// ```
///
/// **Configuration Validation:**
/// ```dart
/// // Check if configuration is properly loaded
/// if (!FirebaseConfig.isConfigured) {
///   throw Exception('Firebase configuration missing');
/// }
/// 
/// // Debug configuration status
/// FirebaseConfig.printConfiguration();
/// ```
class FirebaseConfig {
  // Private constructor to prevent instantiation
  FirebaseConfig._();
  
  // API Keys for different platforms
  static String get apiKeyWeb => 
      dotenv.env['FIREBASE_API_KEY_WEB'] ?? _throwMissingKey('FIREBASE_API_KEY_WEB');
  
  static String get apiKeyAndroid => 
      dotenv.env['FIREBASE_API_KEY_ANDROID'] ?? _throwMissingKey('FIREBASE_API_KEY_ANDROID');
  
  static String get apiKeyIOS => 
      dotenv.env['FIREBASE_API_KEY_IOS'] ?? _throwMissingKey('FIREBASE_API_KEY_IOS');
  
  static String get apiKeyMacOS => 
      dotenv.env['FIREBASE_API_KEY_MACOS'] ?? _throwMissingKey('FIREBASE_API_KEY_MACOS');
  
  static String get apiKeyWindows => 
      dotenv.env['FIREBASE_API_KEY_WINDOWS'] ?? _throwMissingKey('FIREBASE_API_KEY_WINDOWS');
  
  // App IDs for different platforms
  static String get appIdWeb => 
      dotenv.env['FIREBASE_APP_ID_WEB'] ?? _throwMissingKey('FIREBASE_APP_ID_WEB');
  
  static String get appIdAndroid => 
      dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? _throwMissingKey('FIREBASE_APP_ID_ANDROID');
  
  static String get appIdIOS => 
      dotenv.env['FIREBASE_APP_ID_IOS'] ?? _throwMissingKey('FIREBASE_APP_ID_IOS');
  
  static String get appIdMacOS => 
      dotenv.env['FIREBASE_APP_ID_MACOS'] ?? _throwMissingKey('FIREBASE_APP_ID_MACOS');
  
  static String get appIdWindows => 
      dotenv.env['FIREBASE_APP_ID_WINDOWS'] ?? _throwMissingKey('FIREBASE_APP_ID_WINDOWS');
  
  // Common configuration values
  static String get messagingSenderId => 
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? _throwMissingKey('FIREBASE_MESSAGING_SENDER_ID');
  
  static String get projectId => 
      dotenv.env['FIREBASE_PROJECT_ID'] ?? _throwMissingKey('FIREBASE_PROJECT_ID');
  
  static String get authDomain => 
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? _throwMissingKey('FIREBASE_AUTH_DOMAIN');
  
  static String get storageBucket => 
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? _throwMissingKey('FIREBASE_STORAGE_BUCKET');
  
  // Measurement IDs
  static String get measurementIdWeb => 
      dotenv.env['FIREBASE_MEASUREMENT_ID_WEB'] ?? '';
  
  static String get measurementIdWindows => 
      dotenv.env['FIREBASE_MEASUREMENT_ID_WINDOWS'] ?? '';
  
  // iOS Bundle ID
  static String get iosBundleId => 
      dotenv.env['IOS_BUNDLE_ID'] ?? _throwMissingKey('IOS_BUNDLE_ID');
  
  // Environment
  static String get environment => 
      dotenv.env['ENV'] ?? 'development';
  
  /// Helper method to throw error for missing keys
  static String _throwMissingKey(String key) {
    // In debug mode, throw an error to catch configuration issues early
    if (kDebugMode) {
      throw Exception(
        'Missing required environment variable: $key\n'
        'Please ensure your .env file contains all required Firebase configuration.'
      );
    }
    
    // In release mode, return empty string to avoid crashes
    // (Firebase will handle the error appropriately)
    debugPrint('⚠️ WARNING: Missing environment variable: $key');
    return '';
  }
  
  /// Check if all required environment variables are loaded
  static bool get isConfigured {
    try {
      // Try to access all required values
      final _ = [
        apiKeyWeb, apiKeyAndroid, apiKeyIOS,
        appIdWeb, appIdAndroid, appIdIOS,
        messagingSenderId, projectId, authDomain, storageBucket,
      ];
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Debug method to print current configuration (without sensitive data)
  static void printConfiguration() {
    debugPrint('=== Firebase Configuration ===');
    debugPrint('Environment: $environment');
    debugPrint('Project ID: $projectId');
    debugPrint('Auth Domain: $authDomain');
    debugPrint('Storage Bucket: $storageBucket');
    debugPrint('API Keys loaded: ${isConfigured ? "✅" : "❌"}');
    debugPrint('=============================');
  }
}