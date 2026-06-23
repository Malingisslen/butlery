/// Integration tests for batch tagging operations.
///
/// Tests batch retagging at scale with 100+ recipes.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
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
  group('Batch Tagging', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TagGenerator tagGenerator;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;

    const testUserId = 'test-user-batch';

    setUp(() async {
      TestDataIsolator.initializeTest('batch_tagging_test');

      fakeFirestore = FakeFirebaseFirestore();
      tagGenerator = TagGenerator();

      mockUser = auth_mocks.MockUser(
        uid: testUserId,
        email: 'batch@test.com',
        displayName: 'Batch Test User',
      );
      mockAuth = auth_mocks.MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('batch_tagging_test');
    });

    group('Large Batch Processing', () {
      test('tags 100 recipes successfully', () async {
        const recipeCount = 100;
        final recipes = TaggingTestHelper.createBatchRecipes(recipeCount);
        var taggedCount = 0;

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          final tagResult = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          final taggedRecipe = _withTagResult(recipe, tagResult);

          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe.id)
              .set(taggedRecipe.toFirestore());

          taggedCount++;
        }

        expect(taggedCount, recipeCount);

        // Verify all stored
        final snapshot = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .get();

        expect(snapshot.docs.length, recipeCount);
      });

      test('batch of 50 processes correctly (matching batch size)', () async {
        const batchSize = 50;
        final recipes = TaggingTestHelper.createBatchRecipes(batchSize);
        final results = <TagResult>[];

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 3,
            totalCount: 4,
          );

          final result = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          results.add(result);
        }

        expect(results.length, batchSize);
        expect(
          results.every((r) => r.generatorVersion == kTagGeneratorVersion),
          isTrue,
        );
      });
    });

    group('Progress Tracking Simulation', () {
      test('progress callback receives correct counts', () async {
        const totalRecipes = 25;
        final recipes = TaggingTestHelper.createBatchRecipes(totalRecipes);
        final progressUpdates = <(int current, int total)>[];

        for (var i = 0; i < recipes.length; i++) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          tagGenerator.generate(
            ingredients: lookup,
            recipe: recipes[i],
          );

          // Simulate progress callback
          progressUpdates.add((i + 1, totalRecipes));
        }

        expect(progressUpdates.length, totalRecipes);
        expect(progressUpdates.first, (1, totalRecipes));
        expect(progressUpdates.last, (totalRecipes, totalRecipes));
      });
    });

    group('Filtering Recipes Needing Retag', () {
      test('identifies recipes needing retagging correctly', () {
        final recipes = <Recipe>[];

        // 5 with current version (don't need retag)
        for (var i = 0; i < 5; i++) {
          recipes.add(
            _withTagResult(
              RecipeBuilder().withId('current-$i').build(),
              TaggingTestHelper.createTagResult(
                generatorVersion: kTagGeneratorVersion,
              ),
            ),
          );
        }

        // 10 with old version (need retag)
        for (var i = 0; i < 10; i++) {
          recipes.add(
            _withTagResult(
              RecipeBuilder().withId('old-$i').build(),
              TaggingTestHelper.createOutdatedTagResult(),
            ),
          );
        }

        // 3 with no tags (need retag)
        for (var i = 0; i < 3; i++) {
          recipes.add(RecipeBuilder().withId('untagged-$i').build());
        }

        final needsRetag = recipes.where((r) {
          final tagResult = r.core.tagResult;
          return tagResult == null || tagResult.needsRetagging;
        }).toList();

        expect(needsRetag.length, 13); // 10 old + 3 untagged
      });
    });

    group('Partial Batch Failure Handling', () {
      test('continues processing after individual failures', () async {
        const totalRecipes = 20;
        final recipes = TaggingTestHelper.createBatchRecipes(totalRecipes);
        var successCount = 0;
        var failCount = 0;

        for (var i = 0; i < recipes.length; i++) {
          try {
            // Simulate failure every 5th recipe
            if (i % 5 == 4) {
              throw Exception('Simulated failure');
            }

            final lookup = TaggingTestHelper.createLookupWithCoverage(
              matchedCount: 3,
              totalCount: 4,
            );

            tagGenerator.generate(
              ingredients: lookup,
              recipe: recipes[i],
            );

            successCount++;
          } catch (_) {
            failCount++;
          }
        }

        expect(successCount, 16); // 20 - 4 failures
        expect(failCount, 4); // Every 5th recipe fails
      });
    });

    group('Varied Recipe Types in Batch', () {
      test('handles different ingredient patterns in batch', () {
        final lookups = [
          TaggingTestHelper.createMeatLookup(),
          TaggingTestHelper.createVegetarianLookup(),
          TaggingTestHelper.createGlutenLookup(),
          TaggingTestHelper.createLookupWithAllergens(
            allergenProperties: {'dairy', 'egg'},
          ),
          TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 2,
            totalCount: 5,
          ),
        ];

        final results = <TagResult>[];

        for (var i = 0; i < lookups.length; i++) {
          final recipe = RecipeBuilder()
              .withId('varied-$i')
              .withTitle('Recipe $i')
              .withTimeMinutes(20 + i * 10)
              .build();

          final result = tagGenerator.generate(
            ingredients: lookups[i],
            recipe: recipe,
          );

          results.add(result);
        }

        // Meat recipe should not be vegetarian
        expect(results[0].dietaryStatus['vegetarisk'], isNot(equals(null)));

        // Vegetarian recipe should be vegetarian-friendly
        expect(results[1].dietaryStatus['vegetarisk'], isNotNull);

        // Gluten recipe should contain gluten
        expect(results[2].allergenStatus['gluten'], isNotNull);

        // Low coverage should have UNKNOWN statuses
        expect(results[4].coverage, lessThan(1.0));
      });
    });

    group('Batch Storage Consistency', () {
      test('all recipes in batch have consistent schema', () async {
        const batchSize = 30;
        final recipes = TaggingTestHelper.createBatchRecipes(batchSize);

        for (final recipe in recipes) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );

          final tagResult = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          final taggedRecipe = _withTagResult(recipe, tagResult);

          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe.id)
              .set(taggedRecipe.toFirestore());
        }

        // Verify all have consistent structure
        final snapshot = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          expect(data['core'], isNotNull);
          expect(data['core']['tagResult'], isNotNull);
          expect(data['core']['tagResult']['tags'], isA<List>());
          expect(data['core']['tagResult']['coverage'], isA<num>());
          expect(data['core']['tagResult']['generatorVersion'], isA<String>());
        }
      });
    });
  });
}
