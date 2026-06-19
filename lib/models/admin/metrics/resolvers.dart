import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/recipe_stats.dart';

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

final Map<MetricKey, Resolver> resolvers = Map.unmodifiable({
  MetricKey.recipeTotal: (data, l10n) => ScalarMetric(data.recipes!.total),
  MetricKey.recipeByMethod: (data, l10n) {
    final stats = data.recipes!;
    return BreakdownMetric([
      for (final m in _recipeMethodOrder)
        BreakdownRow(_recipeMethodLabel(l10n, m), stats.count(m)),
    ]);
  },
});
