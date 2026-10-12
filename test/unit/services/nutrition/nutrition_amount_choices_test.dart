/// A line with no amount of its own is counted from a usual amount or from
/// one the household entered, and says which.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';

late NutritionTable _table;
late Map<String, dynamic> _matching;

RecipeIngredient _ing(num? amount, String? unit, String name) =>
    RecipeIngredient(
      amount: amount,
      unit: unit,
      name: name,
      raw: [if (amount != null) '$amount', ?unit, name].join(' '),
    );

double _gPerDl(String name) =>
    ((_matching['ingredients'] as Map<String, dynamic>)[name]['gPerDl'] as num)
        .toDouble();

NutritionCalculator _calc([
  Map<String, NutritionAmountChoice> amounts = const {},
]) => NutritionCalculator(table: _table, amountChoices: amounts);

void main() {
  setUpAll(() {
    final matching = File('assets/data/naring_matchning.json');
    _matching = jsonDecode(matching.readAsStringSync()) as Map<String, dynamic>;
    _table = NutritionTable.fromJsonStrings(
      foodsJson: File('assets/data/livsmedel_naring.json').readAsStringSync(),
      matchingJson: matching.readAsStringSync(),
    );
  });

  group('usual amounts', () {
    test(
      'salt with no amount counts 1 tsk for four portions, as an estimate',
      () {
        final line = _calc()
            .calculate(ingredients: [_ing(null, null, 'salt')], portions: 4)
            .lines
            .single;
        expect(line.status, NutritionLineStatus.estimated);
        expect(line.amountSource, NutritionAmountSource.usual);
        expect(line.amountUnit, 'tsk');
        expect(line.grams, closeTo(0.05 * _gPerDl('salt'), 1e-9));
      },
    );

    test('the usual amount follows the recipe\'s portions', () {
      final eight = _calc()
          .calculate(ingredients: [_ing(null, null, 'salt')], portions: 8)
          .lines
          .single;
      expect(eight.grams, closeTo(0.1 * _gPerDl('salt'), 1e-9));
      final unstated = _calc()
          .calculate(ingredients: [_ing(null, null, 'salt')], portions: null)
          .lines
          .single;
      expect(unstated.grams, closeTo(0.05 * _gPerDl('salt'), 1e-9));
    });

    test('an estimate counts in the total and in "x of y"', () {
      final summary = _calc().calculate(
        ingredients: [_ing(null, null, 'smör'), _ing(2, 'dl', 'mjölk')],
        portions: 4,
      );
      expect(summary.estimatedLines, 1);
      expect(summary.countedLines, 2);
      expect(summary.countableLines, 2);
      expect(summary.missing, isEmpty);
      expect(summary.total.kcal, greaterThan(100));
    });

    test('frying fat named with its purpose still finds the usual amount', () {
      for (final name in [
        'smör till stekning',
        'olja till stekning',
        'smör till formen',
      ]) {
        final line = _calc()
            .calculate(ingredients: [_ing(null, null, name)], portions: 4)
            .lines
            .single;
        expect(line.status, NutritionLineStatus.estimated, reason: name);
      }
    });

    test('a stated amount wins over the usual one', () {
      final line = _calc()
          .calculate(ingredients: [_ing(10, 'g', 'salt')], portions: 4)
          .lines
          .single;
      expect(line.status, NutritionLineStatus.counted);
      expect(line.grams, 10);
    });

    test(
      'a stated amount in a unit that cannot be weighed gets no usual one',
      () {
        final line = _calc()
            .calculate(ingredients: [_ing(1, 'nypa', 'salt')], portions: 4)
            .lines
            .single;
        expect(line.status, NutritionLineStatus.noAmount);
      },
    );

    test('a household amount may still replace such a line', () {
      final line =
          _calc({'salt': const NutritionAmountChoice(amount: 2, unit: 'g')})
              .calculate(ingredients: [_ing(1, 'nypa', 'salt')], portions: 4)
              .lines
              .single;
      expect(line.status, NutritionLineStatus.estimated);
      expect(line.grams, 2);
    });

    test('a food with no usual amount is never guessed', () {
      final summary = _calc().calculate(
        ingredients: [_ing(null, null, 'kycklingfilé')],
        portions: 4,
      );
      expect(summary.lines.single.status, NutritionLineStatus.noAmount);
      expect(summary.missing, hasLength(1));
    });

    test('to-taste herbs with no usual amount stay out of the count', () {
      final line = _calc()
          .calculate(ingredients: [_ing(null, null, 'citronskal')], portions: 4)
          .lines
          .single;
      expect(line.status, NutritionLineStatus.skipped);
    });
  });

  group('the household\'s own amounts', () {
    final chickenKey = NutritionKey.storageKey('kycklingfilé')!;
    final saltKey = NutritionKey.storageKey('salt')!;

    test('an amount for every recipe makes a missing line countable', () {
      final line =
          _calc({
                chickenKey: const NutritionAmountChoice(amount: 600, unit: 'g'),
              })
              .calculate(
                ingredients: [_ing(null, null, 'kycklingfilé')],
                portions: 4,
              )
              .lines
              .single;
      expect(line.status, NutritionLineStatus.estimated);
      expect(line.amountSource, NutritionAmountSource.household);
      expect(line.grams, 600);
    });

    test('an amount for every recipe is written for four portions', () {
      final line =
          _calc({
                chickenKey: const NutritionAmountChoice(amount: 600, unit: 'g'),
              })
              .calculate(
                ingredients: [_ing(null, null, 'kycklingfilé')],
                portions: 2,
              )
              .lines
              .single;
      expect(line.grams, 300);
    });

    test(
      'an amount for this recipe is used as entered, whatever the portions',
      () {
        final recipeKey = NutritionAmountChoice.recipeKey(
          'abc-123',
          chickenKey,
        )!;
        final line =
            _calc({
                  chickenKey: const NutritionAmountChoice(
                    amount: 600,
                    unit: 'g',
                  ),
                  recipeKey: const NutritionAmountChoice(
                    amount: 450,
                    unit: 'g',
                  ),
                })
                .calculate(
                  ingredients: [_ing(null, null, 'kycklingfilé')],
                  portions: 2,
                  recipeId: 'abc-123',
                )
                .lines
                .single;
        expect(line.amountSource, NutritionAmountSource.thisRecipe);
        expect(line.grams, 450);
      },
    );

    test('another recipe does not see this recipe\'s amount', () {
      final recipeKey = NutritionAmountChoice.recipeKey('abc-123', chickenKey)!;
      final line =
          _calc({
                recipeKey: const NutritionAmountChoice(amount: 450, unit: 'g'),
              })
              .calculate(
                ingredients: [_ing(null, null, 'kycklingfilé')],
                portions: 4,
                recipeId: 'other-recipe',
              )
              .lines
              .single;
      expect(line.status, NutritionLineStatus.noAmount);
    });

    test('an entered amount wins over the usual one', () {
      final line =
          _calc({
                saltKey: const NutritionAmountChoice(amount: 2, unit: 'tsk'),
              })
              .calculate(ingredients: [_ing(null, null, 'salt')], portions: 4)
              .lines
              .single;
      expect(line.amountSource, NutritionAmountSource.household);
      expect(line.grams, closeTo(0.1 * _gPerDl('salt'), 1e-9));
    });

    test('an amount that cannot be weighed for the food falls through', () {
      final line =
          _calc({
                chickenKey: const NutritionAmountChoice(amount: 2, unit: 'dl'),
              })
              .calculate(
                ingredients: [_ing(null, null, 'kycklingfilé')],
                portions: 4,
              )
              .lines
              .single;
      expect(line.status, NutritionLineStatus.noAmount);
    });

    test('a food with no density offers only mass units', () {
      final line = _calc()
          .calculate(
            ingredients: [_ing(null, null, 'kycklingfilé')],
            portions: 4,
          )
          .lines
          .single;
      expect(line.enterableUnits, ['g', 'kg', 'st']);
    });

    test('a line with a unit it cannot weigh also takes an amount', () {
      final line =
          _calc({
                chickenKey: const NutritionAmountChoice(amount: 500, unit: 'g'),
              })
              .calculate(
                ingredients: [_ing(3, 'nypor', 'kycklingfilé')],
                portions: 4,
              )
              .lines
              .single;
      expect(line.status, NutritionLineStatus.estimated);
      expect(line.grams, 500);
    });
  });

  group('NutritionAmountChoice', () {
    test('recipe keys fit the rules for UUID and Firestore ids', () {
      const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
      expect(NutritionAmountChoice.recipeKey(uuid, 'salt'), isNotNull);
      expect(
        NutritionAmountChoice.recipeKey('AbCdEfGhIjKlMnOpQrSt', 'salt'),
        isNotNull,
      );
    });

    test('a key longer than the rules allow is refused', () {
      final longKey = 'a' * 60;
      expect(
        NutritionAmountChoice.recipeKey('x' * 40, longKey)!.length,
        lessThanOrEqualTo(103),
      );
      expect(NutritionAmountChoice.recipeKey('x' * 41, 'salt'), isNull);
      expect(NutritionAmountChoice.keyShape.hasMatch('a' * 61), isFalse);
    });

    test('fromMap refuses what the rules refuse', () {
      expect(NutritionAmountChoice.fromMap({'a': 0, 'u': 'g'}), isNull);
      expect(NutritionAmountChoice.fromMap({'a': 100001, 'u': 'g'}), isNull);
      expect(NutritionAmountChoice.fromMap({'a': 5, 'u': 'nypa'}), isNull);
      expect(NutritionAmountChoice.fromMap({'a': '5', 'u': 'g'}), isNull);
      expect(NutritionAmountChoice.fromMap(null), isNull);
      expect(
        NutritionAmountChoice.fromMap({'a': 1.5, 'u': 'tsk'}),
        const NutritionAmountChoice(amount: 1.5, unit: 'tsk'),
      );
    });
  });

  group('candidates and bundled defaults', () {
    final chickenKey = NutritionKey.storageKey('kycklingfilé')!;

    test('an unweighable recipe amount falls through to the household one', () {
      final line =
          _calc({
                NutritionAmountChoice.recipeKey('r1', chickenKey)!:
                    const NutritionAmountChoice(amount: 2, unit: 'dl'),
                chickenKey: const NutritionAmountChoice(amount: 200, unit: 'g'),
              })
              .calculate(
                ingredients: [_ing(null, null, 'kycklingfilé')],
                portions: 4,
                recipeId: 'r1',
              )
              .lines
              .single;
      expect(line.amountSource, NutritionAmountSource.household);
      expect(line.grams, 200);
    });

    test('a food with a density offers volume units too', () {
      final line = _calc()
          .calculate(ingredients: [_ing(null, null, 'salt')], portions: 4)
          .lines
          .single;
      expect(line.enterableUnits, containsAll(['g', 'kg', 'dl', 'msk', 'tsk']));
    });

    test('every curated usual amount is a valid amount that weighs out', () {
      final ingredients = _matching['ingredients'] as Map<String, dynamic>;
      final withDefault = [
        for (final e in ingredients.entries)
          if ((e.value as Map).containsKey('default')) e.key,
      ];
      expect(withDefault, isNotEmpty);
      for (final name in withDefault) {
        final line = _calc()
            .calculate(ingredients: [_ing(null, null, name)], portions: 4)
            .lines
            .single;
        expect(
          line.status,
          NutritionLineStatus.estimated,
          reason: '$name: its default is dropped or does not weigh out',
        );
        expect(line.grams, greaterThan(0), reason: name);
      }
    });
  });
}
