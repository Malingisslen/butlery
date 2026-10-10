import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';

Map<String, dynamic> _food(
  int id,
  String name, {
  double kcal = 0,
  double protein = 0,
  double salt = 0,
}) => {'id': id, 'name': name, 'kcal': kcal, 'protein': protein, 'salt': salt};

// Values are round on purpose so the expected totals can be checked by eye.
final NutritionTable _table = NutritionTable.fromJsonStrings(
  foodsJson: jsonEncode({
    'version': 'test',
    'foods': [
      _food(1, 'Mjölk', kcal: 60, protein: 3.5),
      _food(10, 'Linser torkade', kcal: 300, protein: 25),
      _food(11, 'Kycklingfilé', kcal: 100, protein: 20),
      _food(13, 'Salt', salt: 99),
      _food(14, 'Koriander', kcal: 40),
      _food(15, 'Havregryn', kcal: 370, protein: 13),
      _food(16, 'Ägg', kcal: 140, protein: 12),
    ],
  }),
  matchingJson: jsonEncode({
    'ingredients': {
      'mjölk': {'food': 1, 'gPerDl': 100},
      'röda linser': {'food': 10, 'gPerDl': 80},
      'kycklingfilé': {
        'food': 11,
        'units': {'st': 150},
      },
      'salt': {'food': 13, 'gPerDl': 120, 'toTaste': true},
      'koriander': {
        'food': 14,
        'toTaste': true,
        'units': {'knippe': 30},
      },
      'ägg': {
        'food': 16,
        'units': {'st': 50},
      },
    },
    'negligible': ['peppar'],
  }),
);

RecipeIngredient _line(num? amount, String? unit, String name) =>
    RecipeIngredient(
      amount: amount,
      unit: unit,
      name: name,
      raw: [if (amount != null) '$amount', ?unit, name].join(' '),
    );

NutritionCalculator _calc([Map<String, int> choices = const {}]) =>
    NutritionCalculator(table: _table, householdChoices: choices);

