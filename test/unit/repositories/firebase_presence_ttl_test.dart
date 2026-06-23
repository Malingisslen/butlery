// test/unit/repositories/firebase_presence_ttl_test.dart
//
// BUT-477: per-doc `expiresAt` TTL contract on presence collections.
// Verifies that the client-side filter masks rows whose `expiresAt` is
// in the past, and that fresh rows survive — for both the recipe and
// shopping presence repositories.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_presence_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_presence_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

void main() {
  group('FirebaseRecipePresenceRepository — expiresAt TTL (BUT-477)', () {
    late FakeFirebaseFirestore fake;
    late FirebaseRecipePresenceRepository repo;

    const recipeId = 'recipe_42';

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirebaseRecipePresenceRepository(
        firestoreRepository: FirestoreRepository(firestore: fake),
      );
    });

    test('setUserPresence writes expiresAt ~ now + 60s', () async {
      final before = DateTime.now().toUtc();
      await repo.setUserPresence(
        recipeId: recipeId,
        userId: 'user_a',
        displayName: 'Anna',
      );
      final after = DateTime.now().toUtc();

      final snap = await fake
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .doc('user_a')
          .get();

      expect(snap.exists, isTrue);
      final raw = snap.data()!['expiresAt'];
      expect(raw, isA<Timestamp>(), reason: 'expiresAt must be a Timestamp');
      final expires = (raw as Timestamp).toDate().toUtc();
      // The TTL window is 60 s — verify expiresAt lands in [before+59s, after+61s].
      // 1 s of slack on either side is plenty for the synchronous test path.
      expect(
        expires.isAfter(before.add(const Duration(seconds: 59))),
        isTrue,
        reason: 'expiresAt should be ~60s in the future, was $expires',
      );
      expect(
        expires.isBefore(after.add(const Duration(seconds: 61))),
        isTrue,
        reason: 'expiresAt should not exceed now+61s, was $expires',
      );
    });

    test('updatePresenceHeartbeat refreshes expiresAt', () async {
      await repo.setUserPresence(
        recipeId: recipeId,
        userId: 'user_a',
        displayName: 'Anna',
      );
      final docRef = fake
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .doc('user_a');
      // Force expiresAt into the past so we can assert that the heartbeat
      // moves it forward.
      await docRef.update({
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
        ),
      });

      await repo.updatePresenceHeartbeat(recipeId: recipeId, userId: 'user_a');

      final snap = await docRef.get();
      final raw = snap.data()!['expiresAt'] as Timestamp;
      expect(
        raw.toDate().toUtc().isAfter(DateTime.now().toUtc()),
        isTrue,
        reason: 'heartbeat must push expiresAt back into the future (was $raw)',
      );
    });

    test(
      'markUserInactive sets expiresAt = now (forces immediate eviction)',
      () async {
        await repo.setUserPresence(
          recipeId: recipeId,
          userId: 'user_a',
          displayName: 'Anna',
        );

        await repo.markUserInactive(recipeId: recipeId, userId: 'user_a');

        final snap = await fake
            .collection(FirestoreCollections.recipePresence)
            .doc(recipeId)
            .collection(FirestoreCollections.activeUsers)
            .doc('user_a')
            .get();
        final raw = snap.data()!['expiresAt'] as Timestamp;
        // expiresAt should be in the past (or very close to now) — anything
        // within +1s tolerance of "now" satisfies the contract.
        expect(
          raw.toDate().toUtc().isBefore(
            DateTime.now().toUtc().add(const Duration(seconds: 1)),
          ),
          isTrue,
          reason: 'leave should evict immediately, was $raw',
        );
      },
    );

    test(
      'watchActiveUsers drops rows where expiresAt is in the past, keeps fresh rows',
      () async {
        final now = DateTime.now().toUtc();
        // Write two rows directly so we can choose expiresAt values precisely.
        final activeUsers = fake
            .collection(FirestoreCollections.recipePresence)
            .doc(recipeId)
            .collection(FirestoreCollections.activeUsers);

        await activeUsers.doc('fresh_user').set({
          'userId': 'fresh_user',
          'displayName': 'Fresh',
          'isActive': true,
          'lastSeen': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30))),
        });

        await activeUsers.doc('stale_user').set({
          'userId': 'stale_user',
          'displayName': 'Stale',
          'isActive': true,
          'lastSeen': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 5)),
          ),
          'expiresAt': Timestamp.fromDate(
            now.subtract(const Duration(seconds: 30)),
          ),
        });

        final rows = await repo.watchActiveUsers(recipeId).first;
        expect(rows, hasLength(1));
        expect(rows.single['userId'], equals('fresh_user'));
      },
    );

    test(
      'watchActiveUsers includes rows with no expiresAt (legacy data)',
      () async {
        // Pre-BUT-477 rows lacked the field. We optimistically include them
        // because the server-side TTL sweeper has nothing to delete on either,
        // and surfacing such users is the lesser harm.
        final now = DateTime.now().toUtc();
        await fake
            .collection(FirestoreCollections.recipePresence)
            .doc(recipeId)
            .collection(FirestoreCollections.activeUsers)
            .doc('legacy_user')
            .set({
              'userId': 'legacy_user',
              'displayName': 'Legacy',
              'isActive': true,
              'lastSeen': Timestamp.fromDate(now),
              // no expiresAt
            });

        final rows = await repo.watchActiveUsers(recipeId).first;
        expect(rows.map((r) => r['userId']), contains('legacy_user'));
      },
    );
  });

  group('FirebaseShoppingPresenceRepository — expiresAt TTL (BUT-477)', () {
    late FakeFirebaseFirestore fake;
    late FirebaseShoppingPresenceRepository repo;

    const listId = 'list_helg';

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirebaseShoppingPresenceRepository(
        firestoreRepository: FirestoreRepository(firestore: fake),
      );
    });

    test('setUserPresence writes expiresAt ~ now + 60s', () async {
      final before = DateTime.now().toUtc();
      await repo.setUserPresence(
        listId: listId,
        userId: 'user_a',
        displayName: 'Anna',
      );
      final after = DateTime.now().toUtc();

      final snap = await fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc('user_a')
          .get();
      expect(snap.exists, isTrue);
      final raw = snap.data()!['expiresAt'] as Timestamp;
      final expires = raw.toDate().toUtc();
      expect(
        expires.isAfter(before.add(const Duration(seconds: 59))),
        isTrue,
      );
      expect(
        expires.isBefore(after.add(const Duration(seconds: 61))),
        isTrue,
      );
    });

    test('watchActiveUsers drops stale rows by expiresAt', () async {
      final now = DateTime.now().toUtc();
      final activeUsers = fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers);

      await activeUsers.doc('fresh_user').set({
        'userId': 'fresh_user',
        'displayName': 'Fresh',
        'isActive': true,
        'lastSeen': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 30))),
      });

      await activeUsers.doc('stale_user').set({
        'userId': 'stale_user',
        'displayName': 'Stale',
        'isActive': true,
        'lastSeen': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 5)),
        ),
        'expiresAt': Timestamp.fromDate(
          now.subtract(const Duration(seconds: 30)),
        ),
      });

      final rows = await repo.watchActiveUsers(listId).first;
      expect(rows, hasLength(1));
      expect(rows.single['userId'], equals('fresh_user'));
    });

    test('updatePresenceHeartbeat refreshes expiresAt', () async {
      await repo.setUserPresence(
        listId: listId,
        userId: 'user_a',
        displayName: 'Anna',
      );
      final docRef = fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc('user_a');
      await docRef.update({
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
        ),
      });

      await repo.updatePresenceHeartbeat(
        listId: listId,
        userId: 'user_a',
      );

      final snap = await docRef.get();
      final raw = snap.data()!['expiresAt'] as Timestamp;
      expect(
        raw.toDate().toUtc().isAfter(DateTime.now().toUtc()),
        isTrue,
      );
    });
  });
}
