/// Unit tests for SchemaOrgRecipeExtractor.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/extractors/schema_org_recipe_extractor.dart';

void main() {
  group('extractTitle', () {
    test('returns name when present', () {
      expect(
        SchemaOrgRecipeExtractor.extractTitle({'name': 'Pasta Bolognese'}),
        'Pasta Bolognese',
      );
    });

    test('trims whitespace', () {
      expect(
        SchemaOrgRecipeExtractor.extractTitle({'name': '  Pasta  '}),
        'Pasta',
      );
    });

    test('unescapes HTML entities', () {
      expect(
        SchemaOrgRecipeExtractor.extractTitle({'name': 'Köttbullar &amp; sås'}),
        'Köttbullar & sås',
      );
    });

    test('"Imported Recipe" fallback when missing/empty', () {
      expect(SchemaOrgRecipeExtractor.extractTitle({}), 'Imported Recipe');
      expect(
        SchemaOrgRecipeExtractor.extractTitle({'name': ''}),
        'Imported Recipe',
      );
    });
  });

  group('extractDescription', () {
    test('returns trimmed + unescaped description', () {
      expect(
        SchemaOrgRecipeExtractor.extractDescription({
          'description': '  Tasty &amp; quick  ',
        }),
        'Tasty & quick',
      );
    });

    test('empty string when missing', () {
      expect(SchemaOrgRecipeExtractor.extractDescription({}), '');
    });
  });

  group('extractIngredients', () {
    test('list → list (trimmed, empty entries filtered)', () {
      expect(
        SchemaOrgRecipeExtractor.extractIngredients({
          'recipeIngredient': ['2 dl mjölk', '500 g pasta', ''],
        }),
        ['2 dl mjölk', '500 g pasta'],
      );
    });

    test('string → single-item list', () {
      expect(
        SchemaOrgRecipeExtractor.extractIngredients({
          'recipeIngredient': '2 dl mjölk',
        }),
        ['2 dl mjölk'],
      );
    });

    test('null → empty list', () {
      expect(SchemaOrgRecipeExtractor.extractIngredients({}), isEmpty);
    });

    test(r'strips price annotations like "$0.18", "$7.95*"', () {
      expect(
        SchemaOrgRecipeExtractor.extractIngredients({
          'recipeIngredient': ['Pasta \$0.18', 'Tomato sauce \$7.95**'],
        }),
        ['Pasta', 'Tomato sauce'],
      );
    });

    test('cleans up empty trailing parens after price strip', () {
      expect(
        SchemaOrgRecipeExtractor.extractIngredients({
          'recipeIngredient': ['Olive oil (\$1.50)'],
        }),
        ['Olive oil'],
      );
    });
  });

  group('extractInstructions', () {
    test('list of strings → list of trimmed steps', () {
      expect(
        SchemaOrgRecipeExtractor.extractInstructions({
          'recipeInstructions': ['  Boil water', 'Add pasta'],
        }),
        ['Boil water', 'Add pasta'],
      );
    });

    test('list of HowToStep maps → extracts text field', () {
      expect(
        SchemaOrgRecipeExtractor.extractInstructions({
          'recipeInstructions': [
            {'@type': 'HowToStep', 'text': 'Boil water'},
            {'text': 'Add pasta'},
          ],
        }),
        ['Boil water', 'Add pasta'],
      );
    });

    test('skips map entries with missing or empty text', () {
      expect(
        SchemaOrgRecipeExtractor.extractInstructions({
          'recipeInstructions': [
            {'text': ''},
            {'text': 'Valid step'},
            {'@type': 'HowToStep'}, // no text
          ],
        }),
        ['Valid step'],
      );
    });

    test('string with multiple sentences splits at ". <Cap>"', () {
      expect(
        SchemaOrgRecipeExtractor.extractInstructions({
          'recipeInstructions': 'Boil water. Add pasta. Cook for 10 minutes.',
        }),
        [
          'Boil water.',
          'Add pasta.',
          'Cook for 10 minutes.',
        ],
      );
    });

    test('single-sentence string → single-step list', () {
      expect(
        SchemaOrgRecipeExtractor.extractInstructions({
          'recipeInstructions': 'Boil water and add pasta',
        }),
        ['Boil water and add pasta'],
      );
    });

    test('null → empty list', () {
      expect(SchemaOrgRecipeExtractor.extractInstructions({}), isEmpty);
    });
  });

  group('extractYield', () {
    test('parses leading number from string', () {
      expect(
        SchemaOrgRecipeExtractor.extractYield({'recipeYield': '4 servings'}),
        4,
      );
    });

    test('returns null when no digit present', () {
      expect(
        SchemaOrgRecipeExtractor.extractYield({'recipeYield': 'a lot'}),
        isNull,
      );
    });

    test('returns null when missing', () {
      expect(SchemaOrgRecipeExtractor.extractYield({}), isNull);
    });
  });

  group('parseDuration (ISO 8601)', () {
    test('null → null', () {
      expect(SchemaOrgRecipeExtractor.parseDuration(null), isNull);
    });

    test('non-PT prefix → null', () {
      expect(SchemaOrgRecipeExtractor.parseDuration('30M'), isNull);
    });

    test('PT30M → 30 minutes', () {
      expect(SchemaOrgRecipeExtractor.parseDuration('PT30M'), 30);
    });

    test('PT1H → 60 minutes', () {
      expect(SchemaOrgRecipeExtractor.parseDuration('PT1H'), 60);
    });

    test('PT1H30M → 90 minutes', () {
      expect(SchemaOrgRecipeExtractor.parseDuration('PT1H30M'), 90);
    });

    test('PT (no hours/minutes) → null', () {
      expect(SchemaOrgRecipeExtractor.parseDuration('PT'), isNull);
    });
  });

  group('extractTime', () {
    test('uses totalTime when present', () {
      expect(
        SchemaOrgRecipeExtractor.extractTime({'totalTime': 'PT45M'}),
        45,
      );
    });

    test('falls back to prepTime + cookTime when totalTime missing', () {
      expect(
        SchemaOrgRecipeExtractor.extractTime({
          'prepTime': 'PT15M',
          'cookTime': 'PT30M',
        }),
        45,
      );
    });

    test('returns null when no time data at all', () {
      expect(SchemaOrgRecipeExtractor.extractTime({}), isNull);
    });

    test('uses only one of prep/cook when the other is missing', () {
      expect(
        SchemaOrgRecipeExtractor.extractTime({'prepTime': 'PT20M'}),
        20,
      );
    });
  });

  group('extractCuisine + extractCategory', () {
    test('string variant returns trimmed + unescaped', () {
      expect(
        SchemaOrgRecipeExtractor.extractCuisine({
          'recipeCuisine': '  Italian &amp; Mediterranean  ',
        }),
        'Italian & Mediterranean',
      );
      expect(
        SchemaOrgRecipeExtractor.extractCategory({
          'recipeCategory': 'Middag',
        }),
        'Middag',
      );
    });

    test('list variant picks first non-empty entry', () {
      expect(
        SchemaOrgRecipeExtractor.extractCuisine({
          'recipeCuisine': ['Swedish', 'Nordic'],
        }),
        'Swedish',
      );
    });

    test('null/missing → null', () {
      expect(SchemaOrgRecipeExtractor.extractCuisine({}), isNull);
      expect(SchemaOrgRecipeExtractor.extractCategory({}), isNull);
    });

    test('empty list → null', () {
      expect(
        SchemaOrgRecipeExtractor.extractCuisine({'recipeCuisine': []}),
        isNull,
      );
    });
  });

  group('extractImages', () {
    test('single string → single-element list', () {
      expect(
        SchemaOrgRecipeExtractor.extractImages({
          'image': 'https://example.com/x.jpg',
        }),
        ['https://example.com/x.jpg'],
      );
    });

    test('list of strings → trimmed, empty filtered', () {
      expect(
        SchemaOrgRecipeExtractor.extractImages({
          'image': ['  https://x/a.jpg  ', 'https://x/b.jpg', ''],
        }),
        ['https://x/a.jpg', 'https://x/b.jpg'],
      );
    });

    test('list of ImageObject maps → extracts url field', () {
      expect(
        SchemaOrgRecipeExtractor.extractImages({
          'image': [
            {'@type': 'ImageObject', 'url': 'https://x/a.jpg'},
            {'url': 'https://x/b.jpg'},
          ],
        }),
        ['https://x/a.jpg', 'https://x/b.jpg'],
      );
    });

    test('single ImageObject map → extracts url', () {
      expect(
        SchemaOrgRecipeExtractor.extractImages({
          'image': {'url': 'https://x/a.jpg'},
        }),
        ['https://x/a.jpg'],
      );
    });

    test('null / unknown shapes → empty list', () {
      expect(SchemaOrgRecipeExtractor.extractImages({}), isEmpty);
      expect(SchemaOrgRecipeExtractor.extractImages({'image': 42}), isEmpty);
    });
  });

  group('createRecipe (end-to-end factory)', () {
    test('builds a Recipe with extracted fields', () {
      final recipe = SchemaOrgRecipeExtractor.createRecipe(
        {
          'name': 'Pasta',
          'description': 'Quick dinner',
          'recipeIngredient': ['200g pasta', '1 tomato'],
          'recipeInstructions': ['Boil water', 'Cook pasta'],
          'recipeYield': '4',
          'prepTime': 'PT10M',
          'cookTime': 'PT15M',
          'recipeCategory': 'Middag',
          'recipeCuisine': 'Italian',
          'image': 'https://x.jpg',
        },
        'https://example.com/recipe',
      );

      expect(recipe.title, 'Pasta');
      expect(recipe.description, 'Quick dinner');
      expect(recipe.ingredients, hasLength(2));
      expect(recipe.instructions, ['Boil water', 'Cook pasta']);
      expect(recipe.portions, 4);
      expect(recipe.timeMinutes, 25);
      expect(recipe.prepTimeMinutes, 10);
      expect(recipe.cookTimeMinutes, 15);
      expect(recipe.mealType, 'Middag');
      expect(recipe.cuisine, 'Italian');
      expect(recipe.imageUrls, ['https://x.jpg']);
      expect(recipe.sourceUrl, 'https://example.com/recipe');
      expect(recipe.type, RecipeType.personal);
    });

    test('uses defaults when data is mostly empty', () {
      final recipe = SchemaOrgRecipeExtractor.createRecipe(
        {},
        'https://example.com/r',
      );
      expect(recipe.title, 'Imported Recipe');
      expect(recipe.mealType, 'Middag'); // default
      expect(recipe.ingredients, isEmpty);
    });
  });
}
