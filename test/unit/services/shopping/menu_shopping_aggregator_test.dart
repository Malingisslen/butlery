/// BUT-956: menu→shopping aggregation.
///
/// Intent: planning a week with two recipes that both need flour yields ONE
/// summed line instead of duplicates — and nothing the user needs to buy is
/// ever silently dropped, however unparseable the ingredient line.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';

Recipe _recipe(String id, List<RecipeIngredient> entries) => Recipe(
      core: RecipeCore(
        id: id,
        title: id,
        description: '',
        ingredients: entries.map((e) => e.raw).toList(),
        structuredIngredients: entries,
        instructions: const ['x'],
        mealType: 'Middag',
      ),
      type: RecipeType.personal,
    );

void main() {
  group('MenuShoppingAggregator (BUT-956)', () {
    test('same ingredient + same unit across recipes sums into one line', () {
      // The ticket's marquee case: 2 dl mjöl + 1 dl mjöl → 3 dl mjöl.
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
              amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
              amount: 1, unit: 'dl', name: 'mjöl', raw: '1 dl mjöl'),
        ]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.amount, 3);
      expect(items.single.unit, 'dl');
      expect(items.single.sourceCount, 2);
    });

    test('Swedish-character variants merge ("Mjöl" + "mjol")', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
              amount: 2, unit: 'dl', name: 'Mjöl', raw: '2 dl Mjöl'),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
              amount: 1, unit: 'dl', name: 'mjol', raw: '1 dl mjol'),
        ]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.amount, 3);
      expect(items.single.name, 'Mjöl',
          reason: 'display keeps first-seen casing');
    });

    test('same ingredient with DIFFERENT units stays as separate honest lines',
        () {
      // Cross-unit conversion is epic scope — two correct lines beat one
      // wrong sum. This is a deliberate V1 constraint, pinned.
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
              amount: 200, unit: 'g', name: 'mjöl', raw: '200 g mjöl'),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
              amount: 1, unit: 'dl', name: 'mjöl', raw: '1 dl mjöl'),
        ]),
      ]);
      expect(items, hasLength(2));
    });

    test(
        'raw-only lines (no amount) land on the list, un-summed, never '
        'dropped', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', [RecipeIngredient.rawOnly('en nypa salt')]),
        _recipe('r2', const [
          RecipeIngredient(name: 'vitlöksklyftor', raw: '1-2 vitlöksklyftor'),
        ]),
      ]);
      expect(items, hasLength(2));
      expect(items.every((i) => i.amount == null), isTrue);
    });

    test('amount-less duplicates collapse to one line by name', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', [RecipeIngredient.rawOnly('salt')]),
        _recipe('r2', [RecipeIngredient.rawOnly('salt')]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.sourceCount, 2);
    });

    test(
        'legacy recipe (no structured data) still contributes via the '
        'raw-only fallback', () {
      // Recipe WITHOUT structuredIngredients — the facade getter degrades to
      // rawOnly entries; the aggregation must include them.
      final legacy = Recipe(
        core: RecipeCore(
          id: 'legacy',
          title: 'legacy',
          description: '',
          ingredients: ['2 dl mjölk'],
          instructions: const ['x'],
          mealType: 'Middag',
        ),
        type: RecipeType.personal,
      );
      final items = MenuShoppingAggregator.aggregate([legacy]);
      expect(items, hasLength(1));
      expect(items.single.amount, isNull,
          reason: 'no derivation here — raw-only lands as amount-less');
    });

    test('output is grouped by category then name (stable shopping order)', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
              amount: 1, unit: 'l', name: 'mjölk', raw: '1 l mjölk'),
          RecipeIngredient(
              amount: 2, unit: 'st', name: 'äpple', raw: '2 st äpple'),
          RecipeIngredient(
              amount: 1, unit: 'st', name: 'gurka', raw: '1 st gurka'),
        ]),
      ]);
      final categories = items.map((i) => i.category).toList();
      final sorted = [...categories]..sort();
      expect(categories, sorted, reason: 'category-major ordering');
    });

    test('blank ingredient names are skipped (never produce empty lines)', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', [RecipeIngredient.rawOnly('   ')]),
      ]);
      expect(items, isEmpty);
    });
  });
}
