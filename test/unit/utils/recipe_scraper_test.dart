/// Unit tests for RecipeScraper - Advanced recipe extraction from HTML content
///
/// Tests comprehensive recipe extraction including:
/// - JSON-LD structured data parsing
/// - Microdata format parsing
/// - Recipe field extraction (name, ingredients, instructions, etc.)
/// - Multi-format support
/// - Error handling and recovery
/// - Edge cases and malformed HTML
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/utils/recipe_scraper.dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RecipeScraper', () {
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    group('JSON-LD Extraction', () {
      test('should extract recipe from single JSON-LD object', () {
        const html = '''
        <html>
          <head>
            <script type="application/ld+json">
            {
              "@type": "Recipe",
              "name": "Swedish Meatballs",
              "recipeIngredient": ["500g ground beef", "1 onion", "2 dl cream"],
              "recipeInstructions": ["Mix ingredients", "Form balls", "Fry until golden"],
              "recipeYield": "4 servings",
              "totalTime": "PT30M",
              "image": "https://example.com/meatballs.jpg"
            }
            </script>
          </head>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['@type'], equals('Recipe'));
        expect(result['name'], equals('Swedish Meatballs'));
        expect(result['recipeIngredient'], hasLength(3));
        expect(result['recipeIngredient'][0], equals('500g ground beef'));
        expect(result['recipeInstructions'], hasLength(3));
        expect(result['recipeInstructions'][0], equals('Mix ingredients'));
        expect(result['recipeYield'], equals('4 servings'));
        expect(result['totalTime'], equals('PT30M'));
        expect(result['image'], equals('https://example.com/meatballs.jpg'));
      });

      test('should extract recipe from JSON-LD array', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          [
            {
              "@type": "Organization",
              "name": "Recipe Site"
            },
            {
              "@type": "Recipe",
              "name": "Kladdkaka",
              "recipeIngredient": ["100g butter", "2 eggs", "3 dl sugar"],
              "recipeInstructions": ["Melt butter", "Mix all", "Bake 15 min"]
            }
          ]
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['@type'], equals('Recipe'));
        expect(result['name'], equals('Kladdkaka'));
        expect(result['recipeIngredient'], hasLength(3));
        expect(result['recipeIngredient'][1], equals('2 eggs'));
      });

      test('should handle case-insensitive script tag', () {
        const html = '''
        <html>
          <SCRIPT TYPE="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Test Recipe"
          }
          </SCRIPT>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Test Recipe'));
      });

      test('should skip non-Recipe JSON-LD objects', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@type": "Organization",
            "name": "Not a Recipe"
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });

      test('should handle malformed JSON gracefully', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Broken JSON",
            // Invalid comment in JSON
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });

      test('should find Recipe in multiple JSON-LD scripts', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {"@type": "WebSite", "name": "Site"}
          </script>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Found Recipe"
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Found Recipe'));
      });
    });

    group('BUG-9: @graph JSON-LD pattern', () {
      test('should extract Recipe from @graph wrapper', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@graph": [
              {
                "@type": "WebSite",
                "name": "Recipe Blog"
              },
              {
                "@type": "Recipe",
                "name": "Kanelbullar",
                "recipeIngredient": ["50g jäst", "3 dl mjölk", "150g smör"],
                "recipeInstructions": ["Lös jästen", "Blanda degen", "Grädda"]
              },
              {
                "@type": "Organization",
                "name": "Baking Corp"
              }
            ]
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['@type'], equals('Recipe'));
        expect(result['name'], equals('Kanelbullar'));
        expect(result['recipeIngredient'], hasLength(3));
        expect(result['recipeIngredient'][0], equals('50g jäst'));
        expect(result['recipeInstructions'], hasLength(3));
      });

      test('should return null for @graph without Recipe type', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@graph": [
              {
                "@type": "WebSite",
                "name": "Just a Blog"
              },
              {
                "@type": "Organization",
                "name": "Some Corp"
              }
            ]
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });

      test('should prefer direct Recipe over @graph when both exist', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Direct Recipe"
          }
          </script>
          <script type="application/ld+json">
          {
            "@graph": [
              {
                "@type": "Recipe",
                "name": "Graph Recipe"
              }
            ]
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        // Direct Recipe is found first since scripts are iterated in order
        expect(result!['name'], equals('Direct Recipe'));
      });

      test('should handle @graph with empty list', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@graph": []
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });
    });

    group('Microdata Extraction', () {
      test('should extract complete recipe from Microdata', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Pannkakor</h1>
            <span itemprop="recipeIngredient">3 dl mjölk</span>
            <span itemprop="recipeIngredient">2 ägg</span>
            <span itemprop="recipeIngredient">1.5 dl mjöl</span>
            <div itemprop="recipeInstructions">Vispa samman mjölk och ägg</div>
            <div itemprop="recipeInstructions">Tillsätt mjöl</div>
            <span itemprop="recipeYield">4 portioner</span>
            <time itemprop="totalTime" content="PT20M">20 minuter</time>
            <img itemprop="image" src="/pannkakor.jpg" />
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['@type'], equals('Recipe'));
        expect(result['name'], equals('Pannkakor'));
        expect(result['recipeIngredient'], hasLength(3));
        expect(result['recipeIngredient'][0], equals('3 dl mjölk'));
        expect(result['recipeInstructions'], hasLength(2));
        expect(result['recipeInstructions'][0],
            equals('Vispa samman mjölk och ägg'));
        expect(result['recipeYield'], equals('4 portioner'));
        expect(result['totalTime'], equals('PT20M'));
        expect(result['image'], equals('/pannkakor.jpg'));
      });

      test('should handle nested instruction elements', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <div itemprop="recipeInstructions">
              <li>Step 1</li>
              <li>Step 2</li>
              <p>Step 3</p>
              <span>Step 4</span>
            </div>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['recipeInstructions'], hasLength(4));
        expect(result['recipeInstructions'][0], equals('Step 1'));
        expect(result['recipeInstructions'][1], equals('Step 2'));
        expect(result['recipeInstructions'][2], equals('Step 3'));
        expect(result['recipeInstructions'][3], equals('Step 4'));
      });

      test('should handle instructions without nested elements', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <div itemprop="recipeInstructions">Mix everything and bake</div>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['recipeInstructions'], hasLength(1));
        expect(
            result['recipeInstructions'][0], equals('Mix everything and bake'));
      });

      test('should extract image from content attribute', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <meta itemprop="image" content="https://example.com/recipe.jpg" />
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['image'], equals('https://example.com/recipe.jpg'));
      });

      test('should extract totalTime from text when no content attribute', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <span itemprop="totalTime">30 minutes</span>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['totalTime'], equals('30 minutes'));
      });

      test('should handle empty ingredient and instruction elements', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <span itemprop="recipeIngredient"></span>
            <span itemprop="recipeIngredient">   </span>
            <span itemprop="recipeIngredient">Valid ingredient</span>
            <div itemprop="recipeInstructions">   </div>
            <div itemprop="recipeInstructions">Valid instruction</div>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['recipeIngredient'], hasLength(1));
        expect(result['recipeIngredient'][0], equals('Valid ingredient'));
        expect(result['recipeInstructions'], hasLength(1));
        expect(result['recipeInstructions'][0], equals('Valid instruction'));
      });
    });

    group('Priority and Fallback', () {
      test('should prioritize JSON-LD over Microdata', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "JSON-LD Recipe"
          }
          </script>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Microdata Recipe</h1>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('JSON-LD Recipe'));
      });

      test('should fall back to Microdata when JSON-LD not found', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Microdata Only</h1>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Microdata Only'));
      });

      test('should use first Microdata recipe if multiple exist', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">First Recipe</h1>
          </div>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Second Recipe</h1>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('First Recipe'));
      });
    });

    group('Edge Cases', () {
      test('should handle empty HTML', () {
        const html = '';
        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });

      test('should handle HTML without recipe data', () {
        const html = '''
        <html>
          <body>
            <h1>Regular Web Page</h1>
            <p>No recipe data here</p>
          </body>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);
        expect(result, isNull);
      });

      test('should handle minimal valid recipe', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          {"@type": "Recipe"}
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['@type'], equals('Recipe'));
      });

      test('should handle special characters in content', () {
        const html = r'''
        <html>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Recipe with \"quotes\" & <tags>",
            "recipeIngredient": ["1/2 cup & 2 tsp"]
          }
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Recipe with "quotes" & <tags>'));
        expect(result['recipeIngredient'][0], equals('1/2 cup & 2 tsp'));
      });

      test('should handle whitespace in JSON-LD content', () {
        const html = '''
        <html>
          <script type="application/ld+json">
          
          
            {
              "@type": "Recipe",
              "name": "Spaced Recipe"
            }
          
          
          </script>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Spaced Recipe'));
      });

      test('should handle missing optional fields', () {
        const html = '''
        <html>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Minimal Recipe</h1>
          </div>
        </html>
        ''';

        final result = extractRecipeFromHtml(html);

        expect(result, isNotNull);
        expect(result!['name'], equals('Minimal Recipe'));
        expect(result['recipeIngredient'], isEmpty);
        expect(result['recipeInstructions'], isEmpty);
        expect(result.containsKey('recipeYield'), isFalse);
        expect(result.containsKey('totalTime'), isFalse);
        expect(result.containsKey('image'), isFalse);
      });
    });
  });
}
