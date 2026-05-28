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

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/notifications/notification_types.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

void main() {
  group('RecipeServiceAdapter', () {
    late RecipeServiceAdapter adapter;
    late MockRecipeRepository mockRecipeRepository;
    late MockCommentsRepository mockCommentsRepository;
    late MockRatingsRepository mockRatingsRepository;
    late MockNotificationsRepository mockNotificationsRepository;

    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator and mocks for each test
      await TestServiceLocator.initialize();

      // Create mocks directly (TestServiceLocator doesn't expose these as static properties)
      mockRecipeRepository = MockRecipeRepository();
      mockCommentsRepository = MockCommentsRepository();
      mockRatingsRepository = MockRatingsRepository();
      mockNotificationsRepository = MockNotificationsRepository();

      // Create adapter with mocked dependencies
      adapter = RecipeServiceAdapter(
        recipeRepository: mockRecipeRepository,
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

        when(() => mockRecipeRepository.create(any()))
            .thenAnswer((_) async => recipe);

        // Act
        final result = await adapter.createRecipe(recipe);

        // Assert
        expect(result, equals('recipe-1'));
        verify(() => mockRecipeRepository.create(recipe)).called(1);
      });

      test('should return null when recipe creation fails', () async {
        // Arrange
        final recipe = RecipeFactory.buildPersonal();

        when(() => mockRecipeRepository.create(any()))
            .thenThrow(Exception('Create failed'));

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

        when(() => mockRecipeRepository.update(any()))
            .thenThrow(Exception('Update failed'));

        // Act
        final result = await adapter.updateRecipe(recipe);

        // Assert
        expect(result, isFalse);
      });

      test('should delete recipe successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';

        // Production calls .read() first to fetch imageUrls before delete.
        // Without a stub mocktail throws on the unstubbed call, which the
        // adapter's broad catch swallows -> result returns false silently.
        when(() => mockRecipeRepository.read(any()))
            .thenAnswer((_) async => null);
        when(() => mockRecipeRepository.delete(any())).thenAnswer((_) async {});

        // Act
        final result = await adapter.deleteRecipe(recipeId);

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeRepository.delete(recipeId)).called(1);
      });

      test('should return false when recipe deletion fails', () async {
        // Arrange
        const recipeId = 'recipe-1';

        when(() => mockRecipeRepository.delete(any()))
            .thenThrow(Exception('Delete failed'));

        // Act
        final result = await adapter.deleteRecipe(recipeId);

        // Assert
        expect(result, isFalse);
      });

      test('should get recipe by ID', () async {
        // Arrange
        const recipeId = 'recipe-1';

        // Act
        final result = await adapter.getRecipeById(recipeId);

        // Assert
        // Currently returns null as getById is not implemented
        expect(result, isNull);
      });

      test('should get recipes for user', () async {
        // Arrange
        const userId = 'user-123';
        final recipes = [
          RecipeFactory.buildPersonal(id: 'recipe-1'),
          RecipeFactory.buildPersonal(id: 'recipe-2'),
        ];

        when(() => mockRecipeRepository.fetchUserRecipes(any()))
            .thenAnswer((_) async => recipes);

        // Act
        final result = await adapter.getRecipesForUser(userId);

        // Assert
        expect(result, equals(recipes));
        verify(() => mockRecipeRepository.fetchUserRecipes(userId)).called(1);
      });

      test('should return empty list when fetching user recipes fails',
          () async {
        // Arrange
        const userId = 'user-123';

        when(() => mockRecipeRepository.fetchUserRecipes(any()))
            .thenThrow(Exception('Fetch failed'));

        // Act
        final result = await adapter.getRecipesForUser(userId);

        // Assert
        expect(result, isEmpty);
      });

      test('should search recipes', () async {
        // Arrange
        const query = 'pasta';
        final recipes = [
          RecipeFactory.buildPersonal(id: 'recipe-1', title: 'Pasta Carbonara'),
          RecipeFactory.buildPersonal(id: 'recipe-2', title: 'Pasta Bolognese'),
        ];

        when(() => mockRecipeRepository.searchRecipes(any()))
            .thenAnswer((_) async => recipes);

        // Act
        final result = await adapter.searchRecipes(query);

        // Assert
        expect(result, equals(recipes));
        verify(() => mockRecipeRepository.searchRecipes(query)).called(1);
      });

      test('should return empty list when search fails', () async {
        // Arrange
        const query = 'pasta';

        when(() => mockRecipeRepository.searchRecipes(any()))
            .thenThrow(Exception('Search failed'));

        // Act
        final result = await adapter.searchRecipes(query);

        // Assert
        expect(result, isEmpty);
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

        when(() => mockNotificationsRepository.sendNotification(
              userId: any(named: 'userId'),
              type: any(named: 'type'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              data: any(named: 'data'),
            )).thenAnswer((_) async {});

        // Act
        await adapter.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        verify(() => mockNotificationsRepository.sendNotification(
              userId: userId,
              type: type,
              title: title,
              body: body,
              data: data,
            )).called(1);
      });

      test('should handle notification sending errors', () async {
        // Arrange
        const userId = 'user-123';
        const type = NotificationType.immediate;
        const title = 'New Recipe';
        const body = 'Check out this new recipe!';

        when(() => mockNotificationsRepository.sendNotification(
              userId: any(named: 'userId'),
              type: any(named: 'type'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              data: any(named: 'data'),
            )).thenThrow(Exception('Send failed'));

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

        when(() => mockRatingsRepository.getBulkRatingStatistics(any()))
            .thenAnswer((_) async => statistics);

        // Act
        final result = await adapter.getBulkRatingStatistics(recipeIds);

        // Assert
        expect(result, equals(statistics));
        verify(() => mockRatingsRepository.getBulkRatingStatistics(recipeIds))
            .called(1);
      });

      test('should return empty map when bulk statistics fails', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2'];

        when(() => mockRatingsRepository.getBulkRatingStatistics(any()))
            .thenThrow(Exception('Bulk fetch failed'));

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

        when(() => mockCommentsRepository.getCommentsStream(any()))
            .thenAnswer((_) => Stream.value(comments));

        // Act
        final stream = adapter.getCommentsStream(recipeId);

        // Assert
        final result = await stream.first;
        expect(result, equals(comments));
        verify(() => mockCommentsRepository.getCommentsStream(recipeId))
            .called(1);
      });

      test('BUT-894: deleteRecipe drains orphan shared_content records',
          () async {
        // Arrange: real adapter wired with a FakeFirebaseFirestore via a
        // mocked FirestoreRepository, plus a stubbed RecipeRepository.
        final fakeFirestore = FakeFirebaseFirestore();
        final firestoreRepo = _MockFirestoreRepository();
        when(() => firestoreRepo.firestore).thenReturn(fakeFirestore);

        const recipeId = 'recipe-orphan-1';
        final localRecipeRepo = MockRecipeRepository();
        when(() => localRecipeRepo.read(any())).thenAnswer((_) async => null);
        when(() => localRecipeRepo.delete(any())).thenAnswer((_) async {});

        final orphanAdapter = RecipeServiceAdapter(
          recipeRepository: localRecipeRepo,
          firestoreRepository: firestoreRepo,
        );

        // Seed a shared_content doc pointing at recipeId — what BUT-894
        // calls a recipient's dead inbox entry after owner deletes the
        // source recipe.
        final sharedRef = await fakeFirestore.collection('shared_content').add({
          'originalRecipeId': recipeId,
          'sharedByUserId': 'owner-1',
          'recipeTitle': 'Soon-orphan',
        });
        // Member doc in the subcollection (drained by the soft-cascade).
        await sharedRef.collection('members').doc('user-A').set({
          'userId': 'user-A',
          'role': 'viewer',
        });

        // Sanity: doc exists before delete.
        final beforeQuery = await fakeFirestore
            .collection('shared_content')
            .where('originalRecipeId', isEqualTo: recipeId)
            .get();
        expect(beforeQuery.docs.length, 1,
            reason: 'seed shared_content record must be present');

        // Act
        final result = await orphanAdapter.deleteRecipe(recipeId);

        // Assert: adapter reports success and the shared_content record
        // (plus its members subcollection) is gone.
        expect(result, isTrue);
        verify(() => localRecipeRepo.delete(recipeId)).called(1);

        final afterQuery = await fakeFirestore
            .collection('shared_content')
            .where('originalRecipeId', isEqualTo: recipeId)
            .get();
        expect(afterQuery.docs, isEmpty,
            reason: 'orphan shared_content must be deleted by BUT-894 cascade');

        final memberDocs = await sharedRef.collection('members').get();
        expect(memberDocs.docs, isEmpty,
            reason: 'members subcollection must be drained before parent doc');
      });

      test('BUT-892: deleteRecipe drains orphan cook_snaps records', () async {
        // Arrange: real adapter wired with a FakeFirebaseFirestore via a
        // mocked FirestoreRepository, plus a stubbed RecipeRepository.
        // Mirrors the BUT-894 pattern — cook_snaps by ANY user become
        // orphans (dangling recipeId) when the owner deletes the recipe.
        final fakeFirestore = FakeFirebaseFirestore();
        final firestoreRepo = _MockFirestoreRepository();
        when(() => firestoreRepo.firestore).thenReturn(fakeFirestore);

        const recipeId = 'recipe-snap-orphan-1';
        final localRecipeRepo = MockRecipeRepository();
        when(() => localRecipeRepo.read(any())).thenAnswer((_) async => null);
        when(() => localRecipeRepo.delete(any())).thenAnswer((_) async {});

        final orphanAdapter = RecipeServiceAdapter(
          recipeRepository: localRecipeRepo,
          firestoreRepository: firestoreRepo,
        );

        // Seed a cook_snap doc by some user pointing at recipeId.
        await fakeFirestore.collection('cook_snaps').add({
          'recipeId': recipeId,
          'userId': 'cook-user-A',
          'imageUrl': 'https://x/snap.jpg',
        });

        // Sanity: doc exists before delete.
        final beforeQuery = await fakeFirestore
            .collection('cook_snaps')
            .where('recipeId', isEqualTo: recipeId)
            .get();
        expect(beforeQuery.docs.length, 1,
            reason: 'seed cook_snap record must be present');

        // Act
        final result = await orphanAdapter.deleteRecipe(recipeId);

        // Assert: adapter reports success and the cook_snap record is gone.
        expect(result, isTrue);
        verify(() => localRecipeRepo.delete(recipeId)).called(1);

        final afterQuery = await fakeFirestore
            .collection('cook_snaps')
            .where('recipeId', isEqualTo: recipeId)
            .get();
        expect(afterQuery.docs, isEmpty,
            reason: 'orphan cook_snaps must be deleted by BUT-892 cascade');
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

        when(() => mockRatingsRepository.getRatingStatisticsStream(any()))
            .thenAnswer((_) => Stream.value(statistics));

        // Act
        final stream = adapter.getRatingStatisticsStream(recipeId);

        // Assert
        final result = await stream.first;
        expect(result, equals(statistics));
        verify(() => mockRatingsRepository.getRatingStatisticsStream(recipeId))
            .called(1);
      });
    });
  });
}
