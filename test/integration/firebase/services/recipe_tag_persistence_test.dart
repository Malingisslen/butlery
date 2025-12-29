/// Integration tests for Recipe Tag Persistence
///
/// Tests the complete recipe lifecycle with tag data:
/// - Create recipe with tags → persisted correctly
/// - Update recipe ingredients → tags regenerated
/// - Delete recipe → no orphaned tag data
/// - Schema compatibility and version handling
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
  group('Recipe Tag Persistence', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TagGenerator tagGenerator;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;

    const testUserId = 'test-user-456';
    const testUserEmail = 'test-persistence@example.com';

    setUp(() async {
      TestDataIsolator.initializeTest('recipe_tag_persistence_test');

      fakeFirestore = FakeFirebaseFirestore();
      tagGenerator = TagGenerator();

      mockUser = auth_mocks.MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: 'Test User',
      );
      mockAuth =
          auth_mocks.MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('recipe_tag_persistence_test');
    });

    group('Recipe Create with Tags', () {
      test('new recipe with complete tag data persists all fields', () async {
        // Create recipe with full tagging
        final recipe = RecipeBuilder()
            .withId('persist-recipe-1')
            .withTitle('Kycklingpasta')
            .withIngredients(['kyckling', 'pasta', 'grädde', 'vitlök'])
            .withTimeMinutes(30)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Add decision logs for H3 audit trail
        expect(tagResult.decisions, isNotNull);

        final recipeWithTags = _withTagResult(recipe, tagResult);

        // Persist to Firestore
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Verify persistence
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final data = doc.data()!;
        expect(data['core']['tagResult'], isNotNull);

        final persistedTags = data['core']['tagResult'];
        expect(persistedTags['tags'], isA<List>());
        expect(persistedTags['coverage'], equals(1.0));
        expect(persistedTags['generatorVersion'], equals(kTagGeneratorVersion));
        expect(persistedTags['allergenStatus'], isA<Map>());
        expect(persistedTags['dietaryStatus'], isA<Map>());
      });

      test('recipe with partial coverage persists unknown ingredients',
          () async {
        final recipe = RecipeBuilder()
            .withId('partial-recipe-1')
            .withTitle('Mystery Stew')
            .withIngredients(['known1', 'unknown1', 'unknown2', 'unknown3'])
            .withTimeMinutes(45)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 1,
          totalCount: 4,
        );

        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        final recipeWithTags = _withTagResult(recipe, tagResult);

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Verify unknown ingredients persisted
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.coverage, closeTo(0.25, 0.01));
        expect(restored.core.tagResult!.unknownIngredients.length, 3);
      });

      test('recipe with isPartial flag persists timeout state', () async {
        final recipe = RecipeBuilder()
            .withId('timeout-recipe-1')
            .withTitle('Timeout Recipe')
            .withIngredients(['pasta', 'tomat'])
            .withTimeMinutes(15)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createGlutenLookup();

        // Generate with zero timeout to trigger isPartial
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        expect(tagResult.isPartial, isTrue);

        final recipeWithTags = _withTagResult(recipe, tagResult);

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Verify isPartial persisted
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.isPartial, isTrue);
      });
    });

    group('Recipe Update with Tags', () {
      test('updating ingredients regenerates tags correctly', () async {
        // Create initial recipe with meat
        final initialRecipe = RecipeBuilder()
            .withId('update-recipe-1')
            .withTitle('Meat Dish')
            .withIngredients(['kyckling', 'potatis'])
            .withTimeMinutes(30)
            .withCreatedBy(testUserId)
            .build();

        final meatLookup = TaggingTestHelper.createMeatLookup();
        final initialTags = tagGenerator.generate(
          ingredients: meatLookup,
          recipe: initialRecipe,
        );

        expect(initialTags.dietaryStatus['vegetarisk'], TriState.contains);

        // Save initial
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(initialRecipe.id)
            .set(_withTagResult(initialRecipe, initialTags).toFirestore());

        // Update to vegetarian ingredients
        final updatedRecipe = initialRecipe.copyWith(
          title: 'Veggie Dish',
          ingredients: ['tofu', 'broccoli', 'ris'],
        );

        final vegLookup = TaggingTestHelper.createVegetarianLookup();
        final updatedTags = tagGenerator.generate(
          ingredients: vegLookup,
          recipe: updatedRecipe,
        );

        expect(updatedTags.dietaryStatus['vegetarisk'], TriState.free);

        // Update in Firestore
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(updatedRecipe.id)
            .set(_withTagResult(updatedRecipe, updatedTags).toFirestore());

        // Verify update persisted
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(updatedRecipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.dietaryStatus['vegetarisk'],
            TriState.free);
        expect(restored.title, 'Veggie Dish');
      });

      test('adding allergen ingredient updates allergen status', () async {
        // Start with allergen-free recipe
        final initialRecipe = RecipeBuilder()
            .withId('allergen-update-1')
            .withTitle('Plain Rice')
            .withIngredients(['ris', 'salt'])
            .withTimeMinutes(20)
            .withCreatedBy(testUserId)
            .build();

        final plainLookup = TaggingTestHelper.createVegetarianLookup();
        final initialTags = tagGenerator.generate(
          ingredients: plainLookup,
          recipe: initialRecipe,
        );

        // Save initial
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(initialRecipe.id)
            .set(_withTagResult(initialRecipe, initialTags).toFirestore());

        // Update to include gluten
        final updatedRecipe = initialRecipe.copyWith(
          ingredients: ['ris', 'pasta', 'salt'],
        );

        final glutenLookup = TaggingTestHelper.createGlutenLookup();
        final updatedTags = tagGenerator.generate(
          ingredients: glutenLookup,
          recipe: updatedRecipe,
        );

        expect(updatedTags.allergenStatus['gluten'], TriState.contains);

        // Update in Firestore
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(updatedRecipe.id)
            .set(_withTagResult(updatedRecipe, updatedTags).toFirestore());

        // Verify allergen status updated
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(updatedRecipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.allergenStatus['gluten'],
            TriState.contains);
      });

      test('coverage changes when ingredients become known', () async {
        // Start with partial coverage
        final initialRecipe = RecipeBuilder()
            .withId('coverage-update-1')
            .withTitle('Mystery Recipe')
            .withIngredients(['known', 'unknown1', 'unknown2'])
            .withTimeMinutes(25)
            .withCreatedBy(testUserId)
            .build();

        final partialLookup = TaggingTestHelper.createLookupWithCoverage(
          matchedCount: 1,
          totalCount: 3,
        );
        final initialTags = tagGenerator.generate(
          ingredients: partialLookup,
          recipe: initialRecipe,
        );

        expect(initialTags.coverage, closeTo(0.333, 0.01));

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(initialRecipe.id)
            .set(_withTagResult(initialRecipe, initialTags).toFirestore());

        // Update with all known ingredients
        final knownRecipe = initialRecipe.copyWith(
          ingredients: ['tofu', 'broccoli', 'ris'],
        );

        final fullLookup = TaggingTestHelper.createVegetarianLookup();
        final updatedTags = tagGenerator.generate(
          ingredients: fullLookup,
          recipe: knownRecipe,
        );

        expect(updatedTags.coverage, 1.0);

        // Update in Firestore
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(knownRecipe.id)
            .set(_withTagResult(knownRecipe, updatedTags).toFirestore());

        // Verify coverage updated
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(knownRecipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.coverage, 1.0);
        expect(restored.core.tagResult!.unknownIngredients, isEmpty);
      });
    });

    group('Recipe Delete - No Orphan Data', () {
      test('deleting recipe removes all tag data', () async {
        // Create recipe with tags
        final recipe = RecipeBuilder()
            .withId('delete-recipe-1')
            .withTitle('To Be Deleted')
            .withIngredients(['kyckling', 'pasta'])
            .withTimeMinutes(30)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        final recipeWithTags = _withTagResult(recipe, tagResult);

        // Save
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Verify exists
        var doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();
        expect(doc.exists, isTrue);

        // Delete
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .delete();

        // Verify deleted
        doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();
        expect(doc.exists, isFalse);
      });

      test('batch delete removes all recipes with tags', () async {
        // Create multiple recipes
        final recipeIds = <String>[];
        for (int i = 0; i < 5; i++) {
          final recipe = RecipeBuilder()
              .withId('batch-delete-$i')
              .withTitle('Recipe $i')
              .withIngredients(['pasta', 'tomat'])
              .withTimeMinutes(20)
              .withCreatedBy(testUserId)
              .build();

          final lookup = TaggingTestHelper.createGlutenLookup();
          final tagResult = tagGenerator.generate(
            ingredients: lookup,
            recipe: recipe,
          );

          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe.id)
              .set(_withTagResult(recipe, tagResult).toFirestore());

          recipeIds.add(recipe.id);
        }

        // Verify all exist
        var snapshot = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .get();
        expect(snapshot.docs.length, 5);

        // Batch delete
        final batch = fakeFirestore.batch();
        for (final id in recipeIds) {
          batch.delete(fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(id));
        }
        await batch.commit();

        // Verify all deleted
        snapshot = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .get();
        expect(snapshot.docs.length, 0);
      });
    });

    group('Schema Compatibility', () {
      test('recipe with missing tagResult fields deserializes safely',
          () async {
        // Simulate old schema data with minimal tagResult
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('legacy-recipe-1')
            .set({
          'core': {
            'id': 'legacy-recipe-1',
            'title': 'Legacy Recipe',
            'createdBy': testUserId,
            'tagResult': {
              'tags': ['old-tag'],
              'coverage': 0.5,
              'generatorVersion': '0.5.0',
              // Missing: allergenStatus, dietaryStatus, decisions
            },
          },
          'type': 0, // RecipeType.personal.index
        });

        // Should deserialize without error
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('legacy-recipe-1')
            .get();

        final recipe = Recipe.fromFirestore(doc);
        expect(recipe.core.tagResult, isNotNull);
        expect(recipe.core.tagResult!.coverage, 0.5);
        expect(recipe.core.tagResult!.needsRetagging, isTrue);
      });

      test('recipe with null tagResult handles gracefully', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('no-tags-recipe')
            .set({
          'core': {
            'id': 'no-tags-recipe',
            'title': 'Untagged Recipe',
            'createdBy': testUserId,
            // No tagResult field at all
          },
          'type': 0, // RecipeType.personal.index
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('no-tags-recipe')
            .get();

        final recipe = Recipe.fromFirestore(doc);
        expect(recipe.core.tagResult, isNull);
      });

      test('needsRetagging detected on version mismatch after read', () async {
        // Save with old version
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('old-version-recipe')
            .set({
          'core': {
            'id': 'old-version-recipe',
            'title': 'Old Version Recipe',
            'createdBy': testUserId,
            'tagResult': {
              'tags': ['pasta'],
              'allergenStatus': {'gluten': 'contains'},
              'dietaryStatus': {},
              'coverage': 1.0,
              'unknownIngredients': [],
              'generatedAt': DateTime.now().toIso8601String(),
              'generatorVersion': '0.9.0', // Old version
            },
          },
          'type': 0, // RecipeType.personal.index
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('old-version-recipe')
            .get();

        final recipe = Recipe.fromFirestore(doc);
        expect(recipe.core.tagResult!.needsRetagging, isTrue);
        expect(recipe.core.tagResult!.generatorVersion, '0.9.0');
      });
    });

    group('Decision Audit Trail (H3)', () {
      test('allergen status persists through roundtrip with gluten', () async {
        // Use gluten lookup which has allergen properties
        final recipe = RecipeBuilder()
            .withId('audit-recipe-1')
            .withTitle('Pasta Recipe')
            .withIngredients(['pasta', 'tomat'])
            .withTimeMinutes(25)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createGlutenLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Verify allergen was detected
        expect(tagResult.allergenStatus['gluten'], TriState.contains);

        final recipeWithTags = _withTagResult(recipe, tagResult);

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Read back and verify allergen status preserved
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.allergenStatus['gluten'],
            TriState.contains);
      });

      test('dietary status persists through roundtrip', () async {
        final recipe = RecipeBuilder()
            .withId('audit-recipe-2')
            .withTitle('Meat Recipe')
            .withIngredients(['kyckling', 'potatis'])
            .withTimeMinutes(30)
            .withCreatedBy(testUserId)
            .build();

        final lookup = TaggingTestHelper.createMeatLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Verify dietary status was detected
        expect(tagResult.dietaryStatus['vegetarisk'], TriState.contains);

        final recipeWithTags = _withTagResult(recipe, tagResult);

        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .set(recipeWithTags.toFirestore());

        // Read back
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc(recipe.id)
            .get();

        final restored = Recipe.fromFirestore(doc);
        expect(restored.core.tagResult!.dietaryStatus['vegetarisk'],
            TriState.contains);
      });
    });
  });
}
