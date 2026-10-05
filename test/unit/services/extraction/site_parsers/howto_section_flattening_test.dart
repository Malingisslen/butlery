/// One fixture holding schema.org shapes goes through the four site
/// parsers, `SchemaOrgRecipeExtractor` and the quality scorer here, and
/// through `SchemaOrgTier` in its own suite. `HowToSection` is standard
/// schema.org, not an Arla quirk (BUT-2020).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/koket_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recept_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_quality_scorer.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';
import 'package:butlery/services/import/extractors/schema_org_recipe_extractor.dart';
import 'package:butlery/utils/recipe_scraper.dart';

import '../../../../fixtures/schema_org/instruction_shapes.dart';

void main() {
  final parsers = <String, RecipeSiteParser>{
    'arla.se': ArlaRecipeParser(),
    'ica.se': IcaRecipeParser(),
    'koket.se': KoketRecipeParser(),
    'recept.se': ReceptRecipeParser(),
  };

  parsers.forEach((site, parser) {
    test('$site reads the instruction shapes the shared way', () {
      final recipe = parser.parseRecipe(instructionShapesPage);

      expect(recipe, isNotNull, reason: 'the page failed to parse at all');
      expect(recipe!['recipeInstructions'], equals(instructionShapesSteps));
    });
  });

  test(
    'SchemaOrgRecipeExtractor reads the instruction shapes the shared way',
    () {
      final data = {'recipeInstructions': jsonDecode(instructionShapesJson)};

      expect(
        SchemaOrgRecipeExtractor.extractInstructions(data),
        equals(instructionShapesSteps),
      );
    },
  );

  test('the quality scorer counts the shared steps', () {
    final score = RecipeQualityScorer.score({
      'name': 'x',
      'recipeIngredient': ['1 ägg'],
      'recipeInstructions': jsonDecode(instructionShapesJson),
    });

    expect(score.instructionCount, instructionShapesSteps.length);
  });

  group('flattenRecipeInstructions', () {
    test('leaves a flat list of HowToStep untouched', () {
      const flat = [
        {'@type': 'HowToStep', 'text': 'Ett.'},
        {'@type': 'HowToStep', 'text': 'Två.'},
      ];

      expect(flattenRecipeInstructions(flat), equals(flat));
    });

    test('keeps plain strings, which some sites still emit', () {
      expect(
        flattenRecipeInstructions(['Ett.', 'Två.']),
        equals(['Ett.', 'Två.']),
      );
    });

    test('keeps a section that carries no itemListElement', () {
      // Nothing to lift out, so dropping it would lose whatever `text` it
      // does carry. Downstream filters decide whether it is usable.
      const section = [
        {'@type': 'HowToSection', 'text': 'Allt i ett stycke.'},
      ];

      expect(flattenRecipeInstructions(section), equals(section));
    });

    test('keeps a section whose itemListElement is empty', () {
      const section = [
        {'@type': 'HowToSection', 'text': 'Kvar.', 'itemListElement': []},
      ];

      expect(flattenRecipeInstructions(section), equals(section));
    });

    test('flattens sections nested more than one level deep', () {
      const nested = [
        {
          '@type': 'HowToSection',
          'itemListElement': [
            {
              '@type': 'HowToSection',
              'itemListElement': [
                {'@type': 'HowToStep', 'text': 'Djupt.'},
              ],
            },
          ],
        },
      ];

      final flattened = flattenRecipeInstructions(nested);
      expect(flattened, hasLength(1));
      expect((flattened.first as Map)['text'], equals('Djupt.'));
    });

    test('returns an empty list for anything that is not a list', () {
      // The string form of `recipeInstructions` is the caller's to handle;
      // all current callers stand behind an `is List` check.
      expect(flattenRecipeInstructions('Ett stycke text.'), isEmpty);
      expect(flattenRecipeInstructions(null), isEmpty);
      expect(flattenRecipeInstructions(<String, dynamic>{}), isEmpty);
    });
  });
}
