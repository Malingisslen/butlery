import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

const double _chartHeight = 180;

/// Distinct line/series colours pulled from the theme (no hardcoded hex). The
/// legend disambiguates, so near-hues are acceptable for an internal tool.
List<Color> _palette(ColorScheme cs) =>
    [cs.primary, cs.tertiary, cs.error, cs.secondary, cs.outline];

String _shortLabel(String label) =>
    label.length <= 8 ? label : '${label.substring(0, 7)}…';

/// A simple vertical bar chart for a breakdown (one bar per row). The table
/// below carries exact labels + values; this is the at-a-glance shape.
class MetricBarChart extends StatelessWidget {
  final List<BreakdownRow> rows;
  const MetricBarChart({required this.rows, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxValue = rows
        .map((r) => r.value.toDouble())
        .fold<double>(0, (m, v) => v > m ? v : m);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: SizedBox(
        height: _chartHeight,
        child: BarChart(
          BarChartData(
            maxY: maxValue == 0 ? 1 : maxValue * 1.2,
            barGroups: [
              for (var i = 0; i < rows.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: rows[i].value.toDouble(),
                      color: cs.primary,
                      width: 18,
                      borderRadius: BorderRadius.zero,
                    ),
                  ],
                ),
            ],
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 32),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_shortLabel(rows[i].label),
                          style: AppTextStyles.bodySmall),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }
}

/// A multi-line chart for a matrix (one line per column, x = rows in chronological
/// order). Used for time series like daily engagement. A legend maps colour →
/// column; exact values live in the table below.
class MetricLineChart extends StatelessWidget {
  final MatrixMetric value;
  const MetricLineChart({required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (value.isEmpty) return const SizedBox.shrink();
    final palette = _palette(cs);
    final rowCount = value.rowLabels.length;

    final lines = <LineChartBarData>[];
    for (var c = 0; c < value.colLabels.length; c++) {
      final spots = <FlSpot>[
        for (var r = 0; r < rowCount; r++)
          // rows arrive newest-first; reverse so the newest day is rightmost
          FlSpot((rowCount - 1 - r).toDouble(), value.cells[r][c].toDouble()),
      ];
      lines.add(LineChartBarData(
        spots: spots,
        color: palette[c % palette.length],
        isCurved: false,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: SizedBox(
            height: _chartHeight,
            child: LineChart(
              LineChartData(
                lineBarsData: lines,
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  // Dates are listed in the table below — keep the axis clean.
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.spacingXs),
          child: Wrap(
            spacing: AppDimensions.spacingMd,
            runSpacing: AppDimensions.spacingXs,
            children: [
              for (var c = 0; c < value.colLabels.length; c++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        color: palette[c % palette.length]),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(value.colLabels[c], style: AppTextStyles.bodySmall),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
