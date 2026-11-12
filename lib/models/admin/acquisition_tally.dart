/// The channel tally for the admin view, with small numbers hidden.
///
/// A cell of 1-4 could point at one person once an account is erased, so it
/// shows as "<5". The total is rounded to the nearest 5, and channels are
/// listed alphabetically rather than by size.
library;

class AcquisitionTally {
  /// Must match `ACQUISITION_SCOPE` in `functions/src/analytics/acquisition-counter.ts`.
  /// Days written under an older scope counted other people and are skipped.
  static const String scope = 'consented-new-account-channel';
  static const String other = 'other';
  static const int smallCell = 5;

  final Map<String, int> bySource;
  final int total;

  /// How many accounts had said yes to statistics on the newest day that
  /// recorded it, or null before the first such day.
  final int? eligible;

  const AcquisitionTally({
    required this.bySource,
    required this.total,
    required this.eligible,
  });

  /// [days] is newest first, as the repository returns it.
  factory AcquisitionTally.fromDays(List<Map<String, dynamic>> days) {
    final bySource = <String, int>{};
    var total = 0;
    int? eligible;
    for (final day in days) {
      final consented = (day['eligible'] as Map?)?['analyticsConsented'];
      if (eligible == null && consented is num) eligible = consented.toInt();
      if (day['scope'] != scope) continue;
      final dayTotal = day['total'];
      if (dayTotal is num) total += dayTotal.toInt();
      final sources = day['bySource'];
      if (sources is Map) {
        sources.forEach((key, value) {
          if (key is String && value is num) {
            bySource[key] = (bySource[key] ?? 0) + value.toInt();
          }
        });
      }
    }
    return AcquisitionTally(
      bySource: bySource,
      total: total,
      eligible: eligible,
    );
  }

  bool get isEmpty => total == 0 && bySource.isEmpty;

  /// Channels alphabetically, [other] last.
  List<String> get sources {
    final keys = bySource.keys.where((k) => k != other).toList()..sort();
    if (bySource.containsKey(other)) keys.add(other);
    return keys;
  }

  static String cell(int count) =>
      count > 0 && count < smallCell ? '<$smallCell' : '$count';

  String get totalLabel {
    if (total > 0 && total < smallCell) return '<$smallCell';
    return '${(total / smallCell).round() * smallCell}';
  }

  String? get eligibleLabel => eligible == null ? null : cell(eligible!);
}
