import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

// Mock classes for Drift DAOs
class MockAppDatabase extends Mock implements AppDatabase {}

class MockRecipeDao extends Mock implements RecipeDao {}

class MockSyncQueueDao extends Mock implements SyncQueueDao {}

// Fake OfflineRecipe for stubbing
class FakeOfflineRecipe extends Fake implements OfflineRecipe {
  @override
  final String id;
  @override
  final String userId;
  @override
  final String recipeJson;
  @override
  final DateTime updatedAt;
  @override
  final bool needsSync;

  FakeOfflineRecipe({
    required this.id,
    required this.userId,
    required this.recipeJson,
    DateTime? updatedAt,
    this.needsSync = false,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(SyncOperation.update);
  });

  group('OfflineUserStorage (Drift)', () {
    late OfflineUserStorage storage;
    late MockAppDatabase mockDatabase;
    late MockRecipeDao mockRecipeDao;
    late MockSyncQueueDao mockSyncQueueDao;

    setUp(() async {
      await BaseUnitTest.setupUnit();

      // Create mocks
      mockDatabase = MockAppDatabase();
      mockRecipeDao = MockRecipeDao();
      mockSyncQueueDao = MockSyncQueueDao();

      // Wire up database DAOs
      when(() => mockDatabase.recipeDao).thenReturn(mockRecipeDao);
      when(() => mockDatabase.syncQueueDao).thenReturn(mockSyncQueueDao);

      // Create storage instance with mock database
      storage = OfflineUserStorage(database: mockDatabase);
    });

    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('User-Scoped Storage', () {
      test('should save recipe with user-specific key', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_123')
            .withTitle('Swedish Meatballs')
            .build();
        const userId = 'user_456';

        when(
          () => mockRecipeDao.upsertRecipe(
            id: any(named: 'id'),
            userId: any(named: 'userId'),
            recipeJson: any(named: 'recipeJson'),
            needsSync: any(named: 'needsSync'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await storage.saveRecipeForUser(recipe, userId, isOnline: true);

        // Assert
        verify(
          () => mockRecipeDao.upsertRecipe(
            id: recipe.id,
            userId: userId,
            recipeJson: any(named: 'recipeJson'),
            needsSync: false,
          ),
        ).called(1);

        // Should not add to sync queue when online
        verifyNever(
          () => mockSyncQueueDao.enqueue(
            userId: any(named: 'userId'),
            recipeId: any(named: 'recipeId'),
            operation: any(named: 'operation'),
          ),
        );
      });

      test('should save recipe and add to sync queue when offline', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_789')
            .withTitle('Köttbullar')
            .build();
        const userId = 'user_123';

        when(
          () => mockRecipeDao.upsertRecipe(
            id: any(named: 'id'),
            userId: any(named: 'userId'),
            recipeJson: any(named: 'recipeJson'),
            needsSync: any(named: 'needsSync'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockSyncQueueDao.enqueue(
            userId: any(named: 'userId'),
            recipeId: any(named: 'recipeId'),
            operation: any(named: 'operation'),
          ),
        ).thenAnswer((_) async => 1);

        // Act
        await storage.saveRecipeForUser(recipe, userId, isOnline: false);

        // Assert
        verify(
          () => mockRecipeDao.upsertRecipe(
            id: recipe.id,
            userId: userId,
            recipeJson: any(named: 'recipeJson'),
            needsSync: true,
          ),
        ).called(1);

        verify(
          () => mockSyncQueueDao.enqueue(
            userId: userId,
            recipeId: recipe.id,
            operation: any(named: 'operation'),
          ),
        ).called(1);
      });

      test('should retrieve recipes for specific user', () async {
        // Arrange
        const userId = 'user_001';

        final recipe1 = RecipeBuilder()
            .withId('recipe_1')
            .withTitle('User 1 Recipe 1')
            .build();
        final recipe2 = RecipeBuilder()
            .withId('recipe_2')
            .withTitle('User 1 Recipe 2')
            .build();

        final offlineRecipes = [
          FakeOfflineRecipe(
            id: 'recipe_1',
            userId: userId,
            recipeJson: _recipeToJson(recipe1),
          ),
          FakeOfflineRecipe(
            id: 'recipe_2',
            userId: userId,
            recipeJson: _recipeToJson(recipe2),
          ),
        ];

        when(
          () => mockRecipeDao.getRecipesForUser(userId),
        ).thenAnswer((_) async => offlineRecipes);

        // Act
        final userRecipes = await storage.getRecipesForUser(userId);

        // Assert
        expect(userRecipes.length, 2);
        expect(userRecipes[0].title, 'User 1 Recipe 1');
        expect(userRecipes[1].title, 'User 1 Recipe 2');
      });
    });

    group('CRUD Operations', () {
      test('should get specific recipe for user', () async {
        // Arrange
        const userId = 'user_123';
        const recipeId = 'recipe_456';
        final recipe = RecipeBuilder()
            .withId(recipeId)
            .withTitle('Specific Recipe')
            .build();

        final offlineRecipe = FakeOfflineRecipe(
          id: recipeId,
          userId: userId,
          recipeJson: _recipeToJson(recipe),
        );

        when(
          () => mockRecipeDao.getRecipe(recipeId, userId),
        ).thenAnswer((_) async => offlineRecipe);

        // Act
        final retrieved = await storage.getRecipeForUser(recipeId, userId);

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.id, recipeId);
        expect(retrieved.title, 'Specific Recipe');
      });

      test('should return null for non-existent recipe', () async {
        // Arrange
        const userId = 'user_123';
        const recipeId = 'non_existent';

        when(
          () => mockRecipeDao.getRecipe(recipeId, userId),
        ).thenAnswer((_) async => null);

        // Act
        final retrieved = await storage.getRecipeForUser(recipeId, userId);

        // Assert
        expect(retrieved, isNull);
      });

      test('should delete recipe and remove from sync queue', () async {
        // Arrange
        const userId = 'user_123';
        const recipeId = 'recipe_456';

        when(
          () => mockRecipeDao.deleteRecipe(recipeId, userId),
        ).thenAnswer((_) async => 1);
        when(
          () => mockSyncQueueDao.removeForRecipe(userId, recipeId),
        ).thenAnswer((_) async => 1);

        // Act
        await storage.deleteRecipeForUser(recipeId, userId);

        // Assert
        verify(() => mockRecipeDao.deleteRecipe(recipeId, userId)).called(1);
        verify(
          () => mockSyncQueueDao.removeForRecipe(userId, recipeId),
        ).called(1);
      });
    });

    group('User Data Management', () {
      test('should clear all data for specific user', () async {
        // Arrange
        const targetUser = 'user_to_clear';

        when(
          () => mockRecipeDao.countForUser(targetUser),
        ).thenAnswer((_) async => 5);
        when(
          () => mockRecipeDao.deleteAllForUser(targetUser),
        ).thenAnswer((_) async => 5);
        when(
          () => mockSyncQueueDao.clearForUser(targetUser),
        ).thenAnswer((_) async => 2);

        // Act
        await storage.clearUserData(targetUser);

        // Assert
        verify(() => mockRecipeDao.deleteAllForUser(targetUser)).called(1);
        verify(() => mockSyncQueueDao.clearForUser(targetUser)).called(1);
      });

      test('should get recipe count for user', () async {
        // Arrange
        const userId = 'user_123';

        when(
          () => mockRecipeDao.countForUser(userId),
        ).thenAnswer((_) async => 10);

        // Act
        final count = await storage.getRecipeCountForUser(userId);

        // Assert
        expect(count, 10);
      });
    });

    group('Reactive Streams', () {
      test('should watch recipes for user', () async {
        // Arrange
        const userId = 'user_123';
        final recipe = RecipeBuilder().withTitle('Watched Recipe').build();

        final offlineRecipes = [
          FakeOfflineRecipe(
            id: recipe.id,
            userId: userId,
            recipeJson: _recipeToJson(recipe),
          ),
        ];

        when(
          () => mockRecipeDao.watchRecipesForUser(userId),
        ).thenAnswer((_) => Stream.value(offlineRecipes));

        // Act
        final stream = storage.watchRecipesForUser(userId);
        final recipes = await stream.first;

        // Assert
        expect(recipes.length, 1);
        expect(recipes[0].title, 'Watched Recipe');
      });
    });

    group('H9: Tag Queueing for Offline Recipes', () {
      test(
        'should queue SyncOperation.tag when recipe has pending tagResult',
        () async {
          // Arrange
          final baseRecipe = RecipeBuilder()
              .withId('recipe_pending')
              .withTitle('Pending Tags Recipe')
              .build();

          // Create recipe with pending tagResult
          final recipe = Recipe(
            core: baseRecipe.core.copyWith(tagResult: TagResult.pending()),
            type: baseRecipe.type,
          );

          const userId = 'user_123';

          when(
            () => mockRecipeDao.upsertRecipe(
              id: any(named: 'id'),
              userId: any(named: 'userId'),
              recipeJson: any(named: 'recipeJson'),
              needsSync: any(named: 'needsSync'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            ),
          ).thenAnswer((_) async => 1);

          // Act
          await storage.saveRecipeForUser(recipe, userId, isOnline: false);

          // Assert - should queue both update AND tag operations
          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.update,
            ),
          ).called(1);

          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.tag,
            ),
          ).called(1);
        },
      );

      test(
        'should queue SyncOperation.tag when recipe has failed tagResult',
        () async {
          // Arrange
          final baseRecipe = RecipeBuilder()
              .withId('recipe_failed')
              .withTitle('Failed Tags Recipe')
              .build();

          // Create recipe with failed tagResult
          final recipe = Recipe(
            core: baseRecipe.core.copyWith(
              tagResult: TagResult.failed(reason: 'Test failure'),
            ),
            type: baseRecipe.type,
          );

          const userId = 'user_123';

          when(
            () => mockRecipeDao.upsertRecipe(
              id: any(named: 'id'),
              userId: any(named: 'userId'),
              recipeJson: any(named: 'recipeJson'),
              needsSync: any(named: 'needsSync'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            ),
          ).thenAnswer((_) async => 1);

          // Act
          await storage.saveRecipeForUser(recipe, userId, isOnline: false);

          // Assert - should queue tag operation for failed tagResult
          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.tag,
            ),
          ).called(1);
        },
      );

      test(
        'should queue SyncOperation.tag when recipe has zero coverage',
        () async {
          // Arrange
          final baseRecipe = RecipeBuilder()
              .withId('recipe_zero_coverage')
              .withTitle('Zero Coverage Recipe')
              .build();

          // Create recipe with zero coverage tagResult
          final recipe = Recipe(
            core: baseRecipe.core.copyWith(
              tagResult: TagResult(
                tags: {},
                allergenStatus: {},
                dietaryStatus: {},
                coverage: 0.0,
                generatedAt: DateTime.now(),
                generatorVersion: 'v1.0', // Valid version but zero coverage
              ),
            ),
            type: baseRecipe.type,
          );

          const userId = 'user_123';

          when(
            () => mockRecipeDao.upsertRecipe(
              id: any(named: 'id'),
              userId: any(named: 'userId'),
              recipeJson: any(named: 'recipeJson'),
              needsSync: any(named: 'needsSync'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            ),
          ).thenAnswer((_) async => 1);

          // Act
          await storage.saveRecipeForUser(recipe, userId, isOnline: false);

          // Assert - should queue tag operation for zero coverage
          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.tag,
            ),
          ).called(1);
        },
      );

      test(
        'should NOT queue SyncOperation.tag when recipe has valid tagResult',
        () async {
          // Arrange
          final baseRecipe = RecipeBuilder()
              .withId('recipe_valid')
              .withTitle('Valid Tags Recipe')
              .build();

          // Create recipe with valid tagResult (good coverage, valid version)
          final recipe = Recipe(
            core: baseRecipe.core.copyWith(
              tagResult: TagResult(
                tags: {'middag', 'kyckling'},
                allergenStatus: {},
                dietaryStatus: {},
                coverage: 0.85, // Good coverage
                generatedAt: DateTime.now(),
                generatorVersion: 'v1.0', // Valid version
              ),
            ),
            type: baseRecipe.type,
          );

          const userId = 'user_123';

          when(
            () => mockRecipeDao.upsertRecipe(
              id: any(named: 'id'),
              userId: any(named: 'userId'),
              recipeJson: any(named: 'recipeJson'),
              needsSync: any(named: 'needsSync'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            ),
          ).thenAnswer((_) async => 1);

          // Act
          await storage.saveRecipeForUser(recipe, userId, isOnline: false);

          // Assert - should queue update but NOT tag operation
          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.update,
            ),
          ).called(1);

          // Verify tag operation was NOT queued
          verifyNever(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.tag,
            ),
          );
        },
      );

      test('should NOT queue SyncOperation.tag when online', () async {
        // Arrange
        final baseRecipe = RecipeBuilder()
            .withId('recipe_online')
            .withTitle('Online Recipe')
            .build();

        // Create recipe with pending tagResult
        final recipe = Recipe(
          core: baseRecipe.core.copyWith(tagResult: TagResult.pending()),
          type: baseRecipe.type,
        );

        const userId = 'user_123';

        when(
          () => mockRecipeDao.upsertRecipe(
            id: any(named: 'id'),
            userId: any(named: 'userId'),
            recipeJson: any(named: 'recipeJson'),
            needsSync: any(named: 'needsSync'),
          ),
        ).thenAnswer((_) async {});

        // Act - save while ONLINE
        await storage.saveRecipeForUser(recipe, userId, isOnline: true);

        // Assert - no sync queue operations when online
        verifyNever(
          () => mockSyncQueueDao.enqueue(
            userId: any(named: 'userId'),
            recipeId: any(named: 'recipeId'),
            operation: any(named: 'operation'),
          ),
        );
      });

      test(
        'should queue SyncOperation.tag when recipe has stale-ingredient version',
        () async {
          // Arrange
          final baseRecipe = RecipeBuilder()
              .withId('recipe_stale')
              .withTitle('Stale Ingredient Recipe')
              .build();

          // Create recipe with stale-ingredient version
          final recipe = Recipe(
            core: baseRecipe.core.copyWith(
              tagResult: TagResult(
                tags: {'middag'},
                allergenStatus: {},
                dietaryStatus: {},
                coverage: 0.5,
                generatedAt: DateTime.now(),
                generatorVersion: 'stale-ingredient', // Needs retagging
              ),
            ),
            type: baseRecipe.type,
          );

          const userId = 'user_123';

          when(
            () => mockRecipeDao.upsertRecipe(
              id: any(named: 'id'),
              userId: any(named: 'userId'),
              recipeJson: any(named: 'recipeJson'),
              needsSync: any(named: 'needsSync'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            ),
          ).thenAnswer((_) async => 1);

          // Act
          await storage.saveRecipeForUser(recipe, userId, isOnline: false);

          // Assert - should queue tag operation for stale-ingredient
          verify(
            () => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipe.id,
              operation: SyncOperation.tag,
            ),
          ).called(1);
        },
      );
    });
  });
}

/// Helper to convert Recipe to JSON string
String _recipeToJson(Recipe recipe) {
  // `type` is serialized as RecipeType.index (int) on the wire, NOT a
  // string. Using "personal" here makes RecipeSerialization.fromJson
  // throw on `as int?`, the inner catch in OfflineUserStorage swallows
  // it, and the recipe is silently dropped. 0 = RecipeType.personal.
  return '{"id":"${recipe.id}","title":"${recipe.title}","description":"${recipe.description}","ingredients":[],"instructions":[],"mealType":"${recipe.mealType}","imageUrls":[],"createdAt":"${recipe.createdAt.toIso8601String()}","updatedAt":"${recipe.updatedAt.toIso8601String()}","isPublic":false,"type":0}';
}
