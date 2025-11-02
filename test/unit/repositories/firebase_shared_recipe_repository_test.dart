/// Comprehensive unit tests for FirebaseSharedRecipeRepository.
///
/// Tests shared recipe operations including create, read, status management (viewed/imported/dismissed),
/// permission validation, and copy-on-write collaboration support.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSharedRecipeRepository - Shared Recipe Management', () {
    late FirebaseSharedRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testOtherUserId = 'other-user-456';
    const testFriendId = 'friend-789';
    const testRecipeId = 'shared-recipe-1';
    const testOriginalRecipeId = 'original-recipe-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseSharedRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    Recipe createTestRecipe(String id, String userId) {
      return Recipe(
        core: RecipeCore(
          id: id,
          title: 'Test Recipe $id',
          description: 'A delicious test recipe',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Dinner',
          createdBy: userId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        type: RecipeType.personal,
      );
    }

    SharedRecipe createSharedRecipe({
      String? id,
      String? originalRecipeId,
      String? sharedByUserId,
      String? sharedByDisplayName,
      List<String>? sharedToUserIds,
      Recipe? recipeSnapshot,
      String? shareMessage,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
      bool allowCollaboration = false,
    }) {
      final recipe = recipeSnapshot ??
          createTestRecipe(originalRecipeId ?? testOriginalRecipeId,
              sharedByUserId ?? testUserId);

      return SharedRecipe(
        id: id ?? testRecipeId,
        originalRecipeId: originalRecipeId ?? testOriginalRecipeId,
        recipeSnapshot: recipe,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        sharedToUserIds: sharedToUserIds ?? [testOtherUserId],
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        viewedByUserIds: viewedByUserIds ?? [],
        engagedByUserIds: engagedByUserIds ?? [],
        dismissedByUserIds: dismissedByUserIds ?? [],
        allowCollaboration: allowCollaboration,
      );
    }

    Future<void> seedSharedRecipe(SharedRecipe sharedRecipe) async {
      await fakeFirestore
          .collection('shared_recipes')
          .doc(sharedRecipe.id)
          .set(sharedRecipe.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared recipe as themselves', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert - Should not throw
        await repository.createSharedRecipe(sharedRecipe);
      });

      test('should reject user from creating shared recipe as another user',
          () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId, // Different from authenticated user
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert
        expect(
          () => repository.createSharedRecipe(sharedRecipe),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared recipe with no recipients', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testUserId,
          sharedToUserIds: [], // Empty list
        );

        // Act & Assert
        expect(
          () => repository.createSharedRecipe(sharedRecipe),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared recipe sent to them', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId], // Current user is recipient
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        final result = await repository.getSharedRecipe(testRecipeId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testRecipeId);
      });

      test('should reject user from viewing shared recipe not sent to them',
          () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Current user not in list
        );
        await seedSharedRecipe(sharedRecipe);

        // Act & Assert
        expect(
          () => repository.getSharedRecipe(testRecipeId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test('should create shared recipe successfully', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          id: 'new-recipe',
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId, testOtherUserId],
          shareMessage: 'Check out this amazing recipe!',
        );

        // Act
        final recipeId = await repository.createSharedRecipe(sharedRecipe);

        // Assert
        expect(recipeId, 'new-recipe');

        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc('new-recipe')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['sharedByUserId'], testUserId);
        expect(doc.data()?['sharedToUserIds'], [testFriendId, testOtherUserId]);
      });

      test('should get all shared recipes for user', () async {
        // Arrange - Create multiple shared recipes
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
        );
        final recipe3 = createSharedRecipe(
          id: 'recipe-3',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Not for current user
        );

        await seedSharedRecipe(recipe1);
        await seedSharedRecipe(recipe2);
        await seedSharedRecipe(recipe3);

        // Act
        final recipes = await repository.getSharedRecipesForUser(testUserId);

        // Assert
        expect(recipes.length, 2);
        expect(recipes.any((r) => r.id == 'recipe-1'), isTrue);
        expect(recipes.any((r) => r.id == 'recipe-2'), isTrue);
        expect(recipes.any((r) => r.id == 'recipe-3'), isFalse);
      });

      test('should get specific shared recipe by ID', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        final result = await repository.getSharedRecipe(testRecipeId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testRecipeId);
        expect(result.recipeSnapshot.title, contains('Test Recipe'));
      });

      test('should return null for non-existent shared recipe', () async {
        // Act
        final result = await repository.getSharedRecipe('non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should delete shared recipe by creator', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testUserId, // Creator
          sharedToUserIds: [testFriendId],
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        await repository.deleteSharedRecipe(testRecipeId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test('should mark shared recipe as viewed', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Not yet viewed
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        await repository.markAsViewed(testRecipeId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .get();
        final viewedByUserIds =
            List<String>.from(doc.data()?['viewedByUserIds'] ?? []);
        expect(viewedByUserIds, contains(testUserId));
      });

      test('should mark shared recipe as imported', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not yet imported
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        await repository.markAsImported(testRecipeId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .get();
        final importedByUserIds =
            List<String>.from(doc.data()?['importedByUserIds'] ?? []);
        expect(importedByUserIds, contains(testUserId));
      });

      test('should mark shared recipe as dismissed', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [],
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        await repository.markAsDismissed(testRecipeId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, contains(testUserId));
      });

      test('should undismiss shared recipe', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Already dismissed
        );
        await seedSharedRecipe(sharedRecipe);

        // Act
        await repository.undismiss(testRecipeId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, isNot(contains(testUserId)));
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count for user', () async {
        // Arrange - Create recipes, some viewed, some not
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [testUserId], // Read
        );
        final recipe3 = createSharedRecipe(
          id: 'recipe-3',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );

        await seedSharedRecipe(recipe1);
        await seedSharedRecipe(recipe2);
        await seedSharedRecipe(recipe3);

        // Act
        final unreadCount = await repository.getUnreadCountForUser(testUserId);

        // Assert
        expect(unreadCount, 2); // recipe-1 and recipe-3 are unread
      });

      test('should get imported recipes for user', () async {
        // Arrange
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [testUserId], // Imported
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not imported
        );

        await seedSharedRecipe(recipe1);
        await seedSharedRecipe(recipe2);

        // Act
        final importedRecipes =
            await repository.getImportedRecipesForUser(testUserId);

        // Assert
        expect(importedRecipes.length, 1);
        expect(importedRecipes.first.id, 'recipe-1');
      });

      test('should filter out dismissed recipes from user query', () async {
        // Arrange
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [], // Not dismissed
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Dismissed
        );

        await seedSharedRecipe(recipe1);
        await seedSharedRecipe(recipe2);

        // Act
        final recipes = await repository.getSharedRecipesForUser(testUserId);

        // Assert
        expect(recipes.length, 1);
        expect(recipes.first.id, 'recipe-1');
        expect(recipes.any((r) => r.id == 'recipe-2'), isFalse);
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        final sharedRecipe = createSharedRecipe();

        // Act & Assert
        expect(
          () => repository.createSharedRecipe(sharedRecipe),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should handle empty shared recipes list', () async {
        // Act - No recipes seeded
        final recipes = await repository.getSharedRecipesForUser(testUserId);

        // Assert
        expect(recipes, isEmpty);
      });

      test('should handle marking non-existent recipe as viewed', () async {
        // Act & Assert - Should not throw, just do nothing
        await repository.markAsViewed('non-existent', testUserId);
      });
    });
  });
}
