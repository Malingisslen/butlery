// lib/core/di/modules/search_module.dart

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/repositories/algolia/algolia_search_repository.dart';
import 'package:butlery/repositories/firebase/firebase_search_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
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
  List<Type> get provides => [SearchRepository];

  @override
  int get priority => 15; // After Core (1), before Content (10)

  @override
  @override
  Future<void> configureUserScope(GetIt container) async {}

  Future<void> configure(GetIt container) async {
    try {
      // Always register Firestore search as the default provider.
      // Feature flags (Remote Config) are not yet fetched at configure() time,
      // so we defer the Algolia swap to initialize().
      container.registerLazySingleton<SearchRepository>(
        () => FirestoreSearchRepository(),
      );
      AppLogger.info(
          'SearchModule: Registered default Firestore search provider');
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

      // Now that Remote Config has been fetched, check the feature flag
      // and swap to Algolia if enabled and credentials are available.
      final featureFlags = container.isRegistered<FeatureFlagService>()
          ? container<FeatureFlagService>()
          : null;

      final useAlgolia =
          featureFlags?.isEnabled(FeatureFlags.enableAlgoliaSearch) ?? false;

      if (useAlgolia) {
        const appId = String.fromEnvironment('ALGOLIA_APP_ID');
        const apiKey = String.fromEnvironment('ALGOLIA_API_KEY');

        if (appId.isNotEmpty && apiKey.isNotEmpty) {
          // Unregister default Firestore provider and register Algolia
          container.unregister<SearchRepository>();
          container.registerLazySingleton<SearchRepository>(
            () => AlgoliaSearchRepository(
              appId: appId,
              apiKey: apiKey,
            ),
          );
          AppLogger.info(
              'SearchModule: Switched to Algolia search provider (feature flag)');
        } else {
          AppLogger.warning(
              'SearchModule: Algolia enabled but credentials missing, keeping Firestore');
        }
      }

      // Perform health check on whichever provider is active
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
