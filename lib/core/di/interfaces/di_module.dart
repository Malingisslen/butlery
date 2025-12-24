/// DI Module interface for modular dependency injection system.
/// This interface defines the contract for all dependency injection modules
/// in the Butlery application. Each module represents a domain-specific
/// collection of services and their dependencies.
/// Example usage:
/// ```dart
/// class CoreModule implements DIModule {
///   @override
///   String get name => 'Core';
///   @override
///   Future<void> configure(GetIt container) async {
///     container.registerSingleton<AuthService>(AuthService());
///   }
/// }
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

/// Interface for dependency injection modules.
/// Each module represents a cohesive domain of services and handles:
/// - Service registration with proper dependency order
/// - Module initialization and health checking
/// - Dependency declaration for proper loading sequence
abstract class DIModule {
  /// The name of this module for identification and logging.
  String get name;

  /// List of module types this module depends on.
  /// These dependencies will be initialized before this module.
  /// Use Type references: `[CoreModule, ContentModule]`
  List<Type> get dependencies;

  /// List of service types this module provides.
  /// Used for dependency resolution and health checking.
  /// Example: `[AuthService, PersistenceService]`
  List<Type> get provides;

  /// Configure and register all services in this module.
  /// This method is called during the dependency injection setup phase.
  /// Register services using the provided GetIt container.
  /// [container] The GetIt service locator instance
  /// Throws [Exception] if service registration fails
  Future<void> configure(GetIt container);

  /// Initialize the module after all services are registered.
  /// This method is called after dependency injection is complete
  /// and should handle any required service initialization.
  /// Throws [Exception] if initialization fails
  Future<void> initialize();

  /// Perform health check on all services provided by this module.
  /// Returns `true` if all services are healthy and functioning properly.
  /// This is used during startup validation and ongoing health monitoring.
  Future<bool> healthCheck();

  /// Get the priority order for this module.
  /// Lower numbers have higher priority (initialize first).
  /// Default priority is 100. Core modules should use lower numbers.
  int get priority => 100;
}

/// Exception thrown when module operations fail.
class DIModuleException implements Exception {
  final String module;
  final String operation;
  final String message;
  final Object? cause;

  const DIModuleException(
    this.module,
    this.operation,
    this.message, [
    this.cause,
  ]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'DIModuleException in $module during $operation: $message$causeStr';
  }
}

/// Mixin for common module functionality.
mixin DIModuleHelpers {
  /// Validate that all required services are registered.
  Future<bool> validateServices(
      GetIt container, List<Type> serviceTypes) async {
    try {
      for (final serviceType in serviceTypes) {
        // Basic check that service type exists (simplified for now)
        // In a full implementation, you'd use reflection or a service registry
        if (serviceType == Object) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Log module operation with consistent formatting.
  void logModuleOperation(String moduleName, String operation,
      {String? details}) {
    final detailStr = details != null ? ' - $details' : '';
    debugPrint('🔧 [$moduleName] $operation$detailStr');
  }
}
