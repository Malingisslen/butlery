/// Where a pasted or photographed recipe ENDS (BUT-2455): page text after the
/// recipe — comments, related recipes, a nutrition box — must not become
/// ingredients or steps, and nothing that belongs to the recipe may be cut.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('HeadingWordLists.recipeTrailerKind', () {
    test('headings and openings that end the recipe', () {
      for (final line in [
        'Kommentarer',
        'Kommentarer (12)',
        'Kommentarer:',
        'Fler recept',
        'Fler recept från oss',
        'Om författaren',
        'Lämna en kommentar',
        'Du kanske också gillar',
        'Prenumerera – 3 nummer för 99 kr',
        'Visa alla 87 kommentarer',
        'Anna skrev: Supergod! Jag tog 3 dl grädde istället.',
        'Gilla · Kommentera · Dela',
      ]) {
        expect(
          HeadingWordLists.recipeTrailerKind(line),
          RecipeTrailerKind.end,
          reason: line,
        );
      }
    });

    test('boxes the method can continue after', () {
      for (final line in [
        'Näringsvärde per portion',
        'Näringsinnehåll (per portion)',
        'VISSTE DU ATT',
        'Visste du att torsk är en av Sveriges vanligaste matfiskar?',
        'Energi 450 kcal',
        'Fett: 18 g',
        'Protein 6 g, Fett 18 g',
        'Per portion: ca 320 kcal',
      ]) {
        expect(
          HeadingWordLists.recipeTrailerKind(line),
          RecipeTrailerKind.box,
          reason: line,
        );
      }
    });

    test('recipe lines and page furniture that does not end a recipe', () {
      for (final line in [
        // A step and an author's note that merely mention comments.
        'Se kommentarer i appen för tips',
        'Kommentar: koka gärna längre',
        // Tips boxes and serving groups belong to the recipe.
        'Tips:',
        'Tips! Servera med ris eller pasta.',
        'Servering',
        'Till servering',
        // Mid-page furniture: skipped elsewhere, never an end.
        'Annons',
        'Dela',
        // Ingredient rows that look like nutrition rows.
        'Socker 100 g',
        '250 g',
        '2 dl mjölk',
        // A lead followed by å/ä/ö continues the word; ASCII \b would split it.
        'Fler receptämnen',
        'Visste du attåt',
      ]) {
        expect(HeadingWordLists.recipeTrailerKind(line), isNull, reason: line);
      }
    });
  });

  group('TextImportStrategy recipe end', () {
    late TextImportStrategy strategy;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      strategy = TextImportStrategy();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<Recipe> parse(String text) async {
      final result = await strategy.import(text);
      expect(result.isSuccess, isTrue, reason: result.errorMessage);
      return result.recipe!;
    }

    bool hasIngredient(Recipe r, String word) =>
        r.ingredients.any((i) => i.toLowerCase().contains(word));

    bool hasStep(Recipe r, String words) =>
        r.instructions.any((i) => i.contains(words));

    const pancakes = '''
Pannkakor
Ingredienser
3 dl vetemjöl
6 dl mjölk
3 ägg
Gör så här
Vispa mjölet med hälften av mjölken till en slät smet.
Stek tunna pannkakor i smör.''';

    test(
      'comments after the recipe are neither steps nor ingredients',
      () async {
        final recipe = await parse('''
$pancakes
Kommentarer (3)
Anna skrev: Supergod! Jag tog 3 dl grädde istället.
Erik skrev: Blev lite för salt för min smak.''');

        expect(hasIngredient(recipe, 'grädde'), isFalse);
        expect(hasStep(recipe, 'Supergod'), isFalse);
        expect(hasStep(recipe, 'salt för min smak'), isFalse);
        expect(hasStep(recipe, 'Stek tunna pannkakor'), isTrue);
      },
    );

    test('an imperative comment after the end is not a step', () async {
      final recipe = await parse('''
$pancakes
Kommentarer (2)
Vänd pannkakorna en gång till och servera med sylt.''');

      expect(hasStep(recipe, 'Vänd pannkakorna'), isFalse);
      expect(hasStep(recipe, 'Stek tunna pannkakor'), isTrue);
    });

    test('comments after a nutrition box are not steps', () async {
      final recipe = await parse('''
$pancakes
Näringsvärde per portion
Energi 300 kcal
Kommentarer (2)
Vänd pannkakorna en gång till och servera med sylt.''');

      expect(hasStep(recipe, 'Vänd pannkakorna'), isFalse);
      expect(hasStep(recipe, 'Stek tunna pannkakor'), isTrue);
    });

    test('a Tips box after the steps is kept', () async {
      final recipe = await parse('''
$pancakes
Tips: Servera med sylt och vispad grädde.''');

      expect(hasStep(recipe, 'Servera med sylt'), isTrue);
    });

    test('a nutrition box above the ingredients stops nothing', () async {
      // No "Ingredienser" header: a header would reopen the recipe on its
      // own and hide whether the box was taken as the end.
      final recipe = await parse('''
Pannbiff
Näringsvärde per portion
Energi 450 kcal
400 g nötfärs
1 ägg
Blanda färs och ägg och forma fyra biffar.
Stek biffarna 4 minuter per sida.''');

      expect(hasIngredient(recipe, 'nötfärs'), isTrue);
      expect(hasStep(recipe, 'Stek biffarna'), isTrue);
    });

    test('an ad between the steps keeps the steps after it', () async {
      final recipe = await parse('''
Pannkakor
Ingredienser
3 dl vetemjöl
6 dl mjölk
Gör så här
Vispa mjölet med hälften av mjölken till en slät smet.
Annons
Stek tunna pannkakor i smör.''');

      expect(hasStep(recipe, 'Stek tunna pannkakor'), isTrue);
    });

    test(
      'a nutrition box between the steps keeps the steps after it',
      () async {
        final recipe = await parse('''
Pannbiff
Ingredienser
400 g nötfärs
1 ägg
Gör så här
Blanda färs och ägg och forma fyra biffar.
Näringsvärde per portion
Energi 450 kcal
Protein 30 g
Stek biffarna 4 minuter per sida.''');

        expect(hasStep(recipe, 'Stek biffarna 4 minuter'), isTrue);
        expect(hasIngredient(recipe, 'protein'), isFalse);
      },
    );

    test(
      'a second recipe after the first one\'s nutrition box is kept',
      () async {
        final recipe = await parse('''
$pancakes
Näringsvärde per portion
Energi 300 kcal
Kladdkaka
Ingredienser
100 g smör
2 dl socker
Gör så här
Smält smöret och rör ner sockret.''');

        expect(hasIngredient(recipe, 'smör'), isTrue);
        expect(hasStep(recipe, 'Smält smöret'), isTrue);
      },
    );

    test(
      'a component\'s ingredients after the method and a box are kept',
      () async {
        final recipe = await parse('''
$pancakes
Näringsvärde per portion
Energi 300 kcal
Glasyr:
2 dl florsocker
1 msk citronsaft
Rör ihop glasyren och bred den över pannkakorna.''');

        expect(hasIngredient(recipe, 'florsocker'), isTrue);
        expect(hasStep(recipe, 'Rör ihop glasyren'), isTrue);
      },
    );

    test('a step that mentions comments ends nothing', () async {
      final recipe = await parse('''
Pannkakor
Ingredienser
3 dl vetemjöl
6 dl mjölk
Gör så här
Vispa mjölet med hälften av mjölken till en slät smet.
Se kommentarer i appen för tips
Stek tunna pannkakor i smör.''');

      expect(hasStep(recipe, 'Stek tunna pannkakor'), isTrue);
    });
  });
}
