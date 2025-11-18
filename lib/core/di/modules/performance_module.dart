/// Performance optimization module for app performance services.
/// This module provides performance optimization services including:
/// - Intelligent caching with predictive loading
/// - Optimized image loading with progressive rendering
/// - Startup optimization with lazy loading
/// - Performance monitoring and metrics
/// This is an optional module that enhances app performance.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';

// Performance services
import 'package:butlery/services/performance/intelligent_cache_manager.dart';
import 'package:butlery/services/performance/startup_optimization_manager.dart';
import 'package:butlery/services/performance/performance_monitoring_service.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

// Dependencies from Core Module
import 'package:butlery/core/di/modules/core_module.dart';

/// Performance optimization module.
/// This module provides advanced performance optimization features
/// and should be loaded after core services are initialized.
class PerformanceModule implements DIModule {
  @override
  String get name => 'Performance';

  @override
  List<Type> get dependencies => [CoreModule];

  @override
  List<Type> get provides => [
        IntelligentCacheManager,
        StartupOptimizationManager,
        PerformanceMonitoringService,
        JsonCacheHelper,
      ];

  @override
  int get priority =>
      15; // Medium priority - cache infrastructure needed by Social module (priority 20)

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [PerformanceModule] Configuring performance services...');
    }

    try {
      // JSON cache helper (singleton - shared cache infrastructure)
      container.registerSingleton<JsonCacheHelper>(
        JsonCacheFactory.recipeCache(), // Primary cache instance for recipes
      );

      // Intelligent cache manager (lazy singleton - initialized on first use)
      container.registerLazySingleton<IntelligentCacheManager>(
        () => IntelligentCacheManager(),
      );

      // Startup optimization manager (singleton - used early in app lifecycle)
      container.registerSingleton<StartupOptimizationManager>(
        StartupOptimizationManager(),
      );

      // Performance monitoring service (singleton)
      container.registerSingleton<PerformanceMonitoringService>(
        PerformanceMonitoringService(),
      );

      if (kDebugMode) {
        debugPrint(
            '✅ [PerformanceModule] Configured 4 performance services (JSON Cache, Intelligent Cache, Startup, Monitoring)');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure performance services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // Initialize performance monitoring first
      final performanceMonitoring = container<PerformanceMonitoringService>();
      performanceMonitoring.initialize();

      // Initialize Firebase Performance (enabled by default)
      await FirebasePerformanceService.setPerformanceCollectionEnabled(true);

      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] Firebase Performance initialized');
      }

      // Note: IntelligentCacheManager is lazy and will initialize on first use
      // StartupOptimizationManager is initialized early in main.dart
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize performance services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Check that all performance services are registered and accessible
      final services = <String, dynamic>{
        'JsonCacheHelper': container<JsonCacheHelper>(),
        'IntelligentCacheManager': container<IntelligentCacheManager>(),
        'StartupOptimizationManager': container<StartupOptimizationManager>(),
        'PerformanceMonitoringService':
            container<PerformanceMonitoringService>(),
      };

      // Basic validation - services are not null
      for (final entry in services.entries) {
        if (entry.value == null) {
          if (kDebugMode) {
            debugPrint('❌ [PerformanceModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [PerformanceModule] Health check failed: $e');
      }
      return false;
    }
  }
}

/// Performance module factory for easy instantiation.
class PerformanceModuleFactory {
  /// Create a new PerformanceModule instance.
  static PerformanceModule create() => PerformanceModule();

  /// Create PerformanceModule with custom configuration.
  static PerformanceModule createWithConfig({
    bool enableIntelligentCache = true,
    bool enablePerformanceMonitoring = true,
    bool enableStartupOptimization = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return PerformanceModule();
  }
}
