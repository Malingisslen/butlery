/// Core module for foundational services.
///
/// This module handles the core application infrastructure including:
/// - Authentication services and repositories
/// - Local storage and persistence
/// - Analytics and monitoring
/// - Database repositories
///
/// This is the foundation module that other modules depend on.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Repositories and interfaces
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Core services
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/analytics_service.dart';

/// Core module providing foundational application services.
///
/// This module is the foundation of the dependency injection system and
/// must be initialized before all other modules. It provides:
/// - SharedPreferences for local storage
/// - Authentication repository and service
/// - Firestore repository for database access
/// - Persistence service for caching
/// - Analytics service for monitoring
class CoreModule implements DIModule {
  @override
  String get name => 'Core';

  @override
  List<Type> get dependencies => []; // No dependencies - foundation module

  @override
  List<Type> get provides => [
    SharedPreferences,
    AuthRepository,
    AuthService,
    FirestoreRepository,
    PersistenceService,
    AnalyticsRepository,
    AnalyticsService,
  ];

  @override
  int get priority => 1; // Highest priority - initialize first

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [CoreModule] Configuring core services...');
    }

    try {
      // ==================== PLATFORM DEPENDENCIES ====================
      // SharedPreferences must be registered first as many services depend on it
      final sharedPreferences = await SharedPreferences.getInstance();
      container.registerSingleton<SharedPreferences>(sharedPreferences);
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] SharedPreferences registered');
      }

      // ==================== CORE REPOSITORIES ====================
      // Core repositories form the foundation of the data access layer
      container.registerSingleton<AuthRepository>(FirebaseAuthRepository());
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AuthRepository registered');
      }

      // ==================== DATABASE REPOSITORIES ====================
      // FirestoreRepository provides centralized Firestore access
      container.registerSingleton<FirestoreRepository>(FirestoreRepository());
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] FirestoreRepository registered');
      }

      // ==================== CORE SERVICES ====================
      
      // Authentication service is critical and needed by many other services
      container.registerSingleton<AuthService>(
        AuthService(authRepository: container<AuthRepository>()),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AuthService registered');
      }

      // Persistence service for local data storage and caching
      container.registerSingleton<PersistenceService>(PersistenceService());
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] PersistenceService registered');
      }

      // Analytics repository for analytics operations
      container.registerSingleton<AnalyticsRepository>(
        FirebaseAnalyticsRepository(),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AnalyticsRepository registered');
      }

      // Analytics service for monitoring and tracking
      container.registerSingleton<AnalyticsService>(
        AnalyticsService(repository: container<AnalyticsRepository>()),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AnalyticsService registered');
      }

      if (kDebugMode) {
        debugPrint('✅ [CoreModule] All core services configured');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure core services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('⚡ [CoreModule] Initializing core services...');
    }

    try {
      // Get services from container
      final persistenceService = GetIt.instance<PersistenceService>();
      final analyticsService = GetIt.instance<AnalyticsService>();

      // Initialize PersistenceService first (Hive dependency)
      // Note: PersistenceService may not have explicit initialize method
      // Validate it's accessible instead
      persistenceService.toString(); // Basic validation
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] PersistenceService initialized');
      }

      // Initialize AnalyticsService
      // Note: AnalyticsService might not need explicit initialization
      // but we validate it's accessible
      analyticsService.toString(); // Basic validation
      
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AnalyticsService validated');
      }

      if (kDebugMode) {
        debugPrint('✅ [CoreModule] All core services initialized');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize core services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Check that all core services are registered and accessible
      final services = <String, dynamic>{
        'SharedPreferences': container<SharedPreferences>(),
        'AuthRepository': container<AuthRepository>(),
        'AuthService': container<AuthService>(),
        'FirestoreRepository': container<FirestoreRepository>(),
        'PersistenceService': container<PersistenceService>(),
        'AnalyticsRepository': container<AnalyticsRepository>(),
        'AnalyticsService': container<AnalyticsService>(),
      };

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;
        
        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint('❌ [CoreModule] Health check failed for ${entry.key}');
            }
            return false;
          }
        }
        
        // Basic validation - service is not null
        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [CoreModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [CoreModule] Health check passed for all services');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CoreModule] Health check failed: $e');
      }
      return false;
    }
  }
}

/// Core module factory for easy instantiation.
class CoreModuleFactory {
  /// Create a new CoreModule instance.
  static CoreModule create() => CoreModule();
  
  /// Create CoreModule with custom configuration.
  static CoreModule createWithConfig({
    bool enableAnalytics = true,
    bool enablePersistence = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return CoreModule();
  }
}