/// Analytics service for tracking user interactions and app metrics

import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

/// Analytics service that delegates to an AnalyticsRepository implementation.
///
/// This service now uses dependency injection for better testability while
/// maintaining the singleton pattern and existing API. The repository pattern
/// allows for easy mocking in tests and switching between different analytics
/// providers if needed.
class AnalyticsService extends BaseService with SingletonServiceMixin<AnalyticsService> {
  final AnalyticsRepository _repository;
  
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
    await _repository.logRecipeCreated(
      source: source,
      hasImage: hasImage,
    );
  }

  /// Log recipe sharing
  Future<void> logRecipeShared({
    required String method,
  }) async {
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
