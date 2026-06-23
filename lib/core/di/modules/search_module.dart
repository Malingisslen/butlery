// lib/core/di/modules/search_module.dart

import 'dart:async';

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/algolia/algolia_search_repository.dart';
import 'package:butlery/repositories/firebase/firebase_search_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
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
  Future<void> configureUserScope(GetIt container) async {
    // BUT-752: subscribe to mid-session consent changes so granting
    // analytics consent post-startup flips the Algolia delegate on without
    // a restart, and revoking it switches us back to Firestore.
    // Registered here (not in `configure`) because ConsentService itself
    // is user-scoped — registered post-sign-in by CoreModule's
    // `configureUserScope`. Pre-emptive `removeListener` keeps re-init
    // calls (hot reload, sign-out/sign-in) idempotent — Flutter's
    // ChangeNotifier semantics allow duplicate `addListener` calls,
    // each fires independently.
    if (container.isRegistered<ConsentService>()) {
      final consent = container<ConsentService>();
      consent.removeListener(_onConsentChanged);
      consent.addListener(_onConsentChanged);
    }
  }

  _DelegatingSearchRepository? _proxy;

  /// Tracks the current delegate kind so [_onConsentChanged] / [_evaluate]
  /// can stay idempotent — re-init only when the desired state differs
  /// from what the proxy is already serving.
  bool _algoliaActive = false;

  /// Handler bound on the SearchModule singleton — same instance on every
  /// add/remove call so listener equality matches and removal is reliable.
  void _onConsentChanged() {
    // Async re-eval but fire-and-forget — listeners must return synchronously.
    // SearchModule is a long-lived DI singleton, no cancellation surface.
    unawaited(_evaluate(GetIt.instance));
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      _proxy = _DelegatingSearchRepository(FirestoreSearchRepository());
      container.registerLazySingleton<SearchRepository>(() => _proxy!);
      AppLogger.info(
        'SearchModule: Registered default Firestore search provider',
      );

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
      await _evaluate(container);

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

  /// Evaluate feature flag + analytics consent and switch the delegate to
  /// match. Idempotent: re-runs are no-ops when the desired state already
  /// equals [_algoliaActive].
  ///
  /// Called both at module init and on every consent change (BUT-752).
  Future<void> _evaluate(GetIt container) async {
    if (_proxy == null) return; // configure() hasn't run yet.

    final featureFlags = container.isRegistered<FeatureFlagService>()
        ? container<FeatureFlagService>()
        : null;
    final useAlgolia =
        featureFlags?.isEnabled(FeatureFlags.enableAlgoliaSearch) ?? false;

    // BUT-580: Algolia search-personalisation qualifies as analytics under
    // our consent model. Even though we never pass `userToken`,
    // `clickAnalytics`, or `analyticsTags` (queries reach Algolia
    // anonymously), the query text + IP-level metadata reaching a
    // third-party EU processor still requires the analytics consent
    // bucket. BUT-751: shared fail-closed gate.
    final hasConsent =
        useAlgolia &&
        await hasAnalyticsConsent(container, logTag: 'SearchModule');
    final wantAlgolia = useAlgolia && hasConsent;

    if (wantAlgolia == _algoliaActive) return;

    if (wantAlgolia) {
      const appId = String.fromEnvironment('ALGOLIA_APP_ID');
      const apiKey = String.fromEnvironment('ALGOLIA_API_KEY');
      if (appId.isEmpty || apiKey.isEmpty) {
        AppLogger.warning(
          'SearchModule: Algolia enabled but credentials missing, keeping Firestore',
        );
        return;
      }
      try {
        _proxy!.delegate = AlgoliaSearchRepository(
          appId: appId,
          apiKey: apiKey,
        );
        _algoliaActive = true;
        AppLogger.info(
          'SearchModule: Switched to Algolia search provider '
          '(feature flag + analytics consent)',
        );
      } on ArgumentError catch (e) {
        // BUT-580: EU-cluster invariant violated. Refuse to init and stay
        // on Firestore — better degraded search than a Chapter V breach.
        AppLogger.warning(
          'SearchModule: Algolia init refused — $e. '
          'Keeping Firestore search.',
        );
      }
    } else {
      _proxy!.delegate = FirestoreSearchRepository();
      _algoliaActive = false;
      AppLogger.info(
        'SearchModule: Reverted to Firestore search (consent revoked '
        'or feature flag off) (BUT-752)',
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
  Future<SearchResult<RecipeSearchHit>> searchRecipes(
    String query, {
    SearchFilters? filters,
    int page = 0,
    int hitsPerPage = 20,
  }) => delegate.searchRecipes(
    query,
    filters: filters,
    page: page,
    hitsPerPage: hitsPerPage,
  );

  @override
  Future<SearchResult<UserSearchHit>> searchUsers(
    String query, {
    int page = 0,
    int hitsPerPage = 20,
  }) => delegate.searchUsers(query, page: page, hitsPerPage: hitsPerPage);

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
  Future<void> batchIndexRecipes(
    List<Recipe> recipes, {
    required String ownerId,
  }) => delegate.batchIndexRecipes(recipes, ownerId: ownerId);

  @override
  Future<List<String>> getSuggestions(
    String partial, {
    String index = 'recipes',
    int limit = 5,
  }) => delegate.getSuggestions(partial, index: index, limit: limit);

  @override
  Future<bool> healthCheck() => delegate.healthCheck();
}
