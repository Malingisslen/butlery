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
    chart: MetricChart.bar,
  ),
  MetricKey.importDomains: MetricDescriptor(
    key: MetricKey.importDomains,
    label: (l10n) => l10n.adminImportSummaryDomains,
    category: MetricCategory.importHealth,
    format: MetricFormat.number,
  ),
  MetricKey.importSuccess: MetricDescriptor(
    key: MetricKey.importSuccess,
    label: (l10n) => l10n.adminImportSummarySuccess,
    category: MetricCategory.importHealth,
    format: MetricFormat.number,
  ),
  MetricKey.importFailure: MetricDescriptor(
    key: MetricKey.importFailure,
    label: (l10n) => l10n.adminImportSummaryFailure,
    category: MetricCategory.importHealth,
    format: MetricFormat.number,
  ),
  MetricKey.importSuccessRate: MetricDescriptor(
    key: MetricKey.importSuccessRate,
    label: (l10n) => l10n.adminImportSummaryRate,
    category: MetricCategory.importHealth,
    format: MetricFormat.percent,
    threshold: const MetricThreshold(warnBelow: 90, badBelow: 75),
  ),
  MetricKey.importDomainTable: MetricDescriptor(
    key: MetricKey.importDomainTable,
    label: (l10n) => l10n.adminImportColDomain,
    category: MetricCategory.importHealth,
    format: MetricFormat.number,
    columnFormats: const [
      MetricFormat.number,
      MetricFormat.number,
      MetricFormat.percent,
    ],
  ),
  MetricKey.engagementUsers: MetricDescriptor(
    key: MetricKey.engagementUsers,
    label: (l10n) => l10n.adminEngagementUsers,
    category: MetricCategory.engagement,
    format: MetricFormat.number,
  ),
  MetricKey.engagementActiveToday: MetricDescriptor(
    key: MetricKey.engagementActiveToday,
    label: (l10n) => l10n.adminEngagementActiveToday,
    category: MetricCategory.engagement,
    format: MetricFormat.number,
  ),
  MetricKey.engagementActive7d: MetricDescriptor(
    key: MetricKey.engagementActive7d,
    label: (l10n) => l10n.adminEngagementActive7d,
    category: MetricCategory.engagement,
    format: MetricFormat.number,
  ),
  MetricKey.engagementActive28d: MetricDescriptor(
    key: MetricKey.engagementActive28d,
    label: (l10n) => l10n.adminEngagementActive28d,
    category: MetricCategory.engagement,
    format: MetricFormat.number,
  ),
  MetricKey.engagementDailyTable: MetricDescriptor(
    key: MetricKey.engagementDailyTable,
    label: (l10n) => l10n.adminEngagementColDate,
    category: MetricCategory.engagement,
    format: MetricFormat.number,
    chart: MetricChart.line,
  ),
});
