/// Feature flag system for controlling application behavior.
///
/// This file provides a centralized system for managing feature flags
/// that control which systems are active in the application. Used for
/// gradual rollout of new features and A/B testing.
library;

import 'package:flutter/foundation.dart';

/// Central feature flag configuration for the Butlery application.
///
/// Controls which systems and features are enabled, allowing for
/// gradual rollout and testing of new functionality.
class FeatureFlags {
  // Private constructor to prevent instantiation
  FeatureFlags._();

  /// Whether to use the new modular dependency injection system.
  ///
  /// When `true`, uses the new DIContainer and ApplicationBootstrap.
  /// When `false`, uses the legacy injection.dart and main.dart initialization.
  ///
  /// Environment variable: USE_MODULAR_DI
  /// Default: false (use legacy system)
  static bool get useModularDI {
    const value = String.fromEnvironment('USE_MODULAR_DI', defaultValue: 'false');
    final result = value.toLowerCase() == 'true';
    
    if (kDebugMode && result) {
      debugPrint('🔄 Feature Flag: Using modular DI system');
    }
    
    return result;
  }

  /// Whether to enable enhanced error handling and recovery.
  ///
  /// When `true`, uses advanced error recovery strategies during bootstrap.
  /// When `false`, uses basic error handling (fail-fast approach).
  ///
  /// Environment variable: ENABLE_ERROR_RECOVERY
  /// Default: true in development, false in production
  static bool get enableErrorRecovery {
    const value = String.fromEnvironment('ENABLE_ERROR_RECOVERY', defaultValue: 'auto');
    
    if (value == 'auto') {
      return kDebugMode; // Enable in debug mode, disable in release
    }
    
    return value.toLowerCase() == 'true';
  }

  /// Whether to enable detailed bootstrap logging.
  ///
  /// When `true`, logs detailed information about bootstrap stages and DI setup.
  /// When `false`, logs only essential information.
  ///
  /// Environment variable: ENABLE_BOOTSTRAP_LOGGING
  /// Default: true in development, false in production
  static bool get enableBootstrapLogging {
    const value = String.fromEnvironment('ENABLE_BOOTSTRAP_LOGGING', defaultValue: 'auto');
    
    if (value == 'auto') {
      return kDebugMode; // Enable in debug mode, disable in release
    }
    
    return value.toLowerCase() == 'true';
  }

  /// Whether to enable health check monitoring.
  ///
  /// When `true`, performs regular health checks on services.
  /// When `false`, skips health monitoring for better performance.
  ///
  /// Environment variable: ENABLE_HEALTH_MONITORING
  /// Default: true
  static bool get enableHealthMonitoring {
    const value = String.fromEnvironment('ENABLE_HEALTH_MONITORING', defaultValue: 'true');
    return value.toLowerCase() == 'true';
  }

  /// Whether to enable fallback to legacy systems on failure.
  ///
  /// When `true`, falls back to legacy initialization if modular system fails.
  /// When `false`, fails fast without fallback.
  ///
  /// Environment variable: ENABLE_LEGACY_FALLBACK
  /// Default: true
  static bool get enableLegacyFallback {
    const value = String.fromEnvironment('ENABLE_LEGACY_FALLBACK', defaultValue: 'true');
    return value.toLowerCase() == 'true';
  }

  /// Whether to enable parallel module initialization.
  ///
  /// When `true`, initializes independent modules in parallel.
  /// When `false`, initializes modules sequentially.
  ///
  /// Environment variable: ENABLE_PARALLEL_INIT
  /// Default: true
  static bool get enableParallelInit {
    const value = String.fromEnvironment('ENABLE_PARALLEL_INIT', defaultValue: 'true');
    return value.toLowerCase() == 'true';
  }

  /// Maximum timeout for bootstrap operations (in seconds).
  ///
  /// Environment variable: BOOTSTRAP_TIMEOUT_SECONDS
  /// Default: 30 seconds
  static Duration get bootstrapTimeout {
    const value = String.fromEnvironment('BOOTSTRAP_TIMEOUT_SECONDS', defaultValue: '30');
    final seconds = int.tryParse(value) ?? 30;
    return Duration(seconds: seconds);
  }

