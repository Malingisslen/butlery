import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/metrics/catalog.dart';
import 'package:butlery/models/admin/metrics/metric_descriptor.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/widgets/admin_metric_info_button.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/views/admin/widgets/metric_charts.dart';
import 'package:butlery/views/admin/widgets/metric_drilldown.dart';

/// Renders one resolved metric by its [MetricValue] kind. The `switch` is
/// exhaustive over the sealed type — adding a 6th kind is a compile error here,
/// not a runtime surprise. Scalars are stat cards; the list kinds share a
/// label/value table; matrix is a grid. (Real charts replace the list/matrix
/// placeholders in Phase 2 via fl_chart.)
class MetricRenderer extends StatelessWidget {
  final MetricKey metricKey;
  final MetricValue value;
  const MetricRenderer({
    required this.metricKey,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final desc = catalog[metricKey]!;
    final label = desc.label(context.l10n);
    final info = AdminMetricInfoButton(metricKey: metricKey);
    return switch (value) {
      final ScalarMetric s => AdminStatCard(
        label: label,
        value: formatMetricValue(s.value, desc.format),
        action: info,
        deltaPercent: s.deltaPercent,
      ),
      BreakdownMetric(rows: final rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.chart == MetricChart.bar) MetricBarChart(rows: rows),
          _LabelValueTable(
            title: label,
            format: desc.format,
            action: info,
            rows: [for (final r in rows) (r.label, r.value)],
          ),
        ],
      ),
      SeriesMetric(points: final points) => _LabelValueTable(
        title: label,
        format: desc.format,
        action: info,
        rows: [for (final p in points) (p.label, p.value)],
      ),
      FunnelMetric(stages: final stages) => _LabelValueTable(
        title: label,
        format: desc.format,
        action: info,
        rows: [for (final s in stages) (s.label, s.value)],
      ),
      final MatrixMetric m => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.chart == MetricChart.line) MetricLineChart(value: m),
          _MatrixTable(
            title: label,
            value: m,
            format: desc.format,
            columnFormats: desc.columnFormats,
            action: info,
            drilldown: desc.drilldown,
          ),
        ],
      ),
    };
  }
}

/// A titled header bar with an optional trailing action (the info button).
class _TableHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const _TableHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.metadataEmphasized),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A titled two-column (label → value) table. Shared by breakdown/series/funnel.
class _LabelValueTable extends StatelessWidget {
  final String title;
  final MetricFormat format;
  final List<(String, num)> rows;
  final Widget? action;
  const _LabelValueTable({
    required this.title,
    required this.format,
    required this.rows,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TableHeader(title: title, action: action),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Text(
              context.l10n.adminMetricNoData,
              style: AppTextStyles.bodyMedium.copyWith(color: cs.outline),
            ),
          )
        else
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatMetricValue(value, format),
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// A titled grid: left column of row labels, a header of column labels, cells.
class _MatrixTable extends StatelessWidget {
  final String title;
  final MatrixMetric value;
  final MetricFormat format;
  final List<MetricFormat>? columnFormats;
  final Widget? action;
  final DrilldownSpec? drilldown;
  const _MatrixTable({
    required this.title,
    required this.value,
    required this.format,
    this.columnFormats,
    this.action,
    this.drilldown,
  });

  MetricFormat _formatFor(int column) {
    final formats = columnFormats;
    if (formats != null && column < formats.length) return formats[column];
    return format;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TableHeader(title: title, action: action),
        if (value.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Text(
              context.l10n.adminMetricNoData,
              style: AppTextStyles.bodyMedium.copyWith(color: cs.outline),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('')),
                for (final c in value.colLabels)
                  DataColumn(
                    label: Text(c, style: AppTextStyles.metadataEmphasized),
                  ),
              ],
              rows: [
                for (var r = 0; r < value.rowLabels.length; r++)
                  DataRow(
                    // A drillable matrix makes each row tappable → its label
                    // (e.g. a domain) is passed to the drilldown handler.
                    onSelectChanged: drilldown == null
                        ? null
                        : (_) => handleMetricDrilldown(
                            context,
                            drilldown!.kind,
                            value.rowLabels[r],
                          ),
                    cells: [
                      DataCell(
                        Text(
                          value.rowLabels[r],
                          style: AppTextStyles.metadataEmphasized,
                        ),
                      ),
                      for (var c = 0; c < value.colLabels.length; c++)
                        DataCell(
                          Text(
                            formatMetricValue(value.cells[r][c], _formatFor(c)),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
