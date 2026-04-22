import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks recipe-related analytics events
class RecipeEventsTracker extends BaseTracker {
  RecipeEventsTracker({required super.repository});

  /// Log recipe creation
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logRecipeCreated(source: source, hasImage: hasImage);
  }

  /// Log recipe sharing
  Future<void> logRecipeShared({required String method}) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logRecipeShared(method: method);
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
      name: 'recipe_viewed',
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
      name: 'recipe_edited',
      parameters: {
        'recipe_id': recipeId,
        if (fieldsChanged != null && fieldsChanged.isNotEmpty)
          'fields_changed': fieldsChanged.join(','),
      },
    );
  }

  /// Log recipe copied
  Future<void> logRecipeCopied({required String recipeId}) async {
    await logEvent(name: 'recipe_copied', parameters: {'recipe_id': recipeId});
  }

  /// Log recipe image uploaded
  Future<void> logRecipeImageUploaded({
    required String recipeId,
    required int imageCount,
    String? uploadSource,
  }) async {
    await logEvent(
      name: 'recipe_image_uploaded',
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
      name: 'recipe_search_performed',
      parameters: {
        'search_query': searchQuery,
        'results_count': resultsCount,
        if (filtersApplied != null && filtersApplied.isNotEmpty)
          'filters_applied': filtersApplied.join(','),
      },
    );
  }
}
