import 'dart:convert';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/services/tagging/ingredient_line_weigher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

Map<String, dynamic> _food(int id, String name) => {
  'id': id,
  'name': name,
  'kcal': 100,
  'protein': 10,
};

// Chicken carries a usual amount, so a test can tell a stated weight from
// the usual one.
final NutritionTable _table = NutritionTable.fromJsonStrings(
  foodsJson: jsonEncode({
    'version': 'test',
    'foods': [
      _food(1, 'Mjölk'),
      _food(11, 'Kycklingfilé'),
      _food(16, 'Ägg'),
    ],
  }),
  matchingJson: jsonEncode({
    'ingredients': {
      'mjölk': {'food': 1, 'gPerDl': 100},
      'kycklingfilé': {
        'food': 11,
        'units': {'st': 150},
        'default': {'amount': 2, 'unit': 'st'},
      },
      'ägg': {
        'food': 16,
        'units': {'st': 50},
      },
    },
  }),
);

Recipe _recipe(List<String> lines, {int portions = 4}) =>
    RecipeBuilder().withIngredients(lines).withPortions(portions).build();

IngredientLookupResult _lookupOf(List<String> names) =>
    TaggingTestHelper.weighedLookup([
      for (final name in names)
        (TaggingTestHelper.ingredient(name, 'protein', {}), null),
    ]);

List<double?> _grams(IngredientLookupResult r) => [
  for (final l in r.lines) l.grams,
];

IngredientLookupResult _weigh(
  IngredientLookupResult lookup,
  Recipe recipe,
  List<String> lookedUp,
) => _weighWith(_table, lookup, recipe, lookedUp);

IngredientLookupResult _weighWith(
  NutritionTable? table,
  IngredientLookupResult lookup,
  Recipe recipe,
  List<String> lookedUp,
) => IngredientLineWeigher.weigh(
  lookup: lookup,
  recipe: recipe,
  lookedUp: lookedUp,
  table: table,
);

void main() {
  group('IngredientLineWeigher.weigh', () {
    test('a stated weight or volume becomes grams on its line', () {
      final lines = ['400 g kycklingfilé', '2 dl mjölk', '3 st ägg'];

      final result = _weigh(
        _lookupOf(['kyckling', 'mjölk', 'ägg']),
        _recipe(lines),
        lines,
      );

      expect(_grams(result), [400, 200, 150]);
    });

    test('a stated weight is the recipe as written, whatever the portions', () {
      final lines = ['400 g kycklingfilé'];

      final result = _weigh(
        _lookupOf(['kyckling']),
        _recipe(lines, portions: 8),
        lines,
      );

      expect(_grams(result), [400]);
    });

    test(
      'a line with no amount stays unweighed, the usual amount is not used',
      () {
        final lines = ['kycklingfilé'];

        final result = _weigh(_lookupOf(['kyckling']), _recipe(lines), lines);

        expect(_grams(result), [null]);
      },
    );

    test('a stated amount the table cannot weigh stays unweighed', () {
      // Chicken has no volume weight, so "3 msk" cannot become grams.
      final lines = ['3 msk kycklingfilé'];

      final result = _weigh(_lookupOf(['kyckling']), _recipe(lines), lines);

      expect(_grams(result), [null]);
    });

    test('a food the table does not know stays unweighed', () {
      final lines = ['2 dl okändmat'];

      final result = _weigh(_lookupOf(['okändmat']), _recipe(lines), lines);

      expect(_grams(result), [null]);
    });

    test(
      'weights stay beside their own line when lookedUp is the recipe lines',
      () {
        final lines = ['400 g kycklingfilé', 'ägg', '2 dl mjölk'];

        final result = _weigh(
          _lookupOf(['kyckling', 'ägg', 'mjölk']),
          _recipe(lines),
          lines,
        );

        expect(_grams(result), [400, null, 200]);
      },
    );

    test('names that skip an empty line map to the non-empty lines', () {
      final lines = ['400 g kycklingfilé', '', '2 dl mjölk'];

      final result = _weigh(
        _lookupOf(['kyckling', 'mjölk']),
        _recipe(lines),
        ['kyckling', 'mjölk'],
      );

      // Mapped by position instead, mjölk would read the empty line's null.
      expect(_grams(result), [400, 200]);
    });

    test('a lookup whose length matches neither the lines nor the non-empty '
        'lines is returned unchanged', () {
      final lines = ['400 g kycklingfilé', '2 dl mjölk', '3 st ägg'];
      final lookup = _lookupOf(['kyckling', 'mjölk']);

      final result = _weigh(lookup, _recipe(lines), ['kyckling', 'mjölk']);

      expect(result, same(lookup));
      expect(_grams(result), [null, null]);
    });

    test('lookedUp and lookup lines of different length return the lookup '
        'unchanged', () {
      final lines = ['400 g kycklingfilé', '2 dl mjölk'];
      final lookup = _lookupOf(['kyckling', 'mjölk']);

      final result = _weigh(lookup, _recipe(lines), [...lines, 'extra']);

      expect(result, same(lookup));
    });

    test('a lookup without recipe lines is returned unchanged', () {
      final lines = ['400 g kycklingfilé'];
      final lookup = TaggingTestHelper.createLookup([
        TaggingTestHelper.ingredient('kyckling', 'protein', {}),
      ]);
      expect(lookup.hasRecipeLines, isFalse);

      final result = _weigh(lookup, _recipe(lines), lines);

      expect(result, same(lookup));
      expect(result.hasRecipeLines, isFalse);
    });

    test('a line stated in grams or kilos is weighed without a table', () {
      final lines = ['400 g okändvara', '1,5 kg potatis'];

      final result = _weighWith(
        null,
        _lookupOf(['okändvara', 'potatis']),
        _recipe(lines),
        lines,
      );

      expect(_grams(result), [400, 1500]);
    });

    test('a line stated in grams is weighed when the table lacks the food', () {
      final lines = ['400 g okändmat'];

      final result = _weigh(_lookupOf(['okändmat']), _recipe(lines), lines);

      expect(_grams(result), [400]);
    });

    test('volume, pieces and no amount stay unweighed without a table', () {
      final lines = ['2 dl mjölk', '3 st ägg', 'kycklingfilé'];

      final result = _weighWith(
        null,
        _lookupOf(['mjölk', 'ägg', 'kyckling']),
        _recipe(lines),
        lines,
      );

      expect(_grams(result), [null, null, null]);
    });

    test('weighing keeps each line\'s names and rows', () {
      final lines = ['400 g kycklingfilé'];
      final lookup = _lookupOf(['kyckling']);

      final weighed = _weigh(lookup, _recipe(lines), lines).lines.single;

      expect(weighed.names, lookup.lines.single.names);
      expect(weighed.ingredients, lookup.lines.single.ingredients);
      expect(weighed.known, isTrue);
    });
  });

  // Without a registered nutrition service the table is missing, and a line
  // stated in grams must still weigh so tags do not depend on the asset.
  test('withTable weighs stated grams when there is no table', () async {
    final lines = ['400 g kycklingfilé', '2 dl grädde'];

    final result = await IngredientLineWeigher.withTable(null)(
      _lookupOf(['kycklingfilé', 'grädde']),
      _recipe(lines),
      lines,
    );

    expect(_grams(result), [400, null]);
  });
}
