@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tools/corpus/corpus_eval_core.dart';
import '../../tools/corpus/corpus_metrics.dart';
import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/ingredient_core_name.dart';

GoldIngredient _ing(String name, {String? preparation, String? quantity}) =>
    GoldIngredient(
      name: name,
      originalLine: name,
      preparation: preparation,
      quantity: quantity,
      unit: quantity == null ? null : 'dl',
    );

GoldRecipe _recipe(List<GoldIngredient> ingredients) => GoldRecipe(
  verified: true,
  title: 'Paj',
  ingredients: ingredients,
  instructions: const [],
);

void main() {
  group('ingredientCoreName', () {
    test('drops preparation before or after the name', () {
      expect(ingredientCoreName('valnötter, grovt hackade'), 'valnötter');
      expect(ingredientCoreName('rumsvarmt smör'), 'smör');
      expect(ingredientCoreName('Fint hackad gul lök'), 'gul lök');
    });

    test('keeps the first alternative', () {
      expect(ingredientCoreName('smör eller margarin'), 'smör');
      expect(ingredientCoreName('salt och/eller peppar'), 'salt');
      expect(ingredientCoreName('honung alternativt sirap'), 'honung');
    });

    test('a word that names a product before the name stays', () {
      expect(ingredientCoreName('kokt skinka'), 'kokt skinka');
      expect(ingredientCoreName('frysta bär'), 'frysta bär');
      expect(ingredientCoreName('grovt salt'), 'grovt salt');
      expect(ingredientCoreName('fint salt'), 'fint salt');
    });

    test('the same word after a comma is a preparation', () {
      expect(ingredientCoreName('potatis, kokt'), 'potatis');
      expect(ingredientCoreName('blåbär, frysta'), 'blåbär');
      expect(ingredientCoreName('mandlar, grovt hackade'), 'mandlar');
    });

    test('drops a parenthetical aside', () {
      expect(ingredientCoreName('äpplen (ca 500 g)'), 'äpplen');
    });

    test('keeps colour, size and kind, which name another product', () {
      expect(ingredientCoreName('röd paprika'), 'röd paprika');
      expect(ingredientCoreName('stor potatis'), 'stor potatis');
    });

    test('a comma that separates two ingredients is kept', () {
      expect(ingredientCoreName('persilja, citron'), 'persilja citron');
    });

    test('a name that is only preparation falls back to itself', () {
      expect(ingredientCoreName('hackad'), 'hackad');
    });
  });

  group('scoreRecipe on core names', () {
    test('the app keeping preparation out of the name is not a miss', () {
      final gold = _recipe([
        _ing('lök, hackad', quantity: '1'),
        _ing('smör eller margarin'),
      ]);
      final predicted = _recipe([
        _ing('lök', preparation: 'hackad', quantity: '1'),
        _ing('smör eller margarin'),
      ]);
      final score = scoreRecipe(gold, predicted);
      expect(score.ingredientNames.f1, 1.0);
      expect(score.ingredientsFull.f1, 1.0);
      expect(score.ingredientDetails!.f1, 1.0);
    });

    test('a dropped preparation or alternative lowers the detail score', () {
      final gold = _recipe([
        _ing('lök, hackad'),
        _ing('smör eller margarin'),
      ]);
      final predicted = _recipe([_ing('lök'), _ing('smör')]);
      final score = scoreRecipe(gold, predicted);
      expect(score.ingredientNames.f1, 1.0);
      expect(score.ingredientDetails!.recall, 0.0);
    });

    test('a different ingredient is still a miss', () {
      final score = scoreRecipe(
        _recipe([_ing('lök, hackad')]),
        _recipe([_ing('purjolök', preparation: 'hackad')]),
      );
      expect(score.ingredientNames.f1, 0.0);
    });

    test('no detail score when the facit names no preparation', () {
      final score = scoreRecipe(
        _recipe([_ing('mjölk')]),
        _recipe([_ing('mjölk')]),
      );
      expect(score.ingredientDetails, isNull);
    });
  });

  test('the detail mean leaves out recipes whose facit has no details', () {
    RecipeReport report(GoldRecipe gold, GoldRecipe predicted) => RecipeReport(
      bookSlug: 'bok',
      recipeId: gold.ingredients.first.name,
      score: scoreRecipe(gold, predicted),
      ocrRecall: const TokenRecallResult(
        recall: 1,
        foundCount: 0,
        totalCount: 0,
        missing: [],
      ),
    );
    final summary = summarize([
      report(_recipe([_ing('lök, hackad')]), _recipe([_ing('lök')])),
      report(_recipe([_ing('mjölk')]), _recipe([_ing('mjölk')])),
    ]);
    expect(summary.detailScored, 1);
    expect(summary.meanIngredientDetailF1, 0.0);
  });
}
