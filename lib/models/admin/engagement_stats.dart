/// Read-models for the admin engagement tab, parsed from the
/// `analytics/feature_retention/daily/{date}` rollups written nightly by the
/// `computeFeatureRetention` Cloud Function.

/// Per-feature activity counts for one window (DAU, WAU-7d, or WAU-28d).
class FeatureCounts {
  final int cooked;
  final int imported;
  final int shared;
  final int mealPlanned;
  final int shopped;

  const FeatureCounts({
    this.cooked = 0,
    this.imported = 0,
    this.shared = 0,
    this.mealPlanned = 0,
    this.shopped = 0,
  });

  /// Upper-bound proxy for distinct active users in the window: at least this
  /// many users were active in the busiest single feature. Exact distinct
  /// counts aren't stored per-feature, so this is intentionally a floor.
  int get max => [cooked, imported, shared, mealPlanned, shopped]
      .reduce((a, b) => a > b ? a : b);

  factory FeatureCounts.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return FeatureCounts(
      cooked: v('cooked'),
      imported: v('imported'),
      shared: v('shared'),
      mealPlanned: v('mealPlanned'),
      shopped: v('shopped'),
    );
  }
}

/// One day's feature-retention aggregate. `date` is the UTC `yyyy-mm-dd` doc id.
class DailyEngagement {
  final String date;
  final FeatureCounts dau;
  final FeatureCounts wau7d;
  final FeatureCounts wau28d;

  const DailyEngagement({
    required this.date,
    required this.dau,
    required this.wau7d,
    required this.wau28d,
  });

  factory DailyEngagement.fromFirestore(String id, Map<String, dynamic> data) {
    // Defensive: a malformed sub-field (not a Map) degrades to zeros rather
    // than throwing — the tab must survive any document shape.
    Map<String, dynamic>? sub(String key) =>
        data[key] is Map ? Map<String, dynamic>.from(data[key] as Map) : null;
    return DailyEngagement(
      date: (data['date'] as String?) ?? id,
      dau: FeatureCounts.fromMap(sub('dau')),
      wau7d: FeatureCounts.fromMap(sub('wau7d')),
      wau28d: FeatureCounts.fromMap(sub('wau28d')),
    );
  }
}
