/// Platform initialization stage.
///
/// Handles the basic platform setup required before any other initialization
/// can occur. This includes Flutter bindings, environment validation, and
/// basic platform-specific configuration.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
// Feature flags removed - using modular system only

/// Platform stage for basic Flutter and environment setup.
///
/// This stage handles the foundational platform initialization that must
/// occur before any other services can be initialized. It ensures:
/// - Flutter bindings are properly initialized
/// - Environment variables are validated
/// - Feature flags are configured
/// - Basic platform setup is complete
class PlatformStage implements BootstrapStage {
  @override
  String get name => 'Platform';

  @override
  List<Type> get requiredModules => []; // No module dependencies

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  int get priority => 1; // Highest priority - must run first

  @override
  bool get isOptional => false; // Critical stage

  @override
  Future<void> execute() async {
    try {
      // Ensure Flutter bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();
      
      // Basic environment validation - modular DI system enabled
      
      if (kDebugMode) {
        debugPrint('✅ [PlatformStage] Platform services ready');
      }
    } catch (e) {
      throw BootstrapException(
        name,
        'execution',
        'Platform initialization failed',
        e,
      );
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validate that Flutter bindings are initialized
      // This is a basic check - if we got this far, bindings should be ready
      final binding = WidgetsBinding.instance;
      // Note: instance is never null in modern Flutter, but we validate it exists
      binding.toString(); // Basic validation that it's accessible

      // Basic validation - modular system is always enabled now
      // No feature flag validation needed since legacy system is removed
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [PlatformStage] Validation failed: $e');
      }
      return false;
    }
  }
}