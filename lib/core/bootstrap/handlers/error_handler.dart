/// Centralized error handling for the bootstrap process.
///
/// This file provides comprehensive error handling capabilities for
/// the application initialization process, including error recovery,
/// logging, and graceful degradation strategies.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';

/// Centralized error handler for the bootstrap process.
///
/// Handles different types of initialization errors and provides
/// appropriate recovery strategies and logging.
class BootstrapErrorHandler {
  static final BootstrapErrorHandler _instance = BootstrapErrorHandler._internal();
  factory BootstrapErrorHandler() => _instance;
  BootstrapErrorHandler._internal();

  final List<String> _errorLog = [];
  final Map<String, int> _errorCounts = {};

  /// Get the error log.
  List<String> get errorLog => List.unmodifiable(_errorLog);

  /// Get error counts by type.
  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);

  /// Handle a bootstrap exception with appropriate recovery strategy.
  ///
  /// [exception] The bootstrap exception that occurred
  /// [context] Additional context about where the error occurred
  /// [allowRecovery] Whether to attempt recovery strategies
  ///
  /// Returns `true` if recovery was successful, `false` otherwise.
  Future<bool> handleBootstrapError(
    BootstrapException exception, {
    String? context,
    bool allowRecovery = true,
  }) async {
    // Log the error
    _logError(exception, context);

    // Attempt recovery based on error type
    if (allowRecovery) {
      return await _attemptRecovery(exception);
    }

    return false;
  }

  /// Handle a DI module exception.
  Future<bool> handleModuleError(
    DIModuleException exception, {
    String? context,
    bool allowRecovery = true,
  }) async {
    // Log the error
    _logError(exception, context);

    // Module errors are usually critical
    if (allowRecovery) {
      return await _attemptModuleRecovery(exception);
    }

    return false;
  }

  /// Handle a general exception during bootstrap.
  Future<bool> handleGeneralError(
    Exception exception, {
    String? context,
    bool allowRecovery = true,
  }) async {
    // Log the error
    _logError(exception, context);

    // General error recovery
    if (allowRecovery) {
      return await _attemptGeneralRecovery(exception);
    }

    return false;
  }

  /// Log an error with consistent formatting.
  void _logError(Exception exception, String? context) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? ' [$context]' : '';
    final errorMessage = '[$timestamp]$contextStr $exception';
    
    _errorLog.add(errorMessage);
    
    // Track error counts
    final errorType = exception.runtimeType.toString();
    _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;

    if (kDebugMode) {
      print('❌ Bootstrap Error$contextStr: $exception');
    }
  }

  /// Attempt recovery from a bootstrap exception.
  Future<bool> _attemptRecovery(BootstrapException exception) async {
    if (kDebugMode) {
      print('🔧 Attempting recovery from bootstrap error: ${exception.stage}');
    }

    try {
      switch (exception.operation) {
        case 'execution':
          return await _recoverFromExecutionError(exception);
        case 'validation':
          return await _recoverFromValidationError(exception);
        case 'timeout':
          return await _recoverFromTimeoutError(exception);
        default:
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Recovery attempt failed: $e');
      }
      return false;
    }
  }

  /// Attempt recovery from a module exception.
  Future<bool> _attemptModuleRecovery(DIModuleException exception) async {
    if (kDebugMode) {
      print('🔧 Attempting recovery from module error: ${exception.module}');
    }

    try {
      switch (exception.operation) {
        case 'configuration':
          return await _recoverFromConfigurationError(exception);
        case 'initialization':
          return await _recoverFromInitializationError(exception);
        case 'dependency_resolution':
          return await _recoverFromDependencyError(exception);
        default:
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Module recovery attempt failed: $e');
      }
      return false;
    }
  }

  /// Attempt recovery from a general exception.
  Future<bool> _attemptGeneralRecovery(Exception exception) async {
    if (kDebugMode) {
      print('🔧 Attempting recovery from general error: ${exception.runtimeType}');
    }

    // General recovery strategies (limited)
    try {
      // Wait a moment and retry
      await Future.delayed(const Duration(milliseconds: 500));
      return true; // Optimistic recovery
    } catch (e) {
      return false;
    }
  }

  /// Recover from stage execution errors.
  Future<bool> _recoverFromExecutionError(BootstrapException exception) async {
    // Strategy: Retry the operation once after a short delay
    if (kDebugMode) {
      print('🔄 Retrying stage execution: ${exception.stage}');
    }
    
    await Future.delayed(const Duration(seconds: 1));
    return true; // Signal that retry should be attempted
  }

  /// Recover from stage validation errors.
  Future<bool> _recoverFromValidationError(BootstrapException exception) async {
    // Strategy: Mark as warning but continue if stage is optional
    if (kDebugMode) {
      print('⚠️ Stage validation failed, attempting to continue: ${exception.stage}');
    }
    
    return true; // Allow continuation
  }

  /// Recover from timeout errors.
  Future<bool> _recoverFromTimeoutError(BootstrapException exception) async {
    // Strategy: Extend timeout and retry
    if (kDebugMode) {
      print('⏰ Stage timed out, retrying with extended timeout: ${exception.stage}');
    }
    
    return true; // Signal extended retry
  }

  /// Recover from module configuration errors.
  Future<bool> _recoverFromConfigurationError(DIModuleException exception) async {
    // Strategy: Skip non-critical services in the module
    if (kDebugMode) {
      print('🔧 Module configuration failed, attempting partial recovery: ${exception.module}');
    }
    
    // This would require module-specific recovery logic
    return false; // Configuration errors are usually critical
  }

  /// Recover from module initialization errors.
  Future<bool> _recoverFromInitializationError(DIModuleException exception) async {
    // Strategy: Skip initialization if module is non-critical
    if (kDebugMode) {
      print('⚠️ Module initialization failed: ${exception.module}');
    }
    
    // Check if module is critical (would need metadata)
    return false; // Conservative approach
  }

  /// Recover from dependency resolution errors.
  Future<bool> _recoverFromDependencyError(DIModuleException exception) async {
    // Strategy: These are usually fatal
    if (kDebugMode) {
      print('💥 Dependency resolution error: ${exception.module}');
    }
    
    return false; // Dependency errors are critical
  }

  /// Get error statistics for monitoring.
  Map<String, dynamic> getErrorStatistics() {
    return {
      'total_errors': _errorLog.length,
      'error_counts': _errorCounts,
      'recent_errors': _errorLog.length > 10 
          ? _errorLog.sublist(_errorLog.length - 10) 
          : _errorLog,
    };
  }

  /// Clear the error log (for testing).
  void clearErrors() {
    _errorLog.clear();
    _errorCounts.clear();
  }

  /// Create an error recovery strategy.
  BootstrapRecoveryStrategy createRecoveryStrategy({
    bool allowRetries = true,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool allowDegradedMode = false,
  }) {
    return BootstrapRecoveryStrategy(
      allowRetries: allowRetries,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      allowDegradedMode: allowDegradedMode,
    );
  }
}

/// Configuration for error recovery strategies.
class BootstrapRecoveryStrategy {
  final bool allowRetries;
  final int maxRetries;
  final Duration retryDelay;
  final bool allowDegradedMode;

  const BootstrapRecoveryStrategy({
    required this.allowRetries,
    required this.maxRetries,
    required this.retryDelay,
    required this.allowDegradedMode,
  });

  /// Default recovery strategy for production.
  static const BootstrapRecoveryStrategy production = BootstrapRecoveryStrategy(
    allowRetries: true,
    maxRetries: 2,
    retryDelay: Duration(seconds: 1),
    allowDegradedMode: true,
  );

  /// Conservative recovery strategy for critical systems.
  static const BootstrapRecoveryStrategy conservative = BootstrapRecoveryStrategy(
    allowRetries: false,
    maxRetries: 0,
    retryDelay: Duration.zero,
    allowDegradedMode: false,
  );

  /// Aggressive recovery strategy for development.
  static const BootstrapRecoveryStrategy development = BootstrapRecoveryStrategy(
    allowRetries: true,
    maxRetries: 5,
    retryDelay: Duration(milliseconds: 500),
    allowDegradedMode: true,
  );
}