/// No-op analytics repository for web platform where Firebase Analytics is not supported.
/// This implementation provides a null object pattern for analytics operations,
/// allowing the app to function on web without Firebase Analytics dependency.
/// All methods complete successfully but perform no actual analytics tracking.
/// **Use Case**: Registered on web platform (`kIsWeb`) to replace FirebaseAnalyticsRepository

import 'dart:ui' show Locale;

import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

/// No-operation analytics repository for platforms without analytics support.
class NoOpAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<void> initialize() async {
    // No-op: Analytics not supported
  }

  @override
  dynamic get observer => null;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logLogin({required String loginMethod}) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logSignUp({required String signUpMethod}) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logLogout() async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logExtractionError({
    required String url,
    required String platform,
    required String error,
    String? errorType,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logManualCopyFallback({
    required String platform,
    String? reason,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logRecipeShared({
    required String method,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logRecipeCooked({
    required String recipeId,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> logAccountDeleted(Map<String, dynamic> parameters) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  }) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setLanguageUserProperty(Locale locale) async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setPlatformUserProperty() async {
    // No-op: Analytics not supported
  }

  @override
  Future<void> setLifecycleStage(LifecycleStage stage) async {
    // No-op: Analytics not supported
  }
}
