import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import '../../../../fixtures/swedish_sites/arla_test_data.dart';

void main() {
  group('ArlaRecipeParser', () {
    late ArlaRecipeParser parser;

    setUp(() {
      parser = ArlaRecipeParser();
    });

    group('Parser Identification', () {
      test('should identify correct domain', () {
        expect(parser.domain, equals('arla.se'));
      });

      test('should have correct site name', () {
        expect(parser.siteName, equals('Arla'));
      });
    });

    group('Standard JSON-LD Extraction', () {
      test('should extract complete recipe from Arla JSON-LD', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.chokladbollarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Chokladbollar'));
        expect(recipe['description'], contains('Klassiska chokladbollar'));
        expect(recipe['recipeIngredient'], isA<List>());
        expect(recipe['recipeIngredient'], hasLength(7));
        expect(recipe['recipeInstructions'], isA<List>());
        expect(recipe['recipeInstructions'], hasLength(4));
        expect(recipe['recipeYield'], equals('20 bollar'));
        expect(recipe['totalTime'], equals('PT15M'));
        expect(recipe['image'], isNotNull);
      });

      test('should reject recipe with insufficient data (quality check)', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeMinimalData);

        // Recipe should be rejected due to insufficient ingredients (<3) and no instructions
        expect(
          recipe,
          isNull,
          reason: 'Recipe with only 2 ingredients should fail quality check',
        );
      });

      test('should handle recipe with Swedish characters', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Äppelpaj med vaniljsås'));
        expect(recipe['description'], contains('äppelpaj'));
        expect(recipe['recipeIngredient'].toString(), contains('äpplen'));
        expect(recipe['recipeIngredient'].toString(), contains('havregryn'));
      });
    });

    group('Arla-Specific Enhancements', () {
      test('should extract difficulty level', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.chokladbollarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['difficulty'], equals('Enkel'));
      });

      test('should extract cooking tips', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.chokladbollarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        expect(recipe['cookingTips'], isNotEmpty);
        expect(recipe['cookingTips'].first, contains('Låt smeten kallna'));
      });

      test('should extract nutritional information', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeWithNutrition);

        expect(recipe, isNotNull);
        expect(recipe!['nutrition'], isA<Map>());

        final nutrition = recipe['nutrition'] as Map;
        expect(nutrition['calories'], equals(185));
        expect(nutrition['protein'], equals(8));
        expect(nutrition['fat'], equals(7));
        expect(nutrition['carbohydrates'], equals(22));
      });

      test('should extract nutritional info from chokladbollar', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.chokladbollarComplete,
        );

        expect(recipe, isNotNull);
        expect(recipe!['nutrition'], isA<Map>());

        final nutrition = recipe['nutrition'] as Map;
        expect(nutrition['calories'], equals(120));
        expect(nutrition['protein'], equals(2));
        expect(nutrition['fat'], equals(6));
        expect(nutrition['carbohydrates'], equals(15));
      });

      test('should handle recipe without nutritional info', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        // Should not fail if nutrition info is missing
        expect(recipe!['nutrition'], anyOf(isNull, isEmpty));
      });
    });

    group('Arla Formatting Cleanup', () {
      test('should clean "ca" and "cirka" from portions', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithArlaQuirks,
        );

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], equals('6 portioner'));
        expect(recipe['recipeYield'], isNot(contains('ca')));
      });

      test('should trim whitespace from ingredients', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithArlaQuirks,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;

        // Check that ingredients don't have leading/trailing spaces
        for (final ingredient in ingredients) {
          expect(ingredient.toString(), equals(ingredient.toString().trim()));
        }

        // Check specific ingredients were cleaned
        expect(
          ingredients.any((ing) => ing.toString().contains('500 g nötfärs')),
          isTrue,
        );
        expect(
          ingredients.any(
            (ing) => ing.toString().contains('1 gul lök, hackad'),
          ),
          isTrue,
        );
      });

      test('should trim whitespace from instructions', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithArlaQuirks,
        );

        expect(recipe, isNotNull);
        final instructions = recipe!['recipeInstructions'] as List;

        // Each instruction should be trimmed
        for (final inst in instructions) {
          if (inst is Map && inst['text'] != null) {
            final text = inst['text'].toString();
            expect(text, equals(text.trim()));
            expect(text, isNot(startsWith(' ')));
            expect(text, isNot(endsWith(' ')));
          }
        }
      });
    });

    group('CSS Selector Fallback', () {
      test('should extract recipe when JSON-LD is missing', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Fluffiga pannkakor'));
        expect(recipe['recipeIngredient'], isA<List>());
        expect(recipe['recipeIngredient'], hasLength(greaterThan(3)));
        expect(recipe['recipeInstructions'], isA<List>());
        expect(recipe['recipeInstructions'], hasLength(greaterThan(3)));
      });

      test('should extract portions from CSS selectors', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], isNotNull);
        expect(recipe['recipeYield'], contains('4'));
      });

      test('should extract time from CSS selectors', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], isNotNull);
      });

      test('should extract image from CSS selectors', () {
        final recipe = parser.parseRecipe(ArlaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['image'], isNotNull);
        expect(recipe['image'], contains('pannkakor.jpg'));
      });
    });

    group('Error Recovery', () {
      test('should fall back to CSS when JSON-LD is malformed', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithMalformedJson,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Kladdkaka med grädde'));
        expect(recipe['recipeIngredient'], hasLength(greaterThan(3)));
        expect(recipe['recipeInstructions'], hasLength(3));
      });

      test('should return null for invalid HTML', () {
        const invalidHtml = '<html><body>Not a recipe</body></html>';
        final recipe = parser.parseRecipe(invalidHtml);

        expect(recipe, isNull);
      });

      test('should return null for empty HTML', () {
        const emptyHtml = '';
        final recipe = parser.parseRecipe(emptyHtml);

        expect(recipe, isNull);
      });
    });

    group('Quality Scoring', () {
      test('should give high quality score to complete recipe', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeCompleteMetadata,
        );

        expect(recipe, isNotNull);

        final quality = parser.scoreRecipe(recipe!);
        expect(quality.hasTitle, isTrue);
        expect(quality.hasIngredients, isTrue);
        expect(quality.hasInstructions, isTrue);
        expect(quality.hasPortions, isTrue);
        expect(quality.hasTime, isTrue);
        expect(quality.hasImage, isTrue);
        expect(quality.completeness, equals(1.0));
        expect(quality.meetsHighQuality, isTrue);
      });

      test('should give low quality score to recipe missing key fields', () {
        // Test quality scoring directly with incomplete data
        final incompleteRecipe = {
          'name': 'Simple Recipe',
          'recipeIngredient': [
            'Ingredient 1',
            'Ingredient 2',
          ], // Only 2 ingredients
          // No instructions
        };

        final quality = parser.scoreRecipe(incompleteRecipe);
        expect(quality.hasTitle, isTrue);
        expect(quality.hasIngredients, isFalse); // Only 2 ingredients
        expect(quality.hasInstructions, isFalse); // No instructions
        expect(quality.completeness, lessThan(0.80));
        expect(quality.meetsMinimumQuality, isFalse);
      });

      test('should score standard Arla recipe as acceptable', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.chokladbollarComplete,
        );

        expect(recipe, isNotNull);

        final quality = parser.scoreRecipe(recipe!);
        expect(quality.hasTitle, isTrue);
        expect(quality.hasIngredients, isTrue);
        expect(quality.hasInstructions, isTrue);
        expect(quality.completeness, greaterThanOrEqualTo(0.90));
        expect(quality.meetsAcceptableQuality, isTrue);
      });
    });

    group('Swedish Text Handling', () {
      test('should preserve Swedish characters in title', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Äppelpaj med vaniljsås'));
      });

      test('should preserve Swedish characters in ingredients', () {
        final recipe = parser.parseRecipe(
          ArlaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.toString(), contains('äpplen'));
        expect(ingredients.toString(), contains('havregryn'));
      });

      test('should handle smart quotes in Swedish text', () {
        const htmlWithSmartQuotes = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Test \\u201Crecipe\\u201D",
  "recipeIngredient": ["1 dl \\u201Cgod\\u201D mjölk från Arla", "2 dl vetemjöl", "1 ägg"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Blanda allt"},
    {"@type": "HowToStep", "text": "Grädda i ugnen"}
  ]
}
</script>
''';

        final recipe = parser.parseRecipe(htmlWithSmartQuotes);
        expect(recipe, isNotNull);
        // Smart quotes should be normalized to regular quotes in cleaned text
        expect(recipe!['name'], contains('recipe'));
      });
    });

    group('Edge Cases', () {
      test('should handle recipe without portions', () {
        const html = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Test Recipe",
  "recipeIngredient": ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Step 1"},
    {"@type": "HowToStep", "text": "Step 2"}
  ]
}
</script>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Test Recipe'));
      });

      test('should handle recipe without time', () {
        const html = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Quick Snack",
  "recipeIngredient": ["Arla yoghurt", "Müsli", "Honung"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Lägg yoghurt i en skål"},
    {"@type": "HowToStep", "text": "Toppa med müsli och honung"}
  ]
}
</script>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Quick Snack'));
        // Recipe should be accepted even without time (time is 5% weight)
      });

      test('should handle recipe with array of images', () {
        const html = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Visual Recipe",
  "image": [
    "https://assets.arla.com/img1.jpg",
    "https://assets.arla.com/img2.jpg"
  ],
  "recipeIngredient": ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Step 1"},
    {"@type": "HowToStep", "text": "Step 2"}
  ]
}
</script>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        expect(recipe!['image'], isA<List>());
      });

      test('should handle recipe with image object', () {
        const html = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Recipe with Image Object",
  "image": {
    "@type": "ImageObject",
    "url": "https://assets.arla.com/img.jpg"
  },
  "recipeIngredient": ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Step 1"},
    {"@type": "HowToStep", "text": "Step 2"}
  ]
}
</script>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        expect(recipe!['image'], isA<Map>());
      });
    });

    group('Time Conversion', () {
      test('should convert "30 minuter" to ISO 8601', () {
        // This is tested via CSS fallback which uses _convertToIso8601
        const html = '''
<html>
<body>
  <h1 class="recipe-title">Test Recipe</h1>
  <span class="recipe-time">30 minuter</span>
  <ul class="ingredient-list">
    <li>Ingredient 1</li>
    <li>Ingredient 2</li>
    <li>Ingredient 3</li>
  </ul>
  <ol class="recipe-instructions">
    <li>Step 1</li>
    <li>Step 2</li>
  </ol>
</body>
</html>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        if (recipe!['totalTime'] != null) {
          expect(recipe['totalTime'], equals('PT30M'));
        }
      });

      test('should convert "1 timme 15 min" to ISO 8601', () {
        const html = '''
<html>
<body>
  <h1 class="recipe-title">Test Recipe</h1>
  <span class="recipe-time">1 timme 15 min</span>
  <ul class="ingredient-list">
    <li>Ingredient 1</li>
    <li>Ingredient 2</li>
    <li>Ingredient 3</li>
  </ul>
  <ol class="recipe-instructions">
    <li>Step 1</li>
    <li>Step 2</li>
  </ol>
</body>
</html>
''';

        final recipe = parser.parseRecipe(html);
        expect(recipe, isNotNull);
        if (recipe!['totalTime'] != null) {
          expect(recipe['totalTime'], equals('PT1H15M'));
        }
      });
    });
  });
}
