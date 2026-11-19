/// Merging AI-read photo pages: a recipe that continues from the page before
/// is joined to it only where there is something to join it to.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/models/photo_ai_recipes.dart';
import 'package:butlery/services/import/photo_recipe_merge.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  const untitled = 'Namnlöst';

  Recipe recipe(
    String title, {
    List<String> ingredients = const [],
    List<String> steps = const [],
  }) => RecipeFactory.build(
    title: title,
    ingredients: ingredients,
    instructions: steps,
  );

  PhotoAiRecipes page(List<Recipe> recipes, {bool continues = false}) =>
      PhotoAiRecipes(recipes, firstContinuesFromPreviousPage: continues);

  List<Recipe> merge(List<PhotoAiRecipes> pages) =>
      mergePhotoRecipes(pages, untitled: untitled);

  test('a continuation on the first page has nothing to join: own recipe', () {
    final result = merge([
      page([
        recipe('', steps: ['Rör ut.']),
      ], continues: true),
    ]);

    expect(result, hasLength(1));
    expect(result.single.title, untitled);
    expect(result.single.instructions, ['Rör ut.']);
  });

  test('a continuation joins the last recipe of the previous page', () {
    final result = merge([
      page([
        recipe('Första', ingredients: ['1 dl mjöl'], steps: ['Blanda.']),
        recipe('Andra', ingredients: ['2 ägg'], steps: ['Vispa.']),
      ]),
      page([
        recipe('', ingredients: ['1 tsk salt'], steps: ['Grädda.']),
      ], continues: true),
    ]);

    expect(result.map((r) => r.title), ['Första', 'Andra']);
    expect(result[0].ingredients, ['1 dl mjöl']);
    expect(result[1].ingredients, ['2 ägg', '1 tsk salt']);
    expect(result[1].instructions, ['Vispa.', 'Grädda.']);
    expect(
      result[1].structuredIngredients.map((i) => i.raw),
      result[1].ingredients,
    );
  });

  test('a line repeated across the page break is kept once', () {
    final result = merge([
      page([
        recipe(
          'Soppa',
          ingredients: ['1 lök', '2 dl grädde'],
          steps: ['A.', 'Koka.'],
        ),
      ]),
      page([
        recipe(
          '',
          ingredients: ['2 DL grädde ', '1 tsk salt'],
          steps: ['koka.', 'Servera.'],
        ),
      ], continues: true),
    ]);

    expect(result.single.ingredients, ['1 lök', '2 dl grädde', '1 tsk salt']);
    expect(result.single.instructions, ['A.', 'Koka.', 'Servera.']);
    expect(
      result.single.structuredIngredients.map((i) => i.raw),
      result.single.ingredients,
    );
  });

  test('three pages in a row all fold into the one recipe', () {
    final result = merge([
      page([
        recipe('Långt', ingredients: ['a'], steps: ['1']),
      ]),
      page([
        recipe('', ingredients: ['b'], steps: ['2']),
      ], continues: true),
      page([
        recipe('', ingredients: ['c'], steps: ['3']),
      ], continues: true),
    ]);

    expect(result, hasLength(1));
    expect(result.single.title, 'Långt');
    expect(result.single.ingredients, ['a', 'b', 'c']);
    expect(result.single.instructions, ['1', '2', '3']);
  });

  test('two recipes on one page stay two, in order', () {
    final result = merge([
      page([
        recipe('Ett', ingredients: ['x']),
        recipe('Två', ingredients: ['y']),
      ]),
    ]);

    expect(result.map((r) => r.title), ['Ett', 'Två']);
  });

  test('a continuation that is not first on its page is its own recipe', () {
    final result = merge([
      page([
        recipe('Ett', ingredients: ['x']),
      ]),
      page([
        recipe('Två', ingredients: ['y']),
        recipe('', ingredients: ['z'], steps: ['s']),
      ]),
    ]);

    expect(result.map((r) => r.title), ['Ett', 'Två', untitled]);
    expect(result[0].ingredients, ['x']);
  });

  test('a titled recipe not flagged as continuation is never joined', () {
    final result = merge([
      page([recipe('Ett')]),
      page([recipe('Två')]),
    ]);

    expect(result.map((r) => r.title), ['Ett', 'Två']);
  });
}
