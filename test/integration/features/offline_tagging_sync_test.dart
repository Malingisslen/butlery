/// Integration tests for offline tagging sync workflow.
///
/// Tests the flow of saving recipes offline with tags
/// and the sync queue behavior for tag operations.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/tagging_test_helper.dart';
import '../../test_support/test_data_isolator.dart';

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
  group('Offline Tagging Sync', () {
    late TagGenerator tagGenerator;

    setUp(() async {
      TestDataIsolator.initializeTest('offline_tagging_sync_test');
      tagGenerator = TagGenerator();
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('offline_tagging_sync_test');
    });

    group('Offline Tag Generation', () {
      test('tags can be generated while offline', () {
        final recipe = RecipeBuilder()
            .withTitle('Offline Recipe')
            .withIngredients(['kyckling', 'ris', 'grönsaker'])
            .withTimeMinutes(30)
            .needsSync()
            .build();

        expect(recipe.offlineData?.isModifiedOffline, isTrue);

        final lookup = TaggingTestHelper.createMeatLookup();
        final tagResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(tagResult.tags, isNotEmpty);
        expect(tagResult.dietaryStatus['vegetarisk'], TriState.contains);
      });

      test('pending tag result marks recipe for future tagging', () {
        final pendingResult = TagResult.pending();

        expect(pendingResult.isPending, isTrue);
        expect(pendingResult.needsRetagging, isTrue);
        expect(pendingResult.generatorVersion, 'pending');
      });

      test('recipe with pending tags gets real tags when synced', () {
        // Simulate offline state - recipe created with pending tags
        final pendingResult = TagResult.pending();
        final recipe = _withTagResult(
          RecipeBuilder()
              .withTitle('Pending Recipe')
              .withIngredients(['pasta', 'tomat', 'basilika'])
              .withTimeMinutes(20)
              .needsSync()
              .build(),
          pendingResult,
        );

        expect(recipe.core.tagResult!.isPending, isTrue);

        // Simulate sync - generate real tags
        final lookup = TaggingTestHelper.createGlutenLookup();
        final syncedResult = tagGenerator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(syncedResult.isPending, isFalse);
        expect(syncedResult.generatorVersion, kTagGeneratorVersion);
        expect(syncedResult.allergenStatus['gluten'], TriState.contains);
      });
    });

    group('Sync Queue Operations', () {
      test('SyncOperation.tag enum value exists', () {
        expect(SyncOperation.values, contains(SyncOperation.tag));
      });

      test('tag operation is distinct from other operations', () {
        expect(SyncOperation.tag, isNot(SyncOperation.create));
        expect(SyncOperation.tag, isNot(SyncOperation.update));
        expect(SyncOperation.tag, isNot(SyncOperation.delete));
      });

      test('all sync operations are defined', () {
        expect(SyncOperation.values.length, greaterThanOrEqualTo(4));
        expect(
          SyncOperation.values,
          containsAll([
            SyncOperation.create,
            SyncOperation.update,
            SyncOperation.delete,
            SyncOperation.tag,
          ]),
        );
      });
    });

    group('Offline to Online Transition', () {
      test('recipe preserves tags through offline data marking', () {
        final tagResult = TaggingTestHelper.createTagResult(
          tags: {'kyckling', 'under-30-min'},
          coverage: 1.0,
        );

        final offlineRecipe = _withTagResult(
          RecipeBuilder()
              .withTitle('Offline Chicken')
              .withIngredients(['kyckling', 'potatis'])
              .withTimeMinutes(25)
              .needsSync()
              .build(),
          tagResult,
        );

        // Verify offline state
        expect(offlineRecipe.offlineData?.isModifiedOffline, isTrue);

        // Verify tags preserved
        expect(offlineRecipe.core.tagResult!.tags, contains('kyckling'));
        expect(offlineRecipe.core.tagResult!.coverage, 1.0);
      });

      test('synced recipe clears offline flag but keeps tags', () {
        final tagResult = TaggingTestHelper.createTagResult(
          tags: {'pasta', 'snabb'},
        );

        final offlineRecipe = _withTagResult(
          RecipeBuilder()
              .withId('recipe-to-sync')
              .withTitle('Quick Pasta')
              .needsSync()
              .build(),
          tagResult,
        );

        // Simulate sync by creating "synced" version
        final syncedRecipe = Recipe(
          core: offlineRecipe.core,
          type: offlineRecipe.type,
          offlineData: const RecipeOfflineData(
            isModifiedOffline: false,
            lastSyncedAt: null,
          ),
        );

        // Tags preserved
        expect(syncedRecipe.core.tagResult!.tags, tagResult.tags);
        // Offline flag cleared
        expect(syncedRecipe.offlineData?.isModifiedOffline, isFalse);
      });
    });

    group('Tag Result Serialization for Offline Storage', () {
      test('tagResult can be serialized to JSON for Drift storage', () {
        final tagResult = TagResult(
          tags: {'test-tag', 'another-tag'},
          allergenStatus: {
            'gluten': TriState.contains,
            'mjölk': TriState.free,
          },
          dietaryStatus: {
            'vegetarisk': TriState.free,
          },
          coverage: 0.85,
          unknownIngredients: ['mystery'],
          generatedAt: DateTime(2024, 1, 15),
          generatorVersion: '1.0.0',
        );

        // Serialize to Firestore format (also used for JSON)
        final json = tagResult.toFirestore();

        expect(json['tags'], contains('test-tag'));
        expect(json['allergenStatus']['gluten'], 'contains');
        expect(json['dietaryStatus']['vegetarisk'], 'free');
        expect(json['coverage'], 0.85);
        expect(json['generatorVersion'], '1.0.0');
      });

      test('tagResult can be deserialized from JSON', () {
        final json = {
          'tags': ['restored-tag'],
          'allergenStatus': {'ägg': 'UNKNOWN'},
          'dietaryStatus': {'vegansk': 'CONTAINS'},
          'coverage': 0.9,
          'unknownIngredients': ['spice'],
          'generatedAt': DateTime(2024, 1, 15).toIso8601String(),
          'generatorVersion': '1.0.0',
        };

        final restored = TagResult.fromFirestore(json);

        expect(restored.tags, contains('restored-tag'));
        expect(restored.allergenStatus['ägg'], TriState.unknown);
        expect(restored.coverage, 0.9);
      });
    });

    group('Batch Offline Sync', () {
      test('multiple offline recipes can queue tag operations', () {
        final recipes = TaggingTestHelper.createBatchRecipes(5);
        final tagResults = <TagResult>[];

        for (final recipe in recipes) {
          // Mark as offline
          final offlineRecipe = Recipe(
            core: recipe.core,
            type: recipe.type,
            offlineData: const RecipeOfflineData(isModifiedOffline: true),
          );

          expect(offlineRecipe.offlineData?.isModifiedOffline, isTrue);

          // Generate tags
          final lookup = TaggingTestHelper.createLookupWithCoverage(
            matchedCount: 4,
            totalCount: 5,
          );
          final result = tagGenerator.generate(
            ingredients: lookup,
            recipe: offlineRecipe,
          );

          tagResults.add(result);
        }

        // All should be valid tag results
        for (final result in tagResults) {
          expect(result.generatorVersion, kTagGeneratorVersion);
          expect(result.coverage, 0.8);
        }
      });
    });
  });
}
