/// Comprehensive unit tests for FirebaseSharedRecipeRepository.
///
/// Tests shared recipe operations with subcollection-based status tracking (Issue #014).
/// Validates create, read, status management (viewed/imported/dismissed via subcollections),
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
  group('FirebaseSharedRecipeRepository - Subcollection Architecture', () {
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
      Recipe? recipeSnapshot,
      String? shareMessage,
      bool allowCollaboration = false,
      int? viewCount,
      int? engagementCount,
      int? dismissalCount,
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
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        allowCollaboration: allowCollaboration,
        viewCount: viewCount ?? 0,
        engagementCount: engagementCount ?? 0,
        dismissalCount: dismissalCount ?? 0,
      );
    }

    Future<void> seedSharedRecipe(
      SharedRecipe sharedRecipe, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
    }) async {
      // Create main document
      await fakeFirestore
          .collection('shared_recipes')
          .doc(sharedRecipe.id)
          .set(sharedRecipe.toFirestore());

      // Create subcollection documents (Issue #014)
      final recipeRef =
          fakeFirestore.collection('shared_recipes').doc(sharedRecipe.id);

      // Seed members subcollection
      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await recipeRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedRecipe.sharedByUserId,
            'addedAt': DateTime.now(),
            'role': 'member',
          });
        }
      }

      // Seed views subcollection
      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await recipeRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now(),
          });
        }
      }

      // Seed engagements subcollection
      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await recipeRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'import',
            'engagedAt': DateTime.now(),
          });
        }
      }

      // Seed dismissals subcollection
      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await recipeRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now(),
          });
        }
      }
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared recipe with recipients',
          () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);

        // Act & Assert - Should not throw
        final recipeId = await repository.createSharedRecipe(
          sharedRecipe,
          recipientIds: [testFriendId],
        );

        // Verify members subcollection created (Issue #014)
        final memberDoc = await fakeFirestore
            .collection('shared_recipes')
            .doc(recipeId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.exists, isTrue);
      });

      test('should reject user from creating shared recipe as another user',
          () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId, // Different from authenticated user
        );

        // Act & Assert
        expect(
          () => repository.createSharedRecipe(
            sharedRecipe,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared recipe with no recipients', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);

        // Act & Assert
        expect(
          () => repository.createSharedRecipe(
            sharedRecipe,
            recipientIds: [], // Empty list
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared recipe they are member of',
          () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId], // Current user is member
        );

        // Act
        final result = await repository.getSharedRecipe(testRecipeId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testRecipeId);
      });

      test('should reject user from viewing shared recipe not member of',
          () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testFriendId], // Current user not in members
        );

        // Act & Assert
        expect(
          () => repository.getSharedRecipe(testRecipeId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test('should create shared recipe with members subcollection', () async {
        // Arrange
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testUserId,
          shareMessage: 'Check out this amazing recipe!',
        );

        // Act
        final recipeId = await repository.createSharedRecipe(
          sharedRecipe,
          recipientIds: [testFriendId, testOtherUserId],
        );

        // Assert - Check auto-generated ID was returned
        expect(recipeId, isNotEmpty);

        final doc = await fakeFirestore
            .collection('shared_recipes')
            .doc(recipeId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['sharedByUserId'], testUserId);

        // Verify members subcollection (Issue #014)
        final membersSnapshot = await fakeFirestore
            .collection('shared_recipes')
            .doc(recipeId)
            .collection('members')
            .get();
        expect(membersSnapshot.docs.length, 2);
        expect(membersSnapshot.docs.any((d) => d.id == testFriendId), isTrue);
        expect(
            membersSnapshot.docs.any((d) => d.id == testOtherUserId), isTrue);
      });

      test('should get all shared recipes for user via members subcollection',
          () async {
        // Arrange - Create multiple shared recipes
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testFriendId,
        );
        final recipe3 = createSharedRecipe(
          id: 'recipe-3',
          sharedByUserId: testOtherUserId,
        );

        await seedSharedRecipe(recipe1, memberUserIds: [testUserId]);
        await seedSharedRecipe(recipe2, memberUserIds: [testUserId]);
        await seedSharedRecipe(recipe3,
            memberUserIds: [testFriendId]); // Not for current user

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
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

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
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testUserId); // Creator
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testFriendId]);

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

    // ===== STATUS MANAGEMENT (SUBCOLLECTIONS) =====

    group('Status Management - Subcollections', () {
      test('should add view to views subcollection', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

        // Act
        await repository.markAsViewed(testRecipeId, testUserId);

        // Assert - Check views subcollection (Issue #014)
        final viewDoc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .collection('views')
            .doc(testUserId)
            .get();
        expect(viewDoc.exists, isTrue);
        expect(viewDoc.data()?['userId'], testUserId);
      });

      test('should add engagement to engagements subcollection', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

        // Act
        await repository.markAsImported(testRecipeId, testUserId);

        // Assert - Check engagements subcollection (Issue #014)
        final engagementDoc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .collection('engagements')
            .doc(testUserId)
            .get();
        expect(engagementDoc.exists, isTrue);
        expect(engagementDoc.data()?['userId'], testUserId);
        expect(engagementDoc.data()?['action'], 'import');
      });

      test('should add dismissal to dismissals subcollection', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

        // Act
        await repository.markAsDismissed(testRecipeId, testUserId);

        // Assert - Check dismissals subcollection (Issue #014)
        final dismissalDoc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isTrue);
        expect(dismissalDoc.data()?['userId'], testUserId);
      });

      test('should remove dismissal from dismissals subcollection', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Already dismissed
        );

        // Act
        await repository.undismiss(testRecipeId, testUserId);

        // Assert - Check dismissals subcollection (Issue #014)
        final dismissalDoc = await fakeFirestore
            .collection('shared_recipes')
            .doc(testRecipeId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isFalse);
      });

      test('should check if user has viewed via hasViewed()', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          viewedByUserIds: [testUserId],
        );

        // Act
        final hasViewed = await repository.hasViewed(testRecipeId, testUserId);

        // Assert
        expect(hasViewed, isTrue);
      });

      test('should check if user has engaged via hasEngaged()', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          engagedByUserIds: [testUserId],
        );

        // Act
        final hasEngaged =
            await repository.hasEngaged(testRecipeId, testUserId);

        // Assert
        expect(hasEngaged, isTrue);
      });

      test('should check if user has dismissed via hasDismissed()', () async {
        // Arrange
        final sharedRecipe =
            createSharedRecipe(sharedByUserId: testOtherUserId);
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          dismissedByUserIds: [testUserId],
        );

        // Act
        final hasDismissed =
            await repository.hasDismissed(testRecipeId, testUserId);

        // Assert
        expect(hasDismissed, isTrue);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count using views subcollection', () async {
        // Arrange - Create recipes, some viewed, some not
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
        );
        final recipe3 = createSharedRecipe(
          id: 'recipe-3',
          sharedByUserId: testFriendId,
        );

        await seedSharedRecipe(recipe1, memberUserIds: [testUserId]); // Unread
        await seedSharedRecipe(recipe2,
            memberUserIds: [testUserId], viewedByUserIds: [testUserId]); // Read
        await seedSharedRecipe(recipe3, memberUserIds: [testUserId]); // Unread

        // Act
        final unreadCount = await repository.getUnreadCountForUser(testUserId);

        // Assert
        expect(unreadCount, 2); // recipe-1 and recipe-3 are unread
      });

      test('should get imported recipes using engagements subcollection',
          () async {
        // Arrange
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
        );

        await seedSharedRecipe(recipe1,
            memberUserIds: [testUserId],
            engagedByUserIds: [testUserId]); // Imported
        await seedSharedRecipe(recipe2,
            memberUserIds: [testUserId]); // Not imported

        // Act
        final importedRecipes =
            await repository.getImportedRecipesForUser(testUserId);

        // Assert
        expect(importedRecipes.length, 1);
        expect(importedRecipes.first.id, 'recipe-1');
      });

      test('should filter out dismissed recipes using dismissals subcollection',
          () async {
        // Arrange
        final recipe1 = createSharedRecipe(
          id: 'recipe-1',
          sharedByUserId: testOtherUserId,
        );
        final recipe2 = createSharedRecipe(
          id: 'recipe-2',
          sharedByUserId: testOtherUserId,
        );

        await seedSharedRecipe(recipe1,
            memberUserIds: [testUserId]); // Not dismissed
        await seedSharedRecipe(recipe2,
            memberUserIds: [testUserId],
            dismissedByUserIds: [testUserId]); // Dismissed

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
          () => repository.createSharedRecipe(
            sharedRecipe,
            recipientIds: [testFriendId],
          ),
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
