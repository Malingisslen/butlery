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
  MetricKey.importDomains: MetricExplanation(
    whatIsIt: (l) => l.metricImportDomainsWhat,
    howCalculated: (l) => l.metricImportDomainsHow,
    whyImportant: (l) => l.metricImportDomainsWhy,
  ),
  MetricKey.importSuccess: MetricExplanation(
    whatIsIt: (l) => l.metricImportSuccessWhat,
    howCalculated: (l) => l.metricImportSuccessHow,
    whyImportant: (l) => l.metricImportSuccessWhy,
  ),
  MetricKey.importFailure: MetricExplanation(
    whatIsIt: (l) => l.metricImportFailureWhat,
    howCalculated: (l) => l.metricImportFailureHow,
    whyImportant: (l) => l.metricImportFailureWhy,
  ),
  MetricKey.importSuccessRate: MetricExplanation(
    whatIsIt: (l) => l.metricImportRateWhat,
    howCalculated: (l) => l.metricImportRateHow,
    whyImportant: (l) => l.metricImportRateWhy,
  ),
  MetricKey.importDomainTable: MetricExplanation(
    whatIsIt: (l) => l.metricImportTableWhat,
    howCalculated: (l) => l.metricImportTableHow,
    whyImportant: (l) => l.metricImportTableWhy,
  ),
  MetricKey.engagementUsers: MetricExplanation(
    whatIsIt: (l) => l.metricEngagementUsersWhat,
    howCalculated: (l) => l.metricEngagementUsersHow,
    whyImportant: (l) => l.metricEngagementUsersWhy,
  ),
  MetricKey.engagementActiveToday: MetricExplanation(
    whatIsIt: (l) => l.metricEngagementActiveWhat,
    howCalculated: (l) => l.metricEngagementActiveHow,
    whyImportant: (l) => l.metricEngagementActiveWhy,
  ),
  MetricKey.engagementActive7d: MetricExplanation(
    whatIsIt: (l) => l.metricEngagementActiveWhat,
    howCalculated: (l) => l.metricEngagementActiveHow,
    whyImportant: (l) => l.metricEngagementActiveWhy,
  ),
  MetricKey.engagementActive28d: MetricExplanation(
    whatIsIt: (l) => l.metricEngagementActiveWhat,
    howCalculated: (l) => l.metricEngagementActiveHow,
    whyImportant: (l) => l.metricEngagementActiveWhy,
  ),
  MetricKey.engagementDailyTable: MetricExplanation(
    whatIsIt: (l) => l.metricEngagementTableWhat,
    howCalculated: (l) => l.metricEngagementTableHow,
    whyImportant: (l) => l.metricEngagementTableWhy,
  ),
});
