/// BUT-1031: pin that ConflictResolutionModule.resolveConflict emits a
/// ConflictEvent through the injected onConflict sink for both winning sides.
///
/// Without the emission, last-write-wins is silent — the ConflictBanner has
/// nothing to render. The test exercises the module in isolation (no
/// RealtimeSyncService wiring) so the only signal under test is the callback
/// invocation per branch of the resolver.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/realtime/conflict_resolution_module.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

import '../../../infrastructure/builders/realtime_menu_builder.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

class _FakeFirestoreRepository extends Mock implements FirestoreRepository {}

/// A resource whose comparison fields throw, so resolveConflict falls into
/// its error branch before choosing a side.
class _ThrowingResource extends Fake implements RealtimeResource {
  _ThrowingResource(this.id);

  @override
  final String id;

  @override
  int get editCount => throw StateError('corrupt editCount');
}

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

      final result = await module.resolveConflict(
        local,
        remote,
        entity: ConflictEntity.recipeOwn,
      );

      expect(result.editCount, 5, reason: 'local should win on editCount');
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.localWon,
      );
      expect(emitted.single.collectionPath, 'recipes');
      expect(emitted.single.docId, 'rt-a');
      expect(
        emitted.single.entity,
        ConflictEntity.recipeOwn,
        reason: 'the entity the caller passed rides on the event',
      );
    });

    test('remoteWon when remote.editCount > local.editCount', () async {
      final now = clock.now();
      final local = _makeRecipe(id: 'a', editCount: 2, lastEditedAt: now);
      final remote = _makeRecipe(id: 'a', editCount: 7, lastEditedAt: now);

      final result = await module.resolveConflict(
        local,
        remote,
        entity: ConflictEntity.recipeOwn,
      );

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

      final result = await module.resolveConflict(
        local,
        remote,
        entity: ConflictEntity.recipeOwn,
      );

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

      final result = await module.resolveConflict(
        local,
        remote,
        entity: ConflictEntity.recipeOwn,
      );

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

    final result = await silentModule.resolveConflict(
      local,
      remote,
      entity: ConflictEntity.recipeOwn,
    );

    expect(result.editCount, 5);
    // Implicit: no callback wired → no NPE, nothing in [emitted].
    expect(emitted, isEmpty);
  });

  group('P3-U07: the resolver error branch is not silent', () {
    // produktregler.md:109: no strategy may silently drop data that only
    // exists locally; flows-roles-budget.md:18: the user always learns that a
    // conflict happened. When the resolver throws, the remote is kept, so the
    // local edit is overwritten exactly as in a remoteWon.
    test('emits exactly one remoteWon and returns the remote', () async {
      final local = _ThrowingResource('doc-err');
      final remote = _ThrowingResource('doc-err');

      final result = await module.resolveConflict<RealtimeResource>(
        local,
        remote,
        entity: ConflictEntity.weekMenu,
      );

      expect(identical(result, remote), isTrue, reason: 'remote is kept');
      expect(emitted, hasLength(1));
      expect(
        emitted.single.chosenStrategy,
        ConflictResolutionStrategy.remoteWon,
      );
      expect(emitted.single.entity, ConflictEntity.weekMenu);
      expect(identical(emitted.single.localValue, local), isTrue);
      expect(emitted.single.docId, 'doc-err');
    });

    test('a sink that throws is called once and never re-emitted', () async {
      var calls = 0;
      final throwingSinkModule = ConflictResolutionModule(
        firestoreRepository: repo,
        getLatestResource: <T extends RealtimeResource>(_) async =>
            throw UnimplementedError(),
        onConflict: (_) {
          calls++;
          throw StateError('listener crashed');
        },
        collectionPath: 'recipes',
      );
      final now = clock.now();
      final local = _makeRecipe(id: 'a', editCount: 5, lastEditedAt: now);
      final remote = _makeRecipe(id: 'a', editCount: 3, lastEditedAt: now);

      final result = await throwingSinkModule.resolveConflict(
        local,
        remote,
        entity: ConflictEntity.recipeOwn,
      );

      expect(calls, 1, reason: 'the error branch must not emit a second time');
      expect(
        result.editCount,
        5,
        reason: 'a broken listener must not flip the resolver to the remote',
      );
    });

    test('a throwing sink in the error branch is called once', () async {
      var calls = 0;
      final throwingSinkModule = ConflictResolutionModule(
        firestoreRepository: repo,
        getLatestResource: <T extends RealtimeResource>(_) async =>
            throw UnimplementedError(),
        onConflict: (_) {
          calls++;
          throw StateError('listener crashed');
        },
      );
      final remote = _ThrowingResource('doc-err');

      final result = await throwingSinkModule.resolveConflict<RealtimeResource>(
        _ThrowingResource('doc-err'),
        remote,
        entity: ConflictEntity.recipeOwn,
      );

      expect(calls, 1);
      expect(identical(result, remote), isTrue);
    });
  });

  group('P3-U07: the model declares its conflict entity', () {
    // produktregler.md:97-107 and beslutslogg B-09: one rule per entity, no
    // generic rule. The model says which row applies; nothing reads the
    // collection path.
    test('a recipe is recipeOwn for its owner', () {
      final recipe = _makeRecipe(
        id: 'a',
        editCount: 1,
        lastEditedAt: DateTime(2026, 1, 1),
      );
      expect(recipe.conflictEntityFor('owner'), ConflictEntity.recipeOwn);
    });

    test('a recipe is recipeShared for anyone else', () {
      final recipe = _makeRecipe(
        id: 'a',
        editCount: 1,
        lastEditedAt: DateTime(2026, 1, 1),
      );
      expect(
        recipe.conflictEntityFor('collaborator'),
        ConflictEntity.recipeShared,
      );
    });

    test('a week menu is weekMenu for owner and collaborator alike', () {
      final menu = RealtimeMenuBuilder().withOwner('owner', 'Anna').build();
      expect(menu.conflictEntityFor('owner'), ConflictEntity.weekMenu);
      expect(menu.conflictEntityFor('collaborator'), ConflictEntity.weekMenu);
    });

    test('the realtime sync never derives the entity from the path', () {
      final sources = [
        'lib/services/realtime/conflict_resolution_module.dart',
        'lib/services/realtime_sync_service.dart',
        'lib/widgets/realtime/conflict_banner.dart',
      ];
      for (final path in sources) {
        final source = File(path).readAsStringSync();
        expect(
          RegExp(r'switch\s*\(\s*[\w.]*collectionPath').hasMatch(source),
          isFalse,
          reason: '$path must read ConflictEvent.entity, not the path',
        );
      }
    });
  });
}
