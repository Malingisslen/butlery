import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/services/tagging/cookbook_ordering.dart';

Recipe _recipe(String id, String title, {List<String> tags = const ['book']}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdBy: 'u1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      personalTagIds: tags,
    ),
    type: RecipeType.personal,
  );
}

List<String> _titles(List<Recipe> recipes) =>
    recipes.map((r) => r.title).toList();

void main() {
  final library = [
    _recipe('1', 'Ostkaka'),
    _recipe('2', 'kanelbullar'),
    _recipe('3', 'Äppelpaj'),
    _recipe('4', 'Ärtsoppa', tags: const ['other']),
    _recipe('5', 'Zucchinisoppa'),
    _recipe('6', 'Åkerbärssylt'),
  ];

  test('without an own order the book is A–Ö in Swedish, case ignored', () {
    final ordered = orderCookbookRecipes(
      tagId: 'book',
      recipes: library,
      cookbook: const CookbookDetails(),
    );
    expect(_titles(ordered), [
      'kanelbullar',
      'Ostkaka',
      'Zucchinisoppa',
      'Åkerbärssylt',
      'Äppelpaj',
    ]);
  });

  test('own order first, then unlisted recipes A–Ö, stale ids skipped', () {
    final ordered = orderCookbookRecipes(
      tagId: 'book',
      recipes: library,
      cookbook: const CookbookDetails(recipeOrder: ['3', 'gone', '1', '4']),
    );
    // '4' is listed but no longer carries the tag, so it is not in the book;
    // '2', '5' and '6' were tagged after the reorder (e.g. by a rule).
    expect(_titles(ordered), [
      'Äppelpaj',
      'Ostkaka',
      'kanelbullar',
      'Zucchinisoppa',
      'Åkerbärssylt',
    ]);
  });

  test('compareSwedish puts å ä ö after z in that order', () {
    final words = ['ö', 'a', 'ä', 'z', 'å']..sort(compareSwedish);
    expect(words, ['a', 'z', 'å', 'ä', 'ö']);
  });
}
