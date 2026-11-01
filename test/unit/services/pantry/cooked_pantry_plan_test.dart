/// Kärnflöde steg 9C: what a cooked recipe offers to take from the pantry.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';

Recipe _recipe(List<RecipeIngredient> entries, {int portions = 4}) => Recipe(
  core: RecipeCore(
    id: 'r',
    title: 'r',
    description: '',
    ingredients: entries.map((e) => e.raw).toList(),
    structuredIngredients: entries,
    instructions: const ['x'],
    mealType: 'Middag',
    portions: portions,
  ),
  type: RecipeType.personal,
);

RecipeIngredient _ing(double? amount, String unit, String name) =>
    RecipeIngredient(
      amount: amount,
      unit: unit,
      name: name,
      raw: '${amount ?? ''} $unit $name',
    );

PantryItem _item(
  String id,
  String name,
  double? quantity,
  String unit, {
  DateTime? expiry,
  String? ingredientId,
  bool isStaple = false,
}) => PantryItem(
  id: id,
  ingredientName: name,
  ingredientId: ingredientId,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
  expiryDate: expiry,
  isStaple: isStaple,
);

void main() {
  final today = DateTime.utc(2026, 10, 31, 12);
  List<CookedPantryTake> plan(
    Recipe recipe,
    List<PantryItem> pantry, {
    int portions = 4,
  }) => withClock(
    Clock.fixed(today),
    () => CookedPantryPlan.of(recipe, portions: portions, pantry: pantry),
  );

  test('matches by name and caps the take by what is in stock', () {
    final takes = plan(
      _recipe([_ing(5, 'dl', 'mjöl')]),
      [_item('a', 'Mjöl', 2, 'dl')],
    );

    expect(takes, hasLength(1));
    expect(takes.single.item.id, 'a');
    expect(takes.single.amount, closeTo(2, 1e-9));
    expect(takes.single.emptiesRow, isTrue);
  });

  test('a take below the stock leaves the rest and does not empty the row', () {
    final takes = plan(
      _recipe([_ing(2, 'dl', 'mjöl')]),
      [_item('a', 'Mjöl', 10, 'dl')],
    );

    expect(takes.single.amount, closeTo(2, 1e-9));
    expect(takes.single.left, closeTo(8, 1e-9));
    expect(takes.single.emptiesRow, isFalse);
  });

  test('matches by ingredient id when the names differ', () {
    final recipe = Recipe(
      core: RecipeCore(
        id: 'r',
        title: 'r',
        description: '',
        ingredients: const ['1 dl vetemjöl'],
        structuredIngredients: const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'vetemjöl',
            raw: '1 dl vetemjöl',
            ingredientId: 'ing-flour',
          ),
        ],
        instructions: const ['x'],
        mealType: 'Middag',
        portions: 4,
      ),
      type: RecipeType.personal,
    );

    final takes = plan(recipe, [
      _item('a', 'Mjöl', 5, 'dl', ingredientId: 'ing-flour'),
    ]);

    expect(takes.single.item.id, 'a');
  });

  test('portions scale the amount', () {
    final recipe = _recipe([_ing(2, 'dl', 'mjöl')]);
    final pantry = [_item('a', 'Mjöl', 10, 'dl')];

    expect(plan(recipe, pantry, portions: 8).single.amount, closeTo(4, 1e-9));
    expect(plan(recipe, pantry, portions: 2).single.amount, closeTo(1, 1e-9));
  });

  test('an expired row, a row without an amount and another unit family are '
      'left alone', () {
    final takes = plan(
      _recipe([
        _ing(1, 'dl', 'mjöl'),
        _ing(1, 'dl', 'socker'),
        _ing(1, 'dl', 'mjölk'),
      ]),
      [
        _item('exp', 'Mjöl', 5, 'dl', expiry: DateTime.utc(2026, 10, 1)),
        _item('none', 'Socker', null, 'dl'),
        _item('mass', 'Mjölk', 500, 'g'),
      ],
    );

    expect(takes, isEmpty);
  });

  test('a staple with a quantity is never offered as a take, its non-staple '
      'twin is', () {
    final recipe = _recipe([_ing(2, 'dl', 'mjöl')]);

    final staple = plan(recipe, [
      _item('s', 'Mjöl', 10, 'dl', isStaple: true),
    ]);
    final twin = plan(recipe, [_item('t', 'Mjöl', 10, 'dl')]);
    final both = plan(recipe, [
      _item('s', 'Mjöl', 10, 'dl', isStaple: true),
      _item('t', 'Mjöl', 10, 'dl'),
    ]);

    expect(staple, isEmpty);
    expect(twin.single.item.id, 't');
    expect([for (final t in both) t.item.id], ['t']);
    expect(both.single.amount, closeTo(2, 1e-9));
  });

  test('two rows of one item: the one closest to its date goes first', () {
    final takes = plan(
      _recipe([_ing(3, 'dl', 'mjöl')]),
      [
        _item('late', 'Mjöl', 2, 'dl', expiry: DateTime.utc(2026, 12, 1)),
        _item('soon', 'Mjöl', 2, 'dl', expiry: DateTime.utc(2026, 11, 5)),
        _item('open', 'Mjöl', 2, 'dl'),
      ],
    );

    expect([for (final t in takes) t.item.id], ['soon', 'late']);
    expect(takes[0].amount, closeTo(2, 1e-9));
    expect(takes[1].amount, closeTo(1, 1e-9));
  });

  test('a recipe line without a unit and a pantry row in st both count '
      'pieces, whichever side is empty', () {
    final noUnitRecipe = plan(
      _recipe([_ing(3, '', 'ägg')]),
      [_item('a', 'Ägg', 12, 'st')],
    );
    final stRecipe = plan(
      _recipe([_ing(3, 'st', 'ägg')]),
      [_item('b', 'Ägg', 12, '')],
    );

    expect(noUnitRecipe.single.amount, closeTo(3, 1e-9));
    expect(stRecipe.single.amount, closeTo(3, 1e-9));
  });

  test('converts between units of one family and takes in the row unit', () {
    final takes = plan(
      _recipe([_ing(2, 'dl', 'mjölk')]),
      [_item('a', 'Mjölk', 1, 'l')],
    );

    expect(takes.single.amount, closeTo(0.2, 1e-9));
    expect(takes.single.left, closeTo(0.8, 1e-9));
  });

  test('withAmount keeps the row and recomputes what is left', () {
    final take = CookedPantryTake(
      item: _item('a', 'Mjöl', 5, 'dl'),
      amount: 1,
    ).withAmount(5);

    expect(take.emptiesRow, isTrue);
    expect(take.item.id, 'a');
  });

  test('a row emptied through a converted unit is still an emptying take, '
      'whatever the float residue', () {
    // 0.35 dl read as litres and back leaves 5.5e-17 of the row.
    final takes = plan(
      _recipe([_ing(1, 'l', 'mjölk')]),
      [_item('a', 'Mjölk', 0.35, 'dl')],
    );

    expect(takes.single.left, greaterThan(0));
    expect(takes.single.left, lessThan(1e-9));
    expect(takes.single.emptiesRow, isTrue);
  });
}
