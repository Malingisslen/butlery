/// Loads the REAL bundled tables (the files `rootBundle` serves in the app)
/// and computes a known recipe by hand, so a bad curated entry, a wrong food
/// id or a broken key fold shows up here rather than in a user's recipe.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';

late String _foodsJson;
late String _matchingJson;
late Map<String, dynamic> _foodsDoc;
late Map<String, dynamic> _matchingDoc;
late NutritionTable _table;

/// The curated row for [name], as written in the matching file.
Map<String, dynamic> _curatedRow(String name) =>
    (_matchingDoc['ingredients'] as Map<String, dynamic>)[name]
        as Map<String, dynamic>;

/// The food-table row for [id], as written in the foods file.
Map<String, dynamic> _foodRow(int id) => (_foodsDoc['foods'] as List)
    .cast<Map<String, dynamic>>()
    .singleWhere((f) => f['id'] == id);

double _kcalOf(String curatedName, double grams) {
  final id = (_curatedRow(curatedName)['food'] as num).toInt();
  return (_foodRow(id)['kcal'] as num).toDouble() * grams / 100;
}

RecipeIngredient _ing(num? amount, String? unit, String name) =>
    RecipeIngredient(
      amount: amount,
      unit: unit,
      name: name,
      raw: [if (amount != null) '$amount', ?unit, name].join(' '),
    );

