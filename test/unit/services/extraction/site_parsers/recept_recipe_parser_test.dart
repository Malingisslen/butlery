import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/recept_recipe_parser.dart';
import '../../../../fixtures/swedish_sites/recept_test_data.dart';

void main() {
  group('ReceptRecipeParser', () {
    late ReceptRecipeParser parser;

    setUp(() {
      parser = ReceptRecipeParser();
    });

    // ============================================================================
    // IDENTIFICATION TESTS
    // ============================================================================

    group('Identification', () {
      test('should identify recept.se domain', () {
        expect(parser.domain, equals('recept.se'));
      });

      test('should have correct site name', () {
        expect(parser.siteName, equals('Recept'));
      });
    });

    // ============================================================================
    // JSON-LD EXTRACTION TESTS
    // ============================================================================

    group('JSON-LD Extraction', () {
      test('should parse complete recipe with JSON-LD', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Klassiska kanelbullar'));
        expect(
          recipe['description'],
          contains('Traditionella svenska kanelbullar'),
        );
        expect(recipe['recipeYield'], equals('25 bullar'));
        expect(recipe['totalTime'], equals('PT45M'));
        expect(recipe['recipeCategory'], equals('Fika'));
        expect(recipe['recipeCuisine'], equals('Svensk'));
      });

      test('should extract ingredients from JSON-LD', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['recipeIngredient'], isA<List>());
        final ingredients = recipe['recipeIngredient'] as List;
        expect(ingredients.length, equals(9));
        expect(ingredients, contains('5 dl mjölk'));
        expect(ingredients, contains('50 g jäst'));
        expect(ingredients, contains('1 dl pärlsocker'));
      });

      test('should extract instructions from JSON-LD', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['recipeInstructions'], isA<List>());
        final instructions = recipe['recipeInstructions'] as List;
        expect(instructions.length, equals(4));

        // Instructions should be HowToStep objects or strings
        final firstStep = instructions[0];
        if (firstStep is Map) {
          expect(firstStep['text'], contains('Värm mjölken'));
        } else {
          expect(firstStep, contains('Värm mjölken'));
        }
      });
    });

    // ============================================================================
    // RECEPT-SPECIFIC ENHANCEMENT TESTS
    // ============================================================================

    group('Recept Enhancements', () {
      test('should extract difficulty level', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['difficulty'], equals('Medel'));
      });

      test('should extract category (meal type)', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['category'], equals('Fika'));
      });

      test('should extract cuisine type', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['cuisine'], equals('Svensk'));
      });

      test('should extract cooking tips', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        final tips = recipe['cookingTips'] as List;
        expect(tips.isNotEmpty, isTrue);
        expect(tips.first, contains('Låt degen jäsa'));
      });

      test('should extract serving suggestions', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['servingSuggestions'], isA<List>());
        final suggestions = recipe['servingSuggestions'] as List;
        expect(suggestions.isNotEmpty, isTrue);
        expect(suggestions.first, contains('kaffe eller mjölk'));
      });

      test('should extract category and cuisine from separate recipe', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithCategoryAndCuisine,
        );

        expect(recipe, isNotNull);
        if (recipe != null) {
          expect(recipe['category'], equals('Middag'));
          expect(recipe['cuisine'], equals('Italiensk'));
          expect(recipe['difficulty'], equals('Enkel'));
        }
      });
    });

    // ============================================================================
    // FORMATTING CLEANUP TESTS
    // ============================================================================

    group('Formatting Cleanup', () {
      test('should clean "ca" and "cirka" from portions', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithReceptQuirks,
        );

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], equals('4 portioner'));
        expect(recipe['recipeYield'], isNot(contains('ca')));
        expect(recipe['recipeYield'], isNot(contains('cirka')));
      });

      test('should trim whitespace from ingredients', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithReceptQuirks,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;

        // Should be trimmed
        expect(ingredients, contains('800 g potatis'));
        expect(ingredients, contains('2 dl mjölk'));
        expect(ingredients, contains('100 g smör'));

        // Should not have leading/trailing whitespace
        for (final ingredient in ingredients) {
          expect(ingredient.toString(), equals(ingredient.toString().trim()));
        }
      });

      test('should trim whitespace from instructions', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithReceptQuirks,
        );

        expect(recipe, isNotNull);
        final instructions = recipe!['recipeInstructions'] as List;

        for (final instruction in instructions) {
          if (instruction is String) {
            expect(instruction, equals(instruction.trim()));
          } else if (instruction is Map && instruction['text'] != null) {
            final text = instruction['text'].toString();
            expect(text, equals(text.trim()));
          }
        }
      });

      test('should filter out empty ingredients', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithReceptQuirks,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;

        // Empty strings should be filtered out
        for (final ingredient in ingredients) {
          expect(ingredient.toString().isNotEmpty, isTrue);
        }
      });
    });

    // ============================================================================
    // CSS FALLBACK TESTS
    // ============================================================================

    group('CSS Fallback Extraction', () {
      test('should extract recipe without JSON-LD using CSS selectors', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithoutJsonLd,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Klassiska svenska pannkakor'));
        expect(recipe['description'], contains('Tunna och luftiga'));
      });

      test('should extract ingredients from HTML when JSON-LD missing', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithoutJsonLd,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.length, greaterThanOrEqualTo(5));
        expect(ingredients, contains('3 ägg'));
        expect(ingredients, contains('6 dl mjölk'));
        expect(ingredients, contains('3 dl vetemjöl'));
      });

      test('should extract instructions from HTML when JSON-LD missing', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithoutJsonLd,
        );

        expect(recipe, isNotNull);
        final instructions = recipe!['recipeInstructions'] as List;
        expect(instructions.length, greaterThanOrEqualTo(4));

        // Check for instruction content
        final instructionTexts = instructions.map((inst) {
          if (inst is String) return inst;
          if (inst is Map && inst['text'] != null) {
            return inst['text'].toString();
          }
          return '';
        }).toList();

        expect(instructionTexts.any((text) => text.contains('Vispa')), isTrue);
        expect(instructionTexts.any((text) => text.contains('Stek')), isTrue);
      });

      test('should extract metadata from HTML when JSON-LD missing', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithoutJsonLd,
        );

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], isNotNull);
        expect(recipe['totalTime'], isNotNull);
        expect(recipe['difficulty'], equals('Enkel'));
        expect(recipe['category'], equals('Frukost'));
      });
    });

    // ============================================================================
    // ERROR RECOVERY TESTS
    // ============================================================================

    group('Error Recovery', () {
      test('should fallback to CSS selectors when JSON-LD is malformed', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithMalformedJson,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Köttfärssås'));
      });

      test('should extract ingredients from HTML when JSON parse fails', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithMalformedJson,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.length, greaterThanOrEqualTo(4));
        expect(ingredients, contains('500 g köttfärs'));
        expect(ingredients, contains('1 burk krossade tomater'));
      });

      test('should extract instructions from HTML when JSON parse fails', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithMalformedJson,
        );

        expect(recipe, isNotNull);
        final instructions = recipe!['recipeInstructions'] as List;
        expect(instructions.length, greaterThanOrEqualTo(3));
      });
    });

    // ============================================================================
    // QUALITY SCORING TESTS
    // ============================================================================

    group('Quality Validation', () {
      test('should accept recipe with complete metadata (high quality)', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeCompleteMetadata,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], isNotEmpty);
        expect(recipe['recipeIngredient'], isNotEmpty);
        expect(recipe['recipeInstructions'], isNotEmpty);
        expect(recipe['description'], isNotEmpty);
        expect(recipe['totalTime'], isNotNull);
        expect(recipe['difficulty'], isNotNull);
        expect(recipe['category'], isNotNull);
        expect(recipe['cuisine'], isNotNull);
        expect(recipe['cookingTips'], isNotNull);
        expect(recipe['servingSuggestions'], isNotNull);
      });

      test('should reject recipe with minimal data (below threshold)', () {
        final recipe = parser.parseRecipe(ReceptTestFixtures.recipeMinimalData);

        // Recipe with only 1 ingredient and no instructions doesn't meet 80% quality threshold
        expect(recipe, isNull);
      });
    });

    // ============================================================================
    // SWEDISH TEXT HANDLING TESTS
    // ============================================================================

    group('Swedish Text Handling', () {
      test('should preserve Swedish characters (Å, Ä, Ö)', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Älggryta med svamp och lingon'));
        // Description has lowercase älgkött (case-insensitive check)
        expect(recipe['description'].toLowerCase(), contains('älgkött'));

        final ingredients = recipe['recipeIngredient'] as List;
        expect(ingredients, contains('800 g älgkött i tärningar'));
      });

      test('should clean smart quotes from Swedish text', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        final description = recipe!['description'] as String?;

        if (description != null) {
          // Should not contain smart quotes
          expect(description, isNot(contains('"')));
          expect(description, isNot(contains('"')));
        }
      });

      test('should normalize whitespace in Swedish text', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        final name = recipe!['name'] as String;

        // Should not have multiple consecutive spaces
        expect(name, isNot(matches(r'\s{2,}')));
      });
    });

    // ============================================================================
    // EDGE CASES TESTS
    // ============================================================================

    group('Edge Cases', () {
      test('should return null for empty HTML', () {
        final recipe = parser.parseRecipe('');
        expect(recipe, isNull);
      });

      test('should return null for HTML without recipe content', () {
        final html = '<html><body><p>Not a recipe</p></body></html>';
        final recipe = parser.parseRecipe(html);
        expect(recipe, isNull);
      });

      test('should handle missing optional fields gracefully', () {
        // Use recipe with Swedish characters which has minimal enhancements
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        // Some optional fields might be missing
        expect(recipe!['servingSuggestions'], anyOf(isNull, isEmpty));
      });

      test('should handle recipe with complete data', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeCompleteMetadata,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], isNotEmpty);
        expect(recipe['recipeIngredient'], isNotEmpty);
        expect(recipe['recipeInstructions'], isNotEmpty);
        expect(recipe['description'], isNotEmpty);
      });

      test('should extract image from recipe', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['image'], isNotNull);
        expect(recipe['image'], contains('https://'));
      });
    });

    // ============================================================================
    // TIME CONVERSION TESTS
    // ============================================================================

    group('Time Conversion', () {
      test('should parse ISO 8601 duration from JSON-LD', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.kanelbullarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['prepTime'], equals('PT30M'));
        expect(recipe['cookTime'], equals('PT15M'));
        expect(recipe['totalTime'], equals('PT45M'));
      });

      test('should handle long cooking times (hours)', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], equals('PT2H30M'));
      });

      test('should handle short cooking times (minutes only)', () {
        final recipe = parser.parseRecipe(
          ReceptTestFixtures.recipeWithCategoryAndCuisine,
        );

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], equals('PT20M'));
      });
    });
  });
}
