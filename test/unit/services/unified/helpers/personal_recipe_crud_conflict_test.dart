/// BUT-2401: after a web save that lost a revision race, the list holds the
/// server's recipe, not the unsaved one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/helpers/personal_recipe_crud.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../test_support/base_unit_test.dart';

class _MockPersonalModule extends Mock implements PersonalRecipeModule {}

class _MockCacheModule extends Mock implements RecipeCacheModule {}

void main() {
  late _MockPersonalModule personal;
  late List<Recipe> recipes;
  late PersonalRecipeCrud crud;
  late Recipe mine;
  late Recipe theirs;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    personal = _MockPersonalModule();
    mine = RecipeFactory.build(id: 'r1', title: 'Min version');
    theirs = RecipeFactory.build(id: 'r1', title: 'Andra fönstret');
    recipes = [RecipeFactory.build(id: 'r1', title: 'Gammal')];
    crud = PersonalRecipeCrud(
      personalModule: personal,
      cacheModule: _MockCacheModule(),
      recipes: recipes,
      notifyListeners: () {},
    );
    when(
      () => personal.updatePersonalRecipe(any()),
    ).thenAnswer((_) async => true);
    when(() => personal.saveRecipeRaw(any())).thenAnswer((_) async {});
  });

  test('updateRecipe puts the server\'s recipe in the list after a lost '
      'race', () async {
    when(() => personal.takeConflictWinner('r1')).thenReturn(theirs);

    await crud.updateRecipe(mine);

    expect(recipes.single.title, 'Andra fönstret');
  });

  test('saveRecipeRaw puts the server\'s recipe in the list after a lost '
      'race', () async {
    when(() => personal.takeConflictWinner('r1')).thenReturn(theirs);

    await crud.saveRecipeRaw(mine);

    expect(recipes.single.title, 'Andra fönstret');
  });

  test('without a conflict the saved recipe goes in the list', () async {
    when(() => personal.takeConflictWinner('r1')).thenReturn(null);

    await crud.updateRecipe(mine);

    expect(recipes.single.title, 'Min version');
  });

  test('a deleted recipe is scrubbed from the weekly menus', () async {
    final scrubbed = <String>[];
    final withCascade = PersonalRecipeCrud(
      personalModule: personal,
      cacheModule: _MockCacheModule(),
      recipes: recipes,
      notifyListeners: () {},
      removeFromWeeklyMenus: (id) async => scrubbed.add(id),
    );
    when(
      () => personal.deletePersonalRecipe('r1'),
    ).thenAnswer((_) async => true);

    await withCascade.deleteRecipe('r1');
    await pumpEventQueue();

    expect(scrubbed, ['r1']);
  });

  test('a failed delete leaves the weekly menus alone', () async {
    final scrubbed = <String>[];
    final withCascade = PersonalRecipeCrud(
      personalModule: personal,
      cacheModule: _MockCacheModule(),
      recipes: recipes,
      notifyListeners: () {},
      removeFromWeeklyMenus: (id) async => scrubbed.add(id),
    );
    when(
      () => personal.deletePersonalRecipe('r1'),
    ).thenAnswer((_) async => false);

    await withCascade.deleteRecipe('r1');
    await pumpEventQueue();

    expect(scrubbed, isEmpty);
  });
}
