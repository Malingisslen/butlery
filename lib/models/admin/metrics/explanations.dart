import 'package:butlery/models/admin/metrics/metric_explanation.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';

/// HOW each metric is explained to the operator (what / how / why), via
/// localized accessors. Read by the info-dialog widget (Phase 2).
final Map<MetricKey, MetricExplanation> explanations = Map.unmodifiable({
  MetricKey.recipeTotal: MetricExplanation(
    whatIsIt: (l) => l.metricRecipeTotalWhat,
    howCalculated: (l) => l.metricRecipeTotalHow,
    whyImportant: (l) => l.metricRecipeTotalWhy,
  ),
  MetricKey.recipeByMethod: MetricExplanation(
    whatIsIt: (l) => l.metricRecipeByMethodWhat,
    howCalculated: (l) => l.metricRecipeByMethodHow,
    whyImportant: (l) => l.metricRecipeByMethodWhy,
  ),
});
