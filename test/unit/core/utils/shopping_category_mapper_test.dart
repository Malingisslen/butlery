/// Unit tests for ShoppingCategoryMapper.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/shopping_category_mapper.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

void main() {
  // BUT-1164: the mapper now emits the fine-grained meat/fish/fruit/veg
  // buckets for new items. Legacy meatFish/fruitVeg are display-only fallbacks
  // for already-stored docs and must never come back out of this mapper.
  test('protein/meat → meat (not legacy meatFish)', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/meat'),
      ShoppingCategory.meat,
    );
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/meat/beef'),
      ShoppingCategory.meat,
    );
  });

  test('protein/seafood → fish (not legacy meatFish)', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/seafood'),
      ShoppingCategory.fish,
    );
  });

  test('protein/dairy → dairy', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup(
          'protein/dairy/cheese'),
      ShoppingCategory.dairy,
    );
  });

  test('protein/egg → dairy', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/egg'),
      ShoppingCategory.dairy,
    );
  });

  test('vegetable → veg (not legacy fruitVeg)', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('vegetable/onion'),
      ShoppingCategory.veg,
    );
  });

  test('fruit → fruit (not legacy fruitVeg)', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('fruit/apple'),
      ShoppingCategory.fruit,
    );
  });

  test('grain → breadGrain', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('grain/rice'),
      ShoppingCategory.breadGrain,
    );
  });

  test('spice → pantry', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('spice/salt'),
      ShoppingCategory.pantry,
    );
  });

  test('fat → pantry', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('fat/olive_oil'),
      ShoppingCategory.pantry,
    );
  });

  test('sweetener → pantry', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('sweetener/sugar'),
      ShoppingCategory.pantry,
    );
  });

  test('unknown group → other', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('beverage/coffee'),
      ShoppingCategory.other,
    );
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup(''),
      ShoppingCategory.other,
    );
  });

  test('case-insensitive: uppercase still matches', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('VEGETABLE/Onion'),
      ShoppingCategory.veg,
    );
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('SPICE'),
      ShoppingCategory.pantry,
    );
  });

  test('BUT-1164: mapper never emits legacy aggregate buckets', () {
    const groups = [
      'protein/meat',
      'protein/seafood',
      'protein/dairy',
      'protein/egg',
      'vegetable/carrot',
      'fruit/banana',
      'grain/oats',
      'spice/pepper',
      'beverage/tea',
      '',
    ];
    for (final group in groups) {
      final result = ShoppingCategoryMapper.categoryFromIngredientGroup(group);
      expect(result, isNot(ShoppingCategory.meatFish),
          reason: '"$group" must not map to legacy meatFish');
      expect(result, isNot(ShoppingCategory.fruitVeg),
          reason: '"$group" must not map to legacy fruitVeg');
    }
  });
}
