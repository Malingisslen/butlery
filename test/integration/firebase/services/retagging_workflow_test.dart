/// Integration tests for the manual retagging workflow.
///
/// Tests version mismatch detection and retagging behavior.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';
import '../../../test_support/test_data_isolator.dart';

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

void main() {
  group('Retagging Workflow', () {
    late TagGenerator tagGenerator;

    setUp(() async {
      TestDataIsolator.initializeTest('retagging_workflow_test');
      tagGenerator = TagGenerator();
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('retagging_workflow_test');
    });

    group('needsRetagging detection', () {
      test('returns true for outdated generator version', () {
        final outdatedTagResult = TagResult(
          tags: {'old-tag'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now().subtract(const Duration(days: 30)),
          generatorVersion: '0.9.0', // Old version
        );

        expect(outdatedTagResult.needsRetagging, isTrue);
      });

      test('returns false for current generator version', () {
        final currentTagResult = TagResult(
          tags: {'current-tag'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: kTagGeneratorVersion,
        );

        expect(currentTagResult.needsRetagging, isFalse);
      });

      test('recipe with null tagResult needs tagging', () {
        final recipe = RecipeBuilder()
            .withTitle('Untagged Recipe')
            .withIngredients(['ingredient1', 'ingredient2'])
            .build();

        expect(recipe.core.tagResult, isNull);
      });
    });

    group('retagging behavior', () {
      test('retagging updates tags to current version', () {
        // Recipe with old tags
        final oldResult = TaggingTestHelper.createOutdatedTagResult();
        final recipe = _withTagResult(
          RecipeBuilder()
              .withTitle('Pasta Carbonara')
              .withIngredients(['pasta', 'bacon', 'ägg', 'parmesan'])
              .withTimeMinutes(20)
              .build(),
          oldResult,
        );

        expect(recipe.core.tagResult!.needsRetagging, isTrue);

        // Retag with current generator
        final lookup = TaggingTestHelper.createGlutenLookup();
        final newResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(newResult.generatorVersion, kTagGeneratorVersion);
        expect(newResult.needsRetagging, isFalse);
      });

      test('retagging preserves correct allergen detection', () {
        final recipe = RecipeBuilder()
            .withTitle('Gluten Pasta')
            .withIngredients(['pasta', 'tomat'])
            .withTimeMinutes(15)
            .build();

        final lookup = TaggingTestHelper.createGlutenLookup();
        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.allergenStatus['gluten'], TriState.contains);
        expect(result.tags, contains('pastabaserad'));
      });

      test('retagging updates dietary status correctly', () {
        // Recipe originally tagged as vegetarian, now with meat
        final oldResult = TagResult(
          tags: {'vegetarisk'},
          allergenStatus: {},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now().subtract(const Duration(days: 7)),
          generatorVersion: '0.9.0',
        );

        final recipe = _withTagResult(
          RecipeBuilder()
              .withTitle('Kyckling med ris')
              .withIngredients(['kyckling', 'ris', 'lök'])
              .withTimeMinutes(30)
              .build(),
          oldResult,
        );

        // Retag with meat ingredients
        final meatLookup = TaggingTestHelper.createMeatLookup();
        final newResult = tagGenerator.generate(
          ingredients: meatLookup,
          recipe: recipe,
        );

        // Should now be CONTAINS (not vegetarian)
        expect(newResult.dietaryStatus['vegetarisk'], TriState.contains);
      });
    });

    group('version comparison', () {
      test('different major version needs retagging', () {
        final result = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: '0.1.0',
        );

        expect(result.needsRetagging, isTrue);
      });

      test('same version does not need retagging', () {
        final result = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: kTagGeneratorVersion,
        );

        expect(result.needsRetagging, isFalse);
      });

      test('pending tag result needs retagging', () {
        final pending = TagResult.pending();

        expect(pending.needsRetagging, isTrue);
        expect(pending.isPending, isTrue);
      });
    });

    group('coverage impact on retagging', () {
      test('low coverage recipe still gets retagged correctly', () {
        final recipe = RecipeBuilder()
            .withTitle('Mystery Dish')
            .withIngredients(['known', 'unknown1', 'unknown2', 'unknown3'])
            .withTimeMinutes(30)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 1,
          totalCount: 4,
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.coverage, 0.25);
        expect(result.unknownIngredients.length, 3);
        expect(result.generatorVersion, kTagGeneratorVersion);
      });

      test('coverage affects allergen status as UNKNOWN', () {
        final recipe = RecipeBuilder()
            .withTitle('Partial Recipe')
            .withIngredients(['pasta', 'mystery sauce', 'unknown spice'])
            .withTimeMinutes(20)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 1,
          totalCount: 3,
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // With incomplete coverage, allergen status should be UNKNOWN
        expect(result.allergenStatus['gluten'], TriState.unknown);
        expect(result.dietaryStatus['vegetarisk'], TriState.unknown);
      });
    });

    group('batch retagging simulation', () {
      test('multiple recipes can be retagged in sequence', () {
        final recipes = TaggingTestHelper.createBatchRecipes(10);
        final results = <TagResult>[];

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          final result = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          results.add(result);
        }

        // All should have current version
        for (final result in results) {
          expect(result.generatorVersion, kTagGeneratorVersion);
          expect(result.needsRetagging, isFalse);
        }
      });

      test('retagging count matches recipes needing retag', () {
        final oldVersion = '0.9.0';
        final currentVersion = kTagGeneratorVersion;

        final tagResults = [
          TaggingTestHelper.createTagResult(generatorVersion: oldVersion),
          TaggingTestHelper.createTagResult(generatorVersion: currentVersion),
          TaggingTestHelper.createTagResult(generatorVersion: oldVersion),
          TaggingTestHelper.createTagResult(generatorVersion: currentVersion),
          TaggingTestHelper.createTagResult(generatorVersion: oldVersion),
        ];

        final needsRetag = tagResults.where((r) => r.needsRetagging).length;

        expect(needsRetag, 3);
      });
    });
  });
}
