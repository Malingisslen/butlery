/// Guards BUT-2482: "Byt i receptet" reported success without saving anything.
/// A content edit may only report true when the edited recipe was handed to
/// the save path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/helpers/recipe_content_operations.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

class _MockSave extends Mock {
  Future<bool> call(Recipe recipe);
}

void main() {
  late _MockSave module;
  late Recipe recipe;
  late RecipeContentOperations ops;

  setUpAll(() => registerFallbackValue(RecipeFactory.build()));

  setUp(() {
    module = _MockSave();
    recipe = RecipeFactory.build(
      id: 'r1',
      ingredients: ['500g köttfärs', '1 gul lök'],
      instructions: ['Blanda', 'Stek'],
    );
    when(
      () => module(any()),
    ).thenAnswer((_) async => true);
    ops = RecipeContentOperations(
      saveRecipe: module.call,
      lookupRecipe: (id) => id == 'r1' ? recipe : null,
    );
  });

  Recipe savedRecipe() =>
      verify(() => module(captureAny())).captured.single as Recipe;

  test('updateIngredient saves the swapped ingredient', () async {
    expect(await ops.updateIngredient('r1', 1, '1 rödlök'), isTrue);
    expect(savedRecipe().core.ingredients, ['500g köttfärs', '1 rödlök']);
  });

  test('add and remove ingredient are saved', () async {
    expect(await ops.addIngredient('r1', '2 dl mjölk'), isTrue);
    expect(savedRecipe().core.ingredients.last, '2 dl mjölk');

    expect(await ops.removeIngredient('r1', 0), isTrue);
    expect(savedRecipe().core.ingredients, ['1 gul lök']);
  });

  test('instruction edits are saved', () async {
    expect(await ops.addInstruction('r1', 'Servera'), isTrue);
    expect(savedRecipe().core.instructions.last, 'Servera');

    expect(await ops.updateInstruction('r1', 0, 'Rör om'), isTrue);
    expect(savedRecipe().core.instructions.first, 'Rör om');

    expect(await ops.removeInstruction('r1', 1), isTrue);
    expect(savedRecipe().core.instructions, ['Blanda']);
  });

  test('a recipe that is not loaded is a failure, nothing is saved', () async {
    expect(await ops.updateIngredient('missing', 0, 'x'), isFalse);
    verifyNever(() => module(any()));
  });

  test('an edit that changes nothing is a failure, nothing is saved', () async {
    expect(await ops.updateIngredient('r1', 9, 'x'), isFalse);
    expect(await ops.updateIngredient('r1', 0, '   '), isFalse);
    expect(await ops.removeInstruction('r1', -1), isFalse);
    verifyNever(() => module(any()));
  });

  test('a failed save is reported as a failure', () async {
    when(
      () => module(any()),
    ).thenAnswer((_) async => false);
    expect(await ops.updateIngredient('r1', 0, '600g köttfärs'), isFalse);
  });
}