void main() {
  group('totals', () {
    test('counted lines add up per100g * grams / 100', () {
      final summary = _calc().calculate(
        ingredients: [
          _line(2, 'dl', 'röda linser'), // 160 g -> 480 kcal, 40 g protein
          _line(2, null, 'kycklingfilé'), // 300 g -> 300 kcal, 60 g protein
          _line(100, 'g', 'mjölk'), // 100 g -> 60 kcal, 3.5 g protein
        ],
        portions: 4,
      );
      expect(summary.total.kcal, closeTo(840, 1e-9));
      expect(summary.total.protein, closeTo(103.5, 1e-9));
      expect(summary.countedLines, 3);
      expect(summary.countableLines, 3);
      expect(summary.missing, isEmpty);
      expect(summary.lines[0].grams, closeTo(160, 1e-9));
      expect(summary.lines[0].food!.id, 10);
    });

    test('a line that cannot be counted adds nothing to the total', () {
      final summary = _calc().calculate(
        ingredients: [
          _line(100, 'g', 'mjölk'),
          _line(3, 'nypor', 'kycklingfilé'),
          _line(1, 'st', 'drakfrukt'),
        ],
        portions: 1,
      );
      expect(summary.total.kcal, closeTo(60, 1e-9));
    });
  });

  group('portions', () {
    final lines = [_line(200, 'g', 'mjölk')]; // 120 kcal

    test('per portion is the total divided by the stated portions', () {
      final summary = _calc().calculate(ingredients: lines, portions: 4);
      expect(summary.total.kcal, closeTo(120, 1e-9));
      expect(summary.perPortion!.kcal, closeTo(30, 1e-9));
      expect(summary.basePortions, 4);
    });

    test('forPortions scales the recipe from its stated portions', () {
      final summary = _calc().calculate(ingredients: lines, portions: 4);
      expect(summary.forPortions(8).kcal, closeTo(240, 1e-9));
      expect(summary.forPortions(2).kcal, closeTo(60, 1e-9));
      expect(summary.forPortions(4).kcal, closeTo(120, 1e-9));
    });

    test(
      'no stated portions: no per portion, forPortions returns the total',
      () {
        final summary = _calc().calculate(ingredients: lines, portions: null);
        expect(summary.perPortion, isNull);
        expect(summary.forPortions(6).kcal, closeTo(120, 1e-9));
      },
    );

    test('zero portions is treated like no portions', () {
      final summary = _calc().calculate(ingredients: lines, portions: 0);
      expect(summary.perPortion, isNull);
      expect(summary.forPortions(6).kcal, closeTo(120, 1e-9));
    });
  });

  group('line statuses', () {
    test(
      'a to-taste ingredient with no amount is skipped and not countable',
      () {
        final summary = _calc().calculate(
          ingredients: [_line(100, 'g', 'mjölk'), _line(null, null, 'salt')],
          portions: 2,
        );
        final salt = summary.lines[1];
        expect(salt.status, NutritionLineStatus.skipped);
        expect(salt.food!.id, 13);
        expect(summary.countableLines, 1);
        expect(summary.countedLines, 1);
        expect(summary.missing, isEmpty);
        expect(summary.total.salt, 0);
      },
    );

    test('a to-taste ingredient WITH an amount is counted', () {
      final summary = _calc().calculate(
        ingredients: [_line(1, 'tsk', 'salt')], // 5 ml * 1.2 g/ml = 6 g
        portions: 1,
      );
      expect(summary.lines.single.status, NutritionLineStatus.counted);
      expect(summary.total.salt, closeTo(5.94, 1e-9));
    });

    test('a curated ingredient that is not to-taste still needs an amount', () {
      final summary = _calc().calculate(
        ingredients: [_line(null, null, 'kycklingfilé')],
        portions: 2,
      );
      expect(summary.lines.single.status, NutritionLineStatus.noAmount);
      expect(summary.lines.single.food!.id, 11);
      expect(summary.missing, hasLength(1));
      expect(summary.countableLines, 1);
      expect(summary.countedLines, 0);
    });

    test('a negligible spice is skipped, with or without an amount line', () {
      final summary = _calc().calculate(
        ingredients: [_line(null, null, 'Peppar'), _line(100, 'g', 'mjölk')],
        portions: 2,
      );
      expect(summary.lines[0].status, NutritionLineStatus.skipped);
      expect(summary.lines[0].food, isNull);
      expect(summary.countableLines, 1);
      expect(summary.missing, isEmpty);
    });

    test(
      'an unknown name is noMatch, keeps its storage key, and is missing',
      () {
        final summary = _calc().calculate(
          ingredients: [_line(2, 'dl', 'Drakfrukt')],
          portions: 2,
        );
        final line = summary.lines.single;
        expect(line.status, NutritionLineStatus.noMatch);
        expect(line.storageKey, 'drakfrukt');
        expect(line.food, isNull);
        expect(line.grams, isNull);
        expect(summary.missing, [line]);
        expect(summary.countableLines, 1);
      },
    );

    test('a matched food with an unknown unit is noAmount, not noMatch', () {
      final summary = _calc().calculate(
        ingredients: [_line(2, 'nypor', 'kycklingfilé')],
        portions: 2,
      );
      final line = summary.lines.single;
      expect(line.status, NutritionLineStatus.noAmount);
      expect(line.food!.id, 11);
      expect(line.grams, isNull);
    });

    test('a volume of something with no density is noAmount', () {
      final summary = _calc().calculate(
        ingredients: [_line(2, 'dl', 'kycklingfilé')],
        portions: 2,
      );
      expect(summary.lines.single.status, NutritionLineStatus.noAmount);
    });
  });

  group('name matching', () {
    test(
      'accents and case in the recipe line still find the curated entry',
      () {
        final summary = _calc().calculate(
          ingredients: [_line(2, 'st', 'Kycklingfile')],
          portions: 1,
        );
        expect(summary.lines.single.status, NutritionLineStatus.counted);
        expect(summary.lines.single.food!.id, 11);
      },
    );

    test('a leading word is dropped: "färsk koriander" is koriander', () {
      final summary = _calc().calculate(
        ingredients: [
          _line(1, 'knippe', 'färsk koriander'), // 30 g -> 12 kcal
          _line(null, null, 'färsk koriander'),
        ],
        portions: 1,
      );
      expect(summary.lines[0].status, NutritionLineStatus.counted);
      expect(summary.lines[0].food!.id, 14);
      expect(summary.total.kcal, closeTo(12, 1e-9));
      expect(summary.lines[1].status, NutritionLineStatus.skipped);
    });

    test('the full name wins over a shorter suffix', () {
      final table = NutritionTable.fromJsonStrings(
        foodsJson: jsonEncode({
          'foods': [
            _food(1, 'Koriander', kcal: 40),
            _food(2, 'Koriander malen', kcal: 300),
          ],
        }),
        matchingJson: jsonEncode({
          'ingredients': {
            'koriander': {'food': 1, 'gPerDl': 10},
            'malen koriander': {'food': 2, 'gPerDl': 40},
          },
        }),
      );
      final summary = NutritionCalculator(table: table).calculate(
        ingredients: [_line(1, 'dl', 'malen koriander')],
        portions: 1,
      );
      expect(summary.lines.single.food!.id, 2);
      expect(summary.lines.single.grams, closeTo(40, 1e-9));
    });

    test('a raw-only legacy line is derived and counted', () {
      final summary = _calc().calculate(
        ingredients: [RecipeIngredient.rawOnly('2 dl mjölk')],
        portions: 2,
      );
      final line = summary.lines.single;
      expect(line.status, NutritionLineStatus.counted);
      expect(line.grams, closeTo(200, 1e-9));
      expect(summary.total.kcal, closeTo(120, 1e-9));
    });

    test(
      'a raw-only legacy line with no amount is still looked up by name',
      () {
        final summary = _calc().calculate(
          ingredients: [RecipeIngredient.rawOnly('Salt')],
          portions: 2,
        );
        expect(summary.lines.single.status, NutritionLineStatus.skipped);
      },
    );
  });

  group('household choices', () {
    final mjolkKey = NutritionKey.storageKey('mjölk')!;

    test(
      'a choice overrides the curated food but keeps the curated weights',
      () {
        // Havregryn (370 kcal) chosen for "mjölk": 2 dl at mjölk's 100 g/dl.
        final summary = _calc({mjolkKey: 15}).calculate(
          ingredients: [_line(2, 'dl', 'Mjölk')],
          portions: 1,
        );
        final line = summary.lines.single;
        expect(line.food!.id, 15);
        expect(line.chosenByHousehold, isTrue);
        expect(line.grams, closeTo(200, 1e-9));
        expect(summary.total.kcal, closeTo(740, 1e-9));
      },
    );

    test('without a choice the curated food is used and not marked chosen', () {
      final summary = _calc().calculate(
        ingredients: [_line(2, 'dl', 'Mjölk')],
        portions: 1,
      );
      expect(summary.lines.single.food!.id, 1);
      expect(summary.lines.single.chosenByHousehold, isFalse);
    });

    test(
      'a choice for an uncurated name works when the amount is in grams',
      () {
        final summary = _calc({'havrebröd': 15}).calculate(
          ingredients: [_line(150, 'g', 'Havrebröd')],
          portions: 1,
        );
        final line = summary.lines.single;
        expect(line.status, NutritionLineStatus.counted);
        expect(line.chosenByHousehold, isTrue);
        expect(summary.total.kcal, closeTo(555, 1e-9));
      },
    );

    test('a choice for an uncurated name cannot weigh a volume or a piece', () {
      final summary = _calc({'havrebröd': 15}).calculate(
        ingredients: [
          _line(2, 'dl', 'Havrebröd'),
          _line(2, null, 'Havrebröd'),
          _line(null, null, 'Havrebröd'),
        ],
        portions: 1,
      );
      for (final line in summary.lines) {
        expect(line.status, NutritionLineStatus.noAmount);
        expect(line.food!.id, 15);
      }
      expect(summary.total.kcal, 0);
    });

    test('a choice made for another name does not apply', () {
      final summary = _calc({mjolkKey: 15}).calculate(
        ingredients: [_line(100, 'g', 'Havrebröd')],
        portions: 1,
      );
      expect(summary.lines.single.status, NutritionLineStatus.noMatch);
    });

    test(
      'a stored food id missing from the table is unmatched, not a crash',
      () {
        final summary = _calc({'havrebröd': 999, mjolkKey: 999}).calculate(
          ingredients: [_line(100, 'g', 'Havrebröd'), _line(100, 'g', 'Mjölk')],
          portions: 1,
        );
        expect(summary.lines[0].status, NutritionLineStatus.noMatch);
        // The curated food is still used for a curated name.
        expect(summary.lines[1].status, NutritionLineStatus.counted);
        expect(summary.lines[1].food!.id, 1);
        expect(summary.lines[1].chosenByHousehold, isFalse);
      },
    );

    test('a choice makes a negligible spice a counted ingredient', () {
      final summary = _calc({'peppar': 15}).calculate(
        ingredients: [_line(10, 'g', 'peppar')],
        portions: 1,
      );
      expect(summary.lines.single.status, NutritionLineStatus.counted);
      expect(summary.total.kcal, closeTo(37, 1e-9));
    });
  });
}
