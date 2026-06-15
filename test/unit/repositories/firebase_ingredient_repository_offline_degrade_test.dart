/// BUT-1331: A cold offline `.get()` on the global ingredients collection
/// throws `FirebaseException('unavailable')`. The repository must degrade to
/// an empty cache (swallow + log) instead of rethrowing — rethrowing crashed
/// every caller (cooking-mode substitution, tagging, import, auto-categorize).
///
/// These tests pin the post-fix contract:
///   1. A lookup that triggers a failing load completes WITHOUT throwing.
///   2. After such a failure the cache is empty (lookups return empty, no crash).
///   3. Self-heal: the failure does not poison `_cacheLoaded`, so a subsequent
///      successful load populates the cache.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';

void main() {
  group('FirebaseIngredientRepository offline degrade (BUT-1331)', () {
    late FakeFirebaseFirestore backing;
    late _FlakyFirestore firestore;

    Future<void> seedIngredient(String id, {required String swedish}) async {
      await backing.collection(FirestoreCollections.ingredients).doc(id).set({
        'id': id,
        'swedish': swedish,
        'english': id,
        'group': 'spice',
        'properties': <String>[],
        'aliasesSv': <String>[],
        'aliasesEn': <String>[],
      });
    }

    setUp(() async {
      backing = FakeFirebaseFirestore();
      // Wrapper makes the FIRST `.get()` throw `unavailable`, then delegates
      // all subsequent reads to the real fake — modelling a cold offline cache
      // that recovers once connectivity returns.
      firestore = _FlakyFirestore(backing, failFirstGet: true);
      await seedIngredient('cinnamon', swedish: 'kanel');
    });

    test('lookup does NOT throw when the cold .get() is unavailable', () async {
      final repo = FirebaseIngredientRepository(firestore: firestore);

      // This is the intent-gate: against the old `rethrow` code, the
      // `unavailable` FirebaseException propagates out of findByName and this
      // expectation fails. Post-fix it completes normally.
      await expectLater(repo.findByName('kanel'), completes);
    });

    test('while .get() keeps failing, lookups degrade to empty (no crash)',
        () async {
      // Every load attempt fails — models a session that stays offline.
      final alwaysOffline = _FlakyFirestore(backing, failAll: true);
      final repo = FirebaseIngredientRepository(firestore: alwaysOffline);

      await expectLater(repo.findByName('kanel'), completion(isNull),
          reason: 'failed load degrades to empty cache');
      expect(await repo.count(), 0);
      expect(await repo.getAll(), isEmpty);
    });

    test(
        'self-heal: a failed load does not poison the cache; a later '
        'successful load populates it', () async {
      final repo = FirebaseIngredientRepository(firestore: firestore);

      // First lookup hits the failing `.get()` → empty cache, no throw.
      expect(await repo.findByName('kanel'), isNull);
      expect(firestore.getCallCount, 1, reason: 'one failed load attempt');

      // Because `_cacheLoadedAt` stays null on failure, the next load is not
      // short-circuited — it retries the (now succeeding) `.get()`.
      await repo.forceRefresh();

      expect(firestore.getCallCount, greaterThanOrEqualTo(2));
      final healed = await repo.findByName('kanel');
      expect(healed, isNotNull,
          reason: 'failure must not poison _cacheLoaded; retry must populate');
      expect(healed!.id, 'cinnamon');
      expect(await repo.count(), 1);
    });
  });
}

/// A [FirebaseFirestore] facade that delegates everything to a real
/// [FakeFirebaseFirestore] except that the ingredients-collection lookup
/// throws `FirebaseException('unavailable')` on its first read access. This
/// models a cold offline cache: `_doLoadCache` resolves the collection inside
/// its try-block (`_firestore.collection(...).get()`), so throwing here is the
/// same failure surface as a throwing `.get()`.
///
/// `CollectionReference`/`Query` are sealed in cloud_firestore 6.x and cannot
/// be implemented, so the failure is injected at `collection()` instead. Seed
/// writes go through the backing fake directly (not this wrapper), so failing
/// the first `collection()` read does not affect seeded data.
class _FlakyFirestore implements FirebaseFirestore {
  _FlakyFirestore(
    this._delegate, {
    this.failFirstGet = false,
    this.failAll = false,
  });

  final FirebaseFirestore _delegate;
  final bool failFirstGet;
  final bool failAll;

  /// Counts reads of the ingredients collection (i.e. load attempts).
  int getCallCount = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == FirestoreCollections.ingredients) {
      getCallCount++;
      if (failAll || (failFirstGet && getCallCount == 1)) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message:
              'Failed to get documents from server, and the cache is empty.',
        );
      }
    }
    return _delegate.collection(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      _delegate.noSuchMethod(invocation);
}
