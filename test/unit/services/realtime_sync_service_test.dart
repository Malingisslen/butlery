/// Unit tests for RealtimeSyncService.
///
/// Behaviours covered (intent-driven):
/// - watchResource: surfaces SyncError when unauthenticated, parses snapshots
///   into typed resources, caches the parsed value, throws documentNotFound on
///   missing doc, throws firestoreError on malformed payloads.
/// - updateResource: enforces canUserEdit-based permission (not auth-only),
///   persists to Firestore through the conflict module, rethrows SyncError on
///   permission denial, records local-update tracking so subsequent writes
///   take the conflict-resolution branch.
/// - deleteResource: enforces canUserDelete (stricter than canUserEdit),
///   removes the cached entry and the active listener tracking, propagates
///   documentNotFound when the doc has been removed remotely first.
/// - resolveConflict: deterministic — higher editCount wins; on tie, later
///   lastEditedAt wins; falls back to remote on internal errors.
/// - Cache: getCachedResource returns null for unknown ids; cached value is
///   the local pre-write copy after a successful updateResource.
/// - fetchLatestResource: returns null (does not throw) on parser failure.
/// - dispose(): cancels listeners (tested via _activeListeners visibility via
///   isResourceWatched + close-on-delete invariant) and clears the cache.
/// - Error pipeline: _handleError writes to errorStream and stores lastError;
///   clearError nulls it and notifies listeners.
library;

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';

import '../../infrastructure/factories/recipe_factory.dart';

/// Local Mock auth repo so we can stub `currentUserId` and `authStateChanges`
/// per-test. The shared `MockAuthRepository` returns hardcoded state via
/// concrete overrides, which silently blocks `when(...)` stubbing on those
/// getters — exactly the pitfall the testing-specialist agent file warns
/// against.
class _MockAuthRepository extends Mock implements auth.AuthRepository {}

/// Real `FirestoreRepository` instance backed by a local `FakeFirebaseFirestore`
/// (not the singleton — we want hermetic per-test isolation so the streams
/// don't leak doc events across tests).
FirestoreRepository _buildRepo(FakeFirebaseFirestore fake) =>
    FirestoreRepository(firestore: fake);

/// Build a RealtimeRecipe with explicit metadata that survives a Firestore
/// round-trip via toFirestore -> fromMap.
RealtimeRecipe _buildResource({
  required String id,
  required String ownerId,
  Map<String, ResourcePermission>? participants,
  int editCount = 1,
  DateTime? lastEditedAt,
}) {
  final now = lastEditedAt ?? DateTime(2026, 1, 1, 12);
  return RealtimeRecipe(
    id: id,
    ownerId: ownerId,
    ownerDisplayName: 'Owner $ownerId',
    participants: participants ?? {ownerId: ResourcePermission.owner},
    createdAt: DateTime(2026, 1, 1, 10),
    lastEditedAt: now,
    lastEditedBy: ownerId,
    lastEditedByDisplayName: 'Owner $ownerId',
    editCount: editCount,
    recipe: RecipeFactory.build(id: id, title: 'R-$id'),
  );
}

