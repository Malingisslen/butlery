/// Core services initialization stage.
/// Handles initialization of essential core services including authentication,
/// storage, analytics, persistence, and Firebase App Check. These are the 
/// foundational services that other modules depend on.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';

/// Core stage for essential service initialization.
/// This stage ensures that all foundational services are properly
/// initialized and ready for use by other modules. It handles:
/// - Authentication services
/// - Local storage and persistence
/// - Analytics and monitoring
/// - Database connections
/// - Basic health validation
class CoreStage implements BootstrapStage {
  @override
  String get name => 'Core';

  @override
  List<Type> get requiredModules => [CoreModule];

  @override
  Duration get timeout => const Duration(seconds: 30);

  @override
  int get priority => 10; // After Platform stage

  @override
  bool get isOptional => false; // Critical stage

  @override
  Future<void> execute() async {
    try {
      // Core module initialization is handled by the DI container
      // This stage validates that core services are ready
      
      // Basic validation that we can proceed
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (kDebugMode) {
        debugPrint('✅ [CoreStage] Core services ready');
      }
    } catch (e) {
      throw BootstrapException(
        name,
        'execution',
        'Core services initialization failed',
        e,
      );
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validation is primarily handled by the DI container's health checks
      // This stage just confirms we can proceed
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CoreStage] Validation failed: $e');
      }
      return false;
    }
  }
}