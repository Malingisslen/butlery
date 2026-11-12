/// Why a pooled rating was switched off; the wire names are the callable's
/// `reasonCode` values.
enum QuarantineReason {
  brigading('brigading'),
  badMerge('bad_merge'),
  other('other')
  ;

  const QuarantineReason(this.wireName);
  final String wireName;

  static QuarantineReason? fromWire(Object? raw) {
    for (final reason in values) {
      if (reason.wireName == raw) return reason;
    }
    return null;
  }
}

/// What `adminInspectPool` returns for one pool: numbers only, nothing about
/// any person.
class PoolInspection {
  const PoolInspection({
    required this.poolKey,
    required this.quarantined,
    required this.reason,
    required this.count,
    required this.average,
    required this.distribution,
    required this.votes24h,
    required this.votes7d,
    required this.sampled,
    required this.youngAccountShare,
    required this.unverifiedShare,
  });

  final String poolKey;
  final bool quarantined;
  final QuarantineReason? reason;
  final int count;
  final double? average;

  /// Votes per whole star, one to five.
  final List<int> distribution;
  final int votes24h;
  final int votes7d;

  /// How many of the newest votes the two shares were computed over.
  final int sampled;

  /// 0..1, or null when nothing could be sampled.
  final double? youngAccountShare;
  final double? unverifiedShare;

  /// Null when the response is not a pool inspection at all.
  static PoolInspection? fromMap(Map<dynamic, dynamic> data) {
    final poolKey = data['poolKey'];
    if (poolKey is! String || poolKey.isEmpty) return null;
    final rawDistribution = data['distribution'];
    return PoolInspection(
      poolKey: poolKey,
      quarantined: data['quarantined'] == true,
      reason: QuarantineReason.fromWire(data['reasonCode']),
      count: _int(data['count']),
      average: _double(data['average']),
      distribution: [
        for (var i = 0; i < 5; i++)
          rawDistribution is List && i < rawDistribution.length
              ? _int(rawDistribution[i])
              : 0,
      ],
      votes24h: _int(data['votes24h']),
      votes7d: _int(data['votes7d']),
      sampled: _int(data['sampled']),
      youngAccountShare: _double(data['youngAccountShare']),
      unverifiedShare: _double(data['unverifiedShare']),
    );
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static double? _double(Object? v) => v is num ? v.toDouble() : null;
}
