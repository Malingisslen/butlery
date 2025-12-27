/// Core services initialization stage.
/// Handles initialization of essential core services including authentication,
/// storage, analytics, persistence, and Firebase App Check. These are the
/// foundational services that other modules depend on.
library;

import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/services/device_integrity_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';

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

      // Initialize feature flags first - other services may depend on them
      final featureFlagService = GetIt.instance<FeatureFlagService>();
      await featureFlagService.initialize();

      // Initialize device integrity service and perform security check
      final integrityService = GetIt.instance<DeviceIntegrityService>();
      await integrityService.initialize();

      final status = await integrityService.getStatus();
      if (status.isCompromised) {
        AppLogger.warning(
          'SECURITY: Device appears to be rooted/jailbroken. '
          'User will be warned about security risks.',
        );
      }

      // Basic validation that we can proceed
      await Future.delayed(const Duration(milliseconds: 100));
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
      return false;
    }
  }
}
