import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';
import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/repositories/engagement_repository.dart';
import 'package:butlery/repositories/recipe_stats_repository.dart';
import 'package:butlery/repositories/site_config_repository.dart';

/// Fetches one category's raw data slice. The adapter over an existing admin
/// repository — repositories are wrapped, not rewritten.
abstract class CategoryFetcher {
  MetricCategory get category;
  Future<Object> fetch();
}

class RecipeCategoryFetcher implements CategoryFetcher {
  final RecipeStatsRepository _repository;
  RecipeCategoryFetcher(this._repository);

  @override
  MetricCategory get category => MetricCategory.recipes;

  @override
  Future<Object> fetch() => _repository.getRecipeStats();
}

class ImportCategoryFetcher implements CategoryFetcher {
  final SiteConfigRepository _repository;
  ImportCategoryFetcher(this._repository);

  @override
  MetricCategory get category => MetricCategory.importHealth;

  @override
  Future<Object> fetch() => _repository.getAllConfigs();
}

class EngagementCategoryFetcher implements CategoryFetcher {
  final EngagementRepository _repository;
  EngagementCategoryFetcher(this._repository);

  @override
  MetricCategory get category => MetricCategory.engagement;

  @override
  Future<Object> fetch() async {
    final count = await _repository.getUserCount();
    // 30 days so the 28-day "active" metric has a prior period to delta against.
    final days = await _repository.getDailyFeatureRetention(limit: 30);
    return EngagementRaw(userCount: count, days: days);
  }
}

/// Assembles [InsightsData] by fetching ONLY the categories whose metrics are
/// on screen (lazy — a mega-fetch would re-run the expensive recipe scan on
/// every tab), caches each raw slice, then runs the pure resolvers.
class MetricsAssembler {
  final Map<MetricCategory, CategoryFetcher> _fetchers;
  final Map<MetricCategory, Object> _cache = {};

  MetricsAssembler(List<CategoryFetcher> fetchers)
      : _fetchers = {for (final f in fetchers) f.category: f};

  /// Resolve [keys] for display. Fetches each needed category (cached unless
  /// [force]), assembles the snapshot, runs the pure resolvers.
  Future<Map<MetricKey, MetricValue>> resolve(
    Set<MetricKey> keys,
    AppLocalizations l10n, {
    bool force = false,
  }) async {
    final categories = keys.map((k) => k.category).toSet();
    if (force) {
      for (final c in categories) {
        _cache.remove(c);
      }
    }
    await Future.wait(categories.map(_ensureFetched));
    final data = _assemble();
    final result = <MetricKey, MetricValue>{};
    for (final k in keys) {
      final resolver = resolvers[k];
      assert(
        resolver != null,
        'No resolver for MetricKey.${k.name} — add one to resolvers.dart '
        'before declaring the key on a tab.',
      );
      if (resolver != null) result[k] = resolver(data, l10n);
    }
    return result;
  }

  Future<void> _ensureFetched(MetricCategory category) async {
    if (_cache.containsKey(category)) return;
    final fetcher = _fetchers[category];
    if (fetcher == null) return; // category not wired yet
    _cache[category] = await fetcher.fetch();
  }

  /// Build the snapshot from cached slices. Grows one field per migrated tab.
  InsightsData _assemble() => InsightsData(
        recipes: _cache[MetricCategory.recipes] as RecipeStats?,
        importConfigs: _cache[MetricCategory.importHealth] as List<SiteConfig>?,
        engagement: _cache[MetricCategory.engagement] as EngagementRaw?,
      );
}
