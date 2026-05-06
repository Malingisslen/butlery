import 'dart:ui' show Locale;

import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

/// Analytics repository interface for abstracting analytics operations.
/// This interface provides a contract for analytics implementations, enabling
/// dependency injection and testability while maintaining flexibility to switch
/// between different analytics providers (Firebase Analytics, custom analytics, etc.).
/// The repository pattern abstracts the underlying analytics implementation,
/// allowing services to depend on this interface rather than concrete Firebase
/// classes, which significantly improves testability and maintainability.
abstract class AnalyticsRepository {
  /// Initialize the analytics system
  Future<void> initialize();

  /// Get the analytics observer for navigation tracking
  /// Returns null if not supported by the implementation
  dynamic get observer;

  /// BUT-786: install/refresh the per-session UUID that gets merged into
  /// every emitted event's `session_id` parameter. Pass `null` to clear.
  /// Caller responsibility — `main.dart` generates one on cold start and on
  /// resume-after-long-background.
  void setSessionId(String? sessionId);

  /// Current session id if installed; `null` until `setSessionId` runs.
  /// Exposed for diagnostics and the `app_open` event so callers can attach
  /// the same id at the boundary.
  String? get currentSessionId;

  /// Log a custom event with optional parameters
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  /// Log user login event
  Future<void> logLogin({required String loginMethod});

  /// Log user sign up event
  Future<void> logSignUp({required String signUpMethod});

  /// Log user logout event
  Future<void> logLogout();

  /// Set user property for segmentation
  Future<void> setUserProperty({
    required String name,
    required String? value,
  });

  /// BUT-803 (PA5): tie subsequent events to a user across devices.
  /// Pass `null` on sign-out to reset. Implementations should be a thin
  /// passthrough to the analytics SDK's `setUserId`.
  Future<void> setUserId(String? userId);

  /// Set whether analytics collection is enabled
  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  /// Log import start event
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
    String imageFormat,
  });

  /// Log successful import
  ///
  /// [imageFormat] / [imageFormatSent] (BUT-662): for the photo OCR path,
  /// `imageFormat` is the original magic-byte-detected format and
  /// `imageFormatSent` is the format actually delivered to OCR. Both
  /// default to `'unknown'` for non-photo import paths.
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
    String imageFormat,
    String imageFormatSent,
  });

  /// Log extraction error
  Future<void> logExtractionError({
    required String url,
    required String platform,
    required String error,
    String? errorType,
    String imageFormat,
  });

  /// Log manual copy fallback usage
  Future<void> logManualCopyFallback({
    required String platform,
    String? reason,
  });

  /// Log recipe creation
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  });

  /// Log recipe sharing
  Future<void> logRecipeShared({
    required String method,
  });

  /// Log when recipe is marked as cooked
  Future<void> logRecipeCooked({
    required String recipeId,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  });

  /// Log menu generation
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  });

  /// Log recipe deletion
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  });

  /// Log account deletion event for GDPR compliance
  Future<void> logAccountDeleted(Map<String, dynamic> parameters);

  /// Set multiple user properties at once
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  });

  /// Emit the `language` user property from a [Locale] (BUT-636).
  /// Only [Locale.languageCode] is sent — region (e.g. `sv_FI`) is dropped
  /// to keep cardinality low and avoid leaking finer-grained device locale.
  Future<void> setLanguageUserProperty(Locale locale);

  /// Emit the `platform` user property (BUT-637).
  /// Value is one of `ios | android | macos | windows | linux | web`.
  /// Caller-free: the implementation reads `defaultTargetPlatform` + `kIsWeb`.
  Future<void> setPlatformUserProperty();

  /// Emit the `lifecycle_stage` user property (BUT-639).
  Future<void> setLifecycleStage(LifecycleStage stage);
}
