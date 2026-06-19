import 'package:butlery/models/admin/metrics/metric_descriptor.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';

/// WHAT each metric is — the catalog. Pure data: label (localized accessor),
/// category, display format, optional colour thresholds and drilldown spec.
final Map<MetricKey, MetricDescriptor> catalog = Map.unmodifiable({
  MetricKey.recipeTotal: MetricDescriptor(
    key: MetricKey.recipeTotal,
    label: (l10n) => l10n.adminRecipesTotal,
    category: MetricCategory.recipes,
    format: MetricFormat.number,
  ),
  MetricKey.recipeByMethod: MetricDescriptor(
    key: MetricKey.recipeByMethod,
    label: (l10n) => l10n.adminRecipesColMethod,
    category: MetricCategory.recipes,
    format: MetricFormat.number,
  ),
});
