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

  /// Set whether analytics collection is enabled
  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  /// Log import start event
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
  });

  /// Log successful import
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
  });

  /// Log extraction error
  Future<void> logExtractionError({
    required String url,
    required String platform,
    required String error,
    String? errorType,
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
}
