/// Core module for foundational services.
/// This module handles the core application infrastructure including:
/// - Authentication services and repositories
/// - Local storage and persistence
/// - Analytics and monitoring
/// - Database repositories
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
import 'package:butlery/repositories/noop/noop_analytics_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Core services
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/analytics_service.dart';

// Account/GDPR services
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/consent_service.dart';

// Firebase dependencies
import 'package:firebase_auth/firebase_auth.dart';

/// Core module providing foundational application services.
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
  List<Type> get provides {
    final services = <Type>[
      SharedPreferences,
      AuthRepository,
      AuthService,
      FirebaseAuditRepository,
      FirebaseConsentRepository,
      FirestoreRepository,
      PersistenceService,
      // Analytics services are available on all platforms (NoOp on web)
      AnalyticsRepository,
      AnalyticsService,
      AccountDeletionService,
      DataExportService,
      ConsentService,
    ];

    return services;
  }

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
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 1: Getting SharedPreferences...');
      }
      final sharedPreferences = await SharedPreferences.getInstance();
      container.registerSingleton<SharedPreferences>(sharedPreferences);
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] SharedPreferences registered');
      }

      // ==================== CORE REPOSITORIES ====================
      // Core repositories form the foundation of the data access layer
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 2: Registering AuthRepository...');
      }
      container.registerSingleton<AuthRepository>(FirebaseAuthRepository());
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AuthRepository registered');
      }

      // Audit repository for GDPR Article 30 compliance (persistent audit logging)
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 3: Registering AuditRepository...');
      }
      container.registerSingleton<FirebaseAuditRepository>(
        FirebaseAuditRepository(),
      );
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AuditRepository registered');
      }

      // Consent repository for GDPR Article 7 compliance (consent management)
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 4: Registering ConsentRepository...');
      }
      container.registerSingleton<FirebaseConsentRepository>(
        FirebaseConsentRepository(
          authRepository: container<AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] ConsentRepository registered');
      }

      // ==================== DATABASE REPOSITORIES ====================
      // FirestoreRepository provides centralized Firestore access
      if (kDebugMode) {
        debugPrint(
            '🔍 [CoreModule] Step 5: Registering FirestoreRepository...');
      }
      container.registerSingleton<FirestoreRepository>(FirestoreRepository());
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] FirestoreRepository registered');
      }

      // ==================== CORE SERVICES ====================

      // Analytics repository for analytics operations
      // IMPORTANT: Must be registered BEFORE AuthService (which depends on it)
      // Uses FirebaseAnalyticsRepository on native platforms, NoOpAnalyticsRepository on web
      if (kDebugMode) {
        debugPrint(
            '🔍 [CoreModule] Step 6: Registering Analytics - kIsWeb=$kIsWeb');
      }

      // Register appropriate repository based on platform
      container.registerSingleton<AnalyticsRepository>(
        kIsWeb ? NoOpAnalyticsRepository() : FirebaseAnalyticsRepository(),
      );
      if (kDebugMode) {
        debugPrint(
            '✅ [CoreModule] AnalyticsRepository registered (${kIsWeb ? "NoOp" : "Firebase"})');
      }

      // Analytics service for monitoring and tracking (available on all platforms)
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Registering AnalyticsService...');
      }
      container.registerSingleton<AnalyticsService>(
        AnalyticsService(repository: container<AnalyticsRepository>()),
      );
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AnalyticsService registered');
      }

      // Authentication service is critical and needed by many other services
      // Note: Depends on AnalyticsService (available on all platforms)
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 7: Registering AuthService...');
      }
      container.registerSingleton<AuthService>(
        AuthService(
          authRepository: container<AuthRepository>(),
          analyticsService: container<AnalyticsService>(),
        ),
      );
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AuthService registered');
      }

      // Persistence service for local data storage and caching
      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Step 8: Registering PersistenceService...');
      }
      container.registerSingleton<PersistenceService>(PersistenceService());
      if (kDebugMode) {
        debugPrint('✅ [CoreModule] PersistenceService registered');
      }

      // ==================== ACCOUNT/GDPR SERVICES ====================

      if (kDebugMode) {
        debugPrint('🔍 [CoreModule] Registering GDPR services...');
        debugPrint('🔍 [CoreModule] kIsWeb = $kIsWeb');
      }

      // Account deletion service for GDPR Article 17 (Right to Erasure)
      container.registerLazySingleton<AccountDeletionService>(
        () {
          if (kDebugMode) {
            debugPrint(
                '🔍 [CoreModule] Creating AccountDeletionService instance...');
          }
          return AccountDeletionService(
            authRepository: container<AuthRepository>(),
            firestoreRepository: container<FirestoreRepository>(),
            authService: container<AuthService>(),
            userService: container(), // Will be provided by content module
            recipeService: container(), // Will be provided by content module
            offlineService: container(), // Will be provided by content module
            analyticsService: container<AnalyticsService>(),
          );
        },
      );

      if (kDebugMode) {
        debugPrint('✅ [CoreModule] AccountDeletionService registered');
      }

      // Data export service for GDPR Article 20 (Right to Data Portability)
      container.registerLazySingleton<DataExportService>(
        () => DataExportService(
          authRepository: container<AuthRepository>(),
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      // Consent service for GDPR Article 7 (Consent Management)
      container.registerLazySingleton<ConsentService>(
        () => ConsentService(
          auth: FirebaseAuth.instance,
          consentRepository: container<FirebaseConsentRepository>(),
        ),
      );

      if (kDebugMode) {
        debugPrint(
          '✅ [CoreModule] Configured 12 core services (Auth, Audit, Consent, Storage, Analytics, Persistence, GDPR)',
        );
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
    try {
      // Get services from container
      final persistenceService = GetIt.instance<PersistenceService>();

      // Initialize PersistenceService first (Hive dependency)
      // Note: PersistenceService may not have explicit initialize method
      // Validate it's accessible instead
      persistenceService.toString(); // Basic validation

      // Initialize AnalyticsService if available (may not be on web)
      // Note: AnalyticsService might not need explicit initialization
      // but we validate it's accessible
      if (GetIt.instance.isRegistered<AnalyticsService>()) {
        final analyticsService = GetIt.instance<AnalyticsService>();
        analyticsService.toString(); // Basic validation
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
      };

      // Add analytics services if they're registered (may not be available on web)
      if (container.isRegistered<AnalyticsRepository>()) {
        services['AnalyticsRepository'] = container<AnalyticsRepository>();
      }
      if (container.isRegistered<AnalyticsService>()) {
        services['AnalyticsService'] = container<AnalyticsService>();
      }

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
