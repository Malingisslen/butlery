/// Integration tests for FirebaseCookEventRepository (BUT-838).
///
/// Intent: the per-user cook-event log must (1) count repeat cooks of the
/// SAME recipe — the old distinct-recipe proxy collapsed them to 1, making
/// `lifecycle_stage == habitual` unreachable for repeat cookers — (2) treat
/// the `since` boundary as inclusive, (3) commit the event doc and the
/// recipe's cookCount bump atomically in one batch, and (4) stay owner-only.
///
/// Fake Lane: FakeFirebaseFirestore + MockFirebaseAuth, no platform channels.
///
/// Deliberately does NOT call BaseUnitTest.setupUnit(): cloud_firestore's
/// `FieldValue` freezes `FieldValueFactoryPlatform.instance` into a
/// `static final` on first use, and the shared test bootstrap creates a
/// FieldValue before FakeFirebaseFirestore installs its mock factory —
/// after which every real `FieldValue.increment` is MethodChannel-backed
/// and the fake's batch commit throws a cast error. Everything this file
/// needs (firestore, auth) is constructed locally per test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart'
    as firebase_auth_mocks;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

void main() {
  group('FirebaseCookEventRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseCookEventRepository repository;

    const testUserId = 'cook-user-1';
    const recipeId = 'recipe-1';
    final now = DateTime(2026, 6, 10, 18, 30);
    final since = now.subtract(const Duration(days: 14));

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      final mockAuth = firebase_auth_mocks.MockFirebaseAuth(
        mockUser: firebase_auth_mocks.MockUser(
          uid: testUserId,
          email: 'cook@example.com',
        ),
        signedIn: true,
      );
      final authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);
      final recipeRepository = FirebaseRecipeRepository(
        authRepository: authRepository,
        firestore: fakeFirestore,
      );
      repository = FirebaseCookEventRepository(
        authRepository: authRepository,
        firestore: fakeFirestore,
        recipeRepository: recipeRepository,
      );

      // logCookEvent batches an update() on the recipe doc — it must exist.
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(testUserId)
          .collection(FirestoreCollections.userRecipes)
          .doc(recipeId)
          .set({
            'core': {'cookCount': 0},
          });
    });

    group('countSince', () {
      test('BUT-838 marquee: 3 cooks of the SAME recipe within 14d count as 3 '
          'and classify as habitual (proxy gave 1)', () async {
        await repository.logCookEvent(
          recipeId,
          now.subtract(const Duration(days: 10)),
        );
        await repository.logCookEvent(
          recipeId,
          now.subtract(const Duration(days: 5)),
        );
        await repository.logCookEvent(recipeId, now);

        final cooksLast14Days = await repository.countSince(testUserId, since);
        expect(
          cooksLast14Days,
          3,
          reason:
              'every cook event of the same recipe must count — the '
              'old distinct-recipe proxy collapsed these to 1',
        );

        final stage = classifyLifecycleStage(
          signupAt: now.subtract(const Duration(days: 60)),
          lastCookAt: now,
          cooksLast14Days: cooksLast14Days,
          now: now,
        );
        expect(
          stage,
          LifecycleStage.habitual,
          reason:
              '3 cooks in 14d is the habitual threshold — with the '
              'proxy count of 1 this stage was unreachable',
        );
      });

      test(
        'event exactly at the since boundary is counted (>= inclusive)',
        () async {
          await repository.logCookEvent(recipeId, since);

          final count = await repository.countSince(testUserId, since);
          expect(count, 1);
        },
      );

      test('events outside the window are excluded', () async {
        await repository.logCookEvent(
          recipeId,
          since.subtract(const Duration(seconds: 1)),
        );
        await repository.logCookEvent(
          recipeId,
          since.subtract(const Duration(days: 30)),
        );
        await repository.logCookEvent(
          recipeId,
          since.add(const Duration(days: 1)),
        );

        final count = await repository.countSince(testUserId, since);
        expect(
          count,
          1,
          reason:
              'only the in-window event counts; pre-boundary events '
              'must not inflate the habitual signal',
        );
      });

      test('is owner-only: counting another user\'s events throws', () async {
        expect(
          () => repository.countSince('someone-else', since),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('logCookEvent (atomic batch)', () {
      test(
        'writes the event doc AND bumps recipe cookCount in one commit',
        () async {
          final ok = await repository.logCookEvent(recipeId, now);
          expect(ok, isTrue);

          // Event doc landed with the documented schema {recipeId, cookedAt}.
          final events = await fakeFirestore
              .collection(FirestoreCollections.recipeCookEvents)
              .doc(testUserId)
              .collection(FirestoreCollections.recipeCookEventEntries)
              .get();
          expect(events.docs, hasLength(1));
          final data = events.docs.single.data();
          expect(data.keys, unorderedEquals(['recipeId', 'cookedAt']));
          expect(data['recipeId'], recipeId);
          expect((data['cookedAt'] as dynamic).toDate(), now);

          // Recipe counter bump landed in the same commit.
          final recipeDoc = await fakeFirestore
              .collection(FirestoreCollections.users)
              .doc(testUserId)
              .collection(FirestoreCollections.userRecipes)
              .doc(recipeId)
              .get();
          final core = recipeDoc.data()?['core'] as Map<String, dynamic>;
          expect(core['cookCount'], 1);
          expect((core['lastCookedAt'] as dynamic).toDate(), now);
        },
      );

      test(
        'a failing recipe update rejects the commit (returns false)',
        () async {
          // Recipe doc missing → the batched update() fails → commit rejects
          // → logCookEvent reports failure so RecipeCookingService does NOT
          // poison its session guard (the user can retry).
          //
          // NOTE: real Firestore rolls back the whole batch server-side (no
          // orphan event doc); fake_cloud_firestore applies batch ops eagerly
          // and leaks the event on a failed commit, so the rollback half of
          // the atomicity guarantee is not assertable here — only the
          // rejected-commit contract is.
          final ok = await repository.logCookEvent('missing-recipe', now);
          expect(
            ok,
            isFalse,
            reason:
                'a commit containing a failing counter bump must report '
                'failure, never a half-success',
          );
        },
      );

      test('signed-out user: returns false and writes no event doc', () async {
        // The cook flow must degrade, not throw, when auth is missing
        // (cold-start race) — and nothing may reach Firestore.
        final signedOutAuth = FirebaseAuthRepository(
          firebaseAuth: firebase_auth_mocks.MockFirebaseAuth(signedIn: false),
        );
        final signedOutRepo = FirebaseCookEventRepository(
          authRepository: signedOutAuth,
          firestore: fakeFirestore,
          recipeRepository: FirebaseRecipeRepository(
            authRepository: signedOutAuth,
            firestore: fakeFirestore,
          ),
        );

        expect(await signedOutRepo.logCookEvent(recipeId, now), isFalse);

        final events = await fakeFirestore
            .collection(FirestoreCollections.recipeCookEvents)
            .doc(testUserId)
            .collection('events')
            .get();
        expect(
          events.docs,
          isEmpty,
          reason: 'a signed-out call must not write any event',
        );
      });

      test('empty recipeId is rejected without writing', () async {
        final ok = await repository.logCookEvent('', now);
        expect(ok, isFalse);

        final events = await fakeFirestore
            .collection(FirestoreCollections.recipeCookEvents)
            .doc(testUserId)
            .collection(FirestoreCollections.recipeCookEventEntries)
            .get();
        expect(events.docs, isEmpty);
      });
    });

    group('exportCookEventsByUser (GDPR Art 15/20, BUT-1235)', () {
      test('owner export returns every logged event as {id, data}', () async {
        await repository.logCookEvent(recipeId, now);
        await repository.logCookEvent(
          'recipe-2',
          now.subtract(const Duration(days: 3)),
        );

        final entries = await repository.exportCookEventsByUser(testUserId);

        expect(entries, hasLength(2));
        for (final entry in entries) {
          expect(
            entry.keys,
            unorderedEquals(['id', 'data']),
            reason: 'export contract is raw {id, data} maps',
          );
          expect(entry['id'], isA<String>());
          final data = entry['data'] as Map<String, dynamic>;
          expect(data.keys, unorderedEquals(['recipeId', 'cookedAt']));
        }
        expect(
          entries.map((e) => (e['data'] as Map)['recipeId']),
          unorderedEquals([recipeId, 'recipe-2']),
        );
      });

      test('limit caps the number of exported events', () async {
        await repository.logCookEvent(recipeId, now);
        await repository.logCookEvent(recipeId, now);
        await repository.logCookEvent(recipeId, now);

        final entries = await repository.exportCookEventsByUser(
          testUserId,
          limit: 2,
        );
        expect(entries, hasLength(2));
      });

      test('is owner-only: exporting another user\'s events throws', () async {
        expect(
          () => repository.exportCookEventsByUser('someone-else'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });
}
