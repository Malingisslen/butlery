/// Unit tests for [FirebaseActivityEventRepository.addEvent].
///
/// `addEvent` is the only write path that bypasses [BaseFirebaseRepository.create]
/// to commit a two-document batch: the activity event itself plus a per-user
/// rate-limit marker that arms the firestore.rules `rateLimitWrite` burst gate.
/// These tests pin three behaviours of that path:
///   1. Deny path — a non-owner actorId is rejected with [PermissionDeniedException]
///      and writes nothing.
///   2. Success path — the event doc and the rate-limit marker are both written
///      in one commit, at their expected paths.
///   3. Audit — the permission check is recorded via the injected audit repository.
///
/// Two further groups cover the read fan-out and the GDPR cascade:
///   - `fetchFriendActivity` — a friend list spanning more than one `whereIn`
///     batch must still return a single globally-ordered, limit-capped page,
///     not just one batch's slice.
///   - `deleteAllByUser` — the GDPR bulk delete must gate on ownership: the
///     owner can wipe their own feed, a foreign caller cannot, and an empty
///     match returns 0 without touching the batch path.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/repositories/firebase/firebase_activity_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';

class MockAuditRepository extends Mock implements FirebaseAuditRepository {}

FirebaseActivityEventRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
  FirebaseAuditRepository? audit,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId, displayName: 'A'),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseActivityEventRepository(
    firestore: firestore,
    authRepository: mockAuth,
    auditRepository: audit,
  );
}

