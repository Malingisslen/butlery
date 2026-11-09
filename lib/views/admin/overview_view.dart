import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/overview_status.dart';
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// First admin tab: says in one box whether anything needs the operator, and
/// for each finding which tab to open.
class OverviewView extends StatefulWidget {
  final void Function(OverviewTarget) onOpenTarget;
  const OverviewView({required this.onOpenTarget, super.key});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  List<OverviewFinding>? _findings;
  bool _loading = false;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  // A metric that did not resolve must fail the load: reading it as 0 would
  // show the all-clear box on missing data.
  int _scalar(MetricValue? v) {
    if (v is ScalarMetric) return v.value.toInt();
    throw StateError('Overview metric did not resolve to a number');
  }

  Future<void> _load({bool force = false}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final anomalies = await ServiceLocator.get<AnomalyRepository>()
          .getLatest();
      final values = await ServiceLocator.get<MetricsAssembler>().resolve(
        {MetricKey.importSuccess, MetricKey.importFailure},
        l10n,
        force: force,
      );
      final findings = assessOverview(
        anomalies: anomalies,
        importSuccess: _scalar(values[MetricKey.importSuccess]),
        importFailure: _scalar(values[MetricKey.importFailure]),
      );
      if (!mounted) return;
      setState(() {
        _findings = findings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final findings = _findings;
    return AdminTabPage(
      title: l10n.adminOverviewTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: l10n.adminRefresh,
          onPressed: _loading ? null : () => _load(force: true),
        ),
      ],
      body: findings == null
          ? (_failed
                ? StateWidget.error(
                    message: l10n.adminOverviewLoadFailed,
                    onAction: _load,
                  )
                : StateWidget.loading(message: l10n.loadingMetrics))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.space16),
              children: [
                _StatusBox(count: findings.length),
                for (final finding in findings) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _FindingCard(
                    finding: finding,
                    onOpen: () => widget.onOpenTarget(finding.target),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final int count;
  const _StatusBox({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ok = count == 0;
    final foreground = ok ? cs.onPrimaryContainer : cs.onErrorContainer;
    return Material(
      color: ok ? cs.primaryContainer : cs.errorContainer,
      borderRadius: BorderRadius.circular(AppDimensions.space8),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok
                  ? l10n.adminOverviewAllClearTitle
                  : l10n.adminOverviewNeedsAction(count),
              style: AppTextStyles.titleLarge.copyWith(color: foreground),
            ),
            if (ok) ...[
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.adminOverviewAllClearBody,
                style: AppTextStyles.bodyMedium.copyWith(color: foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final OverviewFinding finding;
  final VoidCallback onOpen;
  const _FindingCard({required this.finding, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final anomalies = finding.kind == OverviewFindingKind.anomalies;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              anomalies
                  ? l10n.adminOverviewAnomaliesTitle
                  : l10n.adminOverviewImportFailuresTitle(finding.number),
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              anomalies
                  ? l10n.adminOverviewAnomaliesAdvice
                  : l10n.adminOverviewImportFailuresAdvice,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.space8),
            TextButton(
              onPressed: onOpen,
              child: Text(l10n.adminOverviewOpenImport),
            ),
          ],
        ),
      ),
    );
  }
}
