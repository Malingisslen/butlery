/// Unit tests for the pooled "Butlery-betyget" read path (Increment 6):
/// FirebaseRatingsRepository.getPooledStats + PooledStats display-floor logic.
///
/// Pure-Dart with FakeFirebaseFirestore. Proves the contract the card/detail
/// rely on: the n >= 5 display floor, correct parsing of the server aggregate,
/// and the null-average (empty pool) case that must never render a pill.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

FirebaseRatingsRepository _repo(FakeFirebaseFirestore fs) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: 'u1'),
    userId: 'u1',
    isAuthenticated: true,
  );
  return FirebaseRatingsRepository(firestore: fs, authRepository: auth);
}

void main() {
  group('PooledStats display-floor logic (decision 8: n >= 5)', () {
    test('below the floor does not display', () {
      expect(
        const PooledStats(count: 4, average: 4.5).meetsDisplayFloor,
        isFalse,
      );
    });

    test('at/above the floor displays', () {
      expect(
        const PooledStats(count: 5, average: 4.3).meetsDisplayFloor,
        isTrue,
      );
    });

    test('null average never displays even with a high count', () {
      expect(
        const PooledStats(count: 99, average: null).meetsDisplayFloor,
        isFalse,
      );
    });

    test('displayAverage formats to one decimal', () {
      expect(const PooledStats(count: 5, average: 4.25).displayAverage, '4.3');
      expect(const PooledStats(count: 0, average: null).displayAverage, '0.0');
    });
  });

  group('getPooledStats reads canonical_recipe_stats/{poolKey}', () {
    test('returns null when no pool doc exists', () async {
      final fs = FakeFirebaseFirestore();
      expect(await _repo(fs).getPooledStats('v1:missing'), isNull);
    });

    test('returns null for an empty poolKey (no read)', () async {
      final fs = FakeFirebaseFirestore();
      expect(await _repo(fs).getPooledStats(''), isNull);
    });

    test('parses count + average from the aggregate doc', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('canonical_recipe_stats').doc('v1:abcd').set({
        'count': 12,
        'average': 4.3,
        'updatedAt': DateTime.utc(2026, 7, 3),
      });
      final stats = await _repo(fs).getPooledStats('v1:abcd');
      expect(stats, isNotNull);
      expect(stats!.count, 12);
      expect(stats.average, 4.3);
      expect(stats.meetsDisplayFloor, isTrue);
    });

    test('parses a whole-number average stored as int (Firestore)', () async {
      // A small pool where everyone rated the same star lands on an integer
      // mean; Firestore stores whole numbers as int, not double. The `as num?`
      // cast must survive this — `as double?` would throw and drop the pill.
      final fs = FakeFirebaseFirestore();
      await fs.collection('canonical_recipe_stats').doc('v1:whole').set({
        'count': 7,
        'average': 5, // int, not 5.0
        'updatedAt': DateTime.utc(2026, 7, 3),
      });
      final stats = await _repo(fs).getPooledStats('v1:whole');
      expect(stats, isNotNull);
      expect(stats!.average, 5.0);
      expect(stats.displayAverage, '5.0');
      expect(stats.meetsDisplayFloor, isTrue);
    });

    test('empty pool (count 0 / average null) → non-displaying stat', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('canonical_recipe_stats').doc('v1:empty').set({
        'count': 0,
        'average': null,
        'updatedAt': DateTime.utc(2026, 7, 3),
      });
      final stats = await _repo(fs).getPooledStats('v1:empty');
      expect(stats, isNotNull);
      expect(stats!.count, 0);
      expect(stats.average, isNull);
      expect(stats.meetsDisplayFloor, isFalse);
    });
  });

  group('getBulkPooledStats (batch read for a list screen)', () {
    test(
      'returns stats keyed by poolKey; missing keys are simply absent',
      () async {
        final fs = FakeFirebaseFirestore();
        await fs.collection('canonical_recipe_stats').doc('v1:a').set({
          'count': 7,
          'average': 4.5,
        });
        await fs.collection('canonical_recipe_stats').doc('v1:b').set({
          'count': 3,
          'average': 5, // int mean stored as int — must survive as num?
        });
        final map = await _repo(
          fs,
        ).getBulkPooledStats(['v1:a', 'v1:b', 'v1:missing']);
        expect(map.keys.toSet(), {'v1:a', 'v1:b'});
        expect(map['v1:a']!.count, 7);
        expect(map['v1:a']!.average, 4.5);
        expect(map['v1:b']!.average, 5.0);
        expect(map.containsKey('v1:missing'), isFalse);
      },
    );

    test('empties dropped, duplicates deduped, empty input → {}', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('canonical_recipe_stats').doc('v1:a').set({
        'count': 6,
        'average': 4.0,
      });
      expect(await _repo(fs).getBulkPooledStats(const []), isEmpty);
      expect(await _repo(fs).getBulkPooledStats(const ['', '']), isEmpty);
      // Duplicate 'v1:a' + an empty key: one unique pool queried, one result.
      final map = await _repo(fs).getBulkPooledStats(['v1:a', 'v1:a', '']);
      expect(map.length, 1);
      expect(map['v1:a']!.count, 6);
    });
  });
}
