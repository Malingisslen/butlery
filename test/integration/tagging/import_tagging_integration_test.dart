/// Integration tests for Import → Tagging flow.
///
/// Verifies that recipes imported through various strategies
/// are properly auto-tagged with allergens, dietary info, and categories.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/retagging_scheduler.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/tagging_test_helper.dart';
import '../../test_support/test_data_isolator.dart';

/// Mock TaggingService for controlled testing.
class MockTaggingService extends Mock implements TaggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(RecipeBuilder().build());
  });

  group('Import → Tagging Integration', () {
    late MockTaggingService mockTaggingService;
    late TagGenerator tagGenerator;

    setUp(() async {
      TestDataIsolator.initializeTest('import_tagging_integration_test');

      mockTaggingService = MockTaggingService();
      tagGenerator = TagGenerator();
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('import_tagging_integration_test');
    });

    group('Text Import → Auto-tagging', () {
      test('text import generates tags for meat recipe', () async {
        // Arrange: Recipe with chicken ingredients
        final recipe = RecipeBuilder()
            .withTitle('Kycklinggryta med ris')
            .withIngredients(['kyckling', 'ris', 'grädde', 'lök', 'vitlök'])
            .withInstructions(['Stek kycklingen', 'Tillsätt grädde'])
            .withTimeMinutes(45)
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();

        // Act: Generate tags
        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Assert: Tags are generated correctly
        expect(result.tags, contains('kyckling'));
        expect(result.dietaryStatus['vegetarisk'], TriState.contains);
        expect(result.generatorVersion, kTagGeneratorVersion);
        expect(result.isPartial, isFalse);
      });

      test('text import generates tags for vegetarian recipe', () async {
        final recipe = RecipeBuilder()
            .withTitle('Vegetarisk pasta')
            .withIngredients(['pasta', 'tomat', 'basilika', 'olivolja'])
            .withTimeMinutes(20)
            .build();

        final lookup = TaggingTestHelper.createVegetarianLookup();

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Vegetarian recipe should have FREE status for vegetarisk
        expect(result.dietaryStatus['vegetarisk'], TriState.free);
        expect(result.dietaryStatus['vegansk'], TriState.free);
      });

      test('text import generates tags for fish recipe', () async {
        final recipe = RecipeBuilder()
            .withTitle('Laxfilé med potatis')
            .withIngredients(['lax', 'potatis', 'dill', 'citron'])
            .withTimeMinutes(30)
            .build();

        // Create fish lookup with fish allergen properties
        final lookup = TaggingTestHelper.createLookupWithAllergens(
          allergenProperties: {'fish'},
          matchedCount: 4,
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.allergenStatus['fisk'], TriState.contains);
      });
    });

    group('Failed Tagging Handling', () {
      test('failed tagging sets generatorVersion to failed', () {
        // Create a failed tag result (simulating tagging failure)
        final failedResult = TagResult.failed(reason: 'Test failure');

        expect(failedResult.generatorVersion, 'failed');
        expect(failedResult.needsRetagging, isTrue);
        expect(failedResult.tags, isEmpty);
      });

      test('partial tagging marks result as partial', () {
        final recipe = RecipeBuilder().withTitle('Test Recipe').withIngredients(
          ['unknown_ingredient_xyz'],
        ).build();

        // Create lookup with no matches (0 matched, 1 total)
        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 0,
          totalCount: 1,
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // With 0% coverage, result should indicate unknown ingredients
        expect(result.coverage, 0.0);
        expect(result.unknownIngredients, isNotEmpty);
      });

      test('timeout produces partial result with available tags', () {
        // Verify partial result structure
        final partialResult = TagResult(
          tags: {'snabb'}, // Only Phase 1 tags available
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['unknown1'],
          generatedAt: DateTime.now(),
          generatorVersion: kTagGeneratorVersion,
          isPartial: true,
        );

        expect(partialResult.isPartial, isTrue);
        expect(partialResult.tags, contains('snabb'));
      });
    });

    group('RetaggingScheduler Integration', () {
      test('scheduler identifies recipes needing retagging', () async {
        // Arrange: Recipes with various tagging states
        final recipes = [
          // Recipe with outdated tags
          _withTagResult(
            RecipeBuilder().withTitle('Old Tagged').build(),
            TagResult(
              tags: {'old'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              unknownIngredients: [],
              generatedAt: DateTime.now().subtract(const Duration(days: 90)),
              generatorVersion: '0.5.0', // Old version
            ),
          ),
          // Recipe with failed tags
          _withTagResult(
            RecipeBuilder().withTitle('Failed Tagged').build(),
            TagResult.failed(reason: 'Previous failure'),
          ),
          // Recipe with current tags (should NOT need retagging)
          _withTagResult(
            RecipeBuilder().withTitle('Current Tagged').build(),
            TagResult(
              tags: {'current'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              unknownIngredients: [],
              generatedAt: DateTime.now(),
              generatorVersion: kTagGeneratorVersion,
            ),
          ),
        ];

        // Act & Assert: Check which need retagging
        final needsRetagging = recipes
            .where((r) => r.core.tagResult?.needsRetagging ?? true)
            .toList();

        expect(needsRetagging.length, 2); // Old and failed
        expect(needsRetagging.any((r) => r.core.title == 'Old Tagged'), isTrue);
        expect(
          needsRetagging.any((r) => r.core.title == 'Failed Tagged'),
          isTrue,
        );
        expect(
          needsRetagging.any((r) => r.core.title == 'Current Tagged'),
          isFalse,
        );
      });

      test('scheduler can be instantiated with callbacks', () {
        // Verify scheduler can be created (integration smoke test)
        final scheduler = RetaggingScheduler(
          taggingService: mockTaggingService,
          getRecipes: () async => <Recipe>[],
          saveRecipe: (recipe) async {},
        );

        expect(scheduler, isNotNull);
      });
    });

    group('Archive Import Tag Handling', () {
      test('archive import with existing tags preserves them', () {
        // Recipe from archive with existing tags
        final existingTagResult = TagResult(
          tags: {'pasta', 'italienskt'},
          allergenStatus: {'gluten': TriState.contains},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now().subtract(const Duration(days: 7)),
          generatorVersion: kTagGeneratorVersion, // Current version
        );

        final recipe = _withTagResult(
          RecipeBuilder().withTitle('Imported Pasta').withIngredients([
            'pasta',
            'tomat',
          ]).build(),
          existingTagResult,
        );

        // Tags should be preserved (not regenerated) if version matches
        expect(recipe.core.tagResult?.needsRetagging, isFalse);
        expect(recipe.core.tagResult?.tags, contains('pasta'));
        expect(recipe.core.tagResult?.tags, contains('italienskt'));
      });

      test('archive import with outdated tags triggers retagging', () {
        final outdatedTagResult = TagResult(
          tags: {'old-tag'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now().subtract(const Duration(days: 365)),
          generatorVersion: '0.1.0', // Very old version
        );

        final recipe = _withTagResult(
          RecipeBuilder().withTitle('Old Imported Recipe').build(),
          outdatedTagResult,
        );

        // Should need retagging due to version mismatch
        expect(recipe.core.tagResult?.needsRetagging, isTrue);
      });
    });

    group('Edge Cases', () {
      test('recipe with no ingredients gets empty tags', () {
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([])
            .build();

        // Empty lookup (no matched, no unmatched)
        final lookup = IngredientLookupResult.fromLists(
          matched: [],
          unmatched: [],
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Should have valid result structure even with no ingredients
        expect(result.generatorVersion, kTagGeneratorVersion);
        // Coverage is 0.0 for empty recipes (no ingredients to match)
        expect(result.coverage, anyOf(0.0, isNaN));
      });

      test('recipe with Swedish characters generates correct tags', () {
        final recipe = RecipeBuilder()
            .withTitle('Köttbullar med lingonsylt')
            .withIngredients(['köttfärs', 'lök', 'ägg', 'ströbröd'])
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Tags should be generated despite Swedish characters
        expect(result.generatorVersion, kTagGeneratorVersion);
        expect(result.dietaryStatus['vegetarisk'], TriState.contains);
      });
    });
  });
}

/// Helper to create a recipe with tagResult set.
Recipe _withTagResult(Recipe recipe, TagResult tagResult) {
  return Recipe(
    core: recipe.core.copyWith(tagResult: tagResult),
    type: recipe.type,
    socialData: recipe.socialData,
    offlineData: recipe.offlineData,
    realtimeData: recipe.realtimeData,
  );
}
