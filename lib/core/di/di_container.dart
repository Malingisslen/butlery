/// Main dependency injection container orchestrator.
///
/// This file manages the modular dependency injection system, coordinating
/// module loading, dependency resolution, and service health monitoring.
/// It replaces the monolithic injection.dart with a modular approach.
library;

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

/// Main container orchestrator for the modular DI system.
///
/// Manages module registration, dependency resolution, and health monitoring.
/// Provides a clean interface for the application bootstrap process.
class DIContainer {
  static final DIContainer _instance = DIContainer._internal();
  factory DIContainer() => _instance;
  DIContainer._internal();

  final GetIt _container = GetIt.instance;
  final List<DIModule> _modules = [];
  final Map<Type, DIModule> _modulesByType = {};
  bool _isInitialized = false;

  /// Get the underlying GetIt instance.
  GetIt get container => _container;

  /// Whether the container has been initialized.
  bool get isInitialized => _isInitialized;

  /// Get all registered modules.
  List<DIModule> get modules => List.unmodifiable(_modules);

  /// Register a module with the container.
  ///
  /// Modules are registered but not immediately configured.
  /// Call [initialize] to configure all modules in dependency order.
  void registerModule(DIModule module) {
    if (_isInitialized) {
      throw DIModuleException(
        module.name,
        'registration',
        'Cannot register modules after initialization',
      );
    }

    _modules.add(module);
    _modulesByType[module.runtimeType] = module;
    
    if (kDebugMode) {
      print('📦 Registered module: ${module.name}');
    }
  }

  /// Register multiple modules at once.
  void registerModules(List<DIModule> modules) {
    for (final module in modules) {
      registerModule(module);
    }
  }

  /// Initialize all registered modules in dependency order.
  ///
  /// This method:
  /// 1. Sorts modules by dependencies and priority
  /// 2. Configures each module (registers services)  
  /// 3. Initializes each module
  /// 4. Validates all modules are healthy
  ///
  /// Throws [DIModuleException] if initialization fails.
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ DIContainer already initialized, skipping');
      }
      return;
    }

    if (kDebugMode) {
      print('🚀 Initializing DIContainer with ${_modules.length} modules...');
    }

    try {
      // Step 1: Sort modules by dependencies and priority
      final sortedModules = _sortModulesByDependencies();
      
      if (kDebugMode) {
        print('📋 Module initialization order: ${sortedModules.map((m) => m.name).join(' → ')}');
      }

      // Step 2: Configure all modules (register services)
      for (final module in sortedModules) {
        await _configureModule(module);
      }

      // Step 3: Initialize all modules
      for (final module in sortedModules) {
        await _initializeModule(module);
      }

      // Step 4: Validate all modules are healthy
      final healthReport = await checkHealth();
      if (!healthReport.isHealthy) {
        throw DIModuleException(
          'DIContainer',
          'initialization',
          'Health check failed: ${healthReport.unhealthyServices.map((s) => s.serviceName).join(', ')}',
        );
      }

      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ DIContainer initialization complete - ${healthReport.healthyCount} services healthy');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DIContainer initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Check health of all services across all modules.
  Future<HealthReport> checkHealth() async {
    final serviceMap = <String, dynamic>{};
    
    for (final module in _modules) {
      for (final serviceType in module.provides) {
        try {
          final service = _container.get(type: serviceType);
          serviceMap['${module.name}.${serviceType.toString()}'] = service;
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not get service $serviceType from module ${module.name}: $e');
          }
        }
      }
    }

    return await HealthChecker.checkServices(serviceMap);
  }

  /// Get a service from the container.
  T get<T extends Object>() => _container.get<T>();

  /// Check if a service is registered.
  bool isRegistered<T extends Object>() => _container.isRegistered<T>();

  /// Reset the container (for testing).
  Future<void> reset() async {
    await _container.reset();
    _modules.clear();
    _modulesByType.clear();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('🔄 DIContainer reset complete');
    }
  }

  /// Configure a single module.
  Future<void> _configureModule(DIModule module) async {
    try {
      if (kDebugMode) {
        print('🔧 Configuring module: ${module.name}');
      }
      
      await module.configure(_container);
      
      if (kDebugMode) {
        print('✅ Module configured: ${module.name} (provides ${module.provides.length} services)');
      }
    } catch (e) {
      throw DIModuleException(
        module.name,
        'configuration',
        'Failed to configure module',
        e,
      );
    }
  }

  /// Initialize a single module.
  Future<void> _initializeModule(DIModule module) async {
    try {
      if (kDebugMode) {
        print('⚡ Initializing module: ${module.name}');
      }
      
      await module.initialize();
      
      // Perform health check
      final isHealthy = await module.healthCheck();
      if (!isHealthy) {
        throw DIModuleException(
          module.name,
          'initialization',
          'Health check failed after initialization',
        );
      }
      
      if (kDebugMode) {
        print('✅ Module initialized: ${module.name}');
      }
    } catch (e) {
      throw DIModuleException(
        module.name,
        'initialization',
        'Failed to initialize module',
        e,
      );
    }
  }

  /// Sort modules by dependencies and priority.
  List<DIModule> _sortModulesByDependencies() {
    final sorted = <DIModule>[];
    final processing = <Type>{};
    final processed = <Type>{};

    void processModule(DIModule module) {
      final moduleType = module.runtimeType;
      
      if (processed.contains(moduleType)) {
        return; // Already processed
      }
      
      if (processing.contains(moduleType)) {
        throw DIModuleException(
          module.name,
          'dependency_resolution',
          'Circular dependency detected in module dependency graph',
        );
      }

      processing.add(moduleType);

      // Process dependencies first
      for (final depType in module.dependencies) {
        final depModule = _modulesByType[depType];
        if (depModule == null) {
          throw DIModuleException(
            module.name,
            'dependency_resolution',
            'Required dependency module $depType not registered',
          );
        }
        processModule(depModule);
      }

      processing.remove(moduleType);
      processed.add(moduleType);
      sorted.add(module);
    }

    // Process all modules
    for (final module in _modules) {
      processModule(module);
    }

    // Sort by priority within dependency groups
    sorted.sort((a, b) => a.priority.compareTo(b.priority));

    return sorted;
  }
}