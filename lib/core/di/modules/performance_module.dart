/// Performance optimization module for app performance services.
/// This module provides performance optimization services including:
/// - Intelligent caching with predictive loading
/// - Optimized image loading with progressive rendering
/// - Performance monitoring and metrics
/// This is an optional module that enhances app performance.
library;

import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';

// Performance services
import 'package:butlery/services/performance/intelligent_cache_manager.dart';
import 'package:butlery/services/performance/performance_monitoring_service.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/monitoring/app_monitoring_service.dart';
import 'package:butlery/services/cache/permission_cache_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

// Dependencies from Core Module
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';

/// Performance optimization module.
/// This module provides advanced performance optimization features
/// and should be loaded after core services are initialized.
class PerformanceModule implements DIModule {
  @override
  String get name => 'Performance';

  @override
  List<Type> get dependencies => [CoreModule, ContentModule];

  @override
  List<Type> get provides => [
        IntelligentCacheManager,
        PerformanceMonitoringService,
        AppMonitoringService,
        JsonCacheHelper,
        PermissionCacheService,
      ];

  @override
  int get priority =>
      15; // Medium priority - cache infrastructure needed by Social module (priority 20)

  @override
  Future<void> configureUserScope(GetIt container) async {}

  @override
  Future<void> configure(GetIt container) async {
    try {
      // JSON cache helper (lazy singleton - uses CacheDao from OfflineService)
      container.registerLazySingleton<JsonCacheHelper>(() {
        final offlineService = container<OfflineService>();
        return JsonCacheHelper(
          'unified_recipes_cache',
          offlineService.database.cacheDao,
        );
      });

      // Intelligent cache manager (lazy singleton - initialized on first use)
      container.registerLazySingleton<IntelligentCacheManager>(
        () => IntelligentCacheManager(),
      );

      // Performance monitoring service
      container.registerLazySingleton<PerformanceMonitoringService>(
        () => PerformanceMonitoringService(),
      );

      // App monitoring service for alerting integration
      container.registerLazySingleton<AppMonitoringService>(
        () => AppMonitoringService(),
      );

      // Permission cache service (lazy singleton - requires FeatureFlagService)
      container.registerLazySingleton<PermissionCacheService>(
        () => PermissionCacheService(
          featureFlags: container<FeatureFlagService>(),
        ),
      );
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

      // Disabled by default — consent-gated via _enableCollectionIfConsented()
      await FirebasePerformanceService.setPerformanceCollectionEnabled(false);

      // Note: IntelligentCacheManager is lazy and will initialize on first use
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
        'PerformanceMonitoringService':
            container<PerformanceMonitoringService>(),
        'AppMonitoringService': container<AppMonitoringService>(),
        'PermissionCacheService': container<PermissionCacheService>(),
      };

      // Basic validation - services are not null
      for (final entry in services.entries) {
        if (entry.value == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
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
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return PerformanceModule();
  }
}
