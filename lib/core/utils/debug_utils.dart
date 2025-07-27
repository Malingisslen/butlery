// lib/core/utils/debug_utils.dart

import 'package:flutter/foundation.dart';

/// Production-safe debug utilities
/// 
/// This utility class ensures all debug operations are only executed
/// in debug mode, preventing any debug information from being exposed
/// in production builds.
class DebugUtils {
  /// Production-safe debug print
  /// Only prints in debug mode, completely removed in release builds
  static void safePrint(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
  
  /// Production-safe debug print with tag
  static void safePrintWithTag(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }
  
  /// Execute code only in debug mode
  static void debugOnly(VoidCallback callback) {
    if (kDebugMode) {
      callback();
    }
  }
  
  /// Execute async code only in debug mode
  static Future<void> debugOnlyAsync(Future<void> Function() callback) async {
    if (kDebugMode) {
      await callback();
    }
  }
  
  /// Return a value in debug mode, or a default in release
  static T debugValue<T>(T debugValue, T releaseValue) {
    return kDebugMode ? debugValue : releaseValue;
  }
  
  /// Assert with a debug-only message
  static void safeAssert(bool condition, String message) {
    assert(() {
      if (!condition) {
        debugPrint('ASSERTION FAILED: $message');
      }
      return condition;
    }());
  }
  
  /// Check if we're in debug mode
  static bool get isDebugMode => kDebugMode;
  
  /// Check if we're in release mode
  static bool get isReleaseMode => kReleaseMode;
  
  /// Check if we're in profile mode
  static bool get isProfileMode => kProfileMode;
}