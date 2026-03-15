import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/retagging_scheduler.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

class MockTaggingService extends Mock implements TaggingService {}

void main() {
  late MockTaggingService mockTaggingService;
  late List<Recipe> recipes;
  late Map<String, Recipe> savedRecipes;
  late RetaggingScheduler scheduler;

  /// Helper: creates a recipe with the given id and tagResult.
  Recipe buildRecipe({required String id, TagResult? tagResult}) {
    final builder = RecipeBuilder()
        .withId(id)
        .withTitle('Recipe $id')
        .withIngredients(['tomat', 'lök']);
    if (tagResult != null) {
      builder.withTagResult(tagResult);
    }
    return builder.build();
  }

  /// Helper: creates a successful TagResult that should NOT trigger retagging.
  TagResult successTagResult() {
    return TagResult(
      tags: {'middag', 'kyckling'},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.85,
      generatedAt: DateTime.now(),
      generatorVersion: kTagGeneratorVersion,
    );
  }

  /// Helper: creates a TagResult marked as failed.
  TagResult failedTagResult() {
    return TagResult.failed(reason: 'Test failure');
  }

  /// Helper: creates a TagResult for lookup timeout.
  TagResult lookupTimeoutTagResult() {
    return TagResult(
      tags: {'timeout-warning'},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 0.0,
      unknownIngredients: ['tomat', 'lök'],
      generatedAt: DateTime.now(),
      generatorVersion: 'lookup_timeout',
      isPartial: true,
      errorReason: 'Ingredient lookup timed out',
    );
  }

  setUp(() {
    mockTaggingService = MockTaggingService();
    recipes = [];
    savedRecipes = {};

    scheduler = RetaggingScheduler(
      taggingService: mockTaggingService,
      getRecipes: () async => recipes,
      saveRecipe: (recipe) async {
        savedRecipes[recipe.id] = recipe;
      },
    );
  });

  setUpAll(() {
    registerFallbackValue(RecipeBuilder().build());
  });

  tearDown(() {
    scheduler.dispose();
  });

  group('RetaggingScheduler', () {
    group('normal retagging flow', () {
      test('should retag recipes with failed tagResult', () async {
        final recipe = buildRecipe(
          id: 'failed-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        final successResult = successTagResult();
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successResult);

        final count = await scheduler.triggerManualRetagging();

        expect(count, 1);
        expect(savedRecipes.containsKey('failed-1'), isTrue);
        verify(() => mockTaggingService.generateTags(any())).called(1);
      });

      test('should retag recipes with null tagResult', () async {
        final recipe = buildRecipe(id: 'null-tags', tagResult: null);
        recipes = [recipe];

        final successResult = successTagResult();
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successResult);

        final count = await scheduler.triggerManualRetagging();

        expect(count, 1);
        expect(savedRecipes.containsKey('null-tags'), isTrue);
      });

      test('should retag recipes with lookup timeout tagResult', () async {
        final recipe = buildRecipe(
          id: 'timeout-1',
          tagResult: lookupTimeoutTagResult(),
        );
        recipes = [recipe];

        final successResult = successTagResult();
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successResult);

        final count = await scheduler.triggerManualRetagging();

        expect(count, 1);
        expect(savedRecipes.containsKey('timeout-1'), isTrue);
      });

      test('should skip recipes with up-to-date tags', () async {
        final recipe = buildRecipe(
          id: 'good-1',
          tagResult: successTagResult(),
        );
        recipes = [recipe];

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
        expect(savedRecipes.isEmpty, isTrue);
        verifyNever(() => mockTaggingService.generateTags(any()));
      });

      test('should skip recipes with allUnknown tagResult', () async {
        final recipe = buildRecipe(
          id: 'unknown-1',
          tagResult: TagResult.allUnknown(['mysterious ingredient']),
        );
        recipes = [recipe];

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
        verifyNever(() => mockTaggingService.generateTags(any()));
      });

      test('should return 0 when no recipes exist', () async {
        recipes = [];

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
      });
    });

    group('failure tracking', () {
      test('should skip recipe after 3 consecutive failures', () async {
        final recipe = buildRecipe(
          id: 'stubborn-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // generateTags returns a still-failed result every time
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => failedTagResult());

        // Attempt 1 — failure recorded (count becomes 1)
        await scheduler.triggerManualRetagging();
        // Attempt 2 — failure recorded (count becomes 2)
        await scheduler.triggerManualRetagging();
        // Attempt 3 — failure recorded (count becomes 3)
        await scheduler.triggerManualRetagging();

        // At this point the recipe has 3 failures, hitting the skip threshold.
        // Attempt 4 — _needsRetagging should return false, so generateTags
        // is NOT called again.
        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => failedTagResult());

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
        verifyNever(() => mockTaggingService.generateTags(any()));
      });

      test('should count null result from generateTags as failure', () async {
        final recipe = buildRecipe(
          id: 'null-result-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // generateTags returns null (service error)
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => null);

        // 3 failures via null returns
        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();

        // 4th attempt: should be skipped
        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => null);

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
        verifyNever(() => mockTaggingService.generateTags(any()));
      });

      test('should count thrown exception as failure', () async {
        final recipe = buildRecipe(
          id: 'exception-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        when(() => mockTaggingService.generateTags(any()))
            .thenThrow(Exception('Network error'));

        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();

        // 4th attempt: should be skipped
        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenThrow(Exception('Network error'));

        final count = await scheduler.triggerManualRetagging();

        expect(count, 0);
        verifyNever(() => mockTaggingService.generateTags(any()));
      });

      test(
          'should clear failure count when recipe succeeds after prior failures',
          () async {
        final recipe = buildRecipe(
          id: 'recoverable-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // First 2 calls fail
        var callCount = 0;
        when(() => mockTaggingService.generateTags(any())).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) {
            return failedTagResult();
          }
          return successTagResult();
        });

        // Attempt 1 — failure (count = 1)
        await scheduler.triggerManualRetagging();
        // Attempt 2 — failure (count = 2)
        await scheduler.triggerManualRetagging();
        // Attempt 3 — success (count cleared)
        final count = await scheduler.triggerManualRetagging();

        expect(count, 1);
        expect(savedRecipes.containsKey('recoverable-1'), isTrue);

        // Verify the saved recipe has the new successful tags
        final saved = savedRecipes['recoverable-1']!;
        expect(saved.core.tagResult, isNotNull);
        expect(saved.core.tagResult!.hasFailed, isFalse);
        expect(saved.core.tagResult!.generatorVersion, kTagGeneratorVersion);
      });

      test(
          'should allow recipe to be retried after success clears failure count',
          () async {
        final recipe = buildRecipe(
          id: 'retry-after-success',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // Fail twice, then succeed
        var callCount = 0;
        when(() => mockTaggingService.generateTags(any())).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) return failedTagResult();
          return successTagResult();
        });

        await scheduler.triggerManualRetagging(); // fail 1
        await scheduler.triggerManualRetagging(); // fail 2
        await scheduler.triggerManualRetagging(); // success — clears count

        // Now if the recipe somehow needs retagging again (e.g., version bump),
        // it should NOT be blocked. Simulate this by making the saved recipe
        // have a failed tagResult again.
        recipes = [
          buildRecipe(id: 'retry-after-success', tagResult: failedTagResult()),
        ];
        savedRecipes.clear();

        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successTagResult());

        final count = await scheduler.triggerManualRetagging();

        // Should process it again since failure count was cleared on success
        expect(count, 1);
        verify(() => mockTaggingService.generateTags(any())).called(1);
      });
    });

    group('resetFailureTracking', () {
      test(
          'should allow previously-skipped recipes to be retried after reset',
          () async {
        final recipe = buildRecipe(
          id: 'reset-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // Fail 3 times to hit the skip threshold
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => failedTagResult());

        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();

        // Confirm it is now skipped
        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successTagResult());

        var count = await scheduler.triggerManualRetagging();
        expect(count, 0);
        verifyNever(() => mockTaggingService.generateTags(any()));

        // Reset failure tracking
        scheduler.resetFailureTracking();

        // Now the recipe should be retried and succeed
        count = await scheduler.triggerManualRetagging();
        expect(count, 1);
        verify(() => mockTaggingService.generateTags(any())).called(1);
        expect(savedRecipes.containsKey('reset-1'), isTrue);
      });

      test('should clear tracking for multiple recipes at once', () async {
        final recipe1 = buildRecipe(
          id: 'multi-1',
          tagResult: failedTagResult(),
        );
        final recipe2 = buildRecipe(
          id: 'multi-2',
          tagResult: failedTagResult(),
        );
        recipes = [recipe1, recipe2];

        // Fail both 3 times
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => failedTagResult());

        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();
        await scheduler.triggerManualRetagging();

        // Both should be skipped now
        reset(mockTaggingService);
        when(() => mockTaggingService.generateTags(any()))
            .thenAnswer((_) async => successTagResult());

        var count = await scheduler.triggerManualRetagging();
        expect(count, 0);

        // Reset and verify both are retried
        scheduler.resetFailureTracking();

        count = await scheduler.triggerManualRetagging();
        expect(count, 2);
        expect(savedRecipes.containsKey('multi-1'), isTrue);
        expect(savedRecipes.containsKey('multi-2'), isTrue);
      });

      test('should be safe to call when no failures are tracked', () {
        // Should not throw
        scheduler.resetFailureTracking();
      });
    });

    group('concurrent retagging guard', () {
      test('should skip when retagging is already in progress', () async {
        final recipe = buildRecipe(
          id: 'concurrent-1',
          tagResult: failedTagResult(),
        );
        recipes = [recipe];

        // Make generateTags slow so we can trigger a second call
        when(() => mockTaggingService.generateTags(any())).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 100),
            () => successTagResult(),
          ),
        );

        // Start two retagging operations simultaneously
        final future1 = scheduler.triggerManualRetagging();
        final future2 = scheduler.triggerManualRetagging();

        final results = await Future.wait([future1, future2]);

        // One should succeed (1), the other should be skipped (0)
        expect(results, containsAll([0, 1]));
      });
    });
  });
}
