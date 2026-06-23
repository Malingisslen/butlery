/// Integration test for scripts/backfill/cook_count.dart against a
/// FakeFirebaseFirestore.
///
/// Seeds three recipes covering every branch of the predicate:
///   * cooked + counter-null  -> should be picked up
///   * cooked + counter set   -> already-backfilled, leave alone
///   * never cooked           -> nothing to do
///
/// Asserts two runs:
/// 1. --dry-run reports the right candidate count without mutating data.
/// 2. live run writes exactly the expected set.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/backfill/cook_count.dart';

const _userId = 'u1';

Future<void> _seed(FakeFirebaseFirestore firestore) async {
  final col = firestore.collection('users').doc(_userId).collection('recipes');

  // Candidate #1: legacy, cooked, counter missing -> needs backfill.
  await col.doc('legacy-cooked').set({
    'core': {
      'id': 'legacy-cooked',
      'title': 'Legacy cooked',
      'lastCookedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
      // no cookCount
    },
    'type': 0,
  });

  // Candidate #2: same profile as #1 — two candidates to prove batching.
  await col.doc('legacy-cooked-2').set({
    'core': {
      'id': 'legacy-cooked-2',
      'title': 'Another legacy',
      'lastCookedAt': Timestamp.fromDate(DateTime(2026, 2, 5)),
    },
    'type': 0,
  });

  // Non-candidate: cooked but counter already populated.
  await col.doc('already-counted').set({
    'core': {
      'id': 'already-counted',
      'title': 'Post-feature cook',
      'lastCookedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
      'cookCount': 4,
    },
    'type': 0,
  });

  // Non-candidate: never cooked.
  await col.doc('never-cooked').set({
    'core': {
      'id': 'never-cooked',
      'title': 'Untouched recipe',
      // no lastCookedAt, no cookCount
    },
    'type': 0,
  });
}

Future<int?> _readCookCount(
  FakeFirebaseFirestore firestore,
  String docId,
) async {
  final doc = await firestore
      .collection('users')
      .doc(_userId)
      .collection('recipes')
      .doc(docId)
      .get();
  final core = doc.data()?['core'] as Map<String, dynamic>?;
  return core?['cookCount'] as int?;
}

void main() {
  group('cook_count backfill', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await _seed(firestore);
    });

    test('--dry-run reports 2 candidates and writes nothing', () async {
      final result = await runCookCountBackfill(
        firestore: firestore,
        dryRun: true,
      );

      expect(result.candidateCount, equals(2));
      expect(result.writtenCount, equals(0));
      expect(result.batchCount, equals(0));

      // Confirm no mutation happened.
      expect(await _readCookCount(firestore, 'legacy-cooked'), isNull);
      expect(await _readCookCount(firestore, 'legacy-cooked-2'), isNull);
      expect(await _readCookCount(firestore, 'already-counted'), equals(4));
      expect(await _readCookCount(firestore, 'never-cooked'), isNull);
    });

    test(
      'live run sets cookCount=1 on exactly the legacy-cooked recipes',
      () async {
        final result = await runCookCountBackfill(firestore: firestore);

        expect(result.candidateCount, equals(2));
        expect(result.writtenCount, equals(2));
        expect(
          result.batchCount,
          equals(1),
          reason: '2 writes should fit in a single batch',
        );

        expect(await _readCookCount(firestore, 'legacy-cooked'), equals(1));
        expect(await _readCookCount(firestore, 'legacy-cooked-2'), equals(1));
        // Untouched records stay untouched.
        expect(await _readCookCount(firestore, 'already-counted'), equals(4));
        expect(await _readCookCount(firestore, 'never-cooked'), isNull);
      },
    );

    test('--user scopes scan to a single user subcollection', () async {
      // Add a second user with a legacy-cooked recipe — must NOT be touched
      // when we target only u1.
      await firestore
          .collection('users')
          .doc('u2')
          .collection('recipes')
          .doc('u2-legacy')
          .set({
            'core': {
              'id': 'u2-legacy',
              'title': 'Other user legacy',
              'lastCookedAt': Timestamp.fromDate(DateTime(2026, 2, 20)),
            },
            'type': 0,
          });

      final result = await runCookCountBackfill(
        firestore: firestore,
        userId: _userId,
      );

      expect(result.candidateCount, equals(2));
      expect(result.writtenCount, equals(2));

      // u2's legacy recipe is untouched.
      final u2Doc = await firestore
          .collection('users')
          .doc('u2')
          .collection('recipes')
          .doc('u2-legacy')
          .get();
      final u2Core = u2Doc.data()?['core'] as Map<String, dynamic>;
      expect(u2Core['cookCount'], isNull);
    });
  });
}
