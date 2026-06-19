import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/models/parsing/site_config.dart';

/// HOW each metric is computed: a pure function from the fetched [InsightsData]
/// (plus localized labels for categorical rows) to a [MetricValue]. No side
/// effects, no fetching — trivially unit-testable with a fixture InsightsData.
typedef Resolver = MetricValue Function(
    InsightsData data, AppLocalizations l10n);

/// Localized label for a recipe import method (reuses the existing tab keys).
String _recipeMethodLabel(AppLocalizations l10n, RecipeImportMethod m) =>
    switch (m) {
      RecipeImportMethod.url => l10n.adminRecipesMethodUrl,
      RecipeImportMethod.photo => l10n.adminRecipesMethodPhoto,
      RecipeImportMethod.textPaste => l10n.adminRecipesMethodText,
      RecipeImportMethod.social => l10n.adminRecipesMethodSocial,
      RecipeImportMethod.manual => l10n.adminRecipesMethodManual,
    };

/// Fixed display order for the recipe-method breakdown.
const _recipeMethodOrder = [
  RecipeImportMethod.url,
  RecipeImportMethod.photo,
  RecipeImportMethod.textPaste,
  RecipeImportMethod.social,
  RecipeImportMethod.manual,
];

/// Domains with real import activity, worst-performing first (any failures
/// first, then lowest success rate, then most recently active). Ported from the
/// old ImportHealthViewModel.
List<SiteConfig> _activeImportConfigs(InsightsData data) {
  final active = data.importConfigs!
      .where((c) => c.successCount + c.failureCount > 0)
      .toList();
  active.sort((a, b) {
    final aFail = a.failureCount > 0;
    final bFail = b.failureCount > 0;
    if (aFail != bFail) return aFail ? -1 : 1;
    final rate = a.successRate.compareTo(b.successRate);
    if (rate != 0) return rate;
    final aTime = a.lastUpdated?.millisecondsSinceEpoch ?? 0;
    final bTime = b.lastUpdated?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  });
  return active;
}

final Map<MetricKey, Resolver> resolvers = Map.unmodifiable({
  MetricKey.recipeTotal: (data, l10n) => ScalarMetric(data.recipes!.total),
  MetricKey.recipeByMethod: (data, l10n) {
    final stats = data.recipes!;
    return BreakdownMetric([
      for (final m in _recipeMethodOrder)
        BreakdownRow(_recipeMethodLabel(l10n, m), stats.count(m)),
    ]);
  },
  MetricKey.importDomains: (data, l10n) =>
      ScalarMetric(_activeImportConfigs(data).length),
  MetricKey.importSuccess: (data, l10n) => ScalarMetric(
      _activeImportConfigs(data).fold(0, (s, c) => s + c.successCount)),
  MetricKey.importFailure: (data, l10n) => ScalarMetric(
      _activeImportConfigs(data).fold(0, (s, c) => s + c.failureCount)),
  MetricKey.importSuccessRate: (data, l10n) {
    final active = _activeImportConfigs(data);
    final success = active.fold(0, (s, c) => s + c.successCount);
    final failure = active.fold(0, (s, c) => s + c.failureCount);
    final total = success + failure;
    return ScalarMetric(total == 0 ? 0 : (success / total * 100).round());
  },
  MetricKey.importDomainTable: (data, l10n) {
    final active = _activeImportConfigs(data);
    return MatrixMetric(
      [for (final c in active) c.domain],
      [
        l10n.adminImportColSuccess,
        l10n.adminImportColFailure,
        l10n.adminImportColRate,
      ],
      [
        for (final c in active)
          [c.successCount, c.failureCount, (c.successRate * 100).round()],
      ],
    );
  },
});
