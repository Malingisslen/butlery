/// Analytics service facade for tracking user interactions and app metrics

import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/trackers.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Analytics service facade that delegates to specialized tracker modules.
/// **GDPR Compliance**: Checks user consent before logging analytics events
/// as required by GDPR Article 7. Auth/security events (login, logout, account
/// deletion) are exempt from consent requirements as they are necessary for
/// service operation.
class AnalyticsService extends BaseService {
  final AnalyticsRepository _repository;
  ConsentService? _consentService;

  // Tracker modules
  late final RecipeEventsTracker _recipeTracker;
  late final MenuEventsTracker _menuTracker;
  late final ShoppingEventsTracker _shoppingTracker;
  late final SocialEventsTracker _socialTracker;
  late final ImportEventsTracker _importTracker;
  late final SystemEventsTracker _systemTracker;

  AnalyticsService({required AnalyticsRepository repository})
      : _repository = repository {
    _recipeTracker = RecipeEventsTracker(repository: _repository);
    _menuTracker = MenuEventsTracker(repository: _repository);
    _shoppingTracker = ShoppingEventsTracker(repository: _repository);
    _socialTracker = SocialEventsTracker(repository: _repository);
    _importTracker = ImportEventsTracker(
      repository: _repository,
      parentService: this,
    );
    _systemTracker = SystemEventsTracker(
      repository: _repository,
      parentService: this,
    );
  }

  @override
  String get serviceName => 'AnalyticsService';

  // Tracker accessors for modular usage
  RecipeEventsTracker get recipe => _recipeTracker;
  MenuEventsTracker get menu => _menuTracker;
  ShoppingEventsTracker get shopping => _shoppingTracker;
  SocialEventsTracker get social => _socialTracker;
  ImportEventsTracker get import => _importTracker;
  SystemEventsTracker get system => _systemTracker;

  /// Set consent service for GDPR compliance checking
  void setConsentService(ConsentService consentService) {
    _consentService = consentService;
    _recipeTracker.setConsentService(consentService);
    _menuTracker.setConsentService(consentService);
    _shoppingTracker.setConsentService(consentService);
    _socialTracker.setConsentService(consentService);
    _importTracker.setConsentService(consentService);
    _systemTracker.setConsentService(consentService);
    app_logger.AppLogger.info(
      '[AnalyticsService] Consent service configured for GDPR compliance',
    );
  }