ActivityEvent _event({
  String id = 'evt-1',
  String actorId = _alice,
  DateTime? createdAt,
}) {
  return ActivityEvent(
    id: id,
    actorId: actorId,
    actorDisplayName: 'A',
    type: ActivityEventType.cooked,
    recipeId: 'recipe-1',
    recipeTitle: 'Köttbullar',
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('FirebaseActivityEventRepository.addEvent', () {
    test(
        'rejects an event whose actorId is not the authenticated user and '
        'writes nothing', () async {
      final firestore = FakeFirebaseFirestore();
      // Authenticated as alice, but the event claims bob is the actor.
      final repo = _repo(firestore, authedUserId: _alice);
      final foreignEvent = _event(id: 'evt-foreign', actorId: _bob);

      await expectLater(
        repo.addEvent(foreignEvent),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Neither the event nor a rate-limit marker should have been written.
      final eventDoc = await firestore
          .collection(FirestoreCollections.activityEvents)
          .doc('evt-foreign')
          .get();
      expect(eventDoc.exists, isFalse);

      final markerDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(_alice)
          .collection(FirestoreCollections.userRateLimits)
          .doc(FirestoreCollections.activityEvents)
          .get();
      expect(markerDoc.exists, isFalse);
    });

    test(
        'commits both the event doc and the rate-limit marker for an owned '
        'event', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      await repo.addEvent(_event(id: 'evt-1', actorId: _alice));

      // 1) The event doc lands in the top-level activity_events collection.
      final eventDoc = await firestore
          .collection(FirestoreCollections.activityEvents)
          .doc('evt-1')
          .get();
      expect(eventDoc.exists, isTrue);
      expect(eventDoc.data()!['actorId'], _alice);
      expect(eventDoc.data()!['recipeTitle'], 'Köttbullar');

      // 2) The rate-limit marker lands under the actor's rate_limits subcollection,
      //    keyed by the activity_events collection name, with a lastWrite +
      //    expireAt so the rules' burst gate is armed.
      final markerDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(_alice)
          .collection(FirestoreCollections.userRateLimits)
          .doc(FirestoreCollections.activityEvents)
          .get();
      expect(markerDoc.exists, isTrue);
      final marker = markerDoc.data()!;
      expect(marker.containsKey('lastWrite'), isTrue);
      expect(marker.containsKey('expireAt'), isTrue);
    });

    test('records the granted permission check via the audit repository',
        () async {
      final firestore = FakeFirebaseFirestore();
      final audit = MockAuditRepository();
      when(() => audit.logPermissionCheck(
            userId: any(named: 'userId'),
            operation: any(named: 'operation'),
            resourceType: any(named: 'resourceType'),
            resourceId: any(named: 'resourceId'),
            granted: any(named: 'granted'),
            metadata: any(named: 'metadata'),
          )).thenAnswer((_) async {});

      final repo = _repo(firestore, authedUserId: _alice, audit: audit);
      await repo.addEvent(_event(id: 'evt-audit', actorId: _alice));

      verify(() => audit.logPermissionCheck(
            userId: _alice,
            operation: 'create',
            resourceType: FirestoreCollections.activityEvents,
            resourceId: 'evt-audit',
            granted: true,
            metadata: any(named: 'metadata'),
          )).called(1);
    });
  });

  group('FirebaseActivityEventRepository.fetchFriendActivity', () {
    // Seeds one event per actor, with createdAt monotonically increasing in
    // actor index so the global ordering is fully determined: actor i's event
    // is older than actor i+1's. Newest events therefore belong to the
    // highest-indexed actors, which deliberately straddle the second whereIn
    // batch — proving the merge isn't just returning the first batch's slice.
    Future<List<String>> seedOnePerActor(
      FakeFirebaseFirestore firestore,
      int actorCount,
    ) async {
      final actorIds = <String>[];
      for (var i = 0; i < actorCount; i++) {
        final actorId = 'friend-${i.toString().padLeft(3, '0')}';
        actorIds.add(actorId);
        await firestore
            .collection(FirestoreCollections.activityEvents)
            .doc('evt-$i')
            .set(
              _event(
                id: 'evt-$i',
                actorId: actorId,
                createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
              ).toFirestore(),
            );
      }
      return actorIds;
    }

    test(
        'merges across two whereIn batches and returns the globally newest, '
        'descending, limit-capped page', () async {
      final firestore = FakeFirebaseFirestore();
      // 31 actors → two whereIn batches (30 + 1) under kFirestoreWhereInLimit.
      final actorIds = await seedOnePerActor(firestore, 31);
      final repo = _repo(firestore);

      const limit = 10;
      final result =
          await repo.fetchFriendActivity(friendIds: actorIds, limit: limit);

      // Capped at limit even though 31 events exist.
      expect(result.length, limit);

      // Strictly descending by createdAt (the cross-batch merge invariant).
      for (var i = 0; i < result.length - 1; i++) {
        expect(
          result[i].createdAt.isAfter(result[i + 1].createdAt),
          isTrue,
          reason: 'result must be descending by createdAt',
        );
      }

      // The newest `limit` events belong to the highest-indexed actors
      // (evt-30 down to evt-21). The single-actor second batch (evt-30) is the
      // newest of all — if the merge dropped it, the head would be wrong.
      final returnedIds = result.map((e) => e.id).toList();
      expect(returnedIds.first, 'evt-30');
      expect(
        returnedIds,
        [for (var i = 30; i > 30 - limit; i--) 'evt-$i'],
      );
    });

    test('returns an empty list for an empty friend list without querying',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final result = await repo.fetchFriendActivity(friendIds: const []);

      expect(result, isEmpty);
    });
  });

  group('FirebaseActivityEventRepository.deleteAllByUser', () {
    Future<void> seedEvents(
      FakeFirebaseFirestore firestore,
      String actorId,
      int count,
    ) async {
      for (var i = 0; i < count; i++) {
        await firestore
            .collection(FirestoreCollections.activityEvents)
            .doc('$actorId-evt-$i')
            .set(_event(id: '$actorId-evt-$i', actorId: actorId).toFirestore());
      }
    }

    Future<int> countEventsFor(
      FakeFirebaseFirestore firestore,
      String actorId,
    ) async {
      final snap = await firestore
          .collection(FirestoreCollections.activityEvents)
          .where('actorId', isEqualTo: actorId)
          .get();
      return snap.docs.length;
    }

    test('owner deletes own events: returns the count and removes the docs',
        () async {
      final firestore = FakeFirebaseFirestore();
      await seedEvents(firestore, _alice, 3);
      final repo = _repo(firestore, authedUserId: _alice);

      final deleted = await repo.deleteAllByUser(_alice);

      expect(deleted, 3);
      expect(await countEventsFor(firestore, _alice), 0);
    });

    test(
        'foreign caller cannot bulk-delete another user feed: throws and leaves '
        "the victim's docs intact", () async {
      final firestore = FakeFirebaseFirestore();
      await seedEvents(firestore, _bob, 3);
      // Authenticated as alice, attempting to wipe bob's feed.
      final repo = _repo(firestore, authedUserId: _alice);

      await expectLater(
        repo.deleteAllByUser(_bob),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Bob's events must all survive the denied cascade.
      expect(await countEventsFor(firestore, _bob), 3);
    });

    test('returns 0 when the owner has no events (empty-match early return)',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);

      final deleted = await repo.deleteAllByUser(_alice);

      expect(deleted, 0);
    });
  });
}
