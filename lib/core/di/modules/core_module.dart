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
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/services/theme_service.dart';
// Core providers
import 'package:butlery/core/providers/locale_provider.dart';

// Account/GDPR services
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/consent_service.dart';

// Device security
import 'package:butlery/services/device_integrity_service.dart';
// Feature flags
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

// Beta feedback
import 'package:butlery/services/feedback/interaction_logger.dart';
import 'package:butlery/services/feedback/feedback_service.dart';

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
      SessionTimeoutService,
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
      // Core providers
      LocaleProvider,
      ThemeService,
      // Feature flags
      FeatureFlagService,
      // Beta feedback
      InteractionLogger,
      FeedbackService,
    ];

    return services;
  }

  @override
  int get priority => 1; // Highest priority - initialize first

  @override
  Future<void> configure(GetIt container) async {
    try {
      // SharedPreferences must be registered first as many services depend on it
      final sharedPreferences = await SharedPreferences.getInstance();
      container.registerSingleton<SharedPreferences>(sharedPreferences);

      // LocaleProvider for app language management
      container.registerSingleton<LocaleProvider>(LocaleProvider());

      // ThemeService for dark/light mode management
      container.registerSingleton<ThemeService>(ThemeService());

      // Feature flags for gradual rollouts and kill switches
      container.registerSingleton<FeatureFlagService>(FeatureFlagService());

      // Core repositories form the foundation of the data access layer
      container.registerSingleton<AuthRepository>(FirebaseAuthRepository());

      // Audit repository for GDPR Article 30 compliance (persistent audit logging)
      container.registerSingleton<FirebaseAuditRepository>(
        FirebaseAuditRepository(),
      );

      // Consent repository for GDPR Article 7 compliance (consent management)
      container.registerSingleton<FirebaseConsentRepository>(
        FirebaseConsentRepository(
          authRepository: container<AuthRepository>(),
          auditRepository: container<FirebaseAuditRepository>(),
        ),
      );

      // FirestoreRepository provides centralized Firestore access
      container.registerSingleton<FirestoreRepository>(FirestoreRepository());

      // Analytics repository for analytics operations
      // IMPORTANT: Must be registered BEFORE AuthService (which depends on it)
      // Uses FirebaseAnalyticsRepository on native platforms, NoOpAnalyticsRepository on web
      // Register appropriate repository based on platform
      container.registerSingleton<AnalyticsRepository>(
        kIsWeb ? NoOpAnalyticsRepository() : FirebaseAnalyticsRepository(),
      );

      // Analytics service for monitoring and tracking (available on all platforms)
      container.registerSingleton<AnalyticsService>(
        AnalyticsService(repository: container<AnalyticsRepository>()),
      );

      // Authentication service is critical and needed by many other services
      // Note: Depends on AnalyticsService (available on all platforms)
      container.registerSingleton<AuthService>(
        AuthService(
          authRepository: container<AuthRepository>(),
          analyticsService: container<AnalyticsService>(),
        ),
      );

      // Session timeout service for automatic logout on inactivity
      // Note: Depends on AuthService and AnalyticsService
      container.registerLazySingleton<SessionTimeoutService>(
        () => SessionTimeoutService(
          authService: container<AuthService>(),
          analyticsService: container<AnalyticsService>(),
        ),
      );

      // Persistence service for local data storage and caching
      container.registerSingleton<PersistenceService>(PersistenceService());

      // Account deletion service for GDPR Article 17 (Right to Erasure)
      container.registerLazySingleton<AccountDeletionService>(() {
        return AccountDeletionService(
          authRepository: container<AuthRepository>(),
          firestoreRepository: container<FirestoreRepository>(),
          authService: container<AuthService>(),
          userService: container(), // Will be provided by content module
          recipeService: container(), // Will be provided by content module
          offlineService: container(), // Will be provided by content module
          analyticsService: container<AnalyticsService>(),
        );
      });

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

      // Device integrity service for root/jailbreak detection
      container.registerLazySingleton<DeviceIntegrityService>(
        () => DeviceIntegrityService(),
      );

      // Beta feedback services
      container.registerLazySingleton<InteractionLogger>(
        () => InteractionLogger(),
      );
      container.registerLazySingleton<FeedbackService>(
        () => FeedbackService(),
      );
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

      // Initialize AnalyticsService and wire consent for GDPR compliance
      if (GetIt.instance.isRegistered<AnalyticsService>()) {
        final analyticsService = GetIt.instance<AnalyticsService>();
        await analyticsService.initialize();

        // Wire ConsentService so analytics respects user consent
        if (GetIt.instance.isRegistered<ConsentService>()) {
          final consentService = GetIt.instance<ConsentService>();
          analyticsService.setConsentService(consentService);
        }
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
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
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
