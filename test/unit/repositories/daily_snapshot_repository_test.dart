// BUT-1700: "no snapshot yet" is null; a failed read is an exception.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/daily_snapshot_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../test_support/failing_firestore.dart';

void main() {
  setUpAll(() async => BaseUnitTest.setupUnit());

  test('returns null when no snapshot exists for the group', () async {
    final repo = DailySnapshotRepository(firestore: FakeFirebaseFirestore());
    expect(await repo.getLatest('recipes'), isNull);
  });

  test('returns the newest snapshot by doc id', () async {
    final db = FakeFirebaseFirestore();
    final daily = db.collection('analytics').doc('recipes').collection('daily');
    await daily.doc('2026-06-19').set({'total': 1});
    await daily.doc('2026-06-20').set({'total': 2});

    final latest = await DailySnapshotRepository(
      firestore: db,
    ).getLatest('recipes');

    expect(latest, {'total': 2});
  });

  test('a failed read throws instead of passing for "no snapshot"', () async {
    final repo = DailySnapshotRepository(firestore: FailingFirestore());
    await expectLater(repo.getLatest('recipes'), throwsFirestoreFailure);
  });
}
