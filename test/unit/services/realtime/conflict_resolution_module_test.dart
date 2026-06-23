/// BUT-1031: pin that ConflictResolutionModule.resolveConflict emits a
/// ConflictEvent through the injected onConflict sink for both winning sides.
///
/// Without the emission, last-write-wins is silent — the ConflictBanner has
/// nothing to render. The test exercises the module in isolation (no
/// RealtimeSyncService wiring) so the only signal under test is the callback
/// invocation per branch of the resolver.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/realtime/conflict_resolution_module.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _FakeFirestoreRepository extends Mock implements FirestoreRepository {}

RealtimeRecipe _makeRecipe({
  required String id,
  required int editCount,
  required DateTime lastEditedAt,
}) {
  return RealtimeRecipe(
    id: 'rt-$id',
    recipe: RecipeFactory.build(id: 'r-$id', title: 't-$id'),
    ownerId: 'owner',
    ownerDisplayName: 'owner',
    participants: const {'owner': ResourcePermission.owner},
    lastEditedAt: lastEditedAt,
    lastEditedBy: 'owner',
    lastEditedByDisplayName: 'owner',
    editCount: editCount,
  );
}

void main() {
  late ConflictResolutionModule module;
  late List<ConflictEvent> emitted;
  late _FakeFirestoreRepository repo;

  setUp(() {
    emitted = <ConflictEvent>[];
    repo = _FakeFirestoreRepository();
    module = ConflictResolutionModule(
      firestoreRepository: repo,
      getLatestResource: <T extends RealtimeResource>(_) async =>
          throw UnimplementedError(),
      onConflict: emitted.add,
      collectionPath: 'recipes',
    );
  });

  group('BUT-1031: resolveConflict emits ConflictEvent', () {
    test('localWon when local.editCount > remote.editCount', () async {
      final now = clock.now();
      final local = _makeRecipe(id: 'a', editCount: 5, lastEditedAt: now);
      final remote = _makeRecipe(id: 'a', editCount: 3, lastEditedAt: now);

      final result = await module.resolveConflict(local, remote);

      expect(result.editCount, 5, reason: 'local should win on editCount');
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.localWon,
      );
      expect(emitted.single.collectionPath, 'recipes');
      expect(emitted.single.docId, 'rt-a');
    });

    test('remoteWon when remote.editCount > local.editCount', () async {
      final now = clock.now();
      final local = _makeRecipe(id: 'a', editCount: 2, lastEditedAt: now);
      final remote = _makeRecipe(id: 'a', editCount: 7, lastEditedAt: now);

      final result = await module.resolveConflict(local, remote);

      expect(result.editCount, 7, reason: 'remote should win on editCount');
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.remoteWon,
      );
    });

    test('localWon on tied editCount + newer local timestamp', () async {
      final older = DateTime(2026, 1, 1);
      final newer = DateTime(2026, 1, 2);
      final local = _makeRecipe(id: 'a', editCount: 1, lastEditedAt: newer);
      final remote = _makeRecipe(id: 'a', editCount: 1, lastEditedAt: older);

      final result = await module.resolveConflict(local, remote);

      expect(result.lastEditedAt, newer);
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.localWon,
      );
    });

    test('remoteWon on tied editCount + newer remote timestamp', () async {
      final older = DateTime(2026, 1, 1);
      final newer = DateTime(2026, 1, 2);
      final local = _makeRecipe(id: 'a', editCount: 1, lastEditedAt: older);
      final remote = _makeRecipe(id: 'a', editCount: 1, lastEditedAt: newer);

      final result = await module.resolveConflict(local, remote);

      expect(result.lastEditedAt, newer);
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.remoteWon,
      );
    });
  });

  group('BUT-1266: shouldResolveConflict false branches', () {
    // The three ways shouldResolveConflict returns false without entering the
    // conflict-resolution path. Each branch matters: a regression flipping any
    // of them to `true` would make updateResource fetch the remote and run the
    // resolver on a write that has NO concurrent edit — needless reads plus a
    // spurious last-write-wins decision (and a phantom ConflictBanner). The
    // window boundary uses `<` (strictly inside), so exactly 5000ms is OUTSIDE
    // — we pin that off-by-one with a withClock boundary assertion.

    /// Tracks whether the remote was fetched, so each test can prove the branch
    /// short-circuited (or not) before the Firestore read.
    late bool remoteFetched;
    late DateTime remoteLastEditedAt;

    ConflictResolutionModule buildModule() => ConflictResolutionModule(
      firestoreRepository: repo,
      getLatestResource: <T extends RealtimeResource>(id) async {
        remoteFetched = true;
        return _makeRecipe(
              id: 'remote',
              editCount: 1,
              lastEditedAt: remoteLastEditedAt,
            )
            as T;
      },
    );

    setUp(() {
      remoteFetched = false;
      remoteLastEditedAt = DateTime(2026, 1, 1);
    });

    test('returns false when there is no prior recordLocalUpdate', () async {
      final m = buildModule();
      final resource = _makeRecipe(
        id: 'untracked',
        editCount: 1,
        lastEditedAt: DateTime(2026, 1, 1),
      );

      // No recordLocalUpdate(resource.id) was called → lastUpdate is null.
      final result = await m.shouldResolveConflict(resource);

      expect(
        result,
        isFalse,
        reason: 'an untracked resource has no local edit to conflict with',
      );
      expect(
        remoteFetched,
        isFalse,
        reason:
            'the null-lastUpdate branch must short-circuit before any '
            'Firestore read',
      );
    });

    test(
      'returns false at exactly the 5000ms window boundary (window elapsed)',
      () async {
        final m = buildModule();
        final start = DateTime(2026, 1, 1, 12);
        final resource = _makeRecipe(
          id: 'elapsed',
          editCount: 1,
          lastEditedAt: start,
        );

        // Record the local update at `start`, then evaluate the guard exactly
        // ConflictResolutionModule.conflictResolutionWindowMs (5000ms) later.
        // The guard is `timeSinceUpdate < 5000`, so 5000ms is OUTSIDE the window.
        await withClock(Clock.fixed(start), () async {
          m.recordLocalUpdate(resource.id);
        });

        final atBoundary = start.add(
          const Duration(
            milliseconds: ConflictResolutionModule.conflictResolutionWindowMs,
          ),
        );

        final result = await withClock(
          Clock.fixed(atBoundary),
          () => m.shouldResolveConflict(resource),
        );

        expect(
          result,
          isFalse,
          reason:
              'at exactly 5000ms the window has elapsed (strict `<`), so '
              'no conflict check runs',
        );
        expect(
          remoteFetched,
          isFalse,
          reason:
              'an elapsed window must short-circuit before the remote '
              'fetch — the edit is too old to be concurrent',
        );

        // Boundary proof: 1ms BEFORE the boundary is still INSIDE the window, so
        // the same setup DOES reach the remote fetch — pinning the `<` direction.
        remoteFetched = false;
        final justInside = atBoundary.subtract(const Duration(milliseconds: 1));
        await withClock(
          Clock.fixed(justInside),
          () => m.shouldResolveConflict(resource),
        );
        expect(
          remoteFetched,
          isTrue,
          reason:
              '4999ms is inside the window → the remote IS fetched, '
              'confirming the boundary is exclusive at 5000ms',
        );
      },
    );

    test(
      'returns false when remote.lastEditedAt is not after lastUpdate',
      () async {
        final m = buildModule();
        final start = DateTime(2026, 1, 1, 12);
        final resource = _makeRecipe(
          id: 'stale-remote',
          editCount: 1,
          lastEditedAt: start,
        );

        // Inside the window, but the remote's last edit is at-or-before our
        // recorded local update → no concurrent remote change → no conflict.
        remoteLastEditedAt = start;

        await withClock(Clock.fixed(start), () async {
          m.recordLocalUpdate(resource.id);
        });

        final result = await withClock(
          Clock.fixed(start.add(const Duration(seconds: 1))),
          () => m.shouldResolveConflict(resource),
        );

        expect(
          remoteFetched,
          isTrue,
          reason:
              'inside the window the remote MUST be read to compare '
              'timestamps',
        );
        expect(
          result,
          isFalse,
          reason:
              'remote.lastEditedAt == lastUpdate is not strictly after, '
              'so there is no newer remote edit to conflict with',
        );
      },
    );
  });

  test('onConflict callback is optional — no throw when null', () async {
    final silentModule = ConflictResolutionModule(
      firestoreRepository: repo,
      getLatestResource: <T extends RealtimeResource>(_) async =>
          throw UnimplementedError(),
    );
    final now = clock.now();
    final local = _makeRecipe(id: 'a', editCount: 5, lastEditedAt: now);
    final remote = _makeRecipe(id: 'a', editCount: 3, lastEditedAt: now);

    final result = await silentModule.resolveConflict(local, remote);

    expect(result.editCount, 5);
    // Implicit: no callback wired → no NPE, nothing in [emitted].
    expect(emitted, isEmpty);
  });
}