  Future<bool> _hasAnalyticsConsent() async {
    if (_consentService == null) return true;
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
      () async => await _repository.initialize(),
      operationName: 'Initialize analytics',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Get the analytics observer for navigation tracking
  dynamic get observer => _repository.observer;

  // Auth events (exempt from consent - necessary for service operation)

  Future<void> logLogin({required String method}) async {
    await _repository.logLogin(loginMethod: method);
  }

  Future<void> logSignUp({required String method}) async {
    await _repository.logSignUp(signUpMethod: method);
  }

  Future<void> logLogout() async {
    await _repository.logLogout();
  }

  Future<void> logAccountDeleted(Map<String, dynamic> parameters) async {
    await executeServiceOperation(
      () async => await _repository.logAccountDeleted(parameters),
      operationName: 'Log account deletion',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  // Generic event methods

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

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!await _hasAnalyticsConsent()) return;
    await executeServiceOperation(
      () async => await _repository.logEvent(name: name, parameters: parameters),
      operationName: 'Log event: $name',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  Future<void> logScreenView({
    required String screenName,
    Map<String, Object>? parameters,
  }) async {
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

  // Delegate methods for backward compatibility

  Future<void> logImportStarted({required String source, String? platform}) =>
      _importTracker.logImportStarted(source: source, platform: platform);

  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
  }) => _importTracker.logImportSuccess(
    source: source,
    platform: platform,
    recipeLength: recipeLength,
  );

  Future<void> logExtractionError({
    required String url,
    required SourcePlatform platform,
    required String error,
    String? errorType,
  }) => _importTracker.logExtractionError(
    url: url,
    platform: platform,
    error: error,
    errorType: errorType,
  );

  Future<void> logManualCopyFallback({
    required SourcePlatform platform,
    String? reason,
  }) => _importTracker.logManualCopyFallback(platform: platform, reason: reason);

  Future<void> logRecipeCreated({required String source, bool hasImage = false}) =>
      _recipeTracker.logRecipeCreated(source: source, hasImage: hasImage);

  Future<void> logRecipeShared({required String method}) =>
      _recipeTracker.logRecipeShared(method: method);

  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) => _recipeTracker.logRecipeCooked(
    recipeId: recipeId,
    recipeTitle: recipeTitle,
    mealType: mealType,
    isFirstTime: isFirstTime,
    daysSinceLastCooked: daysSinceLastCooked,
  );

  Future<void> logRecipeDeleted({
    required String recipeId,
    required String recipeTitle,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) => _recipeTracker.logRecipeDeleted(
    recipeId: recipeId,
    recipeTitle: recipeTitle,
    mealType: mealType,
    isPersonal: isPersonal,
    createdAt: createdAt,
    daysSinceCreated: daysSinceCreated,
  );

  Future<void> logRecipeViewed({
    required String recipeId,
    required String recipeType,
    String? source,
  }) => _recipeTracker.logRecipeViewed(
    recipeId: recipeId,
    recipeType: recipeType,
    source: source,
  );

  Future<void> logRecipeEdited({
    required String recipeId,
    List<String>? fieldsChanged,
  }) => _recipeTracker.logRecipeEdited(
    recipeId: recipeId,
    fieldsChanged: fieldsChanged,
  );

  Future<void> logRecipeCopied({required String recipeId}) =>
      _recipeTracker.logRecipeCopied(recipeId: recipeId);

  Future<void> logRecipeImageUploaded({
    required String recipeId,
    required int imageCount,
    String? uploadSource,
  }) => _recipeTracker.logRecipeImageUploaded(
    recipeId: recipeId,
    imageCount: imageCount,
    uploadSource: uploadSource,
  );

  Future<void> logRecipeSearchPerformed({
    required String searchQuery,
    required int resultsCount,
    List<String>? filtersApplied,
  }) => _recipeTracker.logRecipeSearchPerformed(
    searchQuery: searchQuery,
    resultsCount: resultsCount,
    filtersApplied: filtersApplied,
  );

  Future<void> logMenuGenerated({required int recipeCount, required String method}) =>
      _menuTracker.logMenuGenerated(recipeCount: recipeCount, method: method);

  Future<void> logMenuGenerationStarted({int? promptLength}) =>
      _menuTracker.logMenuGenerationStarted(promptLength: promptLength);

  Future<void> logMenuGenerationFailed({
    required String errorCode,
    String? errorMessage,
  }) => _menuTracker.logMenuGenerationFailed(
    errorCode: errorCode,
    errorMessage: errorMessage,
  );

  Future<void> logMenuSaved({
    required String menuId,
    required int recipeCount,
    bool isShared = false,
  }) => _menuTracker.logMenuSaved(
    menuId: menuId,
    recipeCount: recipeCount,
    isShared: isShared,
  );

  Future<void> logMenuLoaded({required String menuId, bool isOwned = true}) =>
      _menuTracker.logMenuLoaded(menuId: menuId, isOwned: isOwned);

  Future<void> logMenuShared({
    required String menuId,
    required int recipientCount,
    String? shareMethod,
  }) => _menuTracker.logMenuShared(
    menuId: menuId,
    recipientCount: recipientCount,
    shareMethod: shareMethod,
  );

  Future<void> logMenuDeleted({required String menuId, String? reason}) =>
      _menuTracker.logMenuDeleted(menuId: menuId, reason: reason);

  Future<void> logShoppingListCreated({
    required String listId,
    required String listType,
    int? initialItemCount,
  }) => _shoppingTracker.logShoppingListCreated(
    listId: listId,
    listType: listType,
    initialItemCount: initialItemCount,
  );

  Future<void> logShoppingListItemAdded({required String listId, String? source}) =>
      _shoppingTracker.logShoppingListItemAdded(listId: listId, source: source);

  Future<void> logShoppingListItemChecked({
    required String listId,
    required int itemCount,
  }) => _shoppingTracker.logShoppingListItemChecked(
    listId: listId,
    itemCount: itemCount,
  );

  Future<void> logShoppingListShared({
    required String listId,
    required int recipientCount,
    String? shareMethod,
  }) => _shoppingTracker.logShoppingListShared(
    listId: listId,
    recipientCount: recipientCount,
    shareMethod: shareMethod,
  );

  Future<void> logShoppingListCompleted({
    required String listId,
    required int itemCount,
    int? timeToCompleteMinutes,
  }) => _shoppingTracker.logShoppingListCompleted(
    listId: listId,
    itemCount: itemCount,
    timeToCompleteMinutes: timeToCompleteMinutes,
  );

  Future<void> logFriendRequestSent({required String recipientId, String? source}) =>
      _socialTracker.logFriendRequestSent(recipientId: recipientId, source: source);

  Future<void> logFriendRequestAccepted({required String senderId}) =>
      _socialTracker.logFriendRequestAccepted(senderId: senderId);

  Future<void> logCommentCreated({
    required String recipeId,
    required int commentLength,
  }) => _socialTracker.logCommentCreated(
    recipeId: recipeId,
    commentLength: commentLength,
  );

  Future<void> logRecipeRated({
    required String recipeId,
    required int rating,
    int? previousRating,
  }) => _socialTracker.logRecipeRated(
    recipeId: recipeId,
    rating: rating,
    previousRating: previousRating,
  );

  Future<void> logErrorOccurred({
    required String errorCode,
    required String errorType,
    String? userAction,
    String? stackTrace,
  }) => _systemTracker.logErrorOccurred(
    errorCode: errorCode,
    errorType: errorType,
    userAction: userAction,
    stackTrace: stackTrace,
  );

  Future<void> logNetworkError({
    required String endpoint,
    required int statusCode,
    String? errorMessage,
  }) => _systemTracker.logNetworkError(
    endpoint: endpoint,
    statusCode: statusCode,
    errorMessage: errorMessage,
  );

  Future<void> logSlowOperation({
    required String operationName,
    required int durationMs,
    int? thresholdMs,
  }) => _systemTracker.logSlowOperation(
    operationName: operationName,
    durationMs: durationMs,
    thresholdMs: thresholdMs,
  );
}
