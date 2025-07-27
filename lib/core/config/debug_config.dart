// lib/core/config/debug_config.dart

import 'package:flutter/foundation.dart';

/// Debug configuration for production safety
/// 
/// This configuration ensures that all debug features are
/// properly disabled in production builds.
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