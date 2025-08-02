/// Performance optimization module for app performance services.
///
/// This module provides performance optimization services including:
/// - Intelligent caching with predictive loading
/// - Optimized image loading with progressive rendering
/// - Startup optimization with lazy loading
/// - Performance monitoring and metrics
///
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

// Dependencies from Core Module
import 'package:butlery/core/di/modules/core_module.dart';

/// Performance optimization module.
///
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
  ];

  @override
  int get priority => 100; // Low priority - loaded after other modules

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [PerformanceModule] Configuring performance services...');
    }

    try {
      // Intelligent cache manager (lazy singleton - initialized on first use)
      container.registerLazySingleton<IntelligentCacheManager>(
        () => IntelligentCacheManager(),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] IntelligentCacheManager registered');
      }

      // Startup optimization manager (singleton - used early in app lifecycle)
      container.registerSingleton<StartupOptimizationManager>(
        StartupOptimizationManager(),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] StartupOptimizationManager registered');
      }

      // Performance monitoring service (singleton)
      container.registerSingleton<PerformanceMonitoringService>(
        PerformanceMonitoringService(),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] PerformanceMonitoringService registered');
      }

      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] All performance services configured');
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
    if (kDebugMode) {
      debugPrint('⚡ [PerformanceModule] Initializing performance services...');
    }

    try {
      final container = GetIt.instance;

      // Initialize performance monitoring first
      final performanceMonitoring = container<PerformanceMonitoringService>();
      performanceMonitoring.initialize();
      
      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] PerformanceMonitoringService initialized');
      }

      // Note: IntelligentCacheManager is lazy and will initialize on first use
      // StartupOptimizationManager is initialized early in main.dart

      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] All performance services initialized');
      }
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
        'IntelligentCacheManager': container<IntelligentCacheManager>(),
        'StartupOptimizationManager': container<StartupOptimizationManager>(),
        'PerformanceMonitoringService': container<PerformanceMonitoringService>(),
      };

      // Get performance metrics
      final performanceMonitoring = container<PerformanceMonitoringService>();
      final metrics = performanceMonitoring.getCurrentSummary();
      
      if (kDebugMode) {
        debugPrint('📊 [PerformanceModule] Current metrics:');
        debugPrint('  Frame rate: ${metrics['frameRate']} FPS');
        debugPrint('  Cache hit rate: ${metrics['cacheHitRate']}%');
        debugPrint('  Network requests: ${metrics['networkRequests']}');
      }

      // Basic validation - services are not null
      for (final entry in services.entries) {
        if (entry.value == null) {
          if (kDebugMode) {
            debugPrint('❌ [PerformanceModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [PerformanceModule] Health check passed');
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