void main() {
  setUpAll(() {
    // flutter test runs with the package root as working directory.
    _foodsJson = File('assets/data/livsmedel_naring.json').readAsStringSync();
    _matchingJson = File(
      'assets/data/naring_matchning.json',
    ).readAsStringSync();
    _foodsDoc = jsonDecode(_foodsJson) as Map<String, dynamic>;
    _matchingDoc = jsonDecode(_matchingJson) as Map<String, dynamic>;
    _table = NutritionTable.fromJsonStrings(
      foodsJson: _foodsJson,
      matchingJson: _matchingJson,
    );
  });

  group('bundled data integrity', () {
    test('every curated ingredient points at a food that exists', () {
      final ingredients = _matchingDoc['ingredients'] as Map<String, dynamic>;
      expect(ingredients, isNotEmpty);
      final dangling = <String>[
        for (final e in ingredients.entries)
          if (_table.food(((e.value as Map)['food'] as num).toInt()) == null)
            e.key,
      ];
      expect(dangling, isEmpty);
    });

    test('every alias lands on a curated ingredient', () {
      final aliases = (_matchingDoc['aliases'] as Map<String, dynamic>)
          .cast<String, String>();
      expect(aliases, isNotEmpty);
      final dangling = <String>[
        for (final e in aliases.entries)
          if (_table.curated(NutritionKey.lookupKey(e.key)) == null) e.key,
      ];
      expect(dangling, isEmpty);
    });

    test('no negligible name is also curated', () {
      final negligible = (_matchingDoc['negligible'] as List).cast<String>();
      expect(negligible, isNotEmpty);
      final both = <String>[
        for (final n in negligible)
          if (_table.curated(NutritionKey.lookupKey(n)) != null) n,
      ];
      expect(both, isEmpty);
    });

    test('the food table carries a version and a source line to credit', () {
      expect(_table.version, isNotEmpty);
      expect(_foodsDoc['license'], contains('CC BY'));
    });
  });

  test(
    'a lentil curry: every line has the expected status and the kcal add up',
    () {
      // 4 portioner. Grams come from the curated weights, kcal from the food
      // table row of the food the curated entry points at:
      //   3 dl röda linser   = 3 * gPerDl                 -> 3 dl * g/dl
      //   400 ml kokosmjölk  = 4 dl * gPerDl
      //   1 burk krossade tomater = units.burk
      //   1 gul lök (no unit)     = units.st
      //   2 klyftor vitlök        = 2 * units.klyfta
      //   1 tsk salt         = 5 ml = 0.05 dl * gPerDl
      final linserG = 3 * (_curatedRow('röda linser')['gPerDl'] as num);
      final kokosG = 4 * (_curatedRow('kokosmjölk')['gPerDl'] as num);
      final tomaterG = (_curatedRow('krossade tomater')['units']['burk'] as num)
          .toDouble();
      final lokG = (_curatedRow('gul lök')['units']['st'] as num).toDouble();
      final vitlokG = 2 * (_curatedRow('vitlök')['units']['klyfta'] as num);
      final saltG = 0.05 * (_curatedRow('salt')['gPerDl'] as num);

      final expectedKcal =
          _kcalOf('röda linser', linserG.toDouble()) +
          _kcalOf('kokosmjölk', kokosG.toDouble()) +
          _kcalOf('krossade tomater', tomaterG) +
          _kcalOf('gul lök', lokG) +
          _kcalOf('vitlök', vitlokG.toDouble()) +
          _kcalOf('salt', saltG.toDouble());

      final summary = NutritionCalculator(table: _table).calculate(
        ingredients: [
          _ing(3, 'dl', 'röda linser'),
          _ing(400, 'ml', 'kokosmjölk'),
          _ing(1, 'burk', 'krossade tomater'),
          _ing(1, null, 'gul lök'),
          _ing(2, 'klyftor', 'vitlök'),
          _ing(1, 'tsk', 'salt'),
          _ing(null, null, 'salt och peppar'),
        ],
        portions: 4,
      );

      expect(
        summary.lines.map((l) => l.status).toList(),
        [
          ...List.filled(6, NutritionLineStatus.counted),
          NutritionLineStatus.skipped,
        ],
      );
      expect(summary.countedLines, 6);
      expect(summary.countableLines, 6);
      expect(summary.missing, isEmpty);

      expect(summary.lines[0].grams, closeTo(linserG, 1e-9));
      expect(summary.lines[1].grams, closeTo(kokosG, 1e-9));
      expect(summary.lines[2].grams, closeTo(tomaterG, 1e-9));
      expect(summary.lines[3].grams, closeTo(lokG, 1e-9));
      expect(summary.lines[4].grams, closeTo(vitlokG, 1e-9));
      expect(summary.lines[5].grams, closeTo(saltG, 1e-9));

      // The curated entries must point at the foods a cook would expect.
      final foodNames = [
        for (final l in summary.lines.take(6)) l.food!.name.toLowerCase(),
      ];
      expect(foodNames[0], contains('linser'));
      expect(foodNames[1], contains('kokos'));
      expect(foodNames[2], contains('tomat'));
      expect(foodNames[3], contains('lök'));
      expect(foodNames[4], contains('vitlök'));
      expect(foodNames[5], contains('salt'));

      expect(summary.total.kcal, closeTo(expectedKcal, 1e-6));
      expect(summary.perPortion!.kcal, closeTo(expectedKcal / 4, 1e-6));
      expect(summary.forPortions(8).kcal, closeTo(expectedKcal * 2, 1e-6));

      // Plausibility, independent of the arithmetic above: a lentil and
      // coconut curry for four is a few hundred kcal a portion.
      expect(summary.perPortion!.kcal, inInclusiveRange(250, 700));
    },
  );

  test('the same recipe as legacy raw-only lines gives the same total', () {
    final structured = NutritionCalculator(table: _table).calculate(
      ingredients: [
        _ing(3, 'dl', 'röda linser'),
        _ing(1, 'tsk', 'salt'),
      ],
      portions: 4,
    );
    final legacy = NutritionCalculator(table: _table).calculate(
      ingredients: [
        RecipeIngredient.rawOnly('3 dl röda linser'),
        RecipeIngredient.rawOnly('1 tsk salt'),
      ],
      portions: 4,
    );
    expect(legacy.countedLines, 2);
    expect(legacy.total.kcal, closeTo(structured.total.kcal, 1e-9));
  });

  test('a recipe line spelled without accents finds the curated entry', () {
    final summary = NutritionCalculator(table: _table).calculate(
      ingredients: [_ing(2, 'st', 'Kycklingfile')],
      portions: 2,
    );
    expect(summary.lines.single.status, NutritionLineStatus.counted);
    expect(summary.lines.single.food!.name.toLowerCase(), contains('kyckling'));
  });
}
