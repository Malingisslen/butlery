/// Q4-03 = A (produktbeslut 2026-09-24): "Lägg {n} varor i inköpslistan"
/// counts the recipe's items the pantry does not already cover, by the week
/// merge's rule (produktregler.md:224-234).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_shopping_handler.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

PantryItem _pantry(
  String name, {
  double? quantity,
  String unit = 'st',
  DateTime? expiry,
}) => PantryItem(
  id: 'p_$name',
  ingredientName: name,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 1, 1),
  expiryDate: expiry,
);

UnifiedShoppingItem _item(String name, double amount, String unit) =>
    UnifiedShoppingItem(name: name, amount: amount, unit: unit, bought: false);

void main() {
  final items = [
    _item('Ägg', 4, 'st'),
    _item('Mjölk', 5, 'dl'),
    _item('Vetemjöl', 3, 'dl'),
    _item('Salt', 1, 'krm'),
  ];

  test('an empty pantry covers nothing', () {
    expect(RecipePantryCheck.toBuy(items, const []), items);
  });

  test('enough at home leaves an item off; name matching ignores case', () {
    final left = RecipePantryCheck.toBuy(items, [_pantry('ägg', quantity: 6)]);

    expect(left.map((i) => i.name), ['Mjölk', 'Vetemjöl', 'Salt']);
  });

  test('some at home leaves the difference, across units in one family', () {
    final left = RecipePantryCheck.toBuy(items, [
      _pantry('Mjölk', quantity: 200, unit: 'ml'),
    ]);

    final milk = left.singleWhere((i) => i.name == 'Mjölk');
    expect(milk.amount, closeTo(3, 1e-9));
    expect(milk.unit, 'dl');
    expect(left, hasLength(4));
  });

  test('har hemma (no amount) subtracts nothing', () {
    final left = RecipePantryCheck.toBuy(items, [_pantry('Salt')]);

    expect(left, hasLength(4));
  });

  test('a row past its date subtracts nothing', () {
    final left = RecipePantryCheck.toBuy(items, [
      _pantry('Ägg', quantity: 12, expiry: DateTime(2000)),
    ]);

    expect(left, hasLength(4));
  });

  test('another unit family subtracts nothing', () {
    final left = RecipePantryCheck.toBuy(items, [
      _pantry('Vetemjöl', quantity: 2, unit: 'kg'),
    ]);

    expect(left, hasLength(4));
  });

  group('the button and what it adds agree', () {
    final recipe = RecipeFactory.build(
      id: 'r1',
      title: 'Pannkakor',
      portions: 4,
      ingredients: const ['3 ägg', '6 dl mjölk', '2 dl vetemjöl'],
    );

    test('no known pantry: no count, every ingredient is added', () {
      expect(
        RecipeShoppingHandler.countToBuy(recipe, portions: 4, pantry: null),
        isNull,
      );
      expect(
        RecipeShoppingHandler.itemsToAdd(recipe, portions: 4),
        hasLength(3),
      );
    });

    // "3 ägg" is parsed without a unit, so the pantry row is unit-less too:
    // the merge's rule matches units as written.
    test('the count is what is added', () {
      final pantry = [_pantry('ägg', quantity: 10, unit: '')];
      final count = RecipeShoppingHandler.countToBuy(
        recipe,
        portions: 4,
        pantry: pantry,
      );
      final added = RecipeShoppingHandler.itemsToAdd(
        recipe,
        portions: 4,
        pantry: pantry,
      );

      expect(count, 2);
      expect(added, hasLength(count!));
      expect(added.map((i) => i.name.toLowerCase()), isNot(contains('ägg')));
    });

    test('everything at home: no count, and nothing is left off', () {
      final pantry = [
        _pantry('ägg', quantity: 10, unit: ''),
        _pantry('mjölk', quantity: 2, unit: 'l'),
        _pantry('vetemjöl', quantity: 1, unit: 'l'),
      ];

      expect(
        RecipeShoppingHandler.countToBuy(recipe, portions: 4, pantry: pantry),
        isNull,
      );
      expect(
        RecipeShoppingHandler.itemsToAdd(recipe, portions: 4, pantry: pantry),
        hasLength(3),
      );
    });
  });
}
