/// Analytics service for tracking user interactions and app metrics

import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Analytics service that delegates to an AnalyticsRepository implementation.
/// This service now uses dependency injection for better testability while
/// maintaining the singleton pattern and existing API. The repository pattern
/// allows for easy mocking in tests and switching between different analytics
/// providers if needed.
/// **GDPR Compliance**: This service checks user consent before logging analytics
/// events as required by GDPR Article 7. Key methods include consent checks via
/// `_hasAnalyticsConsent()`. Auth/security events (login, logout, account deletion)
/// are exempt from consent requirements as they are necessary for service operation.
class AnalyticsService extends BaseService {
  final AnalyticsRepository _repository;
  ConsentService? _consentService;

  AnalyticsService({required AnalyticsRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'AnalyticsService';

  /// Set consent service for GDPR compliance checking
  /// This should be called after ConsentService is initialized
  void setConsentService(ConsentService consentService) {
    _consentService = consentService;
    app_logger.AppLogger.info(
      '[AnalyticsService] Consent service configured for GDPR compliance',
    );
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
      app_logger.AppLogger.warning(
        '[AnalyticsService] Failed to check consent, defaulting to false: $e',
      );
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
        await _repository.logImportStarted(source: source, platform: platform);
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

    await _repository.logRecipeCreated(source: source, hasImage: hasImage);
  }

  /// Log recipe sharing
  Future<void> logRecipeShared({required String method}) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await _repository.logRecipeShared(method: method);
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

  // ===== STANDARDIZED EVENT METHODS (Analytics Strategy Document) =====

  /// Log a generic event with parameters
  /// Use this for custom events not covered by specific methods
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await executeServiceOperation(
      () async {
        await _repository.logEvent(name: name, parameters: parameters);
      },
      operationName: 'Log event: $name',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Log screen view for navigation tracking
  Future<void> logScreenView({
    required String screenName,
    Map<String, Object>? parameters,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await executeServiceOperation(
      () async {
        await _repository.logEvent(
          name: 'screen_viewed',
          parameters: {'screen_name': screenName, ...?parameters},
        );
      },
      operationName: 'Log screen view',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  // ===== RECIPE EVENTS =====

  /// Log recipe viewed (standardized event)
  Future<void> logRecipeViewed({
    required String recipeId,
    required String recipeType,
    String? source,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'recipe_viewed',
      parameters: {
        'recipe_id': recipeId,
        'recipe_type': recipeType,
        if (source != null) 'source': source,
      },
    );
  }

  /// Log recipe edited (standardized event)
  Future<void> logRecipeEdited({
    required String recipeId,
    List<String>? fieldsChanged,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'recipe_edited',
      parameters: {
        'recipe_id': recipeId,
        if (fieldsChanged != null && fieldsChanged.isNotEmpty)
          'fields_changed': fieldsChanged.join(','),
      },
    );
  }

  /// Log recipe copied (standardized event)
  Future<void> logRecipeCopied({required String recipeId}) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(name: 'recipe_copied', parameters: {'recipe_id': recipeId});
  }

  /// Log recipe image uploaded (standardized event)
  Future<void> logRecipeImageUploaded({
    required String recipeId,
    required int imageCount,
    String? uploadSource,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'recipe_image_uploaded',
      parameters: {
        'recipe_id': recipeId,
        'image_count': imageCount,
        if (uploadSource != null) 'upload_source': uploadSource,
      },
    );
  }

  /// Log recipe search performed (standardized event)
  Future<void> logRecipeSearchPerformed({
    required String searchQuery,
    required int resultsCount,
    List<String>? filtersApplied,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'recipe_search_performed',
      parameters: {
        'search_query': searchQuery,
        'results_count': resultsCount,
        if (filtersApplied != null && filtersApplied.isNotEmpty)
          'filters_applied': filtersApplied.join(','),
      },
    );
  }

  // ===== MENU EVENTS =====

  /// Log menu generation started (standardized event)
  Future<void> logMenuGenerationStarted({int? promptLength}) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'menu_generation_started',
      parameters: {if (promptLength != null) 'prompt_length': promptLength},
    );
  }

  /// Log menu generation failed (standardized event)
  Future<void> logMenuGenerationFailed({
    required String errorCode,
    String? errorMessage,
  }) async {
    // Error events exempt from consent check (service operation tracking)
    await logEvent(
      name: 'menu_generation_failed',
      parameters: {
        'error_code': errorCode,
        if (errorMessage != null) 'error_message': errorMessage,
      },
    );
  }

  /// Log menu saved (standardized event)
  Future<void> logMenuSaved({
    required String menuId,
    required int recipeCount,
    bool isShared = false,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'menu_saved',
      parameters: {
        'menu_id': menuId,
        'recipe_count': recipeCount,
        'is_shared': isShared,
      },
    );
  }

  /// Log menu loaded (standardized event)
  Future<void> logMenuLoaded({
    required String menuId,
    bool isOwned = true,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'menu_loaded',
      parameters: {'menu_id': menuId, 'is_owned': isOwned},
    );
  }

  /// Log menu shared (standardized event)
  Future<void> logMenuShared({
    required String menuId,
    required int recipientCount,
    String? shareMethod,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'menu_shared',
      parameters: {
        'menu_id': menuId,
        'recipient_count': recipientCount,
        if (shareMethod != null) 'share_method': shareMethod,
      },
    );
  }

  /// Log menu deleted (standardized event)
  Future<void> logMenuDeleted({required String menuId, String? reason}) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'menu_deleted',
      parameters: {'menu_id': menuId, if (reason != null) 'reason': reason},
    );
  }

  // ===== SHOPPING LIST EVENTS =====

  /// Log shopping list created (standardized event)
  Future<void> logShoppingListCreated({
    required String listId,
    required String listType,
    int? initialItemCount,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'shopping_list_created',
      parameters: {
        'list_id': listId,
        'list_type': listType,
        if (initialItemCount != null) 'initial_item_count': initialItemCount,
      },
    );
  }

  /// Log shopping list item added (standardized event)
  Future<void> logShoppingListItemAdded({
    required String listId,
    String? source,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'shopping_list_item_added',
      parameters: {'list_id': listId, if (source != null) 'source': source},
    );
  }

  /// Log shopping list item checked (standardized event)
  Future<void> logShoppingListItemChecked({
    required String listId,
    required int itemCount,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'shopping_list_item_checked',
      parameters: {'list_id': listId, 'item_count': itemCount},
    );
  }

  /// Log shopping list shared (standardized event)
  Future<void> logShoppingListShared({
    required String listId,
    required int recipientCount,
    String? shareMethod,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'shopping_list_shared',
      parameters: {
        'list_id': listId,
        'recipient_count': recipientCount,
        if (shareMethod != null) 'share_method': shareMethod,
      },
    );
  }

  /// Log shopping list completed (standardized event)
  Future<void> logShoppingListCompleted({
    required String listId,
    required int itemCount,
    int? timeToCompleteMinutes,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'shopping_list_completed',
      parameters: {
        'list_id': listId,
        'item_count': itemCount,
        if (timeToCompleteMinutes != null)
          'time_to_complete_minutes': timeToCompleteMinutes,
      },
    );
  }

  // ===== SOCIAL EVENTS =====

  /// Log friend request sent (standardized event)
  Future<void> logFriendRequestSent({
    required String recipientId,
    String? source,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'friend_request_sent',
      parameters: {
        'recipient_id': recipientId,
        if (source != null) 'source': source,
      },
    );
  }

  /// Log friend request accepted (standardized event)
  Future<void> logFriendRequestAccepted({required String senderId}) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'friend_request_accepted',
      parameters: {'sender_id': senderId},
    );
  }

  /// Log comment created (standardized event)
  Future<void> logCommentCreated({
    required String recipeId,
    required int commentLength,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'comment_created',
      parameters: {'recipe_id': recipeId, 'comment_length': commentLength},
    );
  }

  /// Log recipe rated (standardized event)
  Future<void> logRecipeRated({
    required String recipeId,
    required int rating,
    int? previousRating,
  }) async {
    // GDPR: Check analytics consent before logging
    if (!await _hasAnalyticsConsent()) return;

    await logEvent(
      name: 'recipe_rated',
      parameters: {
        'recipe_id': recipeId,
        'rating': rating,
        if (previousRating != null) 'previous_rating': previousRating,
      },
    );
  }

  // ===== ERROR & PERFORMANCE EVENTS =====

  /// Log error occurred (standardized event)
  /// Error events exempt from consent check (service operation tracking)
  Future<void> logErrorOccurred({
    required String errorCode,
    required String errorType,
    String? userAction,
    String? stackTrace,
  }) async {
    await executeServiceOperation(
      () async {
        await _repository.logEvent(
          name: 'error_occurred',
          parameters: {
            'error_code': errorCode,
            'error_type': errorType,
            if (userAction != null) 'user_action': userAction,
            if (stackTrace != null)
              'stack_trace': stackTrace.substring(
                0,
                stackTrace.length > 500 ? 500 : stackTrace.length,
              ),
          },
        );
      },
      operationName: 'Log error',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Log network error (standardized event)
  /// Error events exempt from consent check (service operation tracking)
  Future<void> logNetworkError({
    required String endpoint,
    required int statusCode,
    String? errorMessage,
  }) async {
    await logEvent(
      name: 'network_error',
      parameters: {
        'endpoint': endpoint,
        'status_code': statusCode,
        if (errorMessage != null) 'error_message': errorMessage,
      },
    );
  }

  /// Log slow operation (standardized event)
  /// Performance events exempt from consent check (service operation tracking)
  Future<void> logSlowOperation({
    required String operationName,
    required int durationMs,
    int? thresholdMs,
  }) async {
    await logEvent(
      name: 'slow_operation',
      parameters: {
        'operation_name': operationName,
        'duration_ms': durationMs,
        if (thresholdMs != null) 'threshold_ms': thresholdMs,
      },
    );
  }
}
