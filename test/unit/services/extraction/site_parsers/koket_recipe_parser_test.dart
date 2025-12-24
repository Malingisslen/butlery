import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/koket_recipe_parser.dart';
import '../../../../fixtures/swedish_sites/koket_test_data.dart';

void main() {
  group('KoketRecipeParser', () {
    late KoketRecipeParser parser;

    setUp(() {
      parser = KoketRecipeParser();
    });

    // ============================================================================
    // IDENTIFICATION TESTS
    // ============================================================================

    group('Identification', () {
      test('should identify koket.se domain', () {
        expect(parser.domain, equals('koket.se'));
      });

      test('should have correct site name', () {
        expect(parser.siteName, equals('Köket'));
      });
    });

    // ============================================================================
    // JSON-LD EXTRACTION TESTS
    // ============================================================================

    group('JSON-LD Extraction', () {
      test('should parse professional recipe with complete JSON-LD', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Klassiska svenska köttbullar'));
        expect(recipe['description'], contains('Perfekta köttbullar'));
        expect(recipe['recipeYield'], equals('4 portioner'));
        expect(recipe['totalTime'], equals('PT45M'));
        expect(recipe['recipeCategory'], equals('Huvudrätt'));
        expect(recipe['recipeCuisine'], equals('Svensk'));
      });

      test('should extract ingredients from JSON-LD', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['recipeIngredient'], isA<List>());
        final ingredients = recipe['recipeIngredient'] as List;
        expect(ingredients.length, equals(7));
        expect(ingredients, contains('500 g nötfärs'));
        expect(ingredients, contains('1 ägg'));
        expect(ingredients, contains('2 dl ströbröd'));
      });

      test('should extract instructions from JSON-LD', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['recipeInstructions'], isA<List>());
        final instructions = recipe['recipeInstructions'] as List;
        expect(instructions.length, equals(3));

        // Instructions should be HowToStep objects or strings
        final firstStep = instructions[0];
        if (firstStep is Map) {
          expect(firstStep['text'], contains('Blanda alla ingredienser'));
        } else {
          expect(firstStep, contains('Blanda alla ingredienser'));
        }
      });
    });

    // ============================================================================
    // KÖKET-SPECIFIC ENHANCEMENT TESTS
    // ============================================================================

    group('Köket Enhancements', () {
      test('should extract difficulty level', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['difficulty'], equals('Enkel'));
      });

      test('should extract user rating with score and count', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['rating'], isA<Map>());
        final rating = recipe['rating'] as Map;
        expect(rating['score'], equals(4.8));
        expect(rating['count'], equals(256));
      });

      test('should extract high rating (5.0)', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithHighRating);

        expect(recipe, isNotNull);
        expect(recipe!['rating'], isA<Map>());
        final rating = recipe['rating'] as Map;
        expect(rating['score'], equals(5.0));
        expect(rating['count'], equals(89));
      });

      test('should extract author information', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['author'], equals('Kökets Kockar'));
      });

      test('should extract cooking tips', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        final tips = recipe['cookingTips'] as List;
        expect(tips.isNotEmpty, isTrue);
        expect(tips.first, contains('Låt smeten svälla'));
      });

      test('should extract seasonal/holiday tags', () {
        final recipe = parser.parseRecipe(KoketTestFixtures.seasonalRecipe);

        expect(recipe, isNotNull);
        expect(recipe!['tags'], isA<List>());
        final tags = recipe['tags'] as List;
        expect(tags, contains('jul'));
        expect(tags, contains('högtid'));
        expect(tags, contains('vinter'));
      });

      test('should extract user tips from UGC recipe', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.userGeneratedRecipe);

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        final tips = recipe['cookingTips'] as List;
        expect(tips.isNotEmpty, isTrue);
        expect(tips.first, contains('socker i smeten'));
      });
    });

    // ============================================================================
    // FORMATTING CLEANUP TESTS
    // ============================================================================

    group('Formatting Cleanup', () {
      test('should clean "ca" and "cirka" from portions', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithKoketQuirks);

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], equals('4 portioner'));
        expect(recipe['recipeYield'], isNot(contains('ca')));
        expect(recipe['recipeYield'], isNot(contains('cirka')));
      });

      test('should trim whitespace from ingredients', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithKoketQuirks);

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;

        // Should be trimmed
        expect(ingredients, contains('500 g köttfärs'));
        expect(ingredients, contains('1 dl vatten'));
        expect(ingredients, contains('8 tortillabröd'));

        // Should not have leading/trailing whitespace
        for (final ingredient in ingredients) {
          expect(ingredient.toString(), equals(ingredient.toString().trim()));
        }
      });

      test('should trim whitespace from instructions', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithKoketQuirks);

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
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithKoketQuirks);

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;

        // "Tillbehör  " (generic non-ingredient) should be cleaned but kept if non-empty
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
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Saftig kladdkaka'));
        expect(recipe['description'], contains('kladdig och god'));
      });

      test('should extract ingredients from HTML when JSON-LD missing', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.length, greaterThanOrEqualTo(5));
        expect(ingredients, contains('2 ägg'));
        expect(ingredients, contains('3 dl socker'));
        expect(ingredients, contains('100 g smör'));
      });

      test('should extract instructions from HTML when JSON-LD missing', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithoutJsonLd);

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

        expect(
            instructionTexts.any((text) => text.contains('Vispa ägg')), isTrue);
        expect(instructionTexts.any((text) => text.contains('Grädda')), isTrue);
      });

      test('should extract metadata from HTML when JSON-LD missing', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], isNotNull);
        expect(recipe['totalTime'], isNotNull);
        expect(recipe['difficulty'], equals('Enkel'));
      });
    });

    // ============================================================================
    // ERROR RECOVERY TESTS
    // ============================================================================

    group('Error Recovery', () {
      test('should fallback to CSS selectors when JSON-LD is malformed', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithMalformedJson);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Italiensk lasagne'));
      });

      test('should extract ingredients from HTML when JSON parse fails', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithMalformedJson);

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.length, greaterThanOrEqualTo(4));
        expect(ingredients, contains('500 g köttfärs'));
        expect(ingredients, contains('1 burk tomater'));
        expect(ingredients, contains('Bechamelsås'));
      });

      test('should extract instructions from HTML when JSON parse fails', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithMalformedJson);

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
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeCompleteMetadata);

        expect(recipe, isNotNull);
        expect(recipe!['name'], isNotEmpty);
        expect(recipe['recipeIngredient'], isNotEmpty);
        expect(recipe['recipeInstructions'], isNotEmpty);
        expect(recipe['description'], isNotEmpty);
        expect(recipe['totalTime'], isNotNull);
        expect(recipe['difficulty'], isNotNull);
        expect(recipe['rating'], isNotNull);
        expect(recipe['cookingTips'], isNotNull);
      });

      test('should reject recipe with minimal data (below threshold)', () {
        final recipe = parser.parseRecipe(KoketTestFixtures.recipeMinimalData);

        // Recipe with only 2 ingredients and no instructions doesn't meet 80% quality threshold
        // Quality = 20% (title) + 26.7% (2/3 ingredients) + 0% (instructions) = 46.7%
        expect(recipe, isNull);
      });

      test('should handle user-generated content with variable quality', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.userGeneratedRecipe);

        expect(recipe, isNotNull);
        expect(recipe!['name'], contains('pannkakor'));
        expect(recipe['author'], equals('Anna Svensson'));
        // UGC should have lower rating but still acceptable quality
        final rating = recipe['rating'] as Map?;
        expect(rating, isNotNull);
        expect(rating!['score'], lessThan(5.0));
      });
    });

    // ============================================================================
    // SWEDISH TEXT HANDLING TESTS
    // ============================================================================

    group('Swedish Text Handling', () {
      test('should preserve Swedish characters (Å, Ä, Ö)', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithSwedishChars);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Ärtsoppa med fläsk'));
        // Description has lowercase ärtsoppa (case-insensitive check)
        expect(recipe['description'].toLowerCase(), contains('ärtsoppa'));

        final ingredients = recipe['recipeIngredient'] as List;
        expect(ingredients, contains('500 g gula ärtor'));
        expect(ingredients, contains('2 rökta fläskben'));
      });

      test('should clean smart quotes from Swedish text', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        final description = recipe!['description'] as String?;

        if (description != null) {
          // Should not contain smart quotes
          expect(description, isNot(contains('"')));
          expect(description, isNot(contains('"')));
        }
      });

      test('should normalize whitespace in Swedish text', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithSwedishChars);

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
        // Use userGeneratedRecipe which passes quality threshold but has minimal enhancements
        final recipe =
            parser.parseRecipe(KoketTestFixtures.userGeneratedRecipe);

        expect(recipe, isNotNull);
        // Some optional fields might be missing (equipment, tags)
        expect(recipe!['equipment'], anyOf(isNull, isEmpty));
      });

      test('should handle recipe with complete data and no missing fields', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeCompleteMetadata);

        expect(recipe, isNotNull);
        expect(recipe!['name'], isNotEmpty);
        expect(recipe['recipeIngredient'], isNotEmpty);
        expect(recipe['recipeInstructions'], isNotEmpty);
        expect(recipe['description'], isNotEmpty);
      });

      test('should extract image from recipe', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

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
        final recipe =
            parser.parseRecipe(KoketTestFixtures.kottbullarProfessional);

        expect(recipe, isNotNull);
        expect(recipe!['prepTime'], equals('PT20M'));
        expect(recipe['cookTime'], equals('PT25M'));
        expect(recipe['totalTime'], equals('PT45M'));
      });

      test('should handle long cooking times (hours)', () {
        final recipe = parser.parseRecipe(KoketTestFixtures.seasonalRecipe);

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], equals('PT4H'));
      });

      test('should handle combined hours and minutes', () {
        final recipe =
            parser.parseRecipe(KoketTestFixtures.recipeWithSwedishChars);

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], equals('PT2H'));
      });
    });
  });
}
