/// One flagged anomaly from the nightly `detectAnomalies` job — a snapshot
/// series whose latest value is >3σ from its 28-day baseline.
class Anomaly {
  /// e.g. 'recipes_total', 'import_health_totalFailure'.
  final String metric;
  final num today;
  final num mean;
  final double z;

  /// 'up' or 'down' (sign of today − mean).
  final String direction;

  const Anomaly({
    required this.metric,
    required this.today,
    required this.mean,
    required this.z,
    required this.direction,
  });

  bool get isUp => direction == 'up';

  factory Anomaly.fromMap(Map<String, dynamic> data) => Anomaly(
    metric: (data['metric'] as String?) ?? 'unknown',
    today: (data['today'] as num?) ?? 0,
    mean: (data['mean'] as num?) ?? 0,
    z: (data['z'] as num?)?.toDouble() ?? 0,
    direction: (data['direction'] as String?) ?? 'up',
  );
}

/// Today's anomaly report (the doc at `analytics/anomalies/{date}`), or empty.
class AnomalyReport {
  final String date;
  final List<Anomaly> anomalies;

  const AnomalyReport({required this.date, required this.anomalies});

  static const empty = AnomalyReport(date: '', anomalies: []);

  bool get hasAnomalies => anomalies.isNotEmpty;

  factory AnomalyReport.fromFirestore(String id, Map<String, dynamic> data) {
    final raw = data['anomalies'];
    return AnomalyReport(
      date: (data['date'] as String?) ?? id,
      anomalies: raw is List
          ? raw
                .whereType<Map>()
                .map((m) => Anomaly.fromMap(Map<String, dynamic>.from(m)))
                .toList()
          : const [],
    );
  }
}
