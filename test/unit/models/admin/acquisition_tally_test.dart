import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/acquisition_tally.dart';

Map<String, dynamic> day(Map<String, int> by, {String? scope, int? eligible}) =>
    {
      'scope': scope ?? AcquisitionTally.scope,
      'total': by.values.fold<int>(0, (a, b) => a + b),
      'bySource': by,
      if (eligible != null) 'eligible': {'analyticsConsented': eligible},
    };

void main() {
  test('cells of 1-4 show as <5, zero and 5 or more show their number', () {
    expect(AcquisitionTally.cell(0), '0');
    expect(AcquisitionTally.cell(1), '<5');
    expect(AcquisitionTally.cell(4), '<5');
    expect(AcquisitionTally.cell(5), '5');
    expect(AcquisitionTally.cell(12), '12');
  });

  test('small cells are judged after summing the whole period', () {
    final t = AcquisitionTally.fromDays([
      day({'instagram': 3}),
      day({'instagram': 4}),
    ]);
    expect(AcquisitionTally.cell(t.bySource['instagram']!), '7');
  });

  test('the total is rounded so it cannot expose a hidden cell', () {
    final t = AcquisitionTally.fromDays([
      day({'instagram': 6, 'tiktok': 3, 'google': 6}),
    ]);
    expect(t.total, 15);
    expect(t.totalLabel, '15');
    final u = AcquisitionTally.fromDays([
      day({'instagram': 6, 'tiktok': 2, 'google': 5}),
    ]);
    expect(u.totalLabel, '15');
    expect(
      AcquisitionTally.fromDays([
        day({'a': 2}),
      ]).totalLabel,
      '<5',
    );
  });

  test('days from an older scope are skipped', () {
    final t = AcquisitionTally.fromDays([
      day({'instagram': 9}, scope: 'consented-signed-in-utm'),
      day({'tiktok': 7}),
    ]);
    expect(t.bySource, {'tiktok': 7});
  });

  test('channels are alphabetical with other last, not by size', () {
    final t = AcquisitionTally.fromDays([
      day({'tiktok': 20, 'other': 1, 'google': 9, 'email': 2}),
    ]);
    expect(t.sources, ['email', 'google', 'tiktok', 'other']);
  });

  test(
    'eligible comes from the newest day that has it, even without a tally',
    () {
      final t = AcquisitionTally.fromDays([
        {
          'eligible': {'analyticsConsented': 40},
        },
        day({'google': 6}, eligible: 30),
      ]);
      expect(t.eligible, 40);
      expect(t.eligibleLabel, '40');
      expect(AcquisitionTally.fromDays([]).eligibleLabel, isNull);
      expect(AcquisitionTally.fromDays([]).isEmpty, isTrue);
    },
  );
}
