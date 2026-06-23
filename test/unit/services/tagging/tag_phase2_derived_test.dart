/// Unit tests for TagPhase2Derived.
///
/// BUG-4: Verifies the mild tag uses 80% threshold (TaggingThresholds.mildCoverageThreshold)
/// instead of requiring 100% coverage, which made the tag effectively unreachable.
///
/// Also covers:
/// - Dish type derived tags
/// - Spicy/mild indicator logic
/// - Few-ingredients tag
/// - Derived tags from Phase 1 base tags
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

void main() {
  late TagPhase2Derived phase2;

  setUp(() {
    phase2 = TagPhase2Derived();
  });

  group('TagPhase2Derived', () {
    group('BUG-4: mild tag uses 80% coverage threshold', () {
      test('should add mild tag when coverage is exactly 80% and no spicy', () {
        // Arrange: 80% coverage (4 out of 5 matched), no spicy
        final recipe = RecipeBuilder()
            .withTitle('Mild Chicken')
            .withIngredients(['chicken', 'rice', 'carrot', 'salt', 'unknown'])
            .build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('chicken', 'protein/meat/poultry', {
              'meat',
              'poultry',
            }),
            TaggingTestHelper.ingredient('rice', 'grain', {}),
            TaggingTestHelper.ingredient('carrot', 'vegetable', {}),
            TaggingTestHelper.ingredient('salt', 'seasoning', {}),
          ],
          unmatched: ['unknown'],
        );
        // coverage = 4/5 = 0.8

        final phase1 = Phase1Result(
          tags: {'kyckling', 'risbaserad'},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(
          result.tags,
          contains('mild'),
          reason:
              'mild should be added at exactly 80% coverage (mildCoverageThreshold)',
        );
        expect(result.tags, isNot(contains('stark')));
      });

      test('should add mild tag when coverage is above 80% and no spicy', () {
        // Arrange: 90% coverage (9 out of 10 matched), no spicy
        final recipe = RecipeBuilder().withTitle('Mild Dish').withIngredients([
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
          'g',
          'h',
          'i',
          'unknown',
        ]).build();

        final matched = List.generate(
          9,
          (i) => TaggingTestHelper.ingredient('item$i', 'vegetable', {}),
        );

        final lookup = IngredientLookupResult.fromLists(
          matched: matched,
          unmatched: ['unknown'],
        );
        // coverage = 9/10 = 0.9

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(result.tags, contains('mild'));
      });

      test('should NOT add mild tag when coverage is below 80%', () {
        // Arrange: 75% coverage (3 out of 4 matched), no spicy
        final recipe = RecipeBuilder()
            .withTitle('Unknown Dish')
            .withIngredients(['a', 'b', 'c', 'unknown'])
            .build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('a', 'vegetable', {}),
            TaggingTestHelper.ingredient('b', 'vegetable', {}),
            TaggingTestHelper.ingredient('c', 'vegetable', {}),
          ],
          unmatched: ['unknown'],
        );
        // coverage = 3/4 = 0.75

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(
          result.tags,
          isNot(contains('mild')),
          reason:
              'mild should NOT be added at 75% coverage (below 80% threshold)',
        );
      });

      test('should add mild tag at 100% coverage and no spicy', () {
        // Arrange: full coverage, no spicy
        final recipe = RecipeBuilder()
            .withTitle('Mild Full Coverage')
            .withIngredients(['rice', 'carrot'])
            .build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('rice', 'grain', {}),
            TaggingTestHelper.ingredient('carrot', 'vegetable', {}),
          ],
          unmatched: [],
        );
        // coverage = 2/2 = 1.0

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(result.tags, contains('mild'));
      });

      test('should NOT add mild tag when spicy even with high coverage', () {
        // Arrange: 100% coverage but has spicy ingredient
        final recipe = RecipeBuilder().withTitle('Spicy Rice').withIngredients([
          'rice',
          'chili',
        ]).build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('rice', 'grain', {}),
            TaggingTestHelper.ingredient('chili', 'spice', {'is-spicy'}),
          ],
          unmatched: [],
        );
        // coverage = 1.0, has is-spicy

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(
          result.tags,
          isNot(contains('mild')),
          reason: 'mild should NOT be present when spicy ingredients exist',
        );
        expect(result.tags, contains('stark'));
      });

      test('threshold constant should be 0.80', () {
        // Verify the threshold value is correct
        expect(
          TaggingThresholds.mildCoverageThreshold,
          0.80,
          reason: 'mildCoverageThreshold should be 80%',
        );
      });
    });

    group('stark (spicy) tag', () {
      test('should add stark when is-spicy present and coverage >= 50%', () {
        // Arrange
        final recipe = RecipeBuilder().withTitle('Spicy Curry').withIngredients(
          ['chili', 'chicken'],
        ).build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('chili', 'spice', {'is-spicy'}),
            TaggingTestHelper.ingredient('chicken', 'protein/meat/poultry', {
              'meat',
            }),
          ],
          unmatched: [],
        );

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(result.tags, contains('stark'));
        expect(result.tags, isNot(contains('mild')));
      });

      test('should NOT add stark when is-spicy present but coverage < 50%', () {
        // Arrange: 1 out of 3 matched (33%), has spicy
        final recipe = RecipeBuilder()
            .withTitle('Unknown Dish')
            .withIngredients(['chili', 'unknown1', 'unknown2'])
            .build();

        final lookup = IngredientLookupResult.fromLists(
          matched: [
            TaggingTestHelper.ingredient('chili', 'spice', {'is-spicy'}),
          ],
          unmatched: ['unknown1', 'unknown2'],
        );
        // coverage = 1/3 = 0.33

        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        // Act
        final result = phase2.calculate(phase1, recipe);

        // Assert
        expect(
          result.tags,
          isNot(contains('stark')),
          reason:
              'stark should not be added at 33% coverage (below 50% threshold)',
        );
        expect(
          result.tags,
          isNot(contains('mild')),
          reason:
              'mild should not be added either (coverage below 80% threshold)',
        );
      });
    });

    group('dish type derived tags', () {
      test('should add pasta-dish when pastabaserad is in Phase 1', () {
        final recipe = RecipeBuilder().withTitle('Pasta').withIngredients([
          'pasta',
        ]).build();

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {'pastabaserad'},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        expect(result.tags, contains('pasta-dish'));
      });

      test('should add rice-dish when risbaserad is in Phase 1', () {
        final recipe = RecipeBuilder().withTitle('Rice Bowl').withIngredients([
          'rice',
        ]).build();

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {'risbaserad'},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        expect(result.tags, contains('rice-dish'));
      });

      test('should add potato-dish when potatisbaserad is in Phase 1', () {
        final recipe = RecipeBuilder()
            .withTitle('Potatisgratang')
            .withIngredients(['potatis'])
            .build();

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {'potatisbaserad'},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        expect(result.tags, contains('potato-dish'));
      });
    });

    group('few ingredients tag', () {
      test('should add få-ingredienser when 6 or fewer ingredients', () {
        final recipe = RecipeBuilder().withTitle('Simple').withIngredients([
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
        ]).build(); // 6 items

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        expect(result.tags, contains('få-ingredienser'));
      });

      test('should NOT add få-ingredienser when more than 6 ingredients', () {
        final recipe = RecipeBuilder().withTitle('Complex').withIngredients([
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
          'g',
        ]).build(); // 7 items

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        expect(result.tags, isNot(contains('få-ingredienser')));
      });
    });

    group('allTags combines Phase 1 and Phase 2', () {
      test('should include tags from both phases', () {
        final recipe = RecipeBuilder().withTitle('Pasta').withIngredients([
          'pasta',
          'tomat',
        ]).build();

        final lookup = _createMinimalLookup();
        final phase1 = Phase1Result(
          tags: {'pastabaserad', 'under-30-min'},
          allergenStatus: {},
          dietaryStatus: {},
          lookup: lookup,
        );

        final result = phase2.calculate(phase1, recipe);

        // Phase 2 should have pasta-dish
        expect(result.tags, contains('pasta-dish'));
        // Combined tags should include Phase 1 tags
        expect(result.allTags, contains('pastabaserad'));
        expect(result.allTags, contains('under-30-min'));
        expect(result.allTags, contains('pasta-dish'));
      });
    });
  });
}

// Helper functions

IngredientLookupResult _createMinimalLookup() {
  return IngredientLookupResult.fromLists(
    matched: [
      const IngredientData(
        id: 'test',
        swedish: 'Test',
        english: 'Test',
        group: 'test',
        properties: {},
      ),
    ],
    unmatched: [],
  );
}
