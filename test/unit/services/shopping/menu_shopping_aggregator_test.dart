/// BUT-956 + BUT-1613: menu→shopping aggregation.
///
/// Intent: planning a week with two recipes that both need flour yields ONE
/// summed line instead of duplicates — and nothing the user needs to buy is
/// ever silently dropped, however unparseable the ingredient line.
///
/// BUT-1613 layered presence-driven QUANTITY SCALING on top: each recipe
/// placement carries a `factor` (present-count / authored-portions) that scales
/// its numeric amounts BEFORE the shared name|unit merge sums them. The
/// factor-1.0 tests below are the original BUT-956/BUT-1278/BUT-1279 contracts,
/// unchanged in expectation — proving scaling is a pure superset (factor 1.0 ==
/// old behaviour). The new group pins the scaling itself.
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

/// One placement at [factor] (default 1.0 = unscaled). The default keeps every
/// pre-BUT-1613 behaviour test asserting the SAME numbers it always did.
ScaledRecipe _p(Recipe r, [double factor = 1.0]) => (recipe: r, factor: factor);

void main() {
  group('MenuShoppingAggregator (BUT-956)', () {
    test('same ingredient + same unit across recipes sums into one line', () {
      // The ticket's marquee case: 2 dl mjöl + 1 dl mjöl → 3 dl mjöl.
      final items = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r1', const [
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'mjöl',
              raw: '2 dl mjöl',
            ),
          ]),
        ),
        _p(
          _recipe('r2', const [
            RecipeIngredient(
              amount: 1,
              unit: 'dl',
              name: 'mjöl',
              raw: '1 dl mjöl',
            ),
          ]),
        ),
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
        _p(
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
        ),
      ]);
      expect(items, hasLength(1), reason: 'sections must not split the line');
      expect(items.single.amount, 125);
      expect(items.single.unit, 'g');
    });

    test('Swedish-character variants merge ("Mjöl" + "mjol")', () {
      final items = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r1', const [
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'Mjöl',
              raw: '2 dl Mjöl',
            ),
          ]),
        ),
        _p(
          _recipe('r2', const [
            RecipeIngredient(
              amount: 1,
              unit: 'dl',
              name: 'mjol',
              raw: '1 dl mjol',
            ),
          ]),
        ),
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
        _p(
          _recipe('r1', const [
            RecipeIngredient(
              amount: 200,
              unit: 'g',
              name: 'mjöl',
              raw: '200 g mjöl',
            ),
          ]),
        ),
        _p(
          _recipe('r2', const [
            RecipeIngredient(
              amount: 1,
              unit: 'dl',
              name: 'mjöl',
              raw: '1 dl mjöl',
            ),
          ]),
        ),
      ]);
      expect(items, hasLength(2));
    });

    test(
      'BUT-1278: compatible VOLUME units merge into one line (3 dl + 200 ml)',
      () {
        // The ticket's marquee case: 3 dl + 200 ml is 500 ml of the same thing —
        // one line, not two. Display reduces to the readable Swedish unit (5 dl).
        final items = MenuShoppingAggregator.aggregate([
          _p(
            _recipe('r1', const [
              RecipeIngredient(
                amount: 3,
                unit: 'dl',
                name: 'grädde',
                raw: '3 dl grädde',
              ),
            ]),
          ),
          _p(
            _recipe('r2', const [
              RecipeIngredient(
                amount: 200,
                unit: 'ml',
                name: 'grädde',
                raw: '200 ml grädde',
              ),
            ]),
          ),
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
          _p(
            _recipe('r1', const [
              RecipeIngredient(
                amount: 1,
                unit: 'kg',
                name: 'potatis',
                raw: '1 kg potatis',
              ),
            ]),
          ),
          _p(
            _recipe('r2', const [
              RecipeIngredient(
                amount: 300,
                unit: 'g',
                name: 'potatis',
                raw: '300 g potatis',
              ),
            ]),
          ),
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
        _p(
          _recipe('r1', const [
            RecipeIngredient(
              amount: 2,
              unit: 'msk',
              name: 'olja',
              raw: '2 msk olja',
            ),
          ]),
        ),
        _p(
          _recipe('r2', const [
            RecipeIngredient(
              amount: 1,
              unit: 'dl',
              name: 'olja',
              raw: '1 dl olja',
            ),
          ]),
        ),
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
          _p(
            _recipe('r1', const [
              RecipeIngredient(
                amount: 2,
                unit: 'st',
                name: 'ägg',
                raw: '2 ägg',
              ),
            ]),
          ),
          _p(
            _recipe('r2', const [
              RecipeIngredient(
                amount: 3,
                unit: 'st',
                name: 'ägg',
                raw: '3 ägg',
              ),
            ]),
          ),
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
            _p(
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
            ),
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
        _p(_recipe('r1', [RecipeIngredient.rawOnly('en nypa salt')])),
        _p(
          _recipe('r2', const [
            RecipeIngredient(name: 'vitlöksklyftor', raw: '1-2 vitlöksklyftor'),
          ]),
        ),
      ]);
      expect(items, hasLength(2));
      expect(items.every((i) => i.amount == null), isTrue);
    });

    test('amount-less duplicates collapse to one line by name', () {
      final items = MenuShoppingAggregator.aggregate([
        _p(_recipe('r1', [RecipeIngredient.rawOnly('salt')])),
        _p(_recipe('r2', [RecipeIngredient.rawOnly('salt')])),
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
      final items = MenuShoppingAggregator.aggregate([_p(legacy)]);
      expect(items, hasLength(1));
      expect(
        items.single.amount,
        isNull,
        reason: 'no derivation here — raw-only lands as amount-less',
      );
    });

    test('output is grouped by category then name (stable shopping order)', () {
      final items = MenuShoppingAggregator.aggregate([
        _p(
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
        ),
      ]);
      final categories = items.map((i) => i.category).toList();
      final sorted = [...categories]..sort();
      expect(categories, sorted, reason: 'category-major ordering');
    });

    test('blank ingredient names are skipped (never produce empty lines)', () {
      final items = MenuShoppingAggregator.aggregate([
        _p(_recipe('r1', [RecipeIngredient.rawOnly('   ')])),
      ]);
      expect(items, isEmpty);
    });
  });

  group('MenuShoppingAggregator presence scaling (BUT-1613)', () {
    test('a factor of 0.5 halves — and 3.0 triples — a numeric amount', () {
      // Proves: the placement factor multiplies the authored amount. "st" has
      // no measurement family so it passes through the merge unchanged — the
      // clean lens on the scale math without unit re-display noise.
      final halved = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r', const [
            RecipeIngredient(amount: 4, unit: 'st', name: 'ägg', raw: '4 ägg'),
          ]),
          0.5,
        ),
      ]);
      expect(halved.single.amount, closeTo(2, 1e-9));
      expect(halved.single.unit, 'st');

      final tripled = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r', const [
            RecipeIngredient(amount: 2, unit: 'st', name: 'ägg', raw: '2 ägg'),
          ]),
          3.0,
        ),
      ]);
      expect(tripled.single.amount, closeTo(6, 1e-9));
    });

    test('the SAME recipe at two placements with DIFFERENT factors scales '
        'per-placement BEFORE the name|unit merge sums them', () {
      // The core BUT-1613 guarantee: "4 dl mjölk" cooked at full presence
      // (factor 1.0 → 4 dl) plus the same dish again at half presence
      // (factor 0.5 → 2 dl) must buy 6 dl — NOT 4 dl (merge-then-scale) and
      // NOT 8 dl (a single factor applied twice). Only scale-then-merge is 6.
      final r = _recipe('r', const [
        RecipeIngredient(
          amount: 4,
          unit: 'dl',
          name: 'mjölk',
          raw: '4 dl mjölk',
        ),
      ]);
      final items = MenuShoppingAggregator.aggregate([_p(r, 1.0), _p(r, 0.5)]);
      expect(items, hasLength(1));
      expect(
        items.single.amount,
        closeTo(6, 1e-9),
        reason: '4 dl × 1.0 + 4 dl × 0.5 = 6 dl (scale each, then sum)',
      );
      expect(items.single.unit, 'dl');
      expect(items.single.sourceCount, 2);
    });

    test(
      'an amount-less line is UNCHANGED by any factor and never dropped',
      () {
        // "salt efter smak" carries no quantity, so no factor — however small —
        // can scale it toward zero or drop it. It must survive present + amount
        // null regardless of the placement factor.
        final items = MenuShoppingAggregator.aggregate([
          _p(
            _recipe('r', [RecipeIngredient.rawOnly('salt efter smak')]),
            0.1,
          ),
        ]);
        expect(items, hasLength(1), reason: 'the amount-less line must remain');
        expect(items.single.name, 'salt efter smak');
        expect(
          items.single.amount,
          isNull,
          reason: 'no amount to scale — a factor cannot zero or drop it',
        );
      },
    );

    test('a small factor against a real amount stays a POSITIVE line, never '
        'zeroed or dropped', () {
      // A positive amount times a positive factor is positive: "1 dl" at
      // factor 0.125 is a real (if tiny) quantity the shopper still needs —
      // it must land present with amount > 0, not rounded away to 0 or dropped.
      // (Unit/exact value are intentionally left unasserted: the compatible-
      // unit merge may re-display 12.5 ml, and pinning that would break on a
      // display refactor without changing the "still positive, still there"
      // behaviour this test exists to prove.)
      final items = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r', const [
            RecipeIngredient(
              amount: 1,
              unit: 'dl',
              name: 'grädde',
              raw: '1 dl grädde',
            ),
          ]),
          0.125,
        ),
      ]);
      expect(items, hasLength(1));
      expect(
        items.single.amount,
        greaterThan(0),
        reason: 'positive amount × positive factor stays positive',
      );
    });

    test('compatible-unit merging still works ACROSS scaled placements', () {
      // Scaling happens before the family merge, so two placements that scale
      // into the same volume family still collapse to one line: "4 dl" at
      // factor 0.5 (→ 2 dl = 200 ml) + "300 ml" at factor 1.0 = 500 ml = 5 dl.
      final items = MenuShoppingAggregator.aggregate([
        _p(
          _recipe('r1', const [
            RecipeIngredient(
              amount: 4,
              unit: 'dl',
              name: 'grädde',
              raw: '4 dl grädde',
            ),
          ]),
          0.5,
        ),
        _p(
          _recipe('r2', const [
            RecipeIngredient(
              amount: 300,
              unit: 'ml',
              name: 'grädde',
              raw: '300 ml grädde',
            ),
          ]),
        ),
      ]);
      expect(
        items,
        hasLength(1),
        reason: 'scaled placements in one family must still merge',
      );
      expect(items.single.unit, 'dl');
      expect(
        items.single.amount,
        closeTo(5, 1e-9),
        reason: '(4 dl × 0.5 = 200 ml) + 300 ml = 500 ml = 5 dl',
      );
      expect(items.single.sourceCount, 2);
    });
  });
}
