// lib/core/di/modules/search_module.dart

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/algolia/algolia_search_repository.dart';
import 'package:butlery/repositories/firebase/firebase_search_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/search/recipe_search_router.dart';
import 'package:butlery/core/utils/logger.dart';

/// Search module providing search functionality with provider abstraction.
///
/// Migration-ready architecture:
/// - Uses SearchRepository interface for provider independence
/// - Feature flag controlled: `enable_algolia_search`
/// - Falls back to Firestore when Algolia is disabled
/// - Ready for future Meilisearch/Typesense migration
///
/// Configuration:
/// - ALGOLIA_APP_ID and ALGOLIA_API_KEY in .env
/// - enable_algolia_search feature flag controls provider
class SearchModule implements DIModule {
  @override
  String get name => 'Search';

  @override
  List<Type> get dependencies => [CoreModule];

  @override
  List<Type> get provides => [SearchRepository, RecipeSearchRouter];

  @override
  int get priority => 15; // After Core (1), before Content (10)

  @override
  Future<void> configureUserScope(GetIt container) async {}

  _DelegatingSearchRepository? _proxy;

  @override
  Future<void> configure(GetIt container) async {
    try {
      _proxy = _DelegatingSearchRepository(FirestoreSearchRepository());
      container.registerLazySingleton<SearchRepository>(() => _proxy!);
      AppLogger.info(
          'SearchModule: Registered default Firestore search provider');

      // BUT-475: router that prefers Algolia (uncapped) over the legacy
      // Firestore client-side filter (200-cap) for recipe text search.
      // Lazy because RecipeRepository is registered by ContentModule,
      // which initialises before us (priority 10 < 15).
      container.registerLazySingleton<RecipeSearchRouter>(
        () => RecipeSearchRouter(
          recipeRepository: container<RecipeRepository>(),
          searchRepository: container<SearchRepository>(),
          analytics: container.isRegistered<AnalyticsService>()
              ? container<AnalyticsService>()
              : null,
          featureFlags: container.isRegistered<FeatureFlagService>()
              ? container<FeatureFlagService>()
              : null,
        ),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure search services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      final featureFlags = container.isRegistered<FeatureFlagService>()
          ? container<FeatureFlagService>()
          : null;

      final useAlgolia =
          featureFlags?.isEnabled(FeatureFlags.enableAlgoliaSearch) ?? false;

      if (useAlgolia) {
        const appId = String.fromEnvironment('ALGOLIA_APP_ID');
        const apiKey = String.fromEnvironment('ALGOLIA_API_KEY');

        if (appId.isNotEmpty && apiKey.isNotEmpty) {
          _proxy!.delegate = AlgoliaSearchRepository(
            appId: appId,
            apiKey: apiKey,
          );
          AppLogger.info(
              'SearchModule: Switched to Algolia search provider (feature flag)');
        } else {
          AppLogger.warning(
              'SearchModule: Algolia enabled but credentials missing, keeping Firestore');
        }
      }

      final searchRepository = container<SearchRepository>();
      final isHealthy = await searchRepository.healthCheck();
      if (!isHealthy) {
        AppLogger.warning('SearchModule: Search provider health check failed');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize search services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;
      final searchRepository = container<SearchRepository>();

      if (searchRepository is HealthCheckable) {
        return await searchRepository.healthCheck();
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Search module factory for easy instantiation.
class SearchModuleFactory {
  static SearchModule create() => SearchModule();
}

class _DelegatingSearchRepository implements SearchRepository {
  SearchRepository delegate;
  _DelegatingSearchRepository(this.delegate);

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
