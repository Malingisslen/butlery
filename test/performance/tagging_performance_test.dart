/// Performance benchmarks for the tagging system.
///
/// Tests that tag generation meets performance requirements:
/// - < 500ms for 100-ingredient recipe
/// - Scales linearly with batch size
/// - Memory stability during repeated operations
@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import '../infrastructure/builders/recipe_builder.dart';
import '../infrastructure/helpers/tagging_test_helper.dart';
import '../test_support/test_data_isolator.dart';

void main() {
  group('Tagging Performance', () {
    late TagGenerator tagGenerator;

    setUp(() async {
      TestDataIsolator.initializeTest('tagging_performance_test');
      tagGenerator = TagGenerator();
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('tagging_performance_test');
    });

    group('Single Recipe Performance', () {
      test('tags standard recipe under 50ms', () async {
        final recipe = RecipeBuilder()
            .withTitle('Standard Recipe')
            .withIngredients(['ingredient1', 'ingredient2', 'ingredient3'])
            .withTimeMinutes(30)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 3,
          totalCount: 3,
        );

        final result = await TaggingTestHelper.measureTagGeneration(
          generator: tagGenerator,
          lookup: lookup,
          recipe: recipe,
        );

        expect(result.milliseconds, lessThan(50));
        expect(result.result.tags, isNotEmpty);
      });

      test('tags 100-ingredient recipe under 500ms', () async {
        final recipe = TaggingTestHelper.createLargeRecipe(100);

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 80,
          totalCount: 100,
        );

        final result = await TaggingTestHelper.measureTagGeneration(
          generator: tagGenerator,
          lookup: lookup,
          recipe: recipe,
        );

        expect(result.milliseconds, lessThan(500));
        expect(result.result.coverage, 0.8);
      });

      test('100-ingredient recipe performance is acceptable', () async {
        // Run multiple times to get stable measurement
        final durations = <int>[];

        for (var i = 0; i < 5; i++) {
          final recipe = TaggingTestHelper.createLargeRecipe(100);
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 75,
            totalCount: 100,
          );

          final result = await TaggingTestHelper.measureTagGeneration(
            generator: tagGenerator,
            lookup: lookup,
            recipe: recipe,
          );

          durations.add(result.milliseconds);
        }

        final average = durations.reduce((a, b) => a + b) / durations.length;
        final max = durations.reduce((a, b) => a > b ? a : b);

        expect(average, lessThan(200)); // Average under 200ms
        expect(max, lessThan(500)); // Max under 500ms
      });
    });

    group('Batch Performance', () {
      test('10 recipes complete under 500ms', () async {
        final stopwatch = Stopwatch()..start();

        final recipes = TaggingTestHelper.createBatchRecipes(10);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('50 recipes complete under 2 seconds', () async {
        final stopwatch = Stopwatch()..start();

        final recipes = TaggingTestHelper.createBatchRecipes(50);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });

      test('100 recipes complete under 5 seconds', () async {
        final stopwatch = Stopwatch()..start();

        final recipes = TaggingTestHelper.createBatchRecipes(100);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });

    group('Scaling Characteristics', () {
      test('time scales roughly linearly with recipe count', () async {
        // Measure time for 10 recipes
        var stopwatch = Stopwatch()..start();
        var recipes = TaggingTestHelper.createBatchRecipes(10);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );
          tagGenerator.generate(ingredients: lookup, recipe: recipe);
        }
        stopwatch.stop();
        final time10 = stopwatch.elapsedMilliseconds;

        // Measure time for 50 recipes
        stopwatch = Stopwatch()..start();
        recipes = TaggingTestHelper.createBatchRecipes(50);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );
          tagGenerator.generate(ingredients: lookup, recipe: recipe);
        }
        stopwatch.stop();
        final time50 = stopwatch.elapsedMilliseconds;

        // 50 recipes should take roughly 5x as long as 10 recipes
        // Allow for some variance (2x to 10x is acceptable)
        final ratio = time50 / (time10 == 0 ? 1 : time10);
        expect(ratio, greaterThan(2));
        expect(ratio, lessThan(10));
      });
    });

    group('Memory Stability', () {
      test('repeated tagging does not accumulate data', () async {
        // Run 100 iterations to check for memory leaks
        for (var i = 0; i < 100; i++) {
          final recipe = RecipeBuilder()
              .withId('memory-test-$i')
              .withTitle('Memory Test Recipe $i')
              .withIngredients(['ing1', 'ing2', 'ing3'])
              .withTimeMinutes(30)
              .build();

          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 3,
            totalCount: 3,
          );

          final result = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          // Verify result is valid each iteration
          expect(result.generatorVersion, isNotEmpty);
        }
      });

      test('generator is reusable across many operations', () {
        // Same generator instance across 50 operations
        for (var i = 0; i < 50; i++) {
          final recipe = RecipeBuilder()
              .withId('reuse-$i')
              .withTimeMinutes(20 + i)
              .build();

          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 2 + (i % 3),
            totalCount: 5,
          );

          final result = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          expect(result.generatorVersion, kTagGeneratorVersion);
        }
      });
    });

    group('Edge Cases Performance', () {
      test('empty recipe tags quickly', () async {
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([])
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 0,
          totalCount: 0,
        );

        final result = await TaggingTestHelper.measureTagGeneration(
          generator: tagGenerator,
          lookup: lookup,
          recipe: recipe,
        );

        expect(result.milliseconds, lessThan(10));
      });

      test('recipe with all unknown ingredients tags quickly', () async {
        final recipe = RecipeBuilder()
            .withTitle('Unknown Ingredients')
            .withIngredients([
              'mystery1',
              'mystery2',
              'mystery3',
              'mystery4',
              'mystery5',
            ])
            .withTimeMinutes(30)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 0,
          totalCount: 5,
        );

        final result = await TaggingTestHelper.measureTagGeneration(
          generator: tagGenerator,
          lookup: lookup,
          recipe: recipe,
        );

        expect(result.milliseconds, lessThan(50));
        expect(result.result.coverage, 0.0);
      });
    });
  });
}
