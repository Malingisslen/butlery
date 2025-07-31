/// Legacy injection bridge to modular DI system.
///
/// This file provides backward compatibility for services that still use
/// the old `sl<T>()` pattern while delegating to the new modular system.
/// This allows gradual migration without breaking existing code.
library;

import 'package:butlery/core/providers/application_provider.dart';

/// Legacy service locator function that delegates to the new modular system.
/// 
/// This maintains backward compatibility for existing code that uses `sl<T>()`
/// while the migration to the new `context.get<T>()` pattern is completed.
T sl<T extends Object>() {
  return ServiceLocator.get<T>();
}

/// Legacy initialization function - now handled by ApplicationBootstrap
Future<void> initializeDependencies() async {
  // This is now handled by ApplicationBootstrap.initialize() in main.dart
  // Keeping this stub for backward compatibility during migration
}

/// Legacy check for DI initialization
bool get isInitialized => ServiceLocator.isInitialized;