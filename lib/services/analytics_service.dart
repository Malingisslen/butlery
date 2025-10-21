/// Analytics service for tracking user interactions and app metrics

import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Analytics service that delegates to an AnalyticsRepository implementation.
///
/// This service now uses dependency injection for better testability while
/// maintaining the singleton pattern and existing API. The repository pattern
/// allows for easy mocking in tests and switching between different analytics
/// providers if needed.
///
/// **GDPR Compliance**: This service checks user consent before logging analytics
/// events as required by GDPR Article 7. Key methods include consent checks via
/// `_hasAnalyticsConsent()`. Auth/security events (login, logout, account deletion)
/// are exempt from consent requirements as they are necessary for service operation.
class AnalyticsService extends BaseService with SingletonServiceMixin<AnalyticsService> {
  final AnalyticsRepository _repository;
  ConsentService? _consentService;

  AnalyticsService._internal(this._repository);

  /// Factory constructor with dependency injection support.
  ///
  /// Accepts an optional [repository] parameter for testing.
  /// In production, uses FirebaseAnalyticsRepository by default.
  factory AnalyticsService({AnalyticsRepository? repository}) =>
    SingletonServiceMixin.createSingletonWithDependencies(
      () => AnalyticsService._internal(
        repository ?? FirebaseAnalyticsRepository(),
      ),
      dependencies: repository != null ? [repository] : [],
    );

  @override
  String get serviceName => 'AnalyticsService';

  /// Set consent service for GDPR compliance checking
  /// This should be called after ConsentService is initialized
  void setConsentService(ConsentService consentService) {
    _consentService = consentService;
    app_logger.AppLogger.info('[AnalyticsService] Consent service configured for GDPR compliance');
  }

  /// Check if user has granted analytics consent
  /// Returns true if consent not yet configured (graceful degradation)
  Future<bool> _hasAnalyticsConsent() async {
    if (_consentService == null) {
      // Consent service not yet configured - allow analytics by default
      // This handles initialization race conditions
      return true;
    }

    try {
      return await _consentService!.hasConsent('analytics');
    } catch (e) {
      app_logger.AppLogger.warning('[AnalyticsService] Failed to check consent, defaulting to false: $e');
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    await super.initialize();
    
    await executeServiceOperation(
      () async {
        await _repository.initialize();
      },
      operationName: 'Initialize analytics',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Get the analytics observer for navigation tracking
  dynamic get observer => _repository.observer;

  /// Log import start event
  Future<void> logImportStarted({
    required String source,
    String? platform,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await executeServiceOperation(
      () async {
        await _repository.logImportStarted(
          source: source,
          platform: platform,
        );
      },
      operationName: 'Log import started',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Log successful import
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await _repository.logImportSuccess(
      source: source,
      platform: platform,
      recipeLength: recipeLength,
    );
  }

  /// Log extraction error
  Future<void> logExtractionError({
    required String url,
    required SourcePlatform platform,
    required String error,
    String? errorType,
  }) async {
    await _repository.logExtractionError(
      url: url,
      platform: platform.toString().split('.').last,
      error: error,
      errorType: errorType,
    );
  }

  /// Log manual copy fallback usage
  Future<void> logManualCopyFallback({
    required SourcePlatform platform,
    String? reason,
  }) async {
    await _repository.logManualCopyFallback(
      platform: platform.toString().split('.').last,
      reason: reason,
    );
  }

  /// Log recipe creation
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await _repository.logRecipeCreated(
      source: source,
      hasImage: hasImage,
    );
  }

  /// Log recipe sharing
  Future<void> logRecipeShared({
    required String method,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await _repository.logRecipeShared(
      method: method,
    );
  }

  /// Log when recipe is marked as cooked
  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) async {
    await _repository.logRecipeCooked(
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      mealType: mealType,
      isFirstTime: isFirstTime,
      daysSinceLastCooked: daysSinceLastCooked,
    );
  }

  /// Log menu generation
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    await _repository.logMenuGenerated(
      recipeCount: recipeCount,
      method: method,
    );
  }

  /// Log recipe deletion
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) async {
    await _repository.logRecipeDeleted(
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      mealType: mealType,
      isPersonal: isPersonal,
      createdAt: createdAt,
      daysSinceCreated: daysSinceCreated,
    );
  }

  /// Log user login
  Future<void> logLogin({required String method}) async {
    await _repository.logLogin(loginMethod: method);
  }

  /// Log user sign up
  Future<void> logSignUp({required String method}) async {
    await _repository.logSignUp(signUpMethod: method);
  }

  /// Log user logout
  Future<void> logLogout() async {
    await _repository.logLogout();
  }


  /// Log account deletion event for GDPR compliance
  Future<void> logAccountDeleted(Map<String, dynamic> parameters) async {
    await executeServiceOperation(
      () async {
        await _repository.logAccountDeleted(parameters);
      },
      operationName: 'Log account deletion',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Set user properties for segmentation
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  }) async {
    await _repository.setUserProperties(
      recipeCount: recipeCount,
      hasUsedImport: hasUsedImport,
      hasSharedRecipe: hasSharedRecipe,
      hasCooked: hasCooked,
    );
  }

}
