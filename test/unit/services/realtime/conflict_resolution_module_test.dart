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
          emitted.single.chosenStrategy, ConflictResolutionStrategy.localWon);
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
          emitted.single.chosenStrategy, ConflictResolutionStrategy.remoteWon);
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
          emitted.single.chosenStrategy, ConflictResolutionStrategy.localWon);
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
          emitted.single.chosenStrategy, ConflictResolutionStrategy.remoteWon);
    });
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
