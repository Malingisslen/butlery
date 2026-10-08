/// BUT-2213: Återställ on a kept version of the user's own recipe (A1, Malin
/// 2026-10-08). The recipe lives on its recipe document, not in
/// realtime_resources (BUT-2151), so the restore reads and writes it the way
/// the recipe editor does; the sharing and revision are the ones the recipe
/// has now.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/services/realtime/queued_recipe_conflicts.dart';
import 'package:butlery/services/realtime_sync_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _MockSync extends Mock implements RealtimeSyncService {}

class _MockStore extends Mock implements OverwrittenVersionRepository {}

const _me = 'u1';

Recipe _recipe(
  String title, {
  int? rev,
  RecipeSocialData? socialData,
  RecipeType type = RecipeType.personal,
}) {
  final built = RecipeFactory.build(id: 'r1', title: title, createdBy: _me);
  return Recipe(
    core: built.core,
    type: type,
    socialData: socialData,
    rev: rev,
  );
}

OverwrittenVersion _kept(Recipe lost) => OverwrittenVersion.capture(
  ownerId: _me,
  entity: ConflictEntity.recipeOwn,
  lost: QueuedRecipeConflicts.asResource(lost, _me),
  winner: QueuedRecipeConflicts.asResource(_recipe('Vinnaren'), _me),
  at: DateTime(2026, 10, 8),
).withId('v1');

void main() {
  late _MockSync sync;
  late Map<String, Recipe> live;
  late List<Recipe> written;
  late OverwrittenVersionService service;

  setUp(() {
    sync = _MockSync();
    live = {};
    written = [];
    service = OverwrittenVersionService(
      repository: _MockStore(),
      syncService: sync,
      readOwnRecipe: (id) async => live[id],
      writeOwnRecipe: (recipe) async {
        written.add(recipe);
        live[recipe.id] = recipe;
      },
    );
  });

  const shared = RecipeSocialData(
    ownerId: _me,
    memberPermissions: {
      _me: ResourcePermission.owner,
      'u2': ResourcePermission.viewer,
    },
  );

  test('the kept recipe is written through the recipe path, on the sharing '
      'and revision the recipe has now', () async {
    live['r1'] = _recipe('Från min andra enhet', rev: 7, socialData: shared);

    final receipt = await service.restore(
      _kept(_recipe('Min ändring', rev: 2)),
    );

    final restored = written.single;
    expect(restored.title, 'Min ändring');
    expect(restored.rev, 7);
    expect(restored.socialData?.memberPermissions, shared.memberPermissions);
    expect(
      (receipt.replaced as RealtimeRecipe).recipe.title,
      'Från min andra enhet',
    );
    verifyZeroInteractions(sync);
  });

  test('Ångra puts back what was replaced, on the revision it has after the '
      'restore', () async {
    live['r1'] = _recipe('Från min andra enhet', rev: 7, socialData: shared);
    final receipt = await service.restore(_kept(_recipe('Min ändring')));
    live['r1'] = _recipe('Min ändring', rev: 8, socialData: shared);

    await service.undo(receipt);

    expect(written.last.title, 'Från min andra enhet');
    expect(written.last.rev, 8);
    expect(
      written.last.socialData?.memberPermissions,
      shared.memberPermissions,
    );
  });

  test('a recipe that is gone has nothing to restore into, and nothing is '
      'written', () async {
    await expectLater(
      service.restore(_kept(_recipe('Min ändring'))),
      throwsA(isA<OverwrittenVersionTargetMissing>()),
    );
    expect(written, isEmpty);
  });
}
