import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart';

/// Exception thrown when a deferred module is not found
class ModuleNotFoundError extends Error {
  final String moduleName;
  ModuleNotFoundError(this.moduleName);

  @override
  String toString() => 'Module not found: $moduleName';
}

/// Exception thrown when module loading fails
class ModuleLoadError extends Error {
  final String moduleName;
  final Object? cause;
  ModuleLoadError(this.moduleName, [this.cause]);

  @override
  String toString() => 'Failed to load module: $moduleName. Cause: $cause';
}

/// Base interface for deferred modules
abstract class DeferredModule {
  /// Load the module's library
  Future<void> load();

  /// Whether the module has been loaded
  bool get isLoaded;

  /// Build a widget for the given route
  Widget buildRoute(String routeName, RouteSettings settings);

  /// Get routes handled by this module
  Set<String> get handledRoutes;
}

/// Centralized manager for deferred module loading with caching
class DeferredModuleLoader {
  static final Map<String, DeferredModule> _modules = {};
  static final Map<String, Future<void>> _loadingFutures = {};

  /// Register a module for deferred loading
  static void register(String moduleName, DeferredModule module) {
    _modules[moduleName] = module;
    AppLogger.debug('📦 Registered deferred module: $moduleName');
  }

  /// Check if a module is registered
  static bool isRegistered(String moduleName) {
    return _modules.containsKey(moduleName);
  }

  /// Check if a module is loaded
  static bool isLoaded(String moduleName) {
    return _modules[moduleName]?.isLoaded ?? false;
  }

  /// Get a loaded module (throws if not loaded)
  static T get<T extends DeferredModule>(String moduleName) {
    final module = _modules[moduleName];
    if (module == null) {
      throw ModuleNotFoundError(moduleName);
    }
    if (!module.isLoaded) {
      throw ModuleLoadError(moduleName, 'Module not yet loaded');
    }
    return module as T;
  }

  /// Get module without type casting
  static DeferredModule? getModule(String moduleName) {
    return _modules[moduleName];
  }

  /// Ensure a module is loaded (with caching to prevent duplicate loading)
  static Future<void> ensureLoaded(
    String moduleName, {
    bool forceReload = false,
  }) async {
    final module = _modules[moduleName];
    if (module == null) {
      throw ModuleNotFoundError(moduleName);
    }

    // Already loaded and not forcing reload
    if (module.isLoaded && !forceReload) {
      return;
    }

    // Check if already loading (prevent duplicate concurrent loads)
    if (_loadingFutures.containsKey(moduleName)) {
      AppLogger.debug('📦 Module $moduleName already loading, waiting...');
      return _loadingFutures[moduleName];
    }

    AppLogger.info('📦 Loading deferred module: $moduleName');
    final stopwatch = Stopwatch()..start();

    try {
      _loadingFutures[moduleName] = module.load();
      await _loadingFutures[moduleName];
      stopwatch.stop();
      AppLogger.success(
        '✅ Module $moduleName loaded in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ Failed to load module $moduleName', e);
      throw ModuleLoadError(moduleName, e);
    } finally {
      _loadingFutures.remove(moduleName);
    }
  }

  /// Find which module handles a given route
  static String? findModuleForRoute(String routeName) {
    for (final entry in _modules.entries) {
      if (entry.value.handledRoutes.contains(routeName)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if a route is handled by any deferred module
  static bool isRouteDeferred(String routeName) {
    return findModuleForRoute(routeName) != null;
  }

  /// Clear all modules (useful for testing)
  static void clear() {
    _modules.clear();
    _loadingFutures.clear();
  }

  /// Get loading status for all modules
  static Map<String, bool> getLoadingStatus() {
    return _modules.map((key, value) => MapEntry(key, value.isLoaded));
  }
}
