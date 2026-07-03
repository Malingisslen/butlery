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
            amount: 2,
            unit: 'dl',
            name: 'mjöl',
            raw: '2 dl mjöl',
          ),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'mjöl',
            raw: '1 dl mjöl',
          ),
        ]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.amount, 3);
      expect(items.single.unit, 'dl');
      expect(items.single.sourceCount, 2);
    });

    test('sections are IGNORED — same ingredient in Deg + Fyllning merges '
        'into one shopping line (PR #211)', () {
      // A kanelbulle has smör in both Deg and Fyllning; the shopper buys one
      // amount of butter. The aggregator keys on name|unit, never section.
      final items = MenuShoppingAggregator.aggregate([
        _recipe('kanelbullar', const [
          RecipeIngredient(
            amount: 75,
            unit: 'g',
            name: 'smör',
            raw: '75 g smör',
            section: 'Deg',
          ),
          RecipeIngredient(
            amount: 50,
            unit: 'g',
            name: 'smör',
            raw: '50 g smör',
            section: 'Fyllning',
          ),
        ]),
      ]);
      expect(items, hasLength(1), reason: 'sections must not split the line');
      expect(items.single.amount, 125);
      expect(items.single.unit, 'g');
    });

    test('Swedish-character variants merge ("Mjöl" + "mjol")', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'Mjöl',
            raw: '2 dl Mjöl',
          ),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'mjol',
            raw: '1 dl mjol',
          ),
        ]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.amount, 3);
      expect(
        items.single.name,
        'Mjöl',
        reason: 'display keeps first-seen casing',
      );
    });

    test('same ingredient across DIFFERENT FAMILIES (weight vs volume) stays '
        'as separate honest lines', () {
      // Cross-FAMILY conversion (g↔dl) needs a density we don't have — two
      // correct lines beat one wrong sum. Pinned: BUT-1278 only merges WITHIN
      // a family, never across.
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
            amount: 200,
            unit: 'g',
            name: 'mjöl',
            raw: '200 g mjöl',
          ),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'mjöl',
            raw: '1 dl mjöl',
          ),
        ]),
      ]);
      expect(items, hasLength(2));
    });

    test(
      'BUT-1278: compatible VOLUME units merge into one line (3 dl + 200 ml)',
      () {
        // The ticket's marquee case: 3 dl + 200 ml is 500 ml of the same thing —
        // one line, not two. Display reduces to the readable Swedish unit (5 dl).
        final items = MenuShoppingAggregator.aggregate([
          _recipe('r1', const [
            RecipeIngredient(
              amount: 3,
              unit: 'dl',
              name: 'grädde',
              raw: '3 dl grädde',
            ),
          ]),
          _recipe('r2', const [
            RecipeIngredient(
              amount: 200,
              unit: 'ml',
              name: 'grädde',
              raw: '200 ml grädde',
            ),
          ]),
        ]);
        expect(
          items,
          hasLength(1),
          reason: 'compatible volume units must collapse to one line',
        );
        final line = items.single;
        expect(line.sourceCount, 2);
        // 3 dl (300 ml) + 200 ml = 500 ml; convertToReadableUnit prefers dl.
        expect(line.unit, 'dl');
        expect(
          line.amount,
          closeTo(5, 1e-9),
          reason: '300 ml + 200 ml = 500 ml = 5 dl',
        );
      },
    );

    test(
      'BUT-1278: compatible WEIGHT units merge into one line (1 kg + 300 g)',
      () {
        final items = MenuShoppingAggregator.aggregate([
          _recipe('r1', const [
            RecipeIngredient(
              amount: 1,
              unit: 'kg',
              name: 'potatis',
              raw: '1 kg potatis',
            ),
          ]),
          _recipe('r2', const [
            RecipeIngredient(
              amount: 300,
              unit: 'g',
              name: 'potatis',
              raw: '300 g potatis',
            ),
          ]),
        ]);
        expect(items, hasLength(1));
        final line = items.single;
        // 1000 g + 300 g = 1300 g → 1.3 kg.
        expect(line.unit, 'kg');
        expect(line.amount, closeTo(1.3, 1e-9));
        expect(line.sourceCount, 2);
      },
    );

    test('BUT-1278: spoon volumes fold into the volume family (2 msk + 1 dl '
        'olja)', () {
      // 2 msk = 30 ml, 1 dl = 100 ml → 130 ml. Proves the Swedish spoon
      // equivalences participate in volume merging.
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
            amount: 2,
            unit: 'msk',
            name: 'olja',
            raw: '2 msk olja',
          ),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'olja',
            raw: '1 dl olja',
          ),
        ]),
      ]);
      expect(items, hasLength(1));
      // 30 ml + 100 ml = 130 ml → 1.3 dl.
      expect(items.single.unit, 'dl');
      expect(items.single.amount, closeTo(1.3, 1e-9));
    });

    test(
      'BUT-1278: unit-less counts ("st") still only sum on exact unit match, '
      'never merged via a family',
      () {
        // "st" has no measurement family — it must keep the original
        // exact-unit-string behavior (sums when identical, separate otherwise).
        final items = MenuShoppingAggregator.aggregate([
          _recipe('r1', const [
            RecipeIngredient(amount: 2, unit: 'st', name: 'ägg', raw: '2 ägg'),
          ]),
          _recipe('r2', const [
            RecipeIngredient(amount: 3, unit: 'st', name: 'ägg', raw: '3 ägg'),
          ]),
        ]);
        expect(items, hasLength(1));
        expect(items.single.amount, 5);
        expect(items.single.unit, 'st');
      },
    );

    test(
      'BUT-1279: excludeNames drops matching lines from the aggregation',
      () {
        // Names passed in excludeNames (already normalized) never reach the
        // output — this is how pantry staples are kept off the list.
        final items = MenuShoppingAggregator.aggregate(
          [
            _recipe('r1', const [
              RecipeIngredient(
                amount: 1,
                unit: 'tsk',
                name: 'salt',
                raw: 'salt',
              ),
              RecipeIngredient(
                amount: 2,
                unit: 'dl',
                name: 'mjöl',
                raw: '2 dl mjöl',
              ),
            ]),
          ],
          excludeNames: {'salt'},
        );
        expect(
          items.map((i) => i.name),
          ['mjöl'],
          reason: 'the excluded staple "salt" must not appear',
        );
      },
    );

    test('raw-only lines (no amount) land on the list, un-summed, never '
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

    test('legacy recipe (no structured data) still contributes via the '
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
      expect(
        items.single.amount,
        isNull,
        reason: 'no derivation here — raw-only lands as amount-less',
      );
    });

    test('output is grouped by category then name (stable shopping order)', () {
      final items = MenuShoppingAggregator.aggregate([
        _recipe('r1', const [
          RecipeIngredient(
            amount: 1,
            unit: 'l',
            name: 'mjölk',
            raw: '1 l mjölk',
          ),
          RecipeIngredient(
            amount: 2,
            unit: 'st',
            name: 'äpple',
            raw: '2 st äpple',
          ),
          RecipeIngredient(
            amount: 1,
            unit: 'st',
            name: 'gurka',
            raw: '1 st gurka',
          ),
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
