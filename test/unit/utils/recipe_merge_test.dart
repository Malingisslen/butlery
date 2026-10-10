// BUT-1817: merging import blocks the splitter wrongly cut out of one recipe.
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/utils/recipe_merge.dart';

import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  final cake = RecipeBuilder()
      .withId('a')
      .withTitle('Kladdkaka')
      .withIngredients(['2 ägg', '3 dl socker'])
      .withInstructions(['Vispa ägg och socker.'])
      .withPortions(8)
      .withTagResult(TagResult.empty())
      .build();
  final frosting = RecipeBuilder()
      .withId('b')
      .withTitle('Glasyr')
      .withIngredients(['100 g smör', '2 dl florsocker'])
      .withInstructions(['Rör ihop smör och florsocker.'])
      .withPortions(null)
      .build();

  test('keeps the first part and appends the rest in order', () {
    final merged = RecipeMerge.merge([cake, frosting]);

    expect(merged.id, 'a');
    expect(merged.title, 'Kladdkaka');
    expect(merged.ingredients, [
      '2 ägg',
      '3 dl socker',
      '100 g smör',
      '2 dl florsocker',
    ]);
    expect(merged.instructions, [
      'Vispa ägg och socker.',
      'Rör ihop smör och florsocker.',
    ]);
    expect(merged.portions, 8);
  });

  test('a later part title becomes the section of its rows', () {
    final merged = RecipeMerge.merge([cake, frosting]);

    expect(merged.structuredIngredients.map((e) => e.raw), merged.ingredients);
    expect(merged.structuredIngredients.map((e) => e.section), [
      null,
      null,
      'Glasyr',
      'Glasyr',
    ]);
  });

  test('a section the part already had is kept', () {
    final sectioned = frosting.copyWith(
      structuredIngredients: [
        for (final line in frosting.ingredients)
          RecipeIngredient.rawOnly(line).copyWithSection('Topping'),
      ],
    );

    final merged = RecipeMerge.merge([cake, sectioned]);

    expect(merged.structuredIngredients.last.section, 'Topping');
  });

  // The first part's preview tags never saw the second part's butter, so
  // they must not survive to describe the merged recipe.
  test('clears preview tags and normalized ingredients', () {
    final normalized = cake.copyWith(ingredientsNormalized: ['ägg', 'socker']);

    final merged = RecipeMerge.merge([normalized, frosting]);

    expect(cake.tagResult, isNotNull);
    expect(merged.tagResult, isNull);
    expect(merged.core.ingredientsNormalized, isNull);
  });

  test(
    'portions and time fall back to a later part when the first has none',
    () {
      final untimed = frosting.copyWith(timeMinutes: null);
      final timed = cake.copyWith(timeMinutes: 45);

      final merged = RecipeMerge.merge([untimed, timed]);

      expect(merged.portions, 8);
      expect(merged.timeMinutes, 45);
    },
  );

  test('a single part is returned unchanged', () {
    expect(RecipeMerge.merge([cake]), same(cake));
  });

  test('no parts is an error', () {
    expect(() => RecipeMerge.merge([]), throwsArgumentError);
  });
}
