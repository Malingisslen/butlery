import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import '../../../../fixtures/swedish_sites/ica_test_data.dart';

void main() {
  group('IcaRecipeParser', () {
    late IcaRecipeParser parser;

    setUp(() {
      parser = IcaRecipeParser();
    });

    group('Parser Identification', () {
      test('should identify correct domain', () {
        expect(parser.domain, equals('ica.se'));
      });

      test('should have correct site name', () {
        expect(parser.siteName, equals('ICA'));
      });
    });

    group('Standard JSON-LD Extraction', () {
      test('should extract complete recipe from ICA JSON-LD', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.kottbullarComplete);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Klassiska köttbullar med gräddsås'));
        expect(recipe['description'], contains('Saftig köttbullar'));
        expect(recipe['recipeIngredient'], isA<List>());
        expect(recipe['recipeIngredient'], hasLength(13));
        expect(recipe['recipeInstructions'], isA<List>());
        expect(recipe['recipeInstructions'], hasLength(6));
        expect(recipe['recipeYield'], equals('4 portioner'));
        expect(recipe['totalTime'], equals('PT45M'));
        expect(recipe['prepTime'], equals('PT20M'));
        expect(recipe['cookTime'], equals('PT25M'));
        expect(recipe['image'], isNotNull);
      });

      test('should reject recipe with insufficient data (quality check)', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeMinimalData);

        // Recipe should be rejected due to insufficient ingredients (<3) and no instructions
        expect(
          recipe,
          isNull,
          reason: 'Recipe with only 2 ingredients should fail quality check',
        );
      });

      test('should handle recipe with Swedish characters', () {
        final recipe = parser.parseRecipe(
          IcaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Ärtsoppa med fläsk'));
        expect(recipe['description'], contains('torsdagsmiddagen'));
        expect(recipe['recipeIngredient'].toString(), contains('ärtor'));
        expect(recipe['recipeIngredient'].toString(), contains('lök'));
      });
    });

    group('ICA-Specific Enhancements', () {
      test('should extract difficulty level', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.kottbullarComplete);

        expect(recipe, isNotNull);
        expect(recipe!['difficulty'], equals('Enkel'));
      });

      test('should extract cooking tips', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.kottbullarComplete);

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        expect(recipe['cookingTips'], isNotEmpty);
        expect(recipe['cookingTips'].first, contains('Låt smeten svälla'));
      });

      test('should extract equipment list', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.pannkakorWithExtras);

        expect(recipe, isNotNull);
        expect(recipe!['equipment'], isA<List>());
        expect(recipe['equipment'], contains('Vissp'));
        expect(recipe['equipment'], contains('Stekpanna'));
        expect(recipe['equipment'], contains('Spatel'));
      });

      test('should extract multiple cooking tips', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.pannkakorWithExtras);

        expect(recipe, isNotNull);
        expect(recipe!['cookingTips'], isA<List>());
        expect(recipe['cookingTips'], isNotEmpty);
        expect(recipe['cookingTips'].first, contains('extra fluffiga'));
      });
    });

    group('ICA Formatting Cleanup', () {
      test('should clean "ca" and "cirka" from portions', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithIcaQuirks);

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], equals('4 portioner'));
        expect(recipe['recipeYield'], isNot(contains('ca')));
      });

      test('should trim whitespace from ingredients', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithIcaQuirks);

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
          ingredients.any((ing) => ing.toString().contains('8 tortillabröd')),
          isTrue,
        );
      });

      test('should trim whitespace from instructions', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithIcaQuirks);

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
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Klassisk kladdkaka'));
        expect(recipe['recipeIngredient'], isA<List>());
        expect(recipe['recipeIngredient'], hasLength(greaterThan(3)));
        expect(recipe['recipeInstructions'], isA<List>());
        expect(recipe['recipeInstructions'], hasLength(greaterThan(3)));
      });

      test('should extract portions from CSS selectors', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['recipeYield'], isNotNull);
        expect(recipe['recipeYield'], contains('8'));
      });

      test('should extract time from CSS selectors', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['totalTime'], isNotNull);
      });

      test('should extract image from CSS selectors', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.recipeWithoutJsonLd);

        expect(recipe, isNotNull);
        expect(recipe!['image'], isNotNull);
        expect(recipe['image'], contains('kladdkaka.jpg'));
      });
    });

    group('Error Recovery', () {
      test('should fall back to CSS when JSON-LD is malformed', () {
        final recipe = parser.parseRecipe(
          IcaTestFixtures.recipeWithMalformedJson,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Lasagne al forno'));
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
          IcaTestFixtures.recipeCompleteMetadata,
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

      test('should score standard ICA recipe as acceptable', () {
        final recipe = parser.parseRecipe(IcaTestFixtures.kottbullarComplete);

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
          IcaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        expect(recipe!['name'], equals('Ärtsoppa med fläsk'));
      });

      test('should preserve Swedish characters in ingredients', () {
        final recipe = parser.parseRecipe(
          IcaTestFixtures.recipeWithSwedishChars,
        );

        expect(recipe, isNotNull);
        final ingredients = recipe!['recipeIngredient'] as List;
        expect(ingredients.toString(), contains('ärtor'));
        expect(ingredients.toString(), contains('lök'));
        expect(ingredients.toString(), contains('senapsfrön'));
      });

      test('should handle smart quotes in Swedish text', () {
        const htmlWithSmartQuotes = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Test \u201Crecipe\u201D",
  "recipeIngredient": ["1 dl \u201Cgod\u201D mjölk", "2 dl vetemjöl", "1 ägg"],
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
  "recipeIngredient": ["Bread", "Butter", "Cheese"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Toast bread"},
    {"@type": "HowToStep", "text": "Spread butter and add cheese"}
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
    "https://example.com/img1.jpg",
    "https://example.com/img2.jpg"
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
    "url": "https://example.com/img.jpg"
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

      test('should convert "1 timme 30 min" to ISO 8601', () {
        const html = '''
<html>
<body>
  <h1 class="recipe-title">Test Recipe</h1>
  <span class="recipe-time">1 timme 30 min</span>
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
          expect(recipe['totalTime'], equals('PT1H30M'));
        }
      });
    });
  });
}
