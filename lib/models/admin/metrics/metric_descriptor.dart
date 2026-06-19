import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';

/// How a metric's value is formatted for display.
enum MetricFormat { number, percent, duration, currency }

/// Optional chart shown above a metric's table. `none` = table only; `bar` =
/// one bar per breakdown row; `line` = one line per matrix column over its rows
/// (a time series). The table always remains below for exact values.
enum MetricChart { none, bar, line }

/// Colour-band thresholds for a scalar (e.g. import success-rate). Pure data —
/// the renderer maps a band to a theme colour, so no colours live here.
class MetricThreshold {
  /// Below this is "warn" (amber); below [badBelow] is "bad" (red).
  final num? warnBelow;
  final num? badBelow;
  const MetricThreshold({this.warnBelow, this.badBelow});
}

/// Whether/how a metric drills down to underlying rows. [clientFilter] means the
/// rows are already in the fetched slice; otherwise a separate capped server
/// query runs (see Phase 5). Null = not drillable.
class DrilldownSpec {
  final bool clientFilter;
  const DrilldownSpec({required this.clientFilter});
}

/// WHAT a metric is — pure catalog data, no logic, no fetching. [label] is a
/// localized accessor so the UI stays Swedish-first with an English fallback.
class MetricDescriptor {
  final MetricKey key;
  final String Function(AppLocalizations) label;
  final MetricCategory category;
  final MetricFormat format;

  /// Per-column formats for a [MatrixMetric] (e.g. [number, number, percent]).
  /// Falls back to [format] for any column not listed. Null = use [format]
  /// for every column.
  final List<MetricFormat>? columnFormats;
  final MetricThreshold? threshold;
  final DrilldownSpec? drilldown;

  /// Chart to show above the table (default none).
  final MetricChart chart;

  const MetricDescriptor({
    required this.key,
    required this.label,
    required this.category,
    required this.format,
    this.columnFormats,
    this.threshold,
    this.drilldown,
    this.chart = MetricChart.none,
  });
}

/// Format a metric value for display per [format]. Pure — no BuildContext.
/// Numbers use Swedish grouping (1 234) and drop the `.0` on whole doubles.
String formatMetricValue(num value, MetricFormat format) {
  switch (format) {
    case MetricFormat.number:
      return NumberFormat.decimalPattern('sv').format(value);
    case MetricFormat.percent:
      return '${value.round()} %';
    case MetricFormat.duration:
      return '${value.round()} min';
    case MetricFormat.currency:
      return '${value.round()} kr';
  }
}