  /// Health check interval for background monitoring (in minutes).
  ///
  /// Environment variable: HEALTH_CHECK_INTERVAL_MINUTES
  /// Default: 5 minutes
  static Duration get healthCheckInterval {
    const value = String.fromEnvironment('HEALTH_CHECK_INTERVAL_MINUTES', defaultValue: '5');
    final minutes = int.tryParse(value) ?? 5;
    return Duration(minutes: minutes);
  }

  /// Get all feature flag values for debugging.
  static Map<String, dynamic> getAllFlags() {
    return {
      'useModularDI': useModularDI,
      'enableErrorRecovery': enableErrorRecovery,
      'enableBootstrapLogging': enableBootstrapLogging,
      'enableHealthMonitoring': enableHealthMonitoring,
      'enableLegacyFallback': enableLegacyFallback,
      'enableParallelInit': enableParallelInit,
      'bootstrapTimeout': '${bootstrapTimeout.inSeconds}s',
      'healthCheckInterval': '${healthCheckInterval.inMinutes}m',
    };
  }

  /// Print all feature flags for debugging.
  static void debugPrintFlags() {
    if (kDebugMode) {
      debugPrint('🚩 Feature Flags Configuration:');
      getAllFlags().forEach((key, value) {
        debugPrint('  $key: $value');
      });
    }
  }

  /// Validate feature flag configuration for conflicts.
  static List<String> validateConfiguration() {
    final issues = <String>[];

    // Check for conflicting flags
    if (useModularDI && !enableHealthMonitoring) {
      issues.add('Modular DI is enabled but health monitoring is disabled - this may cause issues');
    }

    if (!enableErrorRecovery && !enableLegacyFallback) {
      issues.add('Both error recovery and legacy fallback are disabled - bootstrap may fail');
    }

    if (bootstrapTimeout.inSeconds < 10) {
      issues.add('Bootstrap timeout is very short (${bootstrapTimeout.inSeconds}s) - may cause timeouts');
    }

    return issues;
  }
}

/// Runtime feature flag controller for dynamic flag changes.
///
/// Allows runtime modification of feature flags for testing and debugging.
/// Should only be used in development builds.
class RuntimeFeatureFlags {
  static final Map<String, bool> _overrides = {};

  /// Override a boolean feature flag at runtime.
  ///
  /// Only works in debug mode for safety.
  static void override(String flagName, bool value) {
    if (kDebugMode) {
      _overrides[flagName] = value;
      print('🚩 Runtime override: $flagName = $value');
    }
  }

  /// Get a feature flag with runtime override support.
  static bool getFlag(String flagName, bool defaultValue) {
    if (kDebugMode && _overrides.containsKey(flagName)) {
      return _overrides[flagName]!;
    }
    return defaultValue;
  }

  /// Clear all runtime overrides.
  static void clearOverrides() {
    if (kDebugMode) {
      _overrides.clear();
      print('🚩 Runtime overrides cleared');
    }
  }

  /// Get all active overrides.
  static Map<String, bool> getOverrides() {
    return Map.unmodifiable(_overrides);
  }
}

/// Feature flag utilities for testing and validation.
class FeatureFlagUtils {
  /// Create a test environment with specific flags.
  static void setupTestEnvironment({
    bool? useModularDI,
    bool? enableErrorRecovery,
    bool? enableHealthMonitoring,
  }) {
    if (!kDebugMode) return;

    if (useModularDI != null) {
      RuntimeFeatureFlags.override('useModularDI', useModularDI);
    }
    if (enableErrorRecovery != null) {
      RuntimeFeatureFlags.override('enableErrorRecovery', enableErrorRecovery);
    }
    if (enableHealthMonitoring != null) {
      RuntimeFeatureFlags.override('enableHealthMonitoring', enableHealthMonitoring);
    }
  }

  /// Reset to default configuration.
  static void resetToDefaults() {
    if (kDebugMode) {
      RuntimeFeatureFlags.clearOverrides();
    }
  }

  /// Validate environment variable format.
  static bool isValidEnvironmentValue(String value) {
    final validValues = ['true', 'false', 'auto'];
    return validValues.contains(value.toLowerCase());
  }
}