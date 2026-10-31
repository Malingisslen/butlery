/// Q4-03 = A (produktbeslut 2026-09-24): "Lägg {n} varor i inköpslistan"
/// counts the recipe's items the pantry does not already cover, by the week
/// merge's rule. Kärnflöde steg 8C: the recipe button and the week menu's
/// shopping list are one computation.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_shopping_handler.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

PantryItem _pantry(
  String name, {
  double? quantity,
  String unit = 'st',
  DateTime? expiry,
  String? ingredientId,
}) => PantryItem(
  id: 'p_$name',
  ingredientName: name,
  ingredientId: ingredientId,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 1, 1),
  expiryDate: expiry,
);

Recipe _recipe(
  List<String> lines, {
  int? portions = 4,
  List<RecipeIngredient> structured = const [],
}) => Recipe(
  core: RecipeCore(
    title: 'Test',
    description: '',
    ingredients: lines,
    structuredIngredients: structured,
    instructions: const [],
    mealType: '',
    portions: portions,
  ),
  type: RecipeType.personal,
);

/// 308 nines: `QuantityParser.parse` returns this as a FINITE double (309
/// becomes Infinity), so the overflow below happens in the scaling
/// arithmetic and not in the parse.
final String _nearMaxQuantity = '9' * 308;

List<UnifiedShoppingItem> _toBuy(
  Recipe recipe, {
  int portions = 4,
  List<PantryItem> pantry = const [],
}) => RecipePantryCheck.check(recipe, portions: portions, pantry: pantry).toBuy;

UnifiedShoppingItem _named(List<UnifiedShoppingItem> items, String name) =>
    items.singleWhere((i) => i.name.toLowerCase() == name.toLowerCase());

Set<String> _names(List<UnifiedShoppingItem> items) =>
    items.map((i) => i.name.toLowerCase()).toSet();

void main() {
  final pancakes = _recipe([
    '4 st ägg',
    '5 dl mjölk',
    '3 dl vetemjöl',
    '1 krm salt',
  ]);

  test('a pantry row of the same registry entry covers a row of another '
      'name', () {
    final red = _recipe(
      ['2 st rödlök'],
      structured: const [
        RecipeIngredient(
          amount: 2,
          unit: 'st',
          name: 'rödlök',
          raw: '2 st rödlök',
          ingredientId: 'onion',
        ),
      ],
    );
    final pantry = [_pantry('Lök', quantity: 5, ingredientId: 'onion')];

    expect(_toBuy(red, pantry: pantry), isEmpty);
    expect(
      _toBuy(_recipe(['2 st rödlök']), pantry: pantry),
      hasLength(1),
      reason: 'without the row id the differing names stay unmatched',
    );
  });

  test('an id match still subtracts only what is at home', () {
    final red = _recipe(
      ['3 st rödlök'],
      structured: const [
        RecipeIngredient(
          amount: 3,
          unit: 'st',
          name: 'rödlök',
          raw: '3 st rödlök',
          ingredientId: 'onion',
        ),
      ],
    );

    final result = RecipePantryCheck.check(
      red,
      portions: 4,
      pantry: [_pantry('lök', quantity: 2, ingredientId: 'onion')],
    );

    expect(result.coveredAtHome, isEmpty);
    expect(result.lessened, ['rödlök']);
    expect(result.toBuy.single.amount, closeTo(1, 1e-9));
  });

  test('an empty pantry covers nothing', () {
    final items = _toBuy(pancakes);

    expect(_names(items), {'ägg', 'mjölk', 'vetemjöl', 'salt'});
    expect(items.every((i) => i.note == null), isTrue);
  });

  test('a pantry row in another spelling of the unit is subtracted', () {
    final left = _toBuy(
      pancakes,
      pantry: [_pantry('Ägg', quantity: 6, unit: 'stycken')],
    );

    expect(_names(left), {'mjölk', 'vetemjöl', 'salt'});
  });

  test('enough at home leaves an item off; name matching ignores case', () {
    final left = _toBuy(pancakes, pantry: [_pantry('ägg', quantity: 6)]);

    expect(_names(left), {'mjölk', 'vetemjöl', 'salt'});
  });

  test('some at home leaves the difference, across units in one family', () {
    final left = _toBuy(
      pancakes,
      pantry: [_pantry('Mjölk', quantity: 200, unit: 'ml')],
    );

    final milk = _named(left, 'mjölk');
    expect(milk.amount, closeTo(3, 1e-9));
    expect(milk.unit, 'dl');
    expect(left, hasLength(4));
  });

  test('har hemma (no amount) subtracts nothing and marks Kanske hemma', () {
    final left = _toBuy(pancakes, pantry: [_pantry('Salt')]);

    expect(left, hasLength(4));
    final salt = _named(left, 'salt');
    expect(salt.amount, 1);
    expect(salt.note, 'Kanske hemma');
    expect(_named(left, 'ägg').note, isNot('Kanske hemma'));
  });

  test('a row without an amount is covered by any stock in date '
      '(Malin 2026-10-31)', () {
    final saltOnly = _recipe(['salt']);

    final result = RecipePantryCheck.check(
      saltOnly,
      portions: 4,
      pantry: [_pantry('Salt', quantity: 1, unit: 'förp')],
    );
    expect(result.toBuy, isEmpty);
    expect(result.coveredAtHome, ['salt']);

    expect(_toBuy(saltOnly, pantry: [_pantry('Salt')]), isEmpty);

    final expired = _toBuy(
      saltOnly,
      pantry: [_pantry('Salt', quantity: 1, expiry: DateTime(2020, 1, 1))],
    );
    expect(expired.single.note, 'Kolla datum');
  });

  test('a row past its date subtracts nothing and marks Kolla datum', () {
    final left = _toBuy(
      pancakes,
      pantry: [_pantry('Ägg', quantity: 12, expiry: DateTime(2000))],
    );

    expect(left, hasLength(4));
    final egg = _named(left, 'ägg');
    expect(egg.amount, 4);
    expect(egg.note, 'Kolla datum');
  });

  test('another unit family subtracts nothing and marks Kanske hemma', () {
    final left = _toBuy(
      pancakes,
      pantry: [_pantry('Vetemjöl', quantity: 2, unit: 'kg')],
    );

    expect(left, hasLength(4));
    expect(_named(left, 'vetemjöl').note, 'Kanske hemma');
  });

  test('names what is covered and what is lessened', () {
    final result = RecipePantryCheck.check(
      pancakes,
      portions: 4,
      pantry: [
        _pantry('ägg', quantity: 6),
        _pantry('Mjölk', quantity: 2, unit: 'dl'),
      ],
    );

    expect(result.coveredAtHome, ['ägg']);
    expect(result.lessened, ['mjölk']);
    expect(_names(result.toBuy), {'mjölk', 'vetemjöl', 'salt'});
  });

  test('one ingredient on two lines is counted against the pantry once', () {
    final twice = _recipe(['2 dl mjölk', '2 st ägg', '1 dl mjölk']);

    final result = RecipePantryCheck.check(
      twice,
      portions: 4,
      pantry: [_pantry('Mjölk', quantity: 2, unit: 'dl')],
    );

    expect(result.coveredAtHome, isEmpty);
    expect(_named(result.toBuy, 'mjölk').amount, closeTo(1, 1e-9));
    expect(result.toBuy, hasLength(2));
  });

  test('two lines in one unit family are joined in the first unit', () {
    final twice = _recipe(['2 dl mjölk', '100 ml mjölk']);

    final left = _toBuy(
      twice,
      pantry: [_pantry('Mjölk', quantity: 1, unit: 'dl')],
    );

    expect(left, hasLength(1));
    expect(left.single.amount, closeTo(2, 1e-9));
    expect(left.single.unit, 'dl');
  });

  test('two lines that do not convert become one row, marked, with the other '
      'amount shown', () {
    final twice = _recipe(['100 g smör', '2 msk smör']);

    final left = _toBuy(
      twice,
      pantry: [_pantry('Smör', quantity: 500, unit: 'g')],
    );

    final butter = left.single;
    expect(butter.amount, 100);
    expect(butter.unit, 'g');
    expect(butter.note, '+ 2 msk · Kanske hemma');
  });

  test('a prepared pantry row covers the plain ingredient', () {
    final left = _toBuy(
      _recipe(['2 st lök']),
      pantry: [_pantry('hackad lök', quantity: 6)],
    );

    expect(left, isEmpty);
  });

  test('lines that differ only by a preparation word are counted once', () {
    final left = _toBuy(_recipe(['1 st hackad lök', '1 st lök']));

    expect(left, hasLength(1));
    expect(left.single.amount, closeTo(2, 1e-9));
  });

  test('lines that do not convert are marked when the pantry holds the plain '
      'name', () {
    final left = _toBuy(
      _recipe(['1 msk hackad lök', '50 g lök']),
      pantry: [_pantry('lök', quantity: 5)],
    );

    expect(left, hasLength(1));
    expect(left.single.note, contains('Kanske hemma'));
    expect(left.single.note, contains('+ '));
  });

  test('one recipe naming an ingredient twice is not "2 recept"', () {
    final left = _toBuy(_recipe(['2 dl mjölk', '1 dl mjölk']));

    expect(left.single.amount, closeTo(3, 1e-9));
    expect(left.single.note, isNull);
  });

  test('every row carries the aisle the week list would put it in', () {
    final left = _toBuy(_recipe(['3 morötter', '2 paprikor']));

    expect(left.map((i) => i.category).toSet(), hasLength(1));
    expect(left.first.category, isNot('other'));
  });

  group('the amount a recipe line states (kärnflöde steg 3)', () {
    test('a line stating no amount gets none, and is not scaled', () {
      final items = _toBuy(
        _recipe(['salt', 'peppar efter smak', 'nypa salt'], portions: 2),
      );

      expect(items.map((i) => i.amount), [0, 0, 0]);
      expect(items.map((i) => i.unit), ['', '', '']);
      expect(items.map((i) => i.quantityText), ['', '', '']);
    });

    test('a range is bought at its highest value, scaled', () {
      final items = _toBuy(
        _recipe(['2-3 dl mjölk', '2-3 tomater'], portions: 2),
      );

      expect(items.map((i) => i.amount), [6, 6]);
    });

    test('a unit written out in full is listed as its short form', () {
      // The list sums rows by unit, so "matsked" and "msk" must meet.
      final items = _toBuy(_recipe(['1 matsked olja', '2 styck ägg']));

      expect(_named(items, 'olja').unit, 'msk');
      expect(_named(items, 'ägg').unit, 'st');
    });
  });

  group('non-finite quantities never reach amount (BUT-2067)', () {
    test('a portion scale that overflows falls back to 1.0', () {
      final items = _toBuy(
        _recipe(['$_nearMaxQuantity dl mjölk'], portions: 1),
        portions: 2,
      );

      expect(items, hasLength(1));
      expect(items.first.amount.isFinite, isTrue);
      expect(items.first.amount, 1.0);
      expect(items.first.unit, 'dl');
    });

    test('an ordinary portion scale is untouched', () {
      final items = _toBuy(_recipe(['2 dl mjölk'], portions: 2));

      expect(items.first.amount, 4.0);
    });

    test('two lines whose sum overflows fall back to 1.0', () {
      final items = _toBuy(
        _recipe(['$_nearMaxQuantity dl mjölk', '$_nearMaxQuantity dl mjölk']),
      );

      expect(items, hasLength(1));
      expect(items.first.amount.isFinite, isTrue);
      expect(items.first.amount, 1.0);
    });
  });

  group('registry id from the recipe line', () {
    test('each shopping row carries the id of its own line', () {
      final recipe = _recipe(
        ['2 dl mellanmjölk', '500 g bringa', '1 hackad lök'],
        structured: const [
          RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'mellanmjölk',
            raw: '2 dl mellanmjölk',
            ingredientId: 'milk',
          ),
          RecipeIngredient(
            amount: 500,
            unit: 'g',
            name: 'bringa',
            raw: '500 g bringa',
          ),
          RecipeIngredient(
            amount: 1,
            name: 'lök',
            raw: '1 hackad lök',
            ingredientId: 'onion',
          ),
        ],
      );

      final items = _toBuy(recipe);

      expect(items.map((i) => (i.name.toLowerCase(), i.ingredientId)).toSet(), {
        ('mellanmjölk', 'milk'),
        ('bringa', null),
        ('lök', 'onion'),
      });
    });

    test('a recipe without stored lines gives rows without ids', () {
      final items = _toBuy(_recipe(['2 dl mjölk', '3 ägg']));

      expect(items, hasLength(2));
      expect(items.map((i) => i.ingredientId), [null, null]);
    });

    test('stored lines that no longer match the text give no ids', () {
      final recipe = _recipe(
        ['4 dl mellanmjölk'],
        structured: const [
          RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'mellanmjölk',
            raw: '2 dl mellanmjölk',
            ingredientId: 'milk',
          ),
        ],
      );

      expect(_toBuy(recipe).single.ingredientId, isNull);
    });
  });

  group('kärnflöde 8C: the recipe button and the week count alike', () {
    final onionStructured = [
      const RecipeIngredient(
        amount: 2,
        unit: 'st',
        name: 'rödlök',
        raw: '2 st rödlök',
        ingredientId: 'onion',
      ),
      const RecipeIngredient(
        amount: 200,
        unit: 'g',
        name: 'bringa',
        raw: '200 g bringa',
      ),
      const RecipeIngredient(
        amount: 1,
        unit: 'st',
        name: 'lök',
        raw: '1 st lök',
        ingredientId: 'onion',
      ),
    ];

    // The factor is spelled out per case rather than recomputed, so a change
    // to how the button derives it cannot move both sides of the comparison.
    final cases =
        <({String label, Recipe recipe, int portions, double factor})>[
          (
            label: 'duplicates at its own portions',
            recipe: _recipe([
              '2 dl mjölk',
              '1 dl mjölk',
              '100 g smör',
              '2 msk smör',
              '3 ägg',
            ]),
            portions: 4,
            factor: 1.0,
          ),
          (
            label: 'duplicates at other portions',
            recipe: _recipe([
              '2 dl mjölk',
              '1 dl mjölk',
              '100 g smör',
              '2 msk smör',
              '3 ägg',
            ]),
            portions: 6,
            factor: 1.5,
          ),
          (
            label: 'ranges',
            recipe: _recipe(['2-3 dl grädde', '2-3 tomater'], portions: 2),
            portions: 5,
            factor: 2.5,
          ),
          (
            label: 'lines without an amount',
            recipe: _recipe(['salt', 'peppar efter smak', '1 krm salt']),
            portions: 8,
            factor: 2.0,
          ),
          (
            label: 'mixed units that convert and units that do not',
            recipe: _recipe([
              '1 dl mjölk',
              '100 ml mjölk',
              '500 g mjöl',
              '2 dl mjöl',
            ]),
            portions: 4,
            factor: 1.0,
          ),
          (
            label: 'structured lines with registry ids',
            recipe: _recipe([
              '2 st rödlök',
              '200 g bringa',
              '1 st lök',
            ], structured: onionStructured),
            portions: 2,
            factor: 0.5,
          ),
          (
            label: 'a recipe without a portion count',
            recipe: _recipe([
              '2 dl mjölk',
              '3 morötter',
              '1 kg potatis',
            ], portions: null),
            portions: 3,
            factor: 3.0,
          ),
          (
            label: 'a recipe stating 0 portions is not scaled',
            recipe: _recipe(['2 dl mjölk', '3 ägg'], portions: 0),
            portions: 4,
            factor: 1.0,
          ),
        ];

    final pantries = <String, List<PantryItem>>{
      'no pantry': const [],
      'a pantry that covers, lessens and marks': [
        _pantry('mjölk', quantity: 2, unit: 'dl'),
        _pantry('smör', quantity: 500, unit: 'g'),
        _pantry('ägg', quantity: 12, unit: ''),
        _pantry('salt'),
        _pantry('Lök', quantity: 1, ingredientId: 'onion'),
        _pantry('mjöl', quantity: 1, unit: 'kg', expiry: DateTime(2000)),
        _pantry('potatis', quantity: 1, unit: 'kg'),
      ],
    };

    test('the pantry fixture covers, lessens and marks (so the comparison '
        'below is not between two untouched lists)', () {
      final result = RecipePantryCheck.check(
        cases.first.recipe,
        portions: cases.first.portions,
        pantry: pantries.values.last,
      );

      expect(result.coveredAtHome, isNotEmpty);
      expect(result.lessened, isNotEmpty);
      expect(
        result.toBuy.map((i) => i.note),
        contains('+ 2 msk · Kanske hemma'),
      );
    });

    for (final c in cases) {
      for (final pantry in pantries.entries) {
        test('${c.label}, ${pantry.key}', () {
          final button = RecipePantryCheck.check(
            c.recipe,
            portions: c.portions,
            pantry: pantry.value,
          );
          final week = MenuShoppingMergePlanner.preview(
            MenuShoppingSource(
              week: DateTime(2026, 11, 2),
              placements: [(recipe: c.recipe, factor: c.factor)],
              recipeCount: 1,
            ),
            MenuShoppingPantry.read(pantry.value),
            const MenuShoppingMergeOptions(),
          );

          List<(String, double, String, String, String?, String?)> fields(
            Iterable<UnifiedShoppingItem> items,
          ) => [
            for (final i in items)
              (i.name, i.amount, i.unit, i.category, i.note, i.ingredientId),
          ];

          expect(
            fields(button.toBuy),
            fields(week.lines.map((l) => l.toItem())),
          );
          expect(button.coveredAtHome, week.coveredAtHome);
        });
      }
    }
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

    // "3 ägg" is parsed without a unit, so the pantry row is unit-less too.
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

    test('everything at home: no count, and nothing is added', () {
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
        isEmpty,
      );
      expect(
        RecipeShoppingHandler.pantryCheck(
          recipe,
          portions: 4,
          pantry: pantry,
        )!.coveredAtHome,
        hasLength(3),
      );
    });
  });
}
