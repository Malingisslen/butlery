import 'package:clock/clock.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks recipe-related analytics events
class RecipeEventsTracker extends BaseTracker {
  RecipeEventsTracker({required super.repository});

  /// Per-install dedupe key for the once-per-user `first_share` milestone.
  /// Suffixed with the user uid so household devices don't cross-fire.
  static const String _firstSharePrefsPrefix = 'sharing_activated_v1_';

  /// Per-install dedupe key for the once-per-user `first_search` milestone
  /// (BUT-588). Same uid-suffix scheme as `_firstSharePrefsPrefix` so two users
  /// on the same device each get their own milestone fire.
  static const String _firstSearchPrefsPrefix = 'search_activated_v1_';

  /// Per-install dedupe key for the once-per-user `first_cook` milestone
  /// (BUT-803 PA11). Cooking is the strongest engagement signal in the app —
  /// time-to-first-cook drops directly into the activation funnel.
  static const String _firstCookPrefsPrefix = 'cooking_activated_v1_';

  /// Log recipe creation
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logRecipeCreated(source: source, hasImage: hasImage);
  }

  /// Log recipe sharing. `recipeId` is sanitized (hashed) by the repository's
  /// PII gate before leaving the device per BUT-421. `recipientCount` is
  /// bucketed locally so we never emit raw fan-out counts that could de-anon
  /// small-group activity.
  Future<void> logRecipeShared({
    required String method,
    String? recipeId,
    int recipientCount = 0,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logEvent(
      name: AnalyticsEvents.recipeShared,
      parameters: {
        'method': method,
        'recipient_count_bucket': _bucketRecipientCount(recipientCount),
        if (recipeId != null && recipeId.isNotEmpty) 'recipe_id': recipeId,
        'timestamp': clock.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Once-per-user `first_share` milestone (BUT-584). Returns true if the
  /// milestone fired (first share), false if skipped (already activated, no
  /// consent, or no userId).
  Future<bool> logFirstShareIfMilestone({
    required String? userId,
    required String shareMethod,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstSharePrefsPrefix,
      eventName: AnalyticsEvents.firstShare,
      userPropertyName: AnalyticsUserProperties.sharingActivated,
      joinedAt: joinedAt,
      extraParams: {'share_method': shareMethod},
    );
  }

  /// Once-per-user `first_search` milestone (BUT-588). Search is a strong
  /// engagement signal — users who search once are more likely to return —
  /// so this milestone gives us time-to-first-search and first-search-in-
  /// session segmentation. `recipeCountAtTime` correlates activation with
  /// library size. BUT-421-compatible: raw query NEVER included.
  Future<bool> logFirstSearchIfMilestone({
    required String? userId,
    required int recipeCountAtTime,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstSearchPrefsPrefix,
      eventName: AnalyticsEvents.firstSearch,
      userPropertyName: AnalyticsUserProperties.searchActivated,
      joinedAt: joinedAt,
      extraParams: {'recipe_count_at_time': recipeCountAtTime},
    );
  }

  /// Once-per-user `first_cook` milestone (BUT-803 PA11). Cooking — pressing
  /// "mark as cooked" — is the strongest activation signal in the app, much
  /// stronger than view/share/search. Time-to-first-cook is the activation
  /// funnel's bottom step. Caller is `logRecipeCooked` callsite (e.g. the
  /// mark-cooked handler in the recipe-detail view-model).
  Future<bool> logFirstCookIfMilestone({
    required String? userId,
    required String mealType,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstCookPrefsPrefix,
      eventName: AnalyticsEvents.firstCook,
      userPropertyName: AnalyticsUserProperties.cookingActivated,
      joinedAt: joinedAt,
      extraParams: {'meal_type': mealType},
    );
  }

  String _bucketRecipientCount(int count) {
    if (count <= 0) return '0';
    if (count == 1) return '1';
    if (count <= 5) return '2-5';
    if (count <= 10) return '6-10';
    if (count <= 50) return '11-50';
    return '51+';
  }

  /// Log when recipe is marked as cooked
  Future<void> logRecipeCooked({
    required String recipeId,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logRecipeCooked(
      recipeId: recipeId,
      mealType: mealType,
      isFirstTime: isFirstTime,
      daysSinceLastCooked: daysSinceLastCooked,
    );
  }

  /// Log recipe deletion
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logRecipeDeleted(
      recipeId: recipeId,
      mealType: mealType,
      isPersonal: isPersonal,
      createdAt: createdAt,
      daysSinceCreated: daysSinceCreated,
    );
  }

  /// Log recipe viewed
  Future<void> logRecipeViewed({
    required String recipeId,
    required String recipeType,
    String? source,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeViewed,
      parameters: {
        'recipe_id': recipeId,
        'recipe_type': recipeType,
        'source': ?source,
      },
    );
  }

  /// Log recipe edited
  Future<void> logRecipeEdited({
    required String recipeId,
    List<String>? fieldsChanged,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeEdited,
      parameters: {
        'recipe_id': recipeId,
        if (fieldsChanged != null && fieldsChanged.isNotEmpty)
          'fields_changed': fieldsChanged.join(','),
      },
    );
  }

  /// Log recipe copied
  Future<void> logRecipeCopied({required String recipeId}) async {
    await logEvent(
      name: AnalyticsEvents.recipeCopied,
      parameters: {'recipe_id': recipeId},
    );
  }

  /// Log recipe image uploaded
  Future<void> logRecipeImageUploaded({
    required String recipeId,
    required int imageCount,
    String? uploadSource,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeImageUploaded,
      parameters: {
        'recipe_id': recipeId,
        'image_count': imageCount,
        'upload_source': ?uploadSource,
      },
    );
  }

  /// Log recipe search performed. The raw `searchQuery` is dropped + bucketed
  /// by the repository's `_sanitize` gate — never leaves the device.
  Future<void> logRecipeSearchPerformed({
    required String searchQuery,
    required int resultsCount,
    List<String>? filtersApplied,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeSearchPerformed,
      parameters: {
        'search_query': searchQuery,
        'results_count': resultsCount,
        if (filtersApplied != null && filtersApplied.isNotEmpty)
          'filters_applied': filtersApplied.join(','),
      },
    );
  }

  /// BUT-802 HIGH-PA4: cooking-mode session started — fires when the user
  /// enters the cooking screen for a recipe. `sessionId` is generated by the
  /// viewmodel and reused across the matching step/completed/abandoned events
  /// so funnels can group by session.
  Future<void> logCookingSessionStarted({
    required String recipeId,
    required String sessionId,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cookingSessionStarted,
      parameters: {
        'recipe_id': recipeId,
        'session_id': sessionId,
        'started_at': clock.now().toUtc().toIso8601String(),
      },
    );
  }

  /// BUT-802 HIGH-PA4: cooking-mode step navigation — emitted on every
  /// next/previous/goToStep transition. `from_step` and `to_step` are
  /// 0-based to match the viewmodel's `_currentStepIndex` semantics.
  Future<void> logCookingStepAdvanced({
    required String recipeId,
    required String sessionId,
    required int fromStep,
    required int toStep,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cookingStepAdvanced,
      parameters: {
        'recipe_id': recipeId,
        'session_id': sessionId,
        'from_step': fromStep,
        'to_step': toStep,
      },
    );
  }

  /// BUT-802 HIGH-PA4: cooking-mode completed — viewmodel reached the last
  /// instruction step before exiting. `steps_viewed` counts distinct steps the
  /// user navigated to (set-based, so revisits don't inflate the count).
  Future<void> logCookingSessionCompleted({
    required String recipeId,
    required String sessionId,
    required int durationSec,
    required int stepsViewed,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cookingSessionCompleted,
      parameters: {
        'recipe_id': recipeId,
        'session_id': sessionId,
        'duration_sec': durationSec,
        'steps_viewed': stepsViewed,
      },
    );
  }

  /// BUT-802 HIGH-PA4: cooking-mode abandoned — viewmodel exited before
  /// reaching the last step. `last_step` is the 0-based step the user was on
  /// when they left, which lets us identify drop-off hotspots.
  Future<void> logCookingSessionAbandoned({
    required String recipeId,
    required String sessionId,
    required int durationSec,
    required int lastStep,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cookingSessionAbandoned,
      parameters: {
        'recipe_id': recipeId,
        'session_id': sessionId,
        'duration_sec': durationSec,
        'last_step': lastStep,
      },
    );
  }
}