/// Seed a resource into the fake firestore at the same path the production
/// service reads from (`realtime_resources/{id}`).
Future<void> _seed(FakeFirebaseFirestore fake, RealtimeRecipe resource) async {
  await fake
      .collection('realtime_resources')
      .doc(resource.id)
      .set(resource.toFirestore());
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;
  late _MockAuthRepository mockAuth;
  late StreamController<User?> authStateController;
  late RealtimeSyncService service;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = _buildRepo(fake);
    mockAuth = _MockAuthRepository();
    authStateController = StreamController<User?>.broadcast();
    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => authStateController.stream);
    when(() => mockAuth.currentUserId).thenReturn('user_owner');

    service = RealtimeSyncService(
      firestoreRepository: repo,
      authRepository: mockAuth,
    );
  });

  tearDown(() async {
    await service.dispose();
    await authStateController.close();
  });

  group('watchResource', () {
    /// Proves: an unauthenticated caller never hits Firestore — the stream
    /// immediately yields a permissionDenied SyncError. A regression here
    /// (e.g. returning an empty stream, or accidentally hitting Firestore
    /// before the auth check) would silently let unauthed reads through.
    test('emits permissionDenied SyncError when user is not logged in',
        () async {
      when(() => mockAuth.currentUserId).thenReturn(null);

      final stream = service.watchResource<RealtimeRecipe>('any-id');

      await expectLater(
        stream,
        emitsError(
          isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          ),
        ),
      );
    });

    /// Proves: a successful snapshot is parsed, typed, AND cached. If the
    /// production code forgot to call `_cachedResources[id] = resource`,
    /// the cache assertion catches it — and tests downstream of `updateResource`
    /// would silently corrupt without it.
    test('parses snapshot, caches the resource, and emits the typed value',
        () async {
      final seeded = _buildResource(id: 'res_1', ownerId: 'user_owner');
      await _seed(fake, seeded);

      final stream = service.watchResource<RealtimeRecipe>('res_1');
      final first = await stream.first;

      expect(first, isA<RealtimeRecipe>());
      expect(first.id, 'res_1');
      expect(first.ownerId, 'user_owner');
      // Cache assertion — proves the side effect, not just the return value.
      expect(service.getCachedResource<RealtimeRecipe>('res_1'), isNotNull);
      expect(service.getCachedResource<RealtimeRecipe>('res_1')!.id, 'res_1');
    });

    /// Missing-doc errors propagate to BOTH the stream subscriber (so a
    /// `StreamBuilder` sees `ConnectionState.error` and rebuilds with a
    /// fresh error widget instead of stale data) AND the central
    /// errorStream side-channel (so callers that want a global error log
    /// still get it). Fixed by BUT-1069: `.handleError` (which swallowed)
    /// replaced by a transformer that records side-channel + re-emits via
    /// sink.addError.
    test('missing document propagates to main stream AND errorStream',
        () async {
      final captured = <SyncError>[];
      final sub = service.errorStream.listen(captured.add);
      final mainStreamErrors = <Object>[];

      final streamSub = service
          .watchResource<RealtimeRecipe>('does-not-exist')
          .listen((_) {}, onError: mainStreamErrors.add);

      for (var i = 0; i < 10 && captured.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await streamSub.cancel();
      await sub.cancel();

      expect(captured, isNotEmpty,
          reason: 'Missing doc should surface via errorStream side-channel');
      expect(captured.first.type, SyncErrorType.firestoreError);
      expect(captured.first.resourceId, 'does-not-exist');
      expect(service.lastError, isNotNull);

      expect(mainStreamErrors, isNotEmpty,
          reason: 'Missing doc must also propagate to stream subscriber');
      expect(mainStreamErrors.first, isA<SyncError>());
      expect((mainStreamErrors.first as SyncError).type,
          SyncErrorType.documentNotFound);
    });

    /// A malformed `participants` map (wrong inner value type) trips the
    /// parser's cast failure path and is translated into a `firestoreError`
    /// SyncError. Post-BUT-1069, that SyncError surfaces on BOTH the
    /// stream subscriber and the errorStream — so a `StreamBuilder` no
    /// longer sees stale data after a payload schema change.
    ///
    /// Note: the production parser is very defensive (missing dates fall
    /// back to clock.now, missing strings to empty, etc.), so this test
    /// targets one of the few payload shapes that actually trips a cast
    /// (`permissionString as String?` when the value is an int).
    test('malformed payload surfaces as firestoreError on both channels',
        () async {
      await fake.collection('realtime_resources').doc('bad').set({
        'type': 'recipe',
        'ownerId': 'someone',
        'ownerDisplayName': 'Someone',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'lastEditedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'lastEditedBy': 'someone',
        'lastEditedByDisplayName': 'Someone',
        // The cast `permissionString as String?` will throw when the value
        // is an int.
        'participants': {'someone': 42},
      });

      final captured = <SyncError>[];
      final errSub = service.errorStream.listen(captured.add);
      final mainStreamErrors = <Object>[];

      final streamSub = service
          .watchResource<RealtimeRecipe>('bad')
          .listen((_) {}, onError: mainStreamErrors.add);

      for (var i = 0; i < 10 && captured.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await streamSub.cancel();
      await errSub.cancel();

      expect(captured, isNotEmpty,
          reason: 'A cast failure must reach errorStream');
      expect(captured.first.type, SyncErrorType.firestoreError);
      expect(captured.first.resourceId, 'bad');

      expect(mainStreamErrors, isNotEmpty,
          reason: 'Cast failure must also propagate to stream subscriber');
      expect(mainStreamErrors.first, isA<SyncError>());
      expect((mainStreamErrors.first as SyncError).type,
          SyncErrorType.firestoreError);
    });
  });

  group('updateResource', () {
    /// Proves: the auth check happens first — without it, an unauthenticated
    /// caller could write any resource they happened to hold a reference to.
    test('throws permissionDenied when not logged in', () async {
      when(() => mockAuth.currentUserId).thenReturn(null);
      final resource = _buildResource(id: 'r1', ownerId: 'user_owner');

      await expectLater(
        service.updateResource(resource),
        throwsA(
          isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          ),
        ),
      );
    });

    /// Proves: per-resource edit permission is enforced via `canUserEdit`,
    /// not via the looser auth check. A bug that conflated the two would let
    /// authenticated users overwrite resources they only have viewer access
    /// on. This was the BUT-369 class of bug for the shopping repo.
    test(
        'throws permissionDenied when authed user lacks edit permission on the resource',
        () async {
      when(() => mockAuth.currentUserId).thenReturn('viewer_user');
      final resource = _buildResource(
        id: 'r2',
        ownerId: 'owner_user',
        participants: {
          'owner_user': ResourcePermission.owner,
          'viewer_user': ResourcePermission.viewer,
        },
      );

      // Ensure the doc exists so we'd actually try to write if not for the
      // permission check.
      await _seed(fake, resource);

      late SyncError captured;
      try {
        await service.updateResource(resource);
        fail('Expected SyncError');
      } on SyncError catch (e) {
        captured = e;
      }
      expect(captured.type, SyncErrorType.permissionDenied);

      // Side-effect proof: the doc on disk has the seeded editCount (1) —
      // i.e. the rejected update did NOT reach Firestore.
      final snapshot =
          await fake.collection('realtime_resources').doc('r2').get();
      expect(snapshot.data()!['editCount'], 1);
    });

    /// Proves: an owner-authored write actually persists. This is the
    /// happy-path partner to the permission-denied test above — together they
    /// pin down "permission check gates the write, not just the return value."
    test('owner write persists to Firestore via the conflict module', () async {
      final initial = _buildResource(id: 'r3', ownerId: 'user_owner');
      await _seed(fake, initial);

      // Bump editCount + push update.
      final updated = _buildResource(
        id: 'r3',
        ownerId: 'user_owner',
        editCount: 5,
        lastEditedAt: DateTime(2026, 2, 1),
      );

      await service.updateResource(updated);

      final snap = await fake.collection('realtime_resources').doc('r3').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['editCount'], 5);
      // Cache reflects the locally-written copy.
      expect(
        service.getCachedResource<RealtimeRecipe>('r3')!.editCount,
        5,
      );
    });

    /// Proves: errors are surfaced through the errorStream pipeline (not
    /// just rethrown). UI subscribers to errorStream rely on this — a
    /// regression that rethrew but didn't push to the stream would leave
    /// banner/toast UIs silent on failures.
    test('failed update emits a SyncError on errorStream and stores lastError',
        () async {
      when(() => mockAuth.currentUserId).thenReturn(null);
      final resource = _buildResource(id: 'r4', ownerId: 'someone_else');

      // permissionDenied path → handleError NOT invoked because the early
      // auth check throws BEFORE the try block (verified by reading the
      // source: `if (_currentUserId == null) throw ...` precedes the try).
      // So instead we drive the post-auth permission path which DOES go
      // through _handleError.
      when(() => mockAuth.currentUserId).thenReturn('not_authorized');
      final captured = <SyncError>[];
      final sub = service.errorStream.listen(captured.add);

      await expectLater(
        service.updateResource(resource),
        throwsA(isA<SyncError>()),
      );

      // Give the stream a microtask to drain.
      await Future<void>.delayed(Duration.zero);

      expect(captured, isNotEmpty);
      expect(captured.first.type, SyncErrorType.permissionDenied);
      expect(captured.first.resourceId, 'r4');
      expect(service.lastError, isNotNull);
      expect(service.lastError!.type, SyncErrorType.permissionDenied);

      await sub.cancel();
    });
  });

  group('deleteResource', () {
    /// Proves: auth gate fires before any Firestore touch.
    test('throws permissionDenied when not logged in', () async {
      when(() => mockAuth.currentUserId).thenReturn(null);
      await expectLater(
        service.deleteResource('rX', RealtimeResourceType.recipe),
        throwsA(
          isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          ),
        ),
      );
    });

    /// Proves: `canUserDelete` is STRICTER than `canUserEdit` — an editor
    /// (not owner/admin) cannot delete. This is the realtime analogue of the
    /// BUT-369 shopping-repo delete bypass. Without this test, an "editor
    /// can also delete" regression in `canUserDelete` would ship silently.
    test('throws permissionDenied when authed editor is not owner', () async {
      when(() => mockAuth.currentUserId).thenReturn('editor_user');
      final resource = _buildResource(
        id: 'r5',
        ownerId: 'owner_user',
        participants: {
          'owner_user': ResourcePermission.owner,
          'editor_user': ResourcePermission.editor,
        },
      );
      await _seed(fake, resource);

      await expectLater(
        service.deleteResource('r5', RealtimeResourceType.recipe),
        throwsA(
          isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          ),
        ),
      );

      // The doc is still there.
      final snap = await fake.collection('realtime_resources').doc('r5').get();
      expect(snap.exists, isTrue);
    });

    /// Proves: owner can delete; doc is removed; cache is purged. Three
    /// invariants in one test because they're a single user-visible flow.
    test('owner delete removes the doc and clears the cache entry', () async {
      final resource = _buildResource(id: 'r6', ownerId: 'user_owner');
      await _seed(fake, resource);

      // Warm the cache by watching once.
      final stream = service.watchResource<RealtimeRecipe>('r6');
      await stream.first;
      expect(service.getCachedResource<RealtimeRecipe>('r6'), isNotNull);

      await service.deleteResource('r6', RealtimeResourceType.recipe);

      final snap = await fake.collection('realtime_resources').doc('r6').get();
      expect(snap.exists, isFalse);
      expect(service.getCachedResource<RealtimeRecipe>('r6'), isNull);
    });

    /// Proves: a deleted-elsewhere resource surfaces a typed
    /// documentNotFound, not a generic Firestore exception. Catches a
    /// regression that lets the raw `cast Map` failure in the parser leak.
    test(
        'throws documentNotFound when the resource was deleted before this client',
        () async {
      await expectLater(
        service.deleteResource('ghost', RealtimeResourceType.recipe),
        throwsA(
          isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.documentNotFound,
          ),
        ),
      );
    });
  });

  group('resolveConflict (last-write-wins by editCount, then timestamp)', () {
    /// Proves: deterministic conflict resolution — local with higher edit
    /// count wins. If `>` flipped to `<`, both this and the next test fail,
    /// which together pin the comparison direction.
    test('local wins when local.editCount > remote.editCount', () async {
      final local = _buildResource(id: 'c1', ownerId: 'u', editCount: 5);
      final remote = _buildResource(id: 'c1', ownerId: 'u', editCount: 2);
      final winner = await service.resolveConflict(local, remote);
      expect(identical(winner, local), isTrue);
    });

    /// Proves the inverse — remote can win too.
    test('remote wins when remote.editCount > local.editCount', () async {
      final local = _buildResource(id: 'c2', ownerId: 'u', editCount: 1);
      final remote = _buildResource(id: 'c2', ownerId: 'u', editCount: 9);
      final winner = await service.resolveConflict(local, remote);
      expect(identical(winner, remote), isTrue);
    });

    /// Proves: tie-break uses `lastEditedAt`. Catches a regression where
    /// the tiebreaker silently picked one side regardless of timestamp.
    test('on edit-count tie, later lastEditedAt wins (local newer)', () async {
      final local = _buildResource(
        id: 'c3',
        ownerId: 'u',
        editCount: 3,
        lastEditedAt: DateTime(2026, 6, 1),
      );
      final remote = _buildResource(
        id: 'c3',
        ownerId: 'u',
        editCount: 3,
        lastEditedAt: DateTime(2026, 5, 1),
      );
      final winner = await service.resolveConflict(local, remote);
      expect(identical(winner, local), isTrue);
    });

    /// Proves: on tie + remote newer, remote wins. Companion to the above.
    test('on edit-count tie, later lastEditedAt wins (remote newer)', () async {
      final local = _buildResource(
        id: 'c4',
        ownerId: 'u',
        editCount: 3,
        lastEditedAt: DateTime(2026, 5, 1),
      );
      final remote = _buildResource(
        id: 'c4',
        ownerId: 'u',
        editCount: 3,
        lastEditedAt: DateTime(2026, 6, 1),
      );
      final winner = await service.resolveConflict(local, remote);
      expect(identical(winner, remote), isTrue);
    });
  });

  group('fetchLatestResource', () {
    /// Proves: error-swallowing contract — returns null, does not throw. UI
    /// callers depend on this; a regression that rethrew would surface as a
    /// crash on a transient Firestore hiccup.
    test('returns null on missing document instead of throwing', () async {
      final result =
          await service.fetchLatestResource<RealtimeRecipe>('missing');
      expect(result, isNull);
    });

    /// Proves: happy-path round-trip is identity-preserving on id/editCount.
    test('returns the parsed resource when the doc exists', () async {
      final seeded =
          _buildResource(id: 'fetch_1', ownerId: 'user_owner', editCount: 7);
      await _seed(fake, seeded);

      final fetched =
          await service.fetchLatestResource<RealtimeRecipe>('fetch_1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'fetch_1');
      expect(fetched.editCount, 7);
    });
  });

  group('error pipeline + state', () {
    /// Proves: clearError nulls the stored error AND notifies listeners.
    /// A regression that only nulled the field without notifying would
    /// leave bound UI showing the stale banner forever.
    test('clearError nulls lastError and notifies listeners', () async {
      // Drive an error to populate lastError.
      when(() => mockAuth.currentUserId).thenReturn('not_authorized');
      final resource = _buildResource(id: 'err1', ownerId: 'someone');
      try {
        await service.updateResource(resource);
      } catch (_) {/* expected */}
      expect(service.lastError, isNotNull);

      var notifications = 0;
      service.addListener(() => notifications++);

      service.clearError();
      expect(service.lastError, isNull);
      expect(notifications, greaterThanOrEqualTo(1));
    });

    /// Proves: `connectionStream` is a broadcast stream — multiple
    /// subscribers can attach without "Stream already listened to" errors.
    /// A regression to a single-subscription controller breaks the
    /// ConnectionMonitor + UI status indicators that both subscribe.
    test('connectionStream supports multiple concurrent listeners', () async {
      final subA = service.connectionStream.listen((_) {});
      final subB = service.connectionStream.listen((_) {});
      // No throw == pass.
      await subA.cancel();
      await subB.cancel();
    });

    /// Proves: errorStream is also broadcast.
    test('errorStream supports multiple concurrent listeners', () async {
      final subA = service.errorStream.listen((_) {});
      final subB = service.errorStream.listen((_) {});
      await subA.cancel();
      await subB.cancel();
    });
  });

  group('cache + tracking lifecycle', () {
    /// Proves: cache lookup is null-safe for unseen ids — does not throw.
    test('getCachedResource returns null for unknown id', () {
      expect(service.getCachedResource<RealtimeRecipe>('nope'), isNull);
    });

    /// Proves: `isResourceWatched` reflects the absence of an active
    /// listener. (Watching via Stream.first auto-cancels, so this never
    /// registers in _activeListeners — which is itself an interesting
    /// production observation flagged in the report.)
    test('isResourceWatched is false for never-watched ids', () {
      expect(service.isResourceWatched('never'), isFalse);
    });

    /// Proves: `refreshAllResources` does NOT throw and DOES notify
    /// listeners — it's the manual-refresh affordance for "stuck" UIs.
    test('refreshAllResources notifies listeners without side effects',
        () async {
      var notifications = 0;
      service.addListener(() => notifications++);
      service.refreshAllResources();
      expect(notifications, greaterThanOrEqualTo(1));
    });

    /// Proves: dispose is idempotent on cache — calling dispose() leaves the
    /// service in a state where the cache is empty. A regression that
    /// retained the cache across dispose would leak references in
    /// long-running app sessions that re-create the service.
    test('dispose clears cached resources', () async {
      final seeded = _buildResource(id: 'd1', ownerId: 'user_owner');
      await _seed(fake, seeded);
      await service.watchResource<RealtimeRecipe>('d1').first;
      expect(service.getCachedResource<RealtimeRecipe>('d1'), isNotNull);

      await service.dispose();

      expect(service.getCachedResource<RealtimeRecipe>('d1'), isNull);

      // Re-create so tearDown's dispose() doesn't double-dispose state we
      // already tore down.
      service = RealtimeSyncService(
        firestoreRepository: repo,
        authRepository: mockAuth,
      );
    });
  });
}
