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
import 'package:butlery/services/monitoring/web_error_reporter.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:butlery/services/cache/permission_cache_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

// Dependencies from Core Module
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';

/// Performance optimization module.
/// This module provides advanced performance optimization features
/// and should be loaded after core services are initialized.
class PerformanceModule implements DIModule {
  /// BUT-431 cold-start: when true, [initialize] skips its non-critical
  /// side-effects (perf-monitoring start + Firebase perf-collection toggle) so
  /// they can run after the first frame. Registration via [configure] is
  /// unaffected and stays eager. Defaults to false so the admin entry point and
  /// the post-login re-init path keep the original eager behavior.
  static bool deferInitSideEffects = false;

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
  int get priority => 15; // Medium priority - cache infrastructure needed by Social module (priority 20)

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    // JsonCacheHelper depends on OfflineService (user-scoped)
    container.registerLazySingleton<JsonCacheHelper>(() {
      final offlineService = app<OfflineService>();
      return JsonCacheHelper(
        'unified_recipes_cache',
        offlineService.database.cacheDao,
      );
    });

    container.registerLazySingleton<IntelligentCacheManager>(
      () => IntelligentCacheManager(),
      dispose: (s) => s.clearCache(),
    );

    container.registerLazySingleton<PermissionCacheService>(
      () => PermissionCacheService(
        featureFlags: app<FeatureFlagService>(),
      ),
      dispose: (s) => s.invalidateAll(),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      // JsonCacheHelper: registered in configureUserScope (depends on OfflineService)

      // Performance monitoring service
      container.registerLazySingleton<PerformanceMonitoringService>(
        () => PerformanceMonitoringService(),
      );

      // App monitoring service for alerting integration.
      // BUT-1405: on web, inject a WebErrorReporter so deliberately-recorded
      // error/critical business errors are forwarded to logWebError instead of
      // dropped (Crashlytics has no web SDK). Native passes null and uses the
      // Crashlytics path. Lazy → ConsentService is registered by first resolve.
      container.registerLazySingleton<AppMonitoringService>(
        () => AppMonitoringService(
          webErrorReporter: kIsWeb
              ? WebErrorReporter(consentService: container<ConsentService>())
              : null,
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
      // BUT-431: nothing resolves these side-effects during first paint, so
      // when deferral is on we skip them here and main() re-runs them in a
      // post-frame callback via [runInitSideEffects]. Registration already
      // happened in configure(); this only delays perf-monitoring start.
      if (deferInitSideEffects) return;

      await runInitSideEffects();

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

  /// The non-critical init side-effects, split out of [initialize] so the
  /// deferred post-frame path (BUT-431) can invoke the exact same work.
  /// Both calls are idempotent: PerformanceMonitoringService guards on its
  /// internal monitoring flag, and the collection toggle is safe to repeat.
  static Future<void> runInitSideEffects() async {
    final container = GetIt.instance;

    // Initialize performance monitoring first
    final performanceMonitoring = container<PerformanceMonitoringService>();
    performanceMonitoring.initialize();

    // Disabled by default — consent-gated via _enableCollectionIfConsented()
    await FirebasePerformanceService.setPerformanceCollectionEnabled(false);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // App-scoped services (always available)
      final services = <String, dynamic>{
        'PerformanceMonitoringService':
            container<PerformanceMonitoringService>(),
        'AppMonitoringService': container<AppMonitoringService>(),
      };

      // User-scoped services (only after login)
      if (container.isRegistered<JsonCacheHelper>()) {
        services['JsonCacheHelper'] = container<JsonCacheHelper>();
      }
      if (container.isRegistered<IntelligentCacheManager>()) {
        services['IntelligentCacheManager'] =
            container<IntelligentCacheManager>();
      }
      if (container.isRegistered<PermissionCacheService>()) {
        services['PermissionCacheService'] =
            container<PermissionCacheService>();
      }

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
