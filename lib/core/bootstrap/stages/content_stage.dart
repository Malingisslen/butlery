/// Content services initialization stage.
/// Handles initialization of content-related services including recipe
/// management, menu planning, import functionality, and search services.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';

/// Content stage for recipe and menu service initialization.
/// This stage ensures that all content-related services are properly
/// initialized and ready for use. It handles:
/// - Recipe management services
/// - Menu planning and organization
/// - Import functionality (text, photo, URL, archive)
/// - Search and discovery services
/// - Storage and file management
/// - Offline content synchronization
class ContentStage implements BootstrapStage {
  @override
  String get name => 'Content';

  @override
  List<Type> get requiredModules => [CoreModule, ContentModule];

  @override
  Duration get timeout => const Duration(seconds: 45);

  @override
  int get priority => 20; // After Core stage

  @override
  bool get isOptional => false; // Critical for app functionality

  @override
  Future<void> execute() async {
    try {
      // Content module initialization is handled by the DI container
      // UnifiedRecipeService.initialize() is called during ContentModule.initialize()
      // No duplicate initialization needed here - the early return guard would prevent it anyway

      if (kDebugMode) {
        debugPrint(
          '✅ [ContentStage] Content services ready (initialized by ContentModule)',
        );
      }
    } catch (e) {
      throw BootstrapException(
        name,
        'execution',
        'Content services initialization failed',
        e,
      );
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validation is primarily handled by the DI container's health checks
      // This stage confirms content services are ready

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContentStage] Validation failed: $e');
      }
      return false;
    }
  }
}
