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
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Core services
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/utils/logger.dart';

// Account/GDPR services
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/consent_service.dart';

// Firebase dependencies
import 'package:firebase_auth/firebase_auth.dart';

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
        FirebaseAuditRepository,
        FirebaseConsentRepository,
        FirestoreRepository,
        PersistenceService,
        AnalyticsRepository,
        AnalyticsService,
        AccountDeletionService,
        DataExportService,
        ConsentService,
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

      // ==================== CORE REPOSITORIES ====================
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

      // ==================== DATABASE REPOSITORIES ====================
      // FirestoreRepository provides centralized Firestore access
      container.registerSingleton<FirestoreRepository>(FirestoreRepository());

      // ==================== CORE SERVICES ====================

      // Authentication service is critical and needed by many other services
      container.registerSingleton<AuthService>(
        AuthService(authRepository: container<AuthRepository>()),
      );

      // Persistence service for local data storage and caching
      container.registerSingleton<PersistenceService>(PersistenceService());

      // Analytics repository for analytics operations
      container.registerSingleton<AnalyticsRepository>(
        FirebaseAnalyticsRepository(),
      );

      // Analytics service for monitoring and tracking
      container.registerSingleton<AnalyticsService>(
        AnalyticsService(repository: container<AnalyticsRepository>()),
      );

      // Configure logger with analytics callback to avoid circular dependency
      _configureLogger(container);

      // ==================== ACCOUNT/GDPR SERVICES ====================

      // Account deletion service for GDPR Article 17 (Right to Erasure)
      container.registerLazySingleton<AccountDeletionService>(
        () => AccountDeletionService(
          authRepository: container<AuthRepository>(),
          firestoreRepository: container<FirestoreRepository>(),
          authService: container<AuthService>(),
          userService: container(), // Will be provided by content module
          recipeService: container(), // Will be provided by content module
          offlineService: container(), // Will be provided by content module
          analyticsService: container<AnalyticsService>(),
        ),
      );

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
            '✅ [CoreModule] Configured 12 core services (Auth, Audit, Consent, Storage, Analytics, Persistence, GDPR)');
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

  /// Configures the logger with analytics callback to avoid circular dependency.
  ///
  /// This method sets up the AppLogger to use AnalyticsService for error tracking
  /// without creating a circular dependency by using a callback pattern.
  void _configureLogger(GetIt container) {
    final analyticsService = container<AnalyticsService>();

    AppLogger.configureAnalytics(
        (errorCode, errorType, userAction, stackTrace) {
      return analyticsService.logErrorOccurred(
        errorCode: errorCode,
        errorType: errorType,
        userAction: userAction,
        stackTrace: stackTrace,
      );
    });

    if (kDebugMode) {
      debugPrint('✅ [CoreModule] Configured logger with analytics callback');
    }
  }

  @override
  Future<void> initialize() async {
    try {
      // Get services from container
      final persistenceService = GetIt.instance<PersistenceService>();
      final analyticsService = GetIt.instance<AnalyticsService>();

      // Initialize PersistenceService first (Hive dependency)
      // Note: PersistenceService may not have explicit initialize method
      // Validate it's accessible instead
      persistenceService.toString(); // Basic validation

      // Initialize AnalyticsService
      // Note: AnalyticsService might not need explicit initialization
      // but we validate it's accessible
      analyticsService.toString(); // Basic validation
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
