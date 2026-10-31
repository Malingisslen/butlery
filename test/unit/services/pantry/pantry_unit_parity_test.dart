/// The cooked-recipe pantry take and the shopping list's pantry deduction
/// must agree on which pantry units count against a recipe unit, and by how
/// much. Each case states how many pantry units cover the whole recipe line
/// by hand, so neither side's own conversion code sets the expectation.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';

typedef _Case = ({
  String label,
  double recipeAmount,
  String recipeUnit,
  double pantryQuantity,
  String pantryUnit,
  // Pantry units that cover the whole recipe line; null when the units
  // cannot be compared.
  double? pantryUnitsForWholeLine,
});

const _cases = <_Case>[
  (
    label: 'same unit, part in stock',
    recipeAmount: 5,
    recipeUnit: 'dl',
    pantryQuantity: 2,
    pantryUnit: 'dl',
    pantryUnitsForWholeLine: 5,
  ),
  (
    label: 'volume family, pantry in ml',
    recipeAmount: 5,
    recipeUnit: 'dl',
    pantryQuantity: 100,
    pantryUnit: 'ml',
    pantryUnitsForWholeLine: 500,
  ),
  (
    label: 'volume family, pantry in litres covers it all',
    recipeAmount: 5,
    recipeUnit: 'dl',
    pantryQuantity: 1,
    pantryUnit: 'l',
    pantryUnitsForWholeLine: 0.5,
  ),
  (
    label: 'weight family, pantry in g',
    recipeAmount: 1,
    recipeUnit: 'kg',
    pantryQuantity: 300,
    pantryUnit: 'g',
    pantryUnitsForWholeLine: 1000,
  ),
  (
    label: 'weight family, pantry in kg covers it all',
    recipeAmount: 500,
    recipeUnit: 'g',
    pantryQuantity: 1,
    pantryUnit: 'kg',
    pantryUnitsForWholeLine: 0.5,
  ),
  (
    label: 'unit-less recipe line against pantry st',
    recipeAmount: 3,
    recipeUnit: '',
    pantryQuantity: 2,
    pantryUnit: 'st',
    pantryUnitsForWholeLine: 3,
  ),
  (
    label: 'recipe st against unit-less pantry row',
    recipeAmount: 3,
    recipeUnit: 'st',
    pantryQuantity: 1,
    pantryUnit: '',
    pantryUnitsForWholeLine: 3,
  ),
  (
    label: 'unit-less pantry row covers a unit-less line',
    recipeAmount: 3,
    recipeUnit: '',
    pantryQuantity: 12,
    pantryUnit: 'st',
    pantryUnitsForWholeLine: 3,
  ),
  (
    label: 'volume against weight',
    recipeAmount: 2,
    recipeUnit: 'dl',
    pantryQuantity: 100,
    pantryUnit: 'g',
    pantryUnitsForWholeLine: null,
  ),
  (
    label: 'volume against pieces',
    recipeAmount: 2,
    recipeUnit: 'dl',
    pantryQuantity: 1,
    pantryUnit: 'st',
    pantryUnitsForWholeLine: null,
  ),
  (
    label: 'weight against volume',
    recipeAmount: 200,
    recipeUnit: 'g',
    pantryQuantity: 1,
    pantryUnit: 'dl',
    pantryUnitsForWholeLine: null,
  ),
];

Recipe _recipe(_Case c) {
  final entry = RecipeIngredient(
    amount: c.recipeAmount,
    unit: c.recipeUnit,
    name: 'mjöl',
    raw: '${c.recipeAmount} ${c.recipeUnit} mjöl',
  );
  return Recipe(
    core: RecipeCore(
      id: 'r',
      title: 'r',
      description: '',
      ingredients: [entry.raw],
      structuredIngredients: [entry],
      instructions: const ['x'],
      mealType: 'Middag',
      portions: 4,
    ),
    type: RecipeType.personal,
  );
}

PantryItem _item(_Case c) => PantryItem(
  id: 'p',
  ingredientName: 'Mjöl',
  quantity: c.pantryQuantity,
  unit: c.pantryUnit,
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  final today = DateTime.utc(2026, 10, 31, 12);

  for (final c in _cases) {
    test('cooked take and shopping deduction agree: ${c.label}', () {
      final recipe = _recipe(c);
      final item = _item(c);
      final whole = c.pantryUnitsForWholeLine;
      final expectedCovered = whole == null
          ? 0.0
          : (c.pantryQuantity / whole).clamp(0.0, 1.0);

      final takes = withClock(
        Clock.fixed(today),
        () => CookedPantryPlan.of(recipe, portions: 4, pantry: [item]),
      );
      final cookedCovered = takes.isEmpty || whole == null
          ? 0.0
          : takes.single.amount / whole;

      final row = MenuShoppingAggregator.aggregateForMerge([
        (recipe: recipe, factor: 1.0),
      ]).items.single;
      final pass = withClock(
        Clock.fixed(today),
        () => MenuShoppingMergePlanner.againstPantry([row], [item]),
      );
      final need = row.amount!;
      final shoppingCovered = pass.lines.isEmpty
          ? 1.0
          : (need - pass.lines.single.amount!) / need;

      expect(cookedCovered, closeTo(expectedCovered, 1e-9));
      expect(shoppingCovered, closeTo(expectedCovered, 1e-9));
      if (whole == null) expect(takes, isEmpty);
    });
  }
}
