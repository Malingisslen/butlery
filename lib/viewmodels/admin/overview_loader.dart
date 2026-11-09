import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/overview_status.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';

/// Reads the few numbers the overview needs, each on its own: a read that
/// fails becomes null, so [assessOverview] marks only that row unavailable.
/// Every read is one bounded query (the same ones the tabs make), never a
/// scan.
Future<List<OverviewRow>> loadOverviewRows(
  AppLocalizations l10n, {
  bool force = false,
}) async {
  final results = await Future.wait<Object?>([
    _attempt<AnomalyReport>(
      () => ServiceLocator.get<AnomalyRepository>().getLatest(),
    ),
    _attempt<Map<MetricKey, MetricValue>>(
      () => ServiceLocator.get<MetricsAssembler>().resolve(
        {MetricKey.importSuccess, MetricKey.importFailure},
        l10n,
        force: force,
      ),
    ),
    _attempt<int>(
      () async =>
          (await ServiceLocator.get<FeedbackRepository>()
                  .watchFeedback(
                    status: FeedbackStatus.newReport,
                    limit: overviewFeedbackReadLimit,
                  )
                  .first)
              .length,
    ),
    _attempt<int>(
      () async =>
          (await ServiceLocator.get<IngredientChangeRequestRepository>()
                  .watchOpen()
                  .first)
              .length,
    ),
  ]);
  final metrics = results[1] as Map<MetricKey, MetricValue>?;
  return assessOverview(
    anomalies: results[0] as AnomalyReport?,
    importSuccess: _scalar(metrics?[MetricKey.importSuccess]),
    importFailure: _scalar(metrics?[MetricKey.importFailure]),
    newFeedback: results[2] as int?,
    openProposals: results[3] as int?,
  );
}

Future<T?> _attempt<T>(Future<T> Function() read) async {
  try {
    return await read();
  } catch (e) {
    // Kept visible: a permission or index error otherwise leaves a row
    // unavailable with nothing to diagnose.
    AppLogger.warning('Overview read failed: $e');
    return null;
  }
}

// A metric that did not resolve to a number is unavailable, not 0.
int? _scalar(MetricValue? v) => v is ScalarMetric ? v.value.toInt() : null;
