/// Integration tests for Tagging Service
///
/// Tests the full recipe save → tag → store → read flow,
/// verifying that tag data persists correctly through Firestore.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
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
  group('Tagging Integration', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TagGenerator tagGenerator;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;

    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';

    setUp(() async {
      TestDataIsolator.initializeTest('tagging_integration_test');

      fakeFirestore = FakeFirebaseFirestore();
      tagGenerator = TagGenerator();

      mockUser = auth_mocks.MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: 'Test User',
      );
      mockAuth = auth_mocks.MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('tagging_integration_test');
    });

    group('Tag Generation Flow', () {
      test('generates tags for recipe with meat ingredients', () {
        final recipe = RecipeBuilder()
            .withTitle('Kycklinggryta')
            .withIngredients(['kyckling', 'potatis', 'grädde', 'lök'])
            .withTimeMinutes(45)
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.tags, contains('kyckling'));
        expect(result.dietaryStatus['vegetarisk'], TriState.contains);
        expect(result.coverage, 1.0);
        expect(result.generatorVersion, kTagGeneratorVersion);
      });

      test('generates tags for vegetarian recipe', () {
        final recipe = RecipeBuilder()
            .withTitle('Tofu Stir Fry')
            .withIngredients(['tofu', 'broccoli', 'ris', 'sojasås'])
            .withTimeMinutes(25)
            .build();

        final lookup = TaggingTestHelper.createVegetarianLookup();

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.dietaryStatus['vegetarisk'], TriState.free);
        expect(result.coverage, 1.0);
      });

      test('handles partial coverage correctly', () {
        final recipe = RecipeBuilder()
            .withTitle('Mystery Dish')
            .withIngredients(['known', 'unknown1', 'unknown2'])
            .withTimeMinutes(30)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 1,
          totalCount: 3,
        );

        final result = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.coverage, closeTo(0.333, 0.01));
        expect(result.unknownIngredients.length, 2);
        expect(result.dietaryStatus['vegetarisk'], TriState.unknown);
      });
    });

    group('Firestore Persistence', () {
      test('tag result persists through Firestore roundtrip', () async {
        final recipe = RecipeBuilder()
            .withId('recipe-1')
            .withTitle('Test Recipe')
            .withIngredients(['pasta', 'tomat'])
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createGlutenLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Save to Firestore
        final recipeWithTags = _withTagResult(recipe, tagResult);
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Read from Firestore
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restoredRecipe = Recipe.fromFirestore(doc);

        // Verify tag result preserved
        expect(restoredRecipe.core.tagResult, isNotNull);
        expect(restoredRecipe.core.tagResult!.tags, tagResult.tags);
        expect(restoredRecipe.core.tagResult!.coverage, tagResult.coverage);
        expect(
          restoredRecipe.core.tagResult!.allergenStatus['gluten'],
          TriState.contains,
        );
      });

      test('allergen tri-state values persist correctly', () async {
        final tagResult = TagResult(
          tags: {'pasta'},
          allergenStatus: {
            'gluten': TriState.contains,
            'mjölk': TriState.free,
            'ägg': TriState.unknown,
          },
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.contains,
          },
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: '1.0.0',
        );

        final recipe = _withTagResult(
          RecipeBuilder()
              .withId('recipe-allergens')
              .withCreatedBy(testUserId)
              .build(),
          tagResult,
        );

        // Save
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipe.toFirestore());

        // Read
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        final restoredTags = restored.core.tagResult!;

        // Verify all tri-state values
        expect(restoredTags.allergenStatus['gluten'], TriState.contains);
        expect(restoredTags.allergenStatus['mjölk'], TriState.free);
        expect(restoredTags.allergenStatus['ägg'], TriState.unknown);
        expect(restoredTags.dietaryStatus['vegetarisk'], TriState.free);
        expect(restoredTags.dietaryStatus['vegansk'], TriState.contains);
      });

      test('coverage percentage accurate after roundtrip', () async {
        final tagResult = TaggingTestHelper.createTagResult(
          coverage: 0.75,
          unknownIngredients: ['mystery1', 'mystery2'],
        );

        final recipe = _withTagResult(
          RecipeBuilder()
              .withId('recipe-coverage')
              .withCreatedBy(testUserId)
              .build(),
          tagResult,
        );

        // Save and read
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipe.toFirestore());

        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);

        expect(restored.core.tagResult!.coverage, 0.75);
        expect(restored.core.tagResult!.unknownIngredients.length, 2);
      });

      test('generator version persists for retagging detection', () async {
        final tagResult = TaggingTestHelper.createTagResult(
          generatorVersion: '0.9.0',
        );

        final recipe = _withTagResult(
          RecipeBuilder()
              .withId('recipe-version')
              .withCreatedBy(testUserId)
              .build(),
          tagResult,
        );

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipe.toFirestore());

        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);

        expect(restored.core.tagResult!.generatorVersion, '0.9.0');
        expect(restored.core.tagResult!.needsRetagging, isTrue);
      });
    });

    group('Recipe Update Flow', () {
      test('updating ingredients triggers new tags', () async {
        // Initial recipe with meat
        final recipe = RecipeBuilder()
            .withId('recipe-update')
            .withTitle('Dinner')
            .withIngredients(['kyckling', 'potatis'])
            .withCreatedBy(testUserId)
            .build();

        final meatLookup = TaggingTestHelper.createMeatLookup();
        final initialTags = tagGenerator.generate(
          ingredients: meatLookup,
          recipe: recipe,
        );

        expect(initialTags.dietaryStatus['vegetarisk'], TriState.contains);

        // Update to vegetarian
        final updatedRecipe = recipe.copyWith(
          title: 'Veggie Dinner',
          ingredients: ['tofu', 'broccoli', 'ris'],
        );

        final veggieLookup = TaggingTestHelper.createVegetarianLookup();
        final updatedTags = tagGenerator.generate(
          ingredients: veggieLookup,
          recipe: updatedRecipe,
        );

        expect(updatedTags.dietaryStatus['vegetarisk'], TriState.free);
      });
    });

    group('Multiple Recipe Handling', () {
      test('each recipe gets independent tag results', () async {
        final recipes = TaggingTestHelper.createBatchRecipes(5);

        for (var i = 0; i < recipes.length; i++) {
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 3 + i,
            totalCount: 5 + i,
          );

          final tagResult = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipes[i],
          );

          final recipeWithTags = _withTagResult(recipes[i], tagResult);

          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipes[i].id)
              .set(recipeWithTags.toFirestore());
        }

        // Verify each recipe has correct independent data
        final snapshot = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .get();

        expect(snapshot.docs.length, 5);

        for (final doc in snapshot.docs) {
          final restored = Recipe.fromFirestore(doc);
          expect(restored.core.tagResult, isNotNull);
          expect(restored.core.tagResult!.coverage, greaterThan(0));
        }
      });
    });
  });
}
