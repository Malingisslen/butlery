/// A pantry staple ("Finns alltid hemma") is always at home: the shopping
/// merge leaves its rows off whatever amount or date the row carries.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';

PantryItem _pantry(
  String name, {
  String? id,
  bool isStaple = false,
  double? quantity,
  String unit = 'st',
  DateTime? expiry,
}) => PantryItem(
  id: id ?? 'p_$name',
  ingredientName: name,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 1, 1),
  expiryDate: expiry,
  isStaple: isStaple,
);

AggregatedShoppingItem _row(String name, double? amount, String unit) =>
    AggregatedShoppingItem(
      name: name,
      amount: amount,
      unit: unit,
      category: 'Övrigt',
      sourceCount: 1,
    );

Recipe _recipe(List<RecipeIngredient> ingredients) => Recipe(
  core: RecipeCore(
    id: 'r',
    title: 'Test',
    description: '',
    ingredients: ingredients.map((i) => i.raw).toList(),
    structuredIngredients: ingredients,
    instructions: const ['x'],
    mealType: 'Middag',
    portions: 4,
  ),
  type: RecipeType.personal,
);

MenuShoppingSource _source() => MenuShoppingSource(
  week: DateTime(2026, 11, 2),
  placements: [
    (
      recipe: _recipe(const [
        RecipeIngredient(
          amount: 5,
          unit: 'dl',
          name: 'mjöl',
          raw: '5 dl mjöl',
        ),
        RecipeIngredient(
          amount: 3,
          unit: 'st',
          name: 'ägg',
          raw: '3 st ägg',
        ),
      ]),
      factor: 1.0,
    ),
  ],
  recipeCount: 1,
);

void main() {
  group('againstPantry: a staple covers its row', () {
    test('without any quantity', () {
      final pass = MenuShoppingMergePlanner.againstPantry(
        [_row('salt', 1, 'tsk')],
        [_pantry('salt', isStaple: true)],
      );

      expect(pass.lines, isEmpty);
      expect(pass.coveredAtHome, ['salt']);
      expect(pass.atHomeCount, 1);
    });

    test('with an expired date', () {
      final pass = MenuShoppingMergePlanner.againstPantry(
        [_row('salt', 1, 'tsk')],
        [
          _pantry(
            'salt',
            isStaple: true,
            quantity: 500,
            unit: 'g',
            expiry: DateTime(2020, 1, 1),
          ),
        ],
      );

      expect(pass.lines, isEmpty);
      expect(pass.coveredAtHome, ['salt']);
    });

    test('with a smaller amount than needed', () {
      final pass = MenuShoppingMergePlanner.againstPantry(
        [_row('mjöl', 5, 'dl')],
        [_pantry('mjöl', isStaple: true, quantity: 1, unit: 'dl')],
      );

      expect(pass.lines, isEmpty);
      expect(pass.coveredAtHome, ['mjöl']);
      expect(pass.lessened, isEmpty);
      expect(pass.atHomeCount, 1);
    });

    test('control: the same pantry row without the staple flag still '
        'leaves the difference to buy', () {
      final pass = MenuShoppingMergePlanner.againstPantry(
        [_row('mjöl', 5, 'dl')],
        [_pantry('mjöl', quantity: 1, unit: 'dl')],
      );

      expect(pass.coveredAtHome, isEmpty);
      expect(pass.lessened, ['mjöl']);
      expect(pass.lines.single.amount, closeTo(4, 1e-9));
    });

    test('a staple among several pantry rows of one item covers it even '
        'beside a non-staple row', () {
      final pass = MenuShoppingMergePlanner.againstPantry(
        [_row('mjöl', 5, 'dl'), _row('ägg', 3, 'st')],
        [
          _pantry('mjöl', quantity: 1, unit: 'dl'),
          _pantry('mjöl', id: 'staple_mjöl', isStaple: true),
        ],
      );

      expect(pass.coveredAtHome, ['mjöl']);
      expect(pass.lines.map((l) => l.name), ['ägg']);
      expect(pass.atHomeCount, 1);
    });
  });

  group('preview with the pantry switch off', () {
    final pantry = MenuShoppingPantry.read([
      _pantry('mjöl', isStaple: true),
      _pantry('ägg', quantity: 12),
    ]);

    test('a staple still leaves its row off and is listed as covered; '
        'a non-staple is not subtracted', () {
      final merge = MenuShoppingMergePlanner.preview(
        _source(),
        pantry,
        const MenuShoppingMergeOptions(subtractPantry: false),
      );

      expect(merge.coveredAtHome, ['mjöl']);
      expect(merge.lines.map((l) => l.name), ['ägg']);
      expect(merge.lines.single.amount, closeTo(3, 1e-9));
      expect(merge.atHomeCount, 1);
    });

    test('with the switch on the staple is left off and the non-staple is '
        'subtracted as before', () {
      final merge = MenuShoppingMergePlanner.preview(
        _source(),
        pantry,
        const MenuShoppingMergeOptions(),
      );

      expect(merge.coveredAtHome, unorderedEquals(['mjöl', 'ägg']));
      expect(merge.lines, isEmpty);
      expect(merge.atHomeCount, 2);
    });
  });
}
