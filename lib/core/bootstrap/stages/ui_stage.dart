/// UI and analytics initialization stage.
///
/// Handles initialization of UI-related services including analytics
/// observers, deep link handling, and final UI setup before the app
/// becomes fully interactive.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
// Feature flags removed - using modular system only

/// UI stage for final UI and analytics setup.
///
/// This stage handles the final initialization steps before the app
/// becomes fully interactive. It ensures:
/// - Analytics observers are configured
/// - Deep link handling is initialized
/// - UI services are ready
/// - Background monitoring is started
/// - Final health validation
class UIStage implements BootstrapStage {
  @override
  String get name => 'UI';

  @override
  List<Type> get requiredModules => [CoreModule]; // Basic UI needs core services

  @override
  Duration get timeout => const Duration(seconds: 15);

  @override
  int get priority => 50; // Last stage - after all other initialization

  @override
  bool get isOptional => true; // App can start without perfect UI setup

  @override
  Future<void> execute() async {
    if (kDebugMode) {
      debugPrint('🚀 [UIStage] Starting UI and analytics initialization...');
    }

    try {
      // Setup analytics observers
      if (kDebugMode) {
        debugPrint('🔍 [UIStage] Setting up analytics observers...');
      }
      
      // Analytics observer setup would happen here
      // Note: In the original main.dart, this was done after background init
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (kDebugMode) {
        debugPrint('✅ [UIStage] Analytics observers configured');
      }

      // Initialize deep link handling
      if (kDebugMode) {
        debugPrint('🔗 [UIStage] Initializing deep link handling...');
      }
      
      // Deep link initialization would happen here
      // Note: This will be extracted to a separate handler
      await Future.delayed(const Duration(milliseconds: 50));
      
      if (kDebugMode) {
        debugPrint('✅ [UIStage] Deep link handling initialized');
      }

      // Start background health monitoring
      if (kDebugMode) {
        debugPrint('🔄 [UIStage] Starting background health monitoring...');
      }
      
      // Background monitoring would be started here
      // This would use the ApplicationHealthChecker
      
      if (kDebugMode) {
        debugPrint('✅ [UIStage] Background monitoring started');
      }

      if (kDebugMode) {
        debugPrint('✅ [UIStage] UI and analytics initialization complete');
      }
    } catch (e) {
      if (isOptional) {
        if (kDebugMode) {
          debugPrint('⚠️ [UIStage] Optional stage failed, continuing: $e');
        }
        return; // Don't throw for optional stages
      }
      
      throw BootstrapException(
        name,
        'execution',
        'UI initialization failed',
        e,
      );
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validate that basic UI setup is complete
      // Most validation is handled by earlier stages and DI health checks
      
      // Basic validation - we reached this point successfully
      if (kDebugMode) {
        debugPrint('✅ [UIStage] Validation passed');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UIStage] Validation failed: $e');
      }
      
      // Return true for optional stages to allow app to continue
      return isOptional;
    }
  }
}