import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/pool_inspection.dart';

void main() {
  group('PoolInspection.fromMap', () {
    test('parses the callable response', () {
      final p = PoolInspection.fromMap({
        'poolKey': 'v1:0123456789abcdef',
        'quarantined': true,
        'reasonCode': 'bad_merge',
        'count': 12,
        'average': 4,
        'distribution': [0, 1, 2, 3, 6],
        'votes24h': 5,
        'votes7d': 9,
        'sampled': 12,
        'youngAccountShare': 0.25,
        'unverifiedShare': null,
      })!;

      expect(p.quarantined, isTrue);
      expect(p.reason, QuarantineReason.badMerge);
      expect(p.average, 4.0);
      expect(p.distribution, [0, 1, 2, 3, 6]);
      expect(p.votes24h, 5);
      expect(p.youngAccountShare, 0.25);
      expect(p.unverifiedShare, isNull);
    });

    test('a short or missing distribution is padded with zeros', () {
      final p = PoolInspection.fromMap({
        'poolKey': 'v1:0123456789abcdef',
        'distribution': [3],
      })!;
      expect(p.distribution, [3, 0, 0, 0, 0]);
      expect(p.average, isNull);
      expect(p.quarantined, isFalse);
      expect(p.reason, isNull);
    });

    test('an unknown reason code is no reason', () {
      final p = PoolInspection.fromMap({
        'poolKey': 'v1:0123456789abcdef',
        'reasonCode': 'spam',
      })!;
      expect(p.reason, isNull);
    });

    test('a response without a poolKey is not an inspection', () {
      expect(PoolInspection.fromMap({'count': 1}), isNull);
    });
  });

  test('every reason round-trips through its wire name', () {
    for (final r in QuarantineReason.values) {
      expect(QuarantineReason.fromWire(r.wireName), r);
    }
  });
}
