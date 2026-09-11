import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ownership.dart';
import 'package:butlery/models/recipe_unified.dart';

Recipe _recipe({String? createdBy, RecipeSocialData? socialData}) => Recipe(
  core: RecipeCore(
    id: 'recipe_1',
    title: 'Test',
    description: 'Test',
    ingredients: const [],
    instructions: const [],
    mealType: 'Test',
    createdAt: DateTime(2026, 9, 11),
    updatedAt: DateTime(2026, 9, 11),
    createdBy: createdBy,
  ),
  type: RecipeType.personal,
  socialData: socialData,
);

void main() {
  group('RecipeOwnership.ownerUid', () {
    test('a non-empty socialData.ownerId wins over createdBy', () {
      final recipe = _recipe(
        createdBy: 'creator',
        socialData: const RecipeSocialData(ownerId: 'owner'),
      );
      expect(recipe.ownerUid, 'owner');
    });

    test('an EMPTY socialData.ownerId falls back to createdBy', () {
      final recipe = _recipe(
        createdBy: 'creator',
        socialData: const RecipeSocialData(ownerId: ''),
      );
      expect(recipe.ownerUid, 'creator');
    });

    test('a null socialData.ownerId falls back to createdBy', () {
      final recipe = _recipe(
        createdBy: 'creator',
        socialData: const RecipeSocialData(),
      );
      expect(recipe.ownerUid, 'creator');
    });

    test('no socialData at all falls back to createdBy', () {
      expect(_recipe(createdBy: 'creator').ownerUid, 'creator');
    });

    test('both fields EMPTY resolve to null, never to an empty string', () {
      final recipe = _recipe(
        createdBy: '',
        socialData: const RecipeSocialData(ownerId: ''),
      );
      expect(recipe.ownerUid, isNull);
    });

    test('both fields absent resolve to null', () {
      expect(_recipe().ownerUid, isNull);
    });
  });
}
