// BUT-1700: a failed admin read must reach the tab as an error, not as a
// zero/empty result that looks like real data.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/engagement_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../test_support/failing_firestore.dart';

void main() {
  setUpAll(() async => BaseUnitTest.setupUnit());

  test('getUserCount counts the user documents', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('a').set({'x': 1});
    await db.collection('users').doc('b').set({'x': 1});

    expect(await EngagementRepository(firestore: db).getUserCount(), 2);
  });

  test(
    'getDailyFeatureRetention returns newest days first, within limit',
    () async {
      final db = FakeFirebaseFirestore();
      final daily = db
          .collection('analytics')
          .doc('feature_retention')
          .collection('daily');
      for (final d in ['2026-06-18', '2026-06-19', '2026-06-20']) {
        await daily.doc(d).set({'date': d});
      }

      final days = await EngagementRepository(
        firestore: db,
      ).getDailyFeatureRetention(limit: 2);

      expect(days, hasLength(2));
      expect(days.first.date, '2026-06-20');
    },
  );

  test('getUserCount throws on a failed read instead of returning 0', () async {
    await expectLater(
      EngagementRepository(firestore: FailingFirestore()).getUserCount(),
      throwsFirestoreFailure,
    );
  });

  test(
    'getDailyFeatureRetention throws instead of returning no days',
    () async {
      await expectLater(
        EngagementRepository(
          firestore: FailingFirestore(),
        ).getDailyFeatureRetention(),
        throwsFirestoreFailure,
      );
    },
  );
}
