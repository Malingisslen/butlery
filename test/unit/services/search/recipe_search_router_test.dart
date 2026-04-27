/// Unit tests for [RecipeSearchRouter] (BUT-475).
///
/// Verifies:
///   - With Algolia delegate active, search routes through SearchRepository
///   - Without Algolia delegate, search falls back to RecipeRepository
///   - Empty/whitespace queries hit neither repository
///   - `has_algolia_search` user property fires once, with correct value
///   - Algolia failure falls back to Firestore search (no swallow)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/algolia/algolia_search_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/search/recipe_search_router.dart';

import '../../../test_support/base_unit_test.dart';

class _MockRecipeRepo extends Mock implements RecipeRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _MockAlgolia extends Mock implements AlgoliaSearchRepository {
  @override
  bool get usesExternalSearch => true;
}

class _MockFirestoreSearch extends Mock implements SearchRepository {
  @override
  bool get usesExternalSearch => false;
}

/// Mimics the production `_DelegatingSearchRepository` proxy that holds a
/// mutable delegate — exposes `delegate` so the router can unwrap.
class _DelegatingProxy implements SearchRepository {
  SearchRepository delegate;
  _DelegatingProxy(this.delegate);

  @override
  bool get usesExternalSearch => delegate.usesExternalSearch;

  @override
  Future<SearchResult<RecipeSearchHit>> searchRecipes(String query,
          {SearchFilters? filters, int page = 0, int hitsPerPage = 20}) =>
      delegate.searchRecipes(query,
          filters: filters, page: page, hitsPerPage: hitsPerPage);

  @override
  Future<SearchResult<UserSearchHit>> searchUsers(String query,
          {int page = 0, int hitsPerPage = 20}) =>
      delegate.searchUsers(query, page: page, hitsPerPage: hitsPerPage);

  @override
  Future<void> indexRecipe(Recipe recipe, {required String ownerId}) =>
      delegate.indexRecipe(recipe, ownerId: ownerId);

  @override
  Future<void> removeRecipe(String recipeId) => delegate.removeRecipe(recipeId);

  @override
  Future<void> indexUser(UserSearchData user) => delegate.indexUser(user);

  @override
  Future<void> removeUser(String userId) => delegate.removeUser(userId);

  @override
  Future<void> batchIndexRecipes(List<Recipe> recipes,
          {required String ownerId}) =>
      delegate.batchIndexRecipes(recipes, ownerId: ownerId);

  @override
  Future<List<String>> getSuggestions(String partial,
          {String index = 'recipes', int limit = 5}) =>
      delegate.getSuggestions(partial, index: index, limit: limit);

  @override
  Future<bool> healthCheck() => delegate.healthCheck();
}

void main() {
  group('RecipeSearchRouter (BUT-475)', () {
    late _MockRecipeRepo recipeRepo;
    late _MockAnalytics analytics;
    late _MockFeatureFlags flags;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      recipeRepo = _MockRecipeRepo();
      analytics = _MockAnalytics();
      flags = _MockFeatureFlags();

      when(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      when(() => recipeRepo.searchRecipes(any()))
          .thenAnswer((_) async => const <Recipe>[]);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('routes through Algolia when delegate is Algolia + flag on', () async {
      final algolia = _MockAlgolia();
      final proxy = _DelegatingProxy(algolia);

      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(true);
      when(() => algolia.searchRecipes(any(),
              filters: any(named: 'filters'),
              page: any(named: 'page'),
              hitsPerPage: any(named: 'hitsPerPage')))
          .thenAnswer((_) async => const SearchResult<RecipeSearchHit>(
                hits: [],
                totalHits: 0,
                page: 0,
                totalPages: 0,
                processingTimeMs: 1,
              ));

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');

      verify(() => algolia.searchRecipes('pasta',
          filters: any(named: 'filters'),
          page: any(named: 'page'),
          hitsPerPage: any(named: 'hitsPerPage'))).called(1);
      verifyNever(() => recipeRepo.searchRecipes(any()));
    });

    test('falls back to RecipeRepository when delegate is Firestore', () async {
      final firestore = _MockFirestoreSearch();
      final proxy = _DelegatingProxy(firestore);

      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(true); // Flag on, but delegate is non-Algolia.

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');

      verify(() => recipeRepo.searchRecipes('pasta')).called(1);
      verifyNever(() => firestore.searchRecipes(any(),
          filters: any(named: 'filters'),
          page: any(named: 'page'),
          hitsPerPage: any(named: 'hitsPerPage')));
    });

    test('falls back to Firestore when feature flag is OFF', () async {
      final algolia = _MockAlgolia();
      final proxy = _DelegatingProxy(algolia);

      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(false); // Kill switch.

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');

      verify(() => recipeRepo.searchRecipes('pasta')).called(1);
      verifyNever(() => algolia.searchRecipes(any()));
    });

    test('empty query returns empty without hitting either repo', () async {
      final firestore = _MockFirestoreSearch();
      final proxy = _DelegatingProxy(firestore);
      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(false);

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      final results1 = await router.searchRecipes('');
      final results2 = await router.searchRecipes('   ');

      expect(results1, isEmpty);
      expect(results2, isEmpty);
      verifyNever(() => recipeRepo.searchRecipes(any()));
      verifyNever(() => firestore.searchRecipes(any()));
    });

    test('sets has_algolia_search=true when Algolia is active', () async {
      final algolia = _MockAlgolia();
      final proxy = _DelegatingProxy(algolia);

      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(true);
      when(() => algolia.searchRecipes(any(),
              filters: any(named: 'filters'),
              page: any(named: 'page'),
              hitsPerPage: any(named: 'hitsPerPage')))
          .thenAnswer((_) async => const SearchResult<RecipeSearchHit>(
                hits: [],
                totalHits: 0,
                page: 0,
                totalPages: 0,
                processingTimeMs: 1,
              ));

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');

      verify(() => analytics.setUserProperty(
            name: 'has_algolia_search',
            value: 'true',
          )).called(1);
    });

    test('sets has_algolia_search=false when on Firestore fallback', () async {
      final firestore = _MockFirestoreSearch();
      final proxy = _DelegatingProxy(firestore);
      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(false);

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');

      verify(() => analytics.setUserProperty(
            name: 'has_algolia_search',
            value: 'false',
          )).called(1);
    });

    test('user property fires only once, even across many searches', () async {
      final firestore = _MockFirestoreSearch();
      final proxy = _DelegatingProxy(firestore);
      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(false);

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      await router.searchRecipes('pasta');
      await router.searchRecipes('lasagne');
      await router.searchRecipes('soppa');

      verify(() => analytics.setUserProperty(
            name: 'has_algolia_search',
            value: 'false',
          )).called(1);
    });

    test('Algolia exception falls back to RecipeRepository transparently',
        () async {
      final algolia = _MockAlgolia();
      final proxy = _DelegatingProxy(algolia);

      when(() => flags.isEnabled(FeatureFlags.enableAlgoliaSearch))
          .thenReturn(true);
      when(() => algolia.searchRecipes(any(),
              filters: any(named: 'filters'),
              page: any(named: 'page'),
              hitsPerPage: any(named: 'hitsPerPage')))
          .thenThrow(Exception('Algolia 503'));

      final router = RecipeSearchRouter(
        recipeRepository: recipeRepo,
        searchRepository: proxy,
        analytics: analytics,
        featureFlags: flags,
      );

      final results = await router.searchRecipes('pasta');

      expect(results, isEmpty);
      verify(() => recipeRepo.searchRecipes('pasta')).called(1);
    });
  });
}
