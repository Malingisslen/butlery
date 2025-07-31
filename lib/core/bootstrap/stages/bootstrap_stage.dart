/// Bootstrap stage interface for application initialization.
///
/// This interface defines the contract for bootstrap stages that handle
/// different phases of application startup. Stages are executed in order
/// and can have dependencies on specific modules being available.
library;

import 'package:flutter/foundation.dart';

/// Interface for application bootstrap stages.
///
/// Each stage represents a phase of application initialization:
/// - Platform setup (Flutter bindings, environment)
/// - Core services (Auth, Storage, Analytics)
/// - Content services (Recipes, Import, Search)
/// - Social services (Friends, Sharing, Messaging)
/// - UI setup (Deep links, Analytics observers)
///
/// Example usage:
/// ```dart
/// class PlatformStage implements BootstrapStage {
///   @override
///   String get name => 'Platform';
///   
///   @override
///   Future<void> execute() async {
///     WidgetsFlutterBinding.ensureInitialized();
///   }
/// }
/// ```
abstract class BootstrapStage {
  /// The name of this stage for identification and logging.
  String get name;

  /// List of module types that must be available before this stage runs.
  ///
  /// These are not dependencies that trigger module loading, but rather
  /// validation that required modules are configured before execution.
  List<Type> get requiredModules;

  /// Maximum time allowed for this stage to complete.
  ///
  /// Stages that exceed this timeout will cause initialization to fail.
  /// Use reasonable timeouts - most stages should complete in seconds.
  Duration get timeout;

  /// Execute this bootstrap stage.
  ///
  /// This method performs the actual initialization work for this stage.
  /// It should be idempotent - safe to call multiple times.
  ///
  /// Throws [BootstrapException] if the stage fails to execute.
  Future<void> execute();

  /// Validate that this stage completed successfully.
  ///
  /// Called after execute() to verify the stage achieved its goals.
  /// Should perform minimal validation to avoid performance impact.
  ///
  /// Returns `true` if validation passes, `false` otherwise.
  Future<bool> validate();

  /// Get the priority order for this stage.
  ///
  /// Lower numbers have higher priority (execute first).
  /// Default priority is 100. Critical stages should use lower numbers.
  int get priority => 100;

  /// Whether this stage can be skipped if it fails.
  ///
  /// Non-critical stages can be skipped to allow the app to start
  /// with reduced functionality. Critical stages will halt startup.
  bool get isOptional => false;
}

/// Exception thrown when bootstrap stage operations fail.
class BootstrapException implements Exception {
  final String stage;
  final String operation;
  final String message;
  final Object? cause;

  const BootstrapException(
    this.stage,
    this.operation,
    this.message, [
    this.cause,
  ]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'BootstrapException in $stage during $operation: $message$causeStr';
  }
}

/// Mixin for common bootstrap stage functionality.
mixin BootstrapStageHelpers {
  /// Execute with timeout and error handling.
  Future<void> executeWithTimeout(
    String stageName,
    Future<void> Function() operation,
    Duration timeout,
  ) async {
    try {
      await operation().timeout(timeout);
    } catch (e) {
      throw BootstrapException(
        stageName,
        'execution',
        'Stage execution failed or timed out',
        e,
      );
    }
  }

  /// Log stage operation with consistent formatting.
  void logStageOperation(String stageName, String operation, {String? details}) {
    final detailStr = details != null ? ' - $details' : '';
    debugPrint('🚀 [$stageName] $operation$detailStr');
  }

  /// Validate environment variable is set.
  String? getEnvironmentVariable(String name, {bool required = false}) {
    // Note: This is a simplified implementation for compilation
    // In production, you'd use dart.io.Platform.environment
    const value = '';
    
    if (required && (value.isEmpty)) {
      throw BootstrapException(
        'Environment',
        'validation',
        'Required environment variable $name is not set',
      );
    }
    
    return value.isEmpty ? null : value;
  }

  /// Wait for a condition with timeout.
  Future<bool> waitForCondition(
    bool Function() condition,
    Duration timeout, {
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      if (condition()) {
        return true;
      }
      await Future.delayed(checkInterval);
    }
    
    return false;
  }
}