// lib/services/search/recipe_search_router.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

/// Routes recipe text search to Algolia when credentials are configured,
/// falling back to the Firestore client-side filter (200-cap) otherwise.
///
/// BUT-475: the legacy `RecipeRepository.searchRecipes` does
/// `getCollectionForUser(userId).orderBy(updatedAt).limit(200)` and filters
/// titles client-side. Users with > 200 recipes silently miss matches in the
/// older tail. Algolia removes the cap entirely (server-side index covers
/// the full corpus), so when an Algolia client is available we route
/// through it and convert hits back to `Recipe` for caller compatibility.
///
/// The decision is checked at call time — the underlying `SearchRepository`
/// in DI is already a `_DelegatingSearchRepository` that flips between
/// Algolia and Firestore based on the `enable_algolia_search` feature flag,
/// so we just inspect whether the live delegate is Algolia.
///
/// Setting the `has_algolia_search` user property is performed once per
/// process — it costs an Analytics call, not a Firestore write.
class RecipeSearchRouter {
  final RecipeRepository _recipeRepository;
  final SearchRepository _searchRepository;
  final AnalyticsService? _analytics;
  final FeatureFlagService? _featureFlags;

  /// Set after the first `searchRecipes` call so we don't re-fire the user
  /// property on every keystroke.
  bool _userPropertyEmitted = false;

  RecipeSearchRouter({
    required RecipeRepository recipeRepository,
    required SearchRepository searchRepository,
    AnalyticsService? analytics,
    FeatureFlagService? featureFlags,
  })  : _recipeRepository = recipeRepository,
        _searchRepository = searchRepository,
        _analytics = analytics,
        _featureFlags = featureFlags;

  /// Search recipes by title. Returns up to 200 hits (the search interface
  /// page size) when routing to Algolia, or up to 200 from Firestore in
  /// fallback mode. Empty queries short-circuit and never hit either repo.
  Future<List<Recipe>> searchRecipes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <Recipe>[];

    final useAlgolia = _algoliaActive();

    // First-call user property — fire-and-forget, never blocks the search.
    if (!_userPropertyEmitted) {
      _userPropertyEmitted = true;
      _setUserPropertyHasAlgoliaSearch(useAlgolia);
    }

    if (useAlgolia) {
      try {
        final hits = await _searchRepository.searchRecipes(
          trimmed,
          hitsPerPage: 200,
        );
        // Convert search hits to Recipe shells. Callers that need the full
        // Recipe doc still hydrate via the repository on selection — the
        // hit covers what the list view needs (title/description/image/etc).
        return hits.hits.map((hit) => hit.toRecipe()).toList();
      } catch (e, st) {
        AppLogger.warning(
          'RecipeSearchRouter: Algolia search failed, falling back to Firestore: $e',
        );
        AppLogger.debug('Stack: $st');
        return await _recipeRepository.searchRecipes(trimmed);
      }
    }

    return await _recipeRepository.searchRecipes(trimmed);
  }

  /// Whether routing should go through the external search provider.
  ///
  /// Honors `enable_algolia_search` as a runtime kill-switch (operator can
  /// flip the flag off via Remote Config) AND defers the per-provider
  /// detection to [SearchRepository.usesExternalSearch] — `SearchModule` is
  /// still the canonical place that flips creds + delegate; we just observe.
  bool _algoliaActive() {
    final flagOn =
        _featureFlags?.isEnabled(FeatureFlags.enableAlgoliaSearch) ?? false;
    if (!flagOn) return false;
    return _searchRepository.usesExternalSearch;
  }

  Future<void> _setUserPropertyHasAlgoliaSearch(bool active) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setUserProperty(
        name: AnalyticsUserProperties.hasAlgoliaSearch,
        value: active ? 'true' : 'false',
      );
    } catch (e) {
      AppLogger.debug('RecipeSearchRouter: setUserProperty failed: $e');
    }
  }
}
