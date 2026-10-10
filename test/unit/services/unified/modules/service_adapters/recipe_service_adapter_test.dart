/// Unit tests for RecipeServiceAdapter - Repository pattern access for UnifiedRecipeService modules
///
/// Tests adapter operations including:
/// - Recipe CRUD operations
/// - Comment operations
/// - Rating operations
/// - Notification operations
/// - Batch operations
/// - Stream operations
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/notifications/notification_types.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

class _MockTrashRepository extends Mock implements TrashRepository {}

void main() {
  group('RecipeServiceAdapter', () {
    late RecipeServiceAdapter adapter;
    late MockRecipeRepository mockRecipeRepository;
    late MockCommentsRepository mockCommentsRepository;
    late MockRatingsRepository mockRatingsRepository;
    late MockNotificationsRepository mockNotificationsRepository;
    late _MockTrashRepository mockTrashRepository;

    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      // Initialize service locator and mocks for each test
      await TestServiceLocator.initialize();

      // Create mocks directly (TestServiceLocator doesn't expose these as static properties)
      mockRecipeRepository = MockRecipeRepository();
      mockCommentsRepository = MockCommentsRepository();
      mockRatingsRepository = MockRatingsRepository();
      mockNotificationsRepository = MockNotificationsRepository();
      mockTrashRepository = _MockTrashRepository();
      when(
        () => mockTrashRepository.moveRecipeToTrash(any()),
      ).thenAnswer((_) async {});

      // Create adapter with mocked dependencies
      adapter = RecipeServiceAdapter(
        recipeRepository: mockRecipeRepository,
        trashRepository: mockTrashRepository,
        commentsRepository: mockCommentsRepository,
        ratingsRepository: mockRatingsRepository,
        notificationsRepository: mockNotificationsRepository,
      );
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    group('Recipe Operations', () {
      test('should create recipe successfully', () async {
        // Arrange
        final recipe = RecipeFactory.buildPersonal(
          id: 'recipe-1',
          title: 'Test Recipe',
          createdBy: 'user-123',
        );

        when(
          () => mockRecipeRepository.create(any()),
        ).thenAnswer((_) async => recipe);

        // Act
        final result = await adapter.createRecipe(recipe);

        // Assert
        expect(result, equals('recipe-1'));
        verify(() => mockRecipeRepository.create(recipe)).called(1);
      });

      test('should return null when recipe creation fails', () async {
        // Arrange
        final recipe = RecipeFactory.buildPersonal();

        when(
          () => mockRecipeRepository.create(any()),
        ).thenThrow(Exception('Create failed'));

        // Act
        final result = await adapter.createRecipe(recipe);

        // Assert
        expect(result, isNull);
      });

      test('should update recipe successfully', () async {
        // Arrange
        final recipe = RecipeFactory.buildPersonal(
          id: 'recipe-1',
          title: 'Updated Recipe',
        );

        when(() => mockRecipeRepository.update(any())).thenAnswer((_) async {});

        // Act
        final result = await adapter.updateRecipe(recipe);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeRepository.update(recipe)).called(1);
      });

      test('should return false when recipe update fails', () async {
        // Arrange
        final recipe = RecipeFactory.buildPersonal();

        when(
          () => mockRecipeRepository.update(any()),
        ).thenThrow(Exception('Update failed'));

        // Act
        final result = await adapter.updateRecipe(recipe);

        // Assert
        expect(result, isFalse);
      });

      test('should delete recipe successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final recipe = RecipeFactory.buildPersonal(id: recipeId);
        when(
          () => mockRecipeRepository.read(any()),
        ).thenAnswer((_) async => recipe);

        // Act
        final result = await adapter.deleteRecipe(recipeId);

        // Assert
        expect(result, isTrue);
        verify(() => mockTrashRepository.moveRecipeToTrash(recipe)).called(1);
        verifyNever(() => mockRecipeRepository.delete(any()));
      });

      test('should return false when recipe deletion fails', () async {
        // Arrange
        const recipeId = 'recipe-1';

        when(
          () => mockRecipeRepository.read(any()),
        ).thenThrow(Exception('Read failed'));

        // Act
        final result = await adapter.deleteRecipe(recipeId);

        // Assert
        expect(result, isFalse);
      });

      test('should get recipes for user', () async {
        // Arrange
        const userId = 'user-123';
        final recipes = [
          RecipeFactory.buildPersonal(id: 'recipe-1'),
          RecipeFactory.buildPersonal(id: 'recipe-2'),
        ];

        when(
          () => mockRecipeRepository.fetchUserRecipes(any()),
        ).thenAnswer((_) async => recipes);

        // Act
        final result = await adapter.getRecipesForUser(userId);

        // Assert
        expect(result, equals(recipes));
        verify(() => mockRecipeRepository.fetchUserRecipes(userId)).called(1);
      });

      test(
        'should return empty list when fetching user recipes fails',
        () async {
          // Arrange
          const userId = 'user-123';

          when(
            () => mockRecipeRepository.fetchUserRecipes(any()),
          ).thenThrow(Exception('Fetch failed'));

          // Act
          final result = await adapter.getRecipesForUser(userId);

          // Assert
          expect(result, isEmpty);
        },
      );

      test('should search recipes', () async {
        // Arrange
        const query = 'pasta';
        final recipes = [
          RecipeFactory.buildPersonal(id: 'recipe-1', title: 'Pasta Carbonara'),
          RecipeFactory.buildPersonal(id: 'recipe-2', title: 'Pasta Bolognese'),
        ];

        when(
          () => mockRecipeRepository.searchRecipes(any()),
        ).thenAnswer((_) async => recipes);

        // Act
        final result = await adapter.searchRecipes(query);

        // Assert
        expect(result, equals(recipes));
        verify(() => mockRecipeRepository.searchRecipes(query)).called(1);
      });

      test('should return empty list when search fails', () async {
        // Arrange
        const query = 'pasta';

        when(
          () => mockRecipeRepository.searchRecipes(any()),
        ).thenThrow(Exception('Search failed'));

        // Act
        final result = await adapter.searchRecipes(query);

        // Assert
        expect(result, isEmpty);
      });

      test(
        'empty or whitespace query short-circuits without hitting the repository',
        () async {
          // Act
          final emptyResult = await adapter.searchRecipes('');
          final whitespaceResult = await adapter.searchRecipes('   ');

          // Assert
          expect(emptyResult, isEmpty);
          expect(whitespaceResult, isEmpty);
          verifyNever(() => mockRecipeRepository.searchRecipes(any()));
        },
      );
    });

    // BUT-907: a delete moves the recipe to the trash, with its photos.
    // What others left on it is deleted by `onRecipeDeleted` (BUT-2327).
    group('delete moves the recipe to the trash', () {
      late RecipeServiceAdapter trashAdapter;
      const recipeId = 'recipe-trash-1';

      setUp(() {
        trashAdapter = RecipeServiceAdapter(
          recipeRepository: mockRecipeRepository,
          trashRepository: mockTrashRepository,
        );
      });

      test(
        'writes the copy with its photos and deletes nothing itself',
        () async {
          final recipe = RecipeFactory.build(
            id: recipeId,
            imageUrls: ['https://img/photo.jpg'],
          );
          when(
            () => mockRecipeRepository.read(recipeId),
          ).thenAnswer((_) async => recipe);
          when(
            () => mockTrashRepository.moveRecipeToTrash(any()),
          ).thenAnswer((_) async {});

          await trashAdapter.delete(recipeId);

          final moved =
              verify(
                    () => mockTrashRepository.moveRecipeToTrash(captureAny()),
                  ).captured.single
                  as Recipe;
          expect(moved.imageUrls, ['https://img/photo.jpg']);
          verifyNever(() => mockRecipeRepository.delete(any()));
        },
      );

      test('a recipe already gone writes no copy and throws', () async {
        when(
          () => mockRecipeRepository.read(recipeId),
        ).thenAnswer((_) async => null);

        await expectLater(
          trashAdapter.delete(recipeId),
          throwsA(isA<ResourceNotFoundException>()),
        );

        verifyNever(() => mockTrashRepository.moveRecipeToTrash(any()));
        verifyNever(() => mockRecipeRepository.delete(any()));
      });

      test('a failed trash write fails the delete', () async {
        when(
          () => mockRecipeRepository.read(recipeId),
        ).thenAnswer((_) async => RecipeFactory.build(id: recipeId));
        when(
          () => mockTrashRepository.moveRecipeToTrash(any()),
        ).thenThrow(Exception('unavailable'));

        await expectLater(trashAdapter.delete(recipeId), throwsException);
        expect(await trashAdapter.deleteRecipe(recipeId), isFalse);
      });
    });

    group('Notification Operations', () {
      test('should send notification successfully', () async {
        // Arrange
        const userId = 'user-123';
        const type = NotificationType.immediate;
        const title = 'New Recipe';
        const body = 'Check out this new recipe!';
        final data = {'recipeId': 'recipe-1'};

        when(
          () => mockNotificationsRepository.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await adapter.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        verify(
          () => mockNotificationsRepository.sendNotification(
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data,
          ),
        ).called(1);
      });

      test('should handle notification sending errors', () async {
        // Arrange
        const userId = 'user-123';
        const type = NotificationType.immediate;
        const title = 'New Recipe';
        const body = 'Check out this new recipe!';

        when(
          () => mockNotificationsRepository.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            data: any(named: 'data'),
          ),
        ).thenThrow(Exception('Send failed'));

        // Act & Assert - Should not throw
        await expectLater(
          adapter.sendNotification(
            userId: userId,
            type: type,
            title: title,
            body: body,
          ),
          completes,
        );
      });
    });

    group('Batch Operations', () {
      test('should get bulk rating statistics', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2', 'recipe-3'];
        final statistics = {
          'recipe-1': RatingStatistics(
            recipeId: 'recipe-1',
            averageRating: 4.5,
            totalRatings: 50,
            ratingDistribution: {1: 1, 2: 2, 3: 5, 4: 17, 5: 25},
          ),
          'recipe-2': RatingStatistics(
            recipeId: 'recipe-2',
            averageRating: 4.0,
            totalRatings: 30,
            ratingDistribution: {1: 2, 2: 3, 3: 5, 4: 10, 5: 10},
          ),
        };

        when(
          () => mockRatingsRepository.getBulkRatingStatistics(any()),
        ).thenAnswer((_) async => statistics);

        // Act
        final result = await adapter.getBulkRatingStatistics(recipeIds);

        // Assert
        expect(result, equals(statistics));
        verify(
          () => mockRatingsRepository.getBulkRatingStatistics(recipeIds),
        ).called(1);
      });

      test('should return empty map when bulk statistics fails', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2'];

        when(
          () => mockRatingsRepository.getBulkRatingStatistics(any()),
        ).thenThrow(Exception('Bulk fetch failed'));

        // Act
        final result = await adapter.getBulkRatingStatistics(recipeIds);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('Stream Operations', () {
      test('should get comments stream', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final comments = [
          RecipeComment(
            id: 'comment-1',
            recipeId: recipeId,
            authorId: 'user-1',
            authorDisplayName: 'User 1',
            text: 'Nice!',
            createdAt: DateTime.now(),
          ),
        ];

        when(
          () => mockCommentsRepository.getCommentsStream(any()),
        ).thenAnswer((_) => Stream.value(comments));

        // Act
        final stream = adapter.getCommentsStream(recipeId);

        // Assert
        final result = await stream.first;
        expect(result, equals(comments));
        verify(
          () => mockCommentsRepository.getCommentsStream(recipeId),
        ).called(1);
      });

      test('should get rating statistics stream', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final statistics = RatingStatistics(
          recipeId: recipeId,
          averageRating: 4.2,
          totalRatings: 42,
          ratingDistribution: {1: 2, 2: 3, 3: 7, 4: 15, 5: 15},
        );

        when(
          () => mockRatingsRepository.getRatingStatisticsStream(any()),
        ).thenAnswer((_) => Stream.value(statistics));

        // Act
        final stream = adapter.getRatingStatisticsStream(recipeId);

        // Assert
        final result = await stream.first;
        expect(result, equals(statistics));
        verify(
          () => mockRatingsRepository.getRatingStatisticsStream(recipeId),
        ).called(1);
      });
    });
  });
}
