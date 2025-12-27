// lib/core/di/modules/search_module.dart

import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  Future<void> configure(GetIt container) async {
    try {
      final featureFlags = container.isRegistered<FeatureFlagService>()
          ? container<FeatureFlagService>()
          : null;

      final useAlgolia =
          featureFlags?.isEnabled(FeatureFlags.enableAlgoliaSearch) ?? false;

      if (useAlgolia) {
        // Try to configure Algolia
        final appId = dotenv.env['ALGOLIA_APP_ID'];
        final apiKey = dotenv.env['ALGOLIA_API_KEY'];

        if (appId != null && apiKey != null && appId.isNotEmpty) {
          container.registerSingleton<SearchRepository>(
            AlgoliaSearchRepository(
              appId: appId,
              apiKey: apiKey,
            ),
          );
          AppLogger.info('SearchModule: Using Algolia search provider');
        } else {
          // Algolia enabled but credentials missing, fall back
          AppLogger.warning(
              'SearchModule: Algolia enabled but credentials missing, using Firestore');
          container.registerSingleton<SearchRepository>(
            FirestoreSearchRepository(),
          );
        }
      } else {
        // Algolia disabled, use Firestore fallback
        container.registerSingleton<SearchRepository>(
          FirestoreSearchRepository(),
        );
        AppLogger.info('SearchModule: Using Firestore search provider');
      }
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
      final searchRepository = container<SearchRepository>();

      // Perform health check
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
