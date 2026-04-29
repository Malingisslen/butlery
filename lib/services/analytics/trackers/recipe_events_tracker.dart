import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks recipe-related analytics events
class RecipeEventsTracker extends BaseTracker {
  RecipeEventsTracker({required super.repository});

  /// Per-install dedupe key for the once-per-user `first_share` milestone.
  /// Suffixed with the user uid so household devices don't cross-fire.
  static const String _firstSharePrefsPrefix = 'sharing_activated_v1_';

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
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Once-per-user `first_share` milestone (BUT-584). Dedupes via a
  /// SharedPreferences flag keyed by uid — survives app restarts, doesn't
  /// require a Firestore write. If [joinedAt] is null we omit the field
  /// rather than emit a guessed value.
  ///
  /// Returns true if the milestone fired (first share), false if skipped
  /// (already activated, no consent, or no userId).
  Future<bool> logFirstShareIfMilestone({
    required String? userId,
    required String shareMethod,
    DateTime? joinedAt,
  }) async {
    if (userId == null || userId.isEmpty) return false;
    if (!await hasAnalyticsConsent()) return false;

    final prefs = await _tryGetPrefs();
    if (prefs == null) return false;

    final key = '$_firstSharePrefsPrefix$userId';
    if (prefs.getBool(key) == true) return false;

    final params = <String, Object>{
      'share_method': shareMethod,
    };
    if (joinedAt != null) {
      params['minutes_since_signup'] =
          DateTime.now().difference(joinedAt).inMinutes;
    }

    await repository.logEvent(
        name: AnalyticsEvents.firstShare, parameters: params);
    await repository.setUserProperty(
      name: AnalyticsUserProperties.sharingActivated,
      value: 'true',
    );
    await prefs.setBool(key, true);
    return true;
  }

  Future<SharedPreferences?> _tryGetPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning(
        'first_share milestone: SharedPreferences unavailable ($e); skipping',
      );
      return null;
    }
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
        if (source != null) 'source': source,
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
        parameters: {'recipe_id': recipeId});
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
        if (uploadSource != null) 'upload_source': uploadSource,
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
}
