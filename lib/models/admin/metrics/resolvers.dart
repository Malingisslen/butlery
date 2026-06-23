import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/models/parsing/site_config.dart';

/// HOW each metric is computed: a pure function from the fetched [InsightsData]
/// (plus localized labels for categorical rows) to a [MetricValue]. No side
/// effects, no fetching — trivially unit-testable with a fixture InsightsData.
typedef Resolver =
    MetricValue Function(InsightsData data, AppLocalizations l10n);

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

/// Prior success-rate (%) from an import snapshot's totals, or null.
num? _snapshotRate(Map<String, dynamic>? snapshot) {
  if (snapshot == null) return null;
  final success = (snapshot['totalSuccess'] as num?) ?? 0;
  final failure = (snapshot['totalFailure'] as num?) ?? 0;
  final total = success + failure;
  if (total == 0) return null;
  return (success / total * 100).round();
}

final Map<MetricKey, Resolver> resolvers = Map.unmodifiable({
  MetricKey.recipeTotal: (data, l10n) => ScalarMetric(
    data.recipes!.total,
    previous: (data.recipeSnapshot?['total'] as num?),
  ),
  MetricKey.recipeByMethod: (data, l10n) {
    final stats = data.recipes!;
    return BreakdownMetric([
      for (final m in _recipeMethodOrder)
        BreakdownRow(_recipeMethodLabel(l10n, m), stats.count(m)),
    ]);
  },
  MetricKey.importDomains: (data, l10n) => ScalarMetric(
    _activeImportConfigs(data).length,
    previous: (data.importSnapshot?['byDomain'] as Map?)?.length,
  ),
  MetricKey.importSuccess: (data, l10n) => ScalarMetric(
    _activeImportConfigs(data).fold(0, (s, c) => s + c.successCount),
    previous: data.importSnapshot?['totalSuccess'] as num?,
  ),
  MetricKey.importFailure: (data, l10n) => ScalarMetric(
    _activeImportConfigs(data).fold(0, (s, c) => s + c.failureCount),
    previous: data.importSnapshot?['totalFailure'] as num?,
  ),
  MetricKey.importSuccessRate: (data, l10n) {
    final active = _activeImportConfigs(data);
    final success = active.fold(0, (s, c) => s + c.successCount);
    final failure = active.fold(0, (s, c) => s + c.failureCount);
    final total = success + failure;
    return ScalarMetric(
      total == 0 ? 0 : (success / total * 100).round(),
      previous: _snapshotRate(data.importSnapshot),
    );
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
  MetricKey.engagementUsers: (data, l10n) =>
      ScalarMetric(data.engagement!.userCount),
  MetricKey.engagementActiveToday: (data, l10n) {
    final days = data.engagement!.days;
    if (days.isEmpty) return const ScalarMetric(0);
    // days are newest-first; offset 1 = yesterday.
    return ScalarMetric(
      days.first.dau.max,
      previous: days.length > 1 ? days[1].dau.max : null,
    );
  },
  MetricKey.engagementActive7d: (data, l10n) {
    final days = data.engagement!.days;
    if (days.isEmpty) return const ScalarMetric(0);
    return ScalarMetric(
      days.first.wau7d.max,
      previous: days.length > 7 ? days[7].wau7d.max : null,
    );
  },
  MetricKey.engagementActive28d: (data, l10n) {
    final days = data.engagement!.days;
    if (days.isEmpty) return const ScalarMetric(0);
    return ScalarMetric(
      days.first.wau28d.max,
      previous: days.length > 28 ? days[28].wau28d.max : null,
    );
  },
  MetricKey.engagementDailyTable: (data, l10n) {
    final days = data.engagement!.days;
    return MatrixMetric(
      [for (final d in days) d.date],
      [
        l10n.adminEngagementColCooked,
        l10n.adminEngagementColImported,
        l10n.adminEngagementColShared,
        l10n.adminEngagementColPlanned,
        l10n.adminEngagementColShopped,
      ],
      [
        for (final d in days)
          [
            d.dau.cooked,
            d.dau.imported,
            d.dau.shared,
            d.dau.mealPlanned,
            d.dau.shopped,
          ],
      ],
    );
  },
});
