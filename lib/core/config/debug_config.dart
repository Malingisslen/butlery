// lib/core/config/debug_config.dart

import 'package:flutter/foundation.dart';

/// Centralized debug and development configuration for the Butlery application.
///
/// This class provides safe access to debug-related settings and ensures that
/// all debug features are properly controlled based on the build mode. It prevents
/// debug information and development tools from being exposed in production builds
/// while providing comprehensive debugging capabilities during development.
///
/// **Build Mode Detection:**
/// - **Debug Mode**: Development builds with full debugging capabilities
/// - **Profile Mode**: Performance testing builds with minimal debugging
/// - **Release Mode**: Production builds with all debugging disabled
///
/// **Security Features:**
/// - Automatic debug feature disabling in production builds
/// - Environment-aware configuration management
/// - Safe default values that prioritize production security
/// - Compile-time optimization through const values
///
/// **Debug Capabilities Controlled:**
/// - Console logging and debug output
/// - Performance monitoring and overlays
/// - Memory leak detection and analysis
/// - Development tools and debug panels
/// - Assertion checking and validation
/// - Debug information display in UI
///
/// **Usage Examples:**
/// ```dart
/// // Check build environment
/// if (DebugConfig.isDebugMode) {
///   print('Development mode active');
/// }
/// 
/// // Conditional debug features
/// if (DebugConfig.enableConsoleLogging) {
///   debugPrint('Debug message');
/// }
/// 
/// // Environment-specific behavior
/// final apiUrl = DebugConfig.environment == 'production' 
///   ? 'https://api.butlery.com'
///   : 'https://dev-api.butlery.com';
/// ```
///
/// **Production Safety:**
/// All debug features are automatically disabled in release builds,
/// ensuring no sensitive information or development tools are exposed
/// to end users while maintaining full debugging capabilities during development.
class DebugConfig {
  DebugConfig._();
  
  /// Check if debug mode is enabled
  static bool get isDebugMode => kDebugMode;
  
  /// Check if release mode is enabled
  static bool get isReleaseMode => kReleaseMode;
  
  /// Check if profile mode is enabled  
  static bool get isProfileMode => kProfileMode;
  
  /// Environment name based on build mode
  static String get environment {
    if (kReleaseMode) return 'production';
    if (kProfileMode) return 'profile';
    return 'development';
  }
  
  /// Should show debug information
  static bool get showDebugInfo => kDebugMode;
  
  /// Should enable debug tools
  static bool get enableDebugTools => kDebugMode;
  
  /// Should log to console
  static bool get enableConsoleLogging => kDebugMode;
  
  /// Should show performance overlay
  static bool get showPerformanceOverlay => false; // Always false in production
  
  /// Should check for memory leaks
  static bool get checkMemoryLeaks => kDebugMode;
  
  /// Should enable assertions
  static bool get enableAssertions => kDebugMode;
}