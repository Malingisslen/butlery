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
/// - Cache: getCachedResource returns null for unknown ids; cached value is
///   the local pre-write copy after a successful updateResource.
/// - fetchLatestResource: returns null (does not throw) on parser failure.
/// - dispose(): clears the cache (consumer code owns the stream
///   subscriptions returned by watchResource; the service does not track
///   them).
/// - Error pipeline: _handleError writes to errorStream and stores lastError;
///   clearError nulls it and notifies listeners.
library;

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:clock/clock.dart';
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
    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer((_) => authStateController.stream);
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
    test(
      'emits permissionDenied SyncError when user is not logged in',
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
      },
    );

    /// Proves: a successful snapshot is parsed, typed, AND cached. If the
    /// production code forgot to call `_cachedResources[id] = resource`,
    /// the cache assertion catches it — and tests downstream of `updateResource`
    /// would silently corrupt without it.
    test(
      'parses snapshot, caches the resource, and emits the typed value',
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
      },
    );

    /// Missing-doc errors propagate to BOTH the stream subscriber (so a
    /// `StreamBuilder` sees `ConnectionState.error` and rebuilds with a
    /// fresh error widget instead of stale data) AND the central
    /// errorStream side-channel (so callers that want a global error log
    /// still get it). Fixed by BUT-1069: `.handleError` (which swallowed)
    /// replaced by a transformer that records side-channel + re-emits via
    /// sink.addError.
    test(
      'missing document propagates to main stream AND errorStream',
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

        expect(
          captured,
          isNotEmpty,
          reason: 'Missing doc should surface via errorStream side-channel',
        );
        expect(captured.first.type, SyncErrorType.firestoreError);
        expect(captured.first.resourceId, 'does-not-exist');
        expect(service.lastError, isNotNull);

        expect(
          mainStreamErrors,
          isNotEmpty,
          reason: 'Missing doc must also propagate to stream subscriber',
        );
        expect(mainStreamErrors.first, isA<SyncError>());
        expect(
          (mainStreamErrors.first as SyncError).type,
          SyncErrorType.documentNotFound,
        );
      },
    );

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
    test(
      'malformed payload surfaces as firestoreError on both channels',
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

        expect(
          captured,
          isNotEmpty,
          reason: 'A cast failure must reach errorStream',
        );
        expect(captured.first.type, SyncErrorType.firestoreError);
        expect(captured.first.resourceId, 'bad');

        expect(
          mainStreamErrors,
          isNotEmpty,
          reason: 'Cast failure must also propagate to stream subscriber',
        );
        expect(mainStreamErrors.first, isA<SyncError>());
        expect(
          (mainStreamErrors.first as SyncError).type,
          SyncErrorType.firestoreError,
        );
      },
    );
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
        final snapshot = await fake
            .collection('realtime_resources')
            .doc('r2')
            .get();
        expect(snapshot.data()!['editCount'], 1);
      },
    );

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

    /// Proves the cache-coherence guarantee on the conflict-LOSS path: when
    /// conflict resolution picks the REMOTE (the local edit lost), the local
    /// cache must reflect the persisted remote winner — NOT the discarded
    /// local copy. A regression that caches the local loser would make
    /// `getCachedResource` hand out an edit that never reached Firestore,
    /// silently diverging cache from disk and corrupting any read-modify-write
    /// keyed off the cache.
    test(
      'cache reflects the remote winner after a conflict the local lost',
      () async {
        await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
          // Seed an initial doc and warm the conflict-tracking window by doing a
          // first owner write (this calls recordLocalUpdate internally).
          final initial = _buildResource(
            id: 'conf1',
            ownerId: 'user_owner',
            editCount: 1,
            lastEditedAt: DateTime(2026, 4, 1, 11, 59),
          );
          await _seed(fake, initial);
          await service.updateResource(initial);

          // A collaborator overwrites the doc with a HIGHER editCount and a
          // timestamp strictly after our recorded local update — so the next
          // write enters conflict resolution and the remote wins.
          final collaborator = _buildResource(
            id: 'conf1',
            ownerId: 'user_owner',
            editCount: 9,
            lastEditedAt: DateTime(2026, 4, 1, 12, 0, 1),
          );
          await _seed(fake, collaborator);

          // Our losing local edit: same id, LOWER editCount than the remote.
          final losingLocal = _buildResource(
            id: 'conf1',
            ownerId: 'user_owner',
            editCount: 2,
            lastEditedAt: DateTime(2026, 4, 1, 11, 59, 30),
          );

          await service.updateResource(losingLocal);

          // Disk holds the remote winner (editCount 9), unchanged by our loss.
          final snap = await fake
              .collection('realtime_resources')
              .doc('conf1')
              .get();
          expect(
            snap.data()!['editCount'],
            9,
            reason: 'remote won → Firestore keeps the collaborator version',
          );

          // Cache must match the persisted winner, not our discarded edit (2).
          expect(
            service.getCachedResource<RealtimeRecipe>('conf1')!.editCount,
            9,
            reason:
                'cache must mirror the persisted remote winner, '
                'not the local edit that lost the conflict',
          );
        });
      },
    );

    /// Proves: errors are surfaced through the errorStream pipeline (not
    /// just rethrown). UI subscribers to errorStream rely on this — a
    /// regression that rethrew but didn't push to the stream would leave
    /// banner/toast UIs silent on failures.
    test(
      'failed update emits a SyncError on errorStream and stores lastError',
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
      },
    );
  });

  group('recoverLocalVersion (BUT-1163 conflict recovery)', () {
    /// Proves the core of the BUT-1163 fix: when a local version that LOST a
    /// conflict is recovered, it must be written back with an editCount that
    /// BEATS the current remote — not the stale (losing) editCount it carried.
    /// Otherwise the next concurrent edit would silently discard it again.
    test(
      'writes the local content back with editCount = remote.editCount + 1',
      () async {
        // Remote currently sits at editCount 9 (it won the conflict).
        final remote = _buildResource(
          id: 'rec1',
          ownerId: 'user_owner',
          editCount: 9,
          lastEditedAt: DateTime(2026, 3, 1),
        );
        await _seed(fake, remote);

        // The local snapshot the user is recovering carries the LOSING count (4).
        final losingLocal = _buildResource(
          id: 'rec1',
          ownerId: 'user_owner',
          editCount: 4,
          lastEditedAt: DateTime(2026, 2, 1),
        );

        await service.recoverLocalVersion(losingLocal);

        final snap = await fake
            .collection('realtime_resources')
            .doc('rec1')
            .get();
        expect(
          snap.data()!['editCount'],
          10,
          reason:
              'recovered version must outrank the remote that beat it '
              '(9 + 1), not re-persist its own stale 4',
        );
      },
    );

    /// Proves the fallback path: if the remote can't be read, the recovery
    /// still bumps the local snapshot's own counter rather than regressing it.
    test(
      'bumps the local counter when no remote exists to compare against',
      () async {
        final local = _buildResource(
          id: 'rec2',
          ownerId: 'user_owner',
          editCount: 3,
        );
        // No seed → getLatestResource throws documentNotFound, caught internally.

        await service.recoverLocalVersion(local);

        final snap = await fake
            .collection('realtime_resources')
            .doc('rec2')
            .get();
        expect(
          snap.data()!['editCount'],
          4,
          reason:
              'no remote to beat → bump the local snapshot (3 + 1), '
              'never write back the un-incremented 3',
        );
      },
    );

    /// BUT-1263: recovery must stamp authorship AND time, not just bump the
    /// counter. `recoverLocalVersion` sets `lastEditedBy: _currentUserId` and
    /// `lastEditedAt: clock.now()`. The other recovery tests only assert
    /// editCount, so a regression that dropped either stamp (e.g. re-persisting
    /// the snapshot's own stale author/time, which is the bug recoverLocalVersion
    /// exists to avoid) would slip through. Under a fixed clock and a recovering
    /// user distinct from the snapshot's author, we pin both: the persisted doc
    /// must record the recovering user as editor and the clock's instant as the
    /// edit time — so the resolver's timestamp tiebreaker and the audit trail
    /// both reflect who actually recovered it and when.
    test(
      'stamps lastEditedBy = current user and lastEditedAt = clock.now()',
      () async {
        final fixedNow = DateTime(2026, 5, 10, 9, 30, 15);

        await withClock(Clock.fixed(fixedNow), () async {
          // The recovering user differs from the snapshot's original author so
          // the authorship bump is observable (not a coincidental match).
          when(() => mockAuth.currentUserId).thenReturn('recovering_user');

          // Local snapshot authored by someone else, carrying a stale edit time.
          final local = RealtimeRecipe(
            id: 'rec_stamp',
            ownerId: 'user_owner',
            ownerDisplayName: 'Owner user_owner',
            participants: const {
              'user_owner': ResourcePermission.owner,
              'recovering_user': ResourcePermission.editor,
            },
            createdAt: DateTime(2026, 1, 1, 10),
            lastEditedAt: DateTime(2026, 2, 1, 8),
            lastEditedBy: 'original_author',
            lastEditedByDisplayName: 'Original Author',
            editCount: 4,
            recipe: RecipeFactory.build(id: 'rec_stamp', title: 'R-rec_stamp'),
          );
          // No seed → fall back to local's own counter, but the stamps are what
          // this test asserts, independent of the editCount path.

          await service.recoverLocalVersion(local);

          final snap = await fake
              .collection('realtime_resources')
              .doc('rec_stamp')
              .get();
          final data = snap.data()!;

          expect(
            data['lastEditedBy'],
            'recovering_user',
            reason:
                'recovery must record the user who recovered it, '
                'not the snapshot\'s original author',
          );
          expect(
            (data['lastEditedAt'] as Timestamp).toDate(),
            fixedNow,
            reason:
                'recovery must stamp the current clock instant, '
                'not re-persist the snapshot\'s stale lastEditedAt',
          );
        });
      },
    );

    /// BUT-1264: covers the guard's FALSE branch. The bump is based on
    /// `max(local.editCount, remote.editCount) + 1` via
    /// `if (remote.editCount > baseEditCount)`. The "+1 over remote" test
    /// exercises the TRUE branch (remote ahead); the "no remote" test skips the
    /// comparison entirely. This case has a remote that exists but is at or
    /// below the local count, so the guard is false and the bump must come from
    /// LOCAL's own count — proving recovery never regresses a local edit that
    /// already outranks (or ties) the remote.
    test(
      'uses local.editCount + 1 when remote.editCount <= local.editCount',
      () async {
        // Remote sits BEHIND the local snapshot (5 <= 7).
        final remote = _buildResource(
          id: 'rec3',
          ownerId: 'user_owner',
          editCount: 5,
          lastEditedAt: DateTime(2026, 2, 1),
        );
        await _seed(fake, remote);

        // Local carries the HIGHER count.
        final local = _buildResource(
          id: 'rec3',
          ownerId: 'user_owner',
          editCount: 7,
          lastEditedAt: DateTime(2026, 3, 1),
        );

        await service.recoverLocalVersion(local);

        final snap = await fake
            .collection('realtime_resources')
            .doc('rec3')
            .get();
        expect(
          snap.data()!['editCount'],
          8,
          reason:
              'guard false (remote 5 <= local 7) → bump local (7 + 1), '
              'never drop down to the lagging remote count',
        );
      },
    );
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
      },
    );
  });

  // BUT-1267: the service-level resolveConflict<T>(local, remote) was dead
  // (no caller — updateResource routes through _conflictModule.resolveConflict,
  // which emits ConflictEvents the service-level copy silently omitted). It and
  // its four last-write-wins pinning tests were removed. The same editCount/
  // timestamp algorithm is now pinned at the module level (with the conflict
  // emission it must carry) in
  // test/unit/services/realtime/conflict_resolution_module_test.dart.

  group('conflictStream (BUT-1265 live delivery end-to-end)', () {
    /// BUT-1265: end-to-end proof that a REAL losing-local conflict — driven
    /// through `updateResource` → `shouldResolveConflict` → the real
    /// `resolveConflict` path — delivers exactly one `ConflictEvent` to a
    /// subscriber that attached BEFORE the conflicting write. The other
    /// conflict tests call `resolveConflict` directly (no stream) or assert
    /// only the cache side effect (line "cache reflects the remote winner");
    /// none verify the broadcast actually reaches a live `conflictStream`
    /// listener. A regression that severed the `onConflict` sink wiring (the
    /// `ConflictResolutionModule` → `_conflictController.add` hop in
    /// `_initializeModules`) would leave the ConflictBanner silent while every
    /// existing test stayed green. We subscribe first, drive a remote-wins
    /// conflict, and assert exactly one event with `chosenStrategy ==
    /// remoteWon` lands on the live subscriber — proving the resolver-to-UI
    /// pipe is intact, not just the resolver's return value.
    test(
      'delivers exactly one remoteWon ConflictEvent to a pre-subscribed listener',
      () async {
        await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
          final events = <ConflictEvent>[];
          // Subscribe BEFORE the conflicting write — this is the contract the
          // banner relies on (the subscriber is live when the conflict resolves).
          final sub = service.conflictStream.listen(events.add);

          // Warm the conflict-tracking window with a first owner write so the
          // next write enters the conflict-resolution branch.
          final initial = _buildResource(
            id: 'cs1',
            ownerId: 'user_owner',
            editCount: 1,
            lastEditedAt: DateTime(2026, 4, 1, 11, 59),
          );
          await _seed(fake, initial);
          await service.updateResource(initial);

          // A collaborator overwrites the doc with a HIGHER editCount and a
          // timestamp strictly after our recorded local update, so the resolver
          // picks the remote (the local edit loses).
          final collaborator = _buildResource(
            id: 'cs1',
            ownerId: 'user_owner',
            editCount: 9,
            lastEditedAt: DateTime(2026, 4, 1, 12, 0, 1),
          );
          await _seed(fake, collaborator);

          // Our losing local edit: lower editCount than the live remote.
          final losingLocal = _buildResource(
            id: 'cs1',
            ownerId: 'user_owner',
            editCount: 2,
            lastEditedAt: DateTime(2026, 4, 1, 11, 59, 30),
          );

          await service.updateResource(losingLocal);

          // Let the broadcast event drain to the live subscriber.
          await Future<void>.delayed(Duration.zero);
          await sub.cancel();

          expect(
            events,
            hasLength(1),
            reason:
                'exactly one conflict resolved → exactly one event '
                'on the live conflictStream subscriber',
          );
          expect(
            events.single.chosenStrategy,
            ConflictResolutionStrategy.remoteWon,
            reason:
                'remote had the higher editCount, so the resolver must '
                'report the local edit lost (remoteWon)',
          );
          expect(events.single.docId, 'cs1');
          expect(
            events.single.remoteValue.editCount,
            9,
            reason:
                'the winning remote (editCount 9) rides on the event so '
                'the banner can show what overwrote the local edit',
          );
        });
      },
    );
  });

  group('fetchLatestResource', () {
    /// Proves: error-swallowing contract — returns null, does not throw. UI
    /// callers depend on this; a regression that rethrew would surface as a
    /// crash on a transient Firestore hiccup.
    test('returns null on missing document instead of throwing', () async {
      final result = await service.fetchLatestResource<RealtimeRecipe>(
        'missing',
      );
      expect(result, isNull);
    });

    /// Proves: happy-path round-trip is identity-preserving on id/editCount.
    test('returns the parsed resource when the doc exists', () async {
      final seeded = _buildResource(
        id: 'fetch_1',
        ownerId: 'user_owner',
        editCount: 7,
      );
      await _seed(fake, seeded);

      final fetched = await service.fetchLatestResource<RealtimeRecipe>(
        'fetch_1',
      );
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
      } catch (_) {
        /* expected */
      }
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

    /// Proves: `refreshAllResources` does NOT throw and DOES notify
    /// listeners — it's the manual-refresh affordance for "stuck" UIs.
    test(
      'refreshAllResources notifies listeners without side effects',
      () async {
        var notifications = 0;
        service.addListener(() => notifications++);
        service.refreshAllResources();
        expect(notifications, greaterThanOrEqualTo(1));
      },
    );

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
