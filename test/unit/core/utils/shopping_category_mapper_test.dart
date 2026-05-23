/// Unit tests for ShoppingCategoryMapper.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/shopping_category_mapper.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

void main() {
  test('protein/meat → meatFish', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/meat'),
      ShoppingCategory.meatFish,
    );
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/meat/beef'),
      ShoppingCategory.meatFish,
    );
  });

  test('protein/seafood → meatFish', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('protein/seafood'),
      ShoppingCategory.meatFish,
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

  test('vegetable → fruitVeg', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('vegetable/onion'),
      ShoppingCategory.fruitVeg,
    );
  });

  test('fruit → fruitVeg', () {
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('fruit/apple'),
      ShoppingCategory.fruitVeg,
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
      ShoppingCategory.fruitVeg,
    );
    expect(
      ShoppingCategoryMapper.categoryFromIngredientGroup('SPICE'),
      ShoppingCategory.pantry,
    );
  });
}
