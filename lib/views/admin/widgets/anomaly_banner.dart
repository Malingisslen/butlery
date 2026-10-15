import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';

/// A dismissible bar at the top of the admin shell that surfaces the latest
/// `detectAnomalies` report — metrics whose value is >3σ off their 28-day
/// baseline. Shows nothing until the nightly snapshots have accrued enough
/// history. Dismissal is per-date (session-scoped).
class AnomalyBanner extends StatefulWidget {
  const AnomalyBanner({super.key});

  /// Dates the operator dismissed this session (so a reload re-checks, but
  /// flipping tabs doesn't nag).
  static final Set<String> _dismissed = {};

  @override
  State<AnomalyBanner> createState() => _AnomalyBannerState();
}

class _AnomalyBannerState extends State<AnomalyBanner> {
  AnomalyReport _report = AnomalyReport.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await ServiceLocator.get<AnomalyRepository>().getLatest();
    if (mounted) setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    if (!_report.hasAnomalies ||
        AnomalyBanner._dismissed.contains(_report.date)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ButleryIcon(ButleryIcons.triangleAlert, color: cs.onErrorContainer),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.adminAnomalyTitle} · ${_report.date}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  for (final anomaly in _report.anomalies)
                    Text(
                      _line(l10n, anomaly),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                ],
              ),
            ),
            ButleryCloseButton(
              color: cs.onErrorContainer,
              semanticLabel: l10n.adminScreenshotClose,
              onPressed: () =>
                  setState(() => AnomalyBanner._dismissed.add(_report.date)),
            ),
          ],
        ),
      ),
    );
  }

  String _line(AppLocalizations l10n, Anomaly anomaly) {
    final label = _metricLabel(l10n, anomaly.metric);
    final how = anomaly.isUp ? l10n.adminAnomalyHigh : l10n.adminAnomalyLow;
    return '$label: $how (${anomaly.today} ⌀${anomaly.mean})';
  }

  String _metricLabel(AppLocalizations l10n, String metric) {
    switch (metric) {
      case 'recipes_total':
        return l10n.adminAnomalyMetricRecipes;
      case 'import_health_totalFailure':
        return l10n.adminAnomalyMetricImportFailure;
      case 'parsing_corrections_total':
        return l10n.adminAnomalyMetricParsing;
      case 'ops_totalEvents':
        return l10n.adminAnomalyMetricOps;
      case 'feedback_total':
        return l10n.adminAnomalyMetricFeedback;
      default:
        return metric;
    }
  }
}
