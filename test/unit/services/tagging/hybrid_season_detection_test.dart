import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

/// Sprint 3: Tests for hybrid season detection.
///
/// The season detection algorithm uses a hybrid approach:
/// 1. If ≥2 ingredients have `seasonAvailability` data, use field-based detection
/// 2. Otherwise, fall back to name-based inference (original algorithm)
void main() {
  late TagGenerator generator;

  setUp(() {
    generator = TagGenerator();
  });

  group('Hybrid Season Detection', () {
    group('field-based detection', () {
      test('uses seasonAvailability field when ≥2 ingredients have data', () {
        final recipe = RecipeBuilder()
            .withTitle('Summer Salad')
            .withTimeMinutes(15)
            .withIngredients(['tomat', 'gurka']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('tomat', 'vegetable', {},
              seasonAvailability: ['sommar']),
          TaggingTestHelper.ingredient('gurka', 'vegetable', {},
              seasonAvailability: ['sommar']),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('sommar'), isTrue);
      });

      test('adds season tag when ≥2 ingredients match that season', () {
        final recipe = RecipeBuilder()
            .withTitle('Autumn Stew')
            .withTimeMinutes(60)
            .withIngredients(['svamp', 'kantarell', 'potato']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('svamp', 'vegetable/mushroom', {},
              seasonAvailability: ['höst']),
          TaggingTestHelper.ingredient('kantarell', 'vegetable/mushroom', {},
              seasonAvailability: ['höst']),
          TaggingTestHelper.ingredient(
              'potato', 'vegetable/root', {}), // No season data
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('höst'), isTrue);
      });

      test('does not add season tag when <2 ingredients match', () {
        final recipe = RecipeBuilder()
            .withTitle('Simple Dish')
            .withTimeMinutes(30)
            .withIngredients(['tomat', 'gurka', 'ris']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('tomat', 'vegetable', {},
              seasonAvailability: ['sommar']),
          TaggingTestHelper.ingredient('gurka', 'vegetable', {},
              seasonAvailability: ['vår']), // Different season
          TaggingTestHelper.ingredient('ris', 'grain', {},
              seasonAvailability: ['vinter']), // Different season
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Each season only has 1 ingredient, so no season tags
        expect(result.hasTag('sommar'), isFalse);
        expect(result.hasTag('vår'), isFalse);
        expect(result.hasTag('vinter'), isFalse);
      });
    });

    group('name-based fallback', () {
      test('falls back to name-based detection when <2 have season data', () {
        // Only one ingredient has seasonAvailability
        final recipe = RecipeBuilder()
            .withTitle('Spring Dish')
            .withTimeMinutes(30)
            .withIngredients(['sparris', 'rädisor']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('sparris', 'vegetable', {},
              seasonAvailability: ['vår']),
          TaggingTestHelper.ingredient(
              'rädisor', 'vegetable', {}), // No seasonAvailability
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Should get 'vår' via name-based fallback (sparris + rädisor match spring list)
        expect(result.hasTag('vår'), isTrue);
      });

      test('uses name matching when no ingredients have season data', () {
        final recipe = RecipeBuilder()
            .withTitle('Berry Dessert')
            .withTimeMinutes(15)
            .withIngredients(['jordgubb', 'hallon']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'jordgubb', 'fruit/berry', {}), // No seasonAvailability
          TaggingTestHelper.ingredient(
              'hallon', 'fruit/berry', {}), // No seasonAvailability
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // Name-based: jordgubb and hallon are summer berries
        expect(result.hasTag('sommar'), isTrue);
      });
    });

    group('multi-season ingredients', () {
      test('counts ingredient toward all its seasons', () {
        final recipe = RecipeBuilder()
            .withTitle('Seasonal Soup')
            .withTimeMinutes(45)
            .withIngredients(['morot', 'potatis', 'purjolök']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('morot', 'vegetable/root', {},
              seasonAvailability: ['höst', 'vinter']),
          TaggingTestHelper.ingredient('potatis', 'vegetable/root', {},
              seasonAvailability: ['höst', 'vinter']),
          TaggingTestHelper.ingredient('purjolök', 'vegetable', {},
              seasonAvailability: ['vår', 'höst']),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // 'höst' appears in all 3 ingredients (≥2 threshold)
        expect(result.hasTag('höst'), isTrue);
        // 'vinter' appears in 2 ingredients (≥2 threshold)
        expect(result.hasTag('vinter'), isTrue);
        // 'vår' only appears in 1 ingredient (<2 threshold)
        expect(result.hasTag('vår'), isFalse);
      });

      test('handles year-round ingredients (all seasons)', () {
        final recipe = RecipeBuilder()
            .withTitle('Simple Pasta')
            .withTimeMinutes(20)
            .withIngredients(['pasta', 'olivolja']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('pasta', 'grain/pasta-bread', {},
              seasonAvailability: ['vår', 'sommar', 'höst', 'vinter']),
          TaggingTestHelper.ingredient('olivolja', 'fat/oil', {},
              seasonAvailability: ['vår', 'sommar', 'höst', 'vinter']),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // All seasons have ≥2 ingredients
        expect(result.hasTag('vår'), isTrue);
        expect(result.hasTag('sommar'), isTrue);
        expect(result.hasTag('höst'), isTrue);
        expect(result.hasTag('vinter'), isTrue);
      });
    });

    group('edge cases', () {
      test('normalizes season names to lowercase', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['item1', 'item2']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('item1', 'vegetable', {},
              seasonAvailability: ['SOMMAR']), // Uppercase
          TaggingTestHelper.ingredient('item2', 'vegetable', {},
              seasonAvailability: ['Sommar']), // Mixed case
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        expect(result.hasTag('sommar'), isTrue);
      });

      test('ignores invalid season names', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['item1', 'item2']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('item1', 'vegetable', {},
              seasonAvailability: ['invalid_season']),
          TaggingTestHelper.ingredient('item2', 'vegetable', {},
              seasonAvailability: ['not_a_season']),
        ]);

        final result = generator.generate(ingredients: lookup, recipe: recipe);

        // No valid season tags
        expect(result.hasTag('vår'), isFalse);
        expect(result.hasTag('sommar'), isFalse);
        expect(result.hasTag('höst'), isFalse);
        expect(result.hasTag('vinter'), isFalse);
      });
    });
  });
}
