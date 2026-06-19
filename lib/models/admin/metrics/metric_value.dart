/// The shape of a resolved metric. A [sealed] union so the renderer's switch is
/// exhaustive at compile time — adding a new kind is a compile error at the one
/// dispatch site (see metric_renderer.dart), not a runtime surprise.
///
/// Resolvers (resolvers.dart) are pure functions that turn already-fetched data
/// into one of these. Rendering and data-fetching never touch this file.
library;

sealed class MetricValue {
  const MetricValue();

  /// Whether this carries no data to show — drives the "Ingen data" placeholder.
  /// A [ScalarMetric] is never empty (a value of 0 is still data); the
  /// list-backed kinds are empty when their list is.
  bool get isEmpty;
}

/// A single number (total users, success rate, correction count). [previous] is
/// the same metric for the prior period, used for delta arrows — null until the
/// nightly snapshot history exists for that source.
class ScalarMetric extends MetricValue {
  final num value;
  final num? previous;
  const ScalarMetric(this.value, {this.previous});

  @override
  bool get isEmpty => false;

  /// Percent change vs the previous period, or null when there's no comparison
  /// basis (no previous, or previous was 0 so a ratio is undefined).
  double? get deltaPercent {
    final p = previous;
    if (p == null || p == 0) return null;
    return (value - p) / p * 100;
  }
}

/// A point on a time series.
class SeriesPoint {
  final String label;
  final num value;
  const SeriesPoint(this.label, this.value);
}

/// A chronological series (daily active users, daily import volume).
class SeriesMetric extends MetricValue {
  final List<SeriesPoint> points;
  final List<SeriesPoint>? previousPoints;
  const SeriesMetric(this.points, {this.previousPoints});

  @override
  bool get isEmpty => points.isEmpty;
}

/// One labelled slice of a categorical breakdown.
class BreakdownRow {
  final String label;
  final num value;
  const BreakdownRow(this.label, this.value);
}

/// A categorical split (recipes by import method, feedback by type, failing
/// domains). Rows are pre-sorted by the resolver.
class BreakdownMetric extends MetricValue {
  final List<BreakdownRow> rows;
  const BreakdownMetric(this.rows);

  @override
  bool get isEmpty => rows.isEmpty;
}

/// A 2-D grid (engagement: day × feature; parsing: domain × issue). [cells] is
/// row-major and indexed [rowLabels][colLabels].
class MatrixMetric extends MetricValue {
  final List<String> rowLabels;
  final List<String> colLabels;
  final List<List<num>> cells;
  const MatrixMetric(this.rowLabels, this.colLabels, this.cells);

  @override
  bool get isEmpty => cells.isEmpty || rowLabels.isEmpty || colLabels.isEmpty;
}

/// One stage of a funnel.
class FunnelStage {
  final String label;
  final num value;
  const FunnelStage(this.label, this.value);
}

/// Ordered, descending funnel stages (retention curve, signup→activate→retain).
class FunnelMetric extends MetricValue {
  final List<FunnelStage> stages;
  const FunnelMetric(this.stages);

  @override
  bool get isEmpty => stages.isEmpty;
}
