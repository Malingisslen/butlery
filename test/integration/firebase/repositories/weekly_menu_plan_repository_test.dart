/// Integration tests for [FirebaseWeeklyMenuPlanRepository] (BUT-361).
///
/// Exercises deterministic doc-ID upsert semantics, missing-doc null return,
/// owner-prefix range delete, >500-doc batch chunking, and the internal
/// permission-method invariants. Cross-user WRITE blocking is firestore.rules'
/// job — `save` passes the CLAIMED owner.
///
/// Uses FakeFirebaseFirestore + MockFirebaseAuth (Fake Lane, post-BUT-389).
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../test_support/test_data_isolator.dart';

const _collection = FirestoreCollections.weeklyMenuPlans;

WeeklyMenuPlan _buildPlan({
  required String userId,
  required DateTime weekStart,
  List<WeeklyMenuPlanEntry> entries = const [],
}) {
  final created = DateTime(2026, 4, 18, 12);
  return WeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor(userId, weekStart),
    userId: userId,
    weekStartDate: IsoWeekUtils.weekStartOf(weekStart),
    entries: entries,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  group('FirebaseWeeklyMenuPlanRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseWeeklyMenuPlanRepository repository;
    late MockFirebaseAuth mockAuth;

    const ownerId = 'user-alpha';
    final weekStart = IsoWeekUtils.weekStartOf(
      DateTime(2026, 4, 13),
    ); // ISO week Mon

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      TestDataIsolator.initializeTest('WeeklyMenuPlanRepository');
      // Use a fresh in-memory Firestore per test — the shared singleton's
      // nuke-and-recreate between tests would still work, but a local
      // instance sidesteps any residual mutation across the suite.
      firestore = FakeFirebaseFirestore();

      mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: ownerId,
          email: 'alpha@example.com',
          displayName: 'Alpha',
        ),
        signedIn: true,
      );

      repository = FirebaseWeeklyMenuPlanRepository(
        firestore: firestore,
        authRepository: FirebaseAuthRepository(firebaseAuth: mockAuth),
      );
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('WeeklyMenuPlanRepository');
    });

    group('save (deterministic upsert)', () {
      test(
        'should use deterministic `{userId}_{YYYY}-W{WW}` doc ID so '
        'saving the same (user, week) twice does not create duplicates',
        () async {
          // Arrange — a plan for the current user + current ISO week.
          final planA = _buildPlan(userId: ownerId, weekStart: weekStart);

          // Act — save, mutate, save again. Deterministic ID means both writes
          // hit the same document.
          await repository.save(planA);

          final planB = planA.copyWith(
            entries: [
              WeeklyMenuPlanEntry.create(
                day: DayOfWeek.wed,
                slot: MealSlot.middag,
                recipeId: 'recipe-1',
                recipeTitle: 'Pasta',
              ),
            ],
          );
          await repository.save(planB);

          // Assert — exactly one doc in the collection, with the latest entries.
          final snapshot = await firestore.collection(_collection).get();
          expect(
            snapshot.docs,
            hasLength(1),
            reason: 'upsert must overwrite, not append a second doc',
          );
          expect(
            snapshot.docs.first.id,
            IsoWeekUtils.weekIdFor(ownerId, weekStart),
          );
          final entriesField = snapshot.docs.first.data()['entries'] as List;
          expect(entriesField, hasLength(1));
          expect((entriesField.first as Map)['recipeTitle'], 'Pasta');
        },
      );

      test('should refuse to persist a plan whose `userId` does not match the '
          'doc-ID prefix (internal self-consistency check)', () async {
        // Arrange — construct a WeeklyMenuPlan with a doc ID that does NOT
        // start with the entity's userId. `save()` calls
        // validateUpdatePermission(plan.userId, plan.id, plan), which
        // requires `resourceId.startsWith('${userId}_')`. The mismatch must
        // be refused, and the refusal must REACH THE CALLER.
        //
        // BUT-1962: this assertion used to read "save() must log-and-return
        // when canWrite is false" — it pinned the defect. A caller could not
        // tell a refusal from a completed save, so the user was shown nothing
        // when their week failed to persist.
        //
        // Scope note: save() uses `plan.userId` (not the authenticated user)
        // as the permission subject. Cross-user forgery blocking is the
        // domain of Firestore security rules, not this repository — the
        // permission methods here only enforce internal consistency. This
        // test pins that contract so future changes to the permission model
        // surface as test failures.
        final forged = WeeklyMenuPlan(
          id: 'spoofed_2026-W15',
          userId: 'user-beta',
          weekStartDate: IsoWeekUtils.weekStartOf(weekStart),
          entries: const [],
          createdAt: DateTime(2026, 4, 18, 12),
          updatedAt: DateTime(2026, 4, 18, 12),
        );

        // Act + assert — the refusal is visible to the caller.
        await expectLater(
          repository.save(forged),
          throwsA(isA<PermissionDeniedException>()),
        );

        // ...and still nothing reached Firestore. Both halves matter: the
        // throw alone would not prove the write was skipped, and the empty
        // collection alone was what the silent version also satisfied.
        final snapshot = await firestore.collection(_collection).get();
        expect(snapshot.docs, isEmpty);
      });
    });

    group('fetchForWeek', () {
      test('should return null for a week with no saved plan '
          '(callers treat null as empty, not as an error)', () async {
        // Arrange — Firestore is empty; no explicit setup required.

        // Act
        final result = await repository.fetchForWeek(
          userId: ownerId,
          weekStart: weekStart,
        );

        // Assert
        expect(result, isNull);
      });

      test(
        'should round-trip a saved plan, preserving entries and week anchor',
        () async {
          // Arrange
          final entry = WeeklyMenuPlanEntry.create(
            day: DayOfWeek.fri,
            slot: MealSlot.lunch,
            recipeId: 'recipe-fri-lunch',
            recipeTitle: 'Tacos',
          );
          final saved = _buildPlan(
            userId: ownerId,
            weekStart: weekStart,
            entries: [entry],
          );
          await repository.save(saved);

          // Act
          final fetched = await repository.fetchForWeek(
            userId: ownerId,
            weekStart: weekStart,
          );

          // Assert
          expect(fetched, isNotNull);
          expect(fetched!.id, IsoWeekUtils.weekIdFor(ownerId, weekStart));
          expect(fetched.userId, ownerId);
          expect(fetched.weekStartDate, IsoWeekUtils.weekStartOf(weekStart));
          expect(fetched.entries, hasLength(1));
          expect(fetched.entries.first.recipeTitle, 'Tacos');
        },
      );
    });

    group('deleteAllByUser — owner-prefix range delete', () {
      test('should delete only the target user\'s plans when multiple users '
          'have docs in the same collection', () async {
        // Arrange — seed 3 plans each for 3 users. All share the same
        // top-level collection; the doc-ID prefix is the only separator.
        const userIds = ['user-alpha', 'user-beta', 'user-gamma'];
        final weeks = [
          DateTime(2026, 4, 6), // w15 / prior
          DateTime(2026, 4, 13),
          DateTime(2026, 4, 20),
        ];
        for (final uid in userIds) {
          for (final w in weeks) {
            final docId = IsoWeekUtils.weekIdFor(uid, w);
            await firestore.collection(_collection).doc(docId).set({
              'userId': uid,
              'weekStartDate': Timestamp.fromDate(IsoWeekUtils.weekStartOf(w)),
              'entries': <Map<String, dynamic>>[],
              'createdAt': Timestamp.now(),
              'updatedAt': Timestamp.now(),
            });
          }
        }
        final before = await firestore.collection(_collection).get();
        expect(before.docs, hasLength(9), reason: 'seeded 3 users × 3 weeks');

        // Act — delete every plan belonging to user-alpha only.
        final deleted = await repository.deleteAllByUser('user-alpha');

        // Assert — deletion count matches and no other user's docs vanished.
        expect(deleted, 3);
        final after = await firestore.collection(_collection).get();
        expect(after.docs, hasLength(6));
        final remainingUsers = after.docs
            .map((d) => d.data()['userId'])
            .toSet();
        expect(remainingUsers, {'user-beta', 'user-gamma'});
      });

      test(
        'should return 0 and do nothing when the user has no plans',
        () async {
          // Arrange — empty collection. Caller is the authenticated user
          // (ownerId) deleting their own data; validateOwnership requires
          // the targetted userId to match the auth context.
          // Act
          final deleted = await repository.deleteAllByUser(ownerId);

          // Assert
          expect(deleted, 0);
        },
      );

      test('should chunk deletes through batchDeleteDocs when the result set '
          'exceeds the 500-op Firestore batch limit', () async {
        // Arrange — seed 600 docs for the authenticated user (ownerId).
        // validateOwnership requires the deleteAllByUser target to match
        // the caller's auth context. Weeks synthesised across 12 ISO
        // years to stay under the "53 weeks per year" ceiling while
        // giving us unique doc IDs.
        for (var i = 0; i < 600; i++) {
          final docId =
              '${ownerId}_${2010 + (i ~/ 53)}'
              '-W${((i % 53) + 1).toString().padLeft(2, '0')}';
          await firestore.collection(_collection).doc(docId).set({
            'userId': ownerId,
            'weekStartDate': Timestamp.now(),
            'entries': <Map<String, dynamic>>[],
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
        }
        final before = await firestore.collection(_collection).get();
        expect(before.docs, hasLength(600));

        // Also seed a different owner — must survive the bulk delete.
        await firestore.collection(_collection).doc('other-owner_2026-W15').set(
          {
            'userId': 'other-owner',
            'weekStartDate': Timestamp.now(),
            'entries': <Map<String, dynamic>>[],
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          },
        );

        // Act — call deleteAllByUser. The implementation's batchDeleteDocs
        // helper has to split >500 docs across >1 batches (500-op limit).
        final deleted = await repository.deleteAllByUser(ownerId);

        // Assert — all 600 bulk docs gone, the unrelated user's doc untouched.
        expect(
          deleted,
          600,
          reason: 'batch chunking must not drop docs past the 500 boundary',
        );
        final after = await firestore.collection(_collection).get();
        expect(after.docs, hasLength(1));
        expect(after.docs.single.data()['userId'], 'other-owner');
      });
    });

    group('permission filter (doc-ID prefix)', () {
      test('validateUpdatePermission should reject when either entity.userId '
          'or the resourceId prefix does not match the caller', () async {
        // Caller is ownerId. Three forged combinations, all must fail.

        // 1. entity.userId mismatch, resourceId prefix match.
        final mismatchedEntity = _buildPlan(
          userId: 'user-beta',
          weekStart: weekStart,
        );
        final docIdOwned = IsoWeekUtils.weekIdFor(ownerId, weekStart);
        expect(
          await repository.validateUpdatePermission(
            ownerId,
            docIdOwned,
            mismatchedEntity,
          ),
          isFalse,
        );

        // 2. entity.userId match, resourceId prefix mismatch.
        final mismatchedResource = _buildPlan(
          userId: ownerId,
          weekStart: weekStart,
        );
        expect(
          await repository.validateUpdatePermission(
            ownerId,
            'user-beta_2026-W15',
            mismatchedResource,
          ),
          isFalse,
        );

        // 3. Both match — should pass.
        expect(
          await repository.validateUpdatePermission(
            ownerId,
            docIdOwned,
            mismatchedResource,
          ),
          isTrue,
        );
      });

      test('validateReadPermission / validateDeletePermission should accept '
          'only docs prefixed with the caller userId', () async {
        // Arrange — two candidate doc IDs, one owned, one foreign.
        final owned = '${ownerId}_2026-W15';
        const foreign = 'user-beta_2026-W15';

        // Assert — read perms
        expect(
          await repository.validateReadPermission(ownerId, owned, null),
          isTrue,
        );
        expect(
          await repository.validateReadPermission(ownerId, foreign, null),
          isFalse,
        );

        // Assert — delete perms
        expect(
          await repository.validateDeletePermission(ownerId, owned),
          isTrue,
        );
        expect(
          await repository.validateDeletePermission(ownerId, foreign),
          isFalse,
        );
      });

      test(
        'validateCreatePermission should require entity.userId == caller',
        () async {
          final ownedEntity = _buildPlan(userId: ownerId, weekStart: weekStart);
          final foreignEntity = _buildPlan(
            userId: 'user-beta',
            weekStart: weekStart,
          );

          expect(
            await repository.validateCreatePermission(ownerId, ownedEntity),
            isTrue,
          );
          expect(
            await repository.validateCreatePermission(ownerId, foreignEntity),
            isFalse,
          );
        },
      );
    });
  });
}
