/// Comprehensive unit tests for FirebaseSharedRecipeRepository.
///
/// Tests shared recipe operations with subcollection-based status tracking (Issue #014).
/// Validates create, read, status management (viewed/imported/dismissed via subcollections),
/// permission validation, and copy-on-write collaboration support.
///
/// NOTE: Tests that exercise FieldValue operations (serverTimestamp, arrayUnion,
/// increment) cannot run against FakeFirebaseFirestore (MethodChannelFieldValue
/// conflicts with MockFieldValuePlatform). They were moved to the emulator lane —
/// see firebase_shared_recipe_repository_integration_test.dart (BUT-1151) — which
/// runs on the CI emulator leg and skips cleanly locally. This file keeps the
/// read/query/permission tests the fake handles natively.
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
    late FakeAuthRepository mockAuthRepo;
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
      fakeFirestore = FakeFirebaseFirestore();

      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

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
      final recipe =
          recipeSnapshot ??
          createTestRecipe(
            originalRecipeId ?? testOriginalRecipeId,
            sharedByUserId ?? testUserId,
          );

      return SharedRecipe(
        id: id ?? testRecipeId,
        originalRecipeId: originalRecipeId ?? testOriginalRecipeId,
        recipeTitle: recipe.title,
        recipeImageUrl: recipe.imageUrls.isNotEmpty
            ? recipe.imageUrls.first
            : null,
        recipePortions: recipe.portions,
        recipeTimeMinutes: recipe.timeMinutes,
        recipeDescription: recipe.description,
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

    /// Seeds a SharedRecipe into FakeFirestore with optional subcollection data.
    /// Includes 'contentType': 'recipe' discriminator required by
    /// getSharedContentForUserViaSubcollection filtering.
    Future<void> seedSharedRecipe(
      SharedRecipe sharedRecipe, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
    }) async {
      // Create main document with contentType discriminator
      final data = sharedRecipe.toFirestore();
      data['contentType'] = 'recipe';
      await fakeFirestore
          .collection('shared_content')
          .doc(sharedRecipe.id)
          .set(data);

      final recipeRef = fakeFirestore
          .collection('shared_content')
          .doc(sharedRecipe.id);

      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await recipeRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedRecipe.sharedByUserId,
            'addedAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'member',
          });
        }
      }

      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await recipeRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await recipeRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'import',
            'engagedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await recipeRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      // Note: the create-with-recipients happy path moved to the emulator lane
      // (addMember uses FieldValue.arrayUnion/increment) — see
      // firebase_shared_recipe_repository_integration_test.dart (BUT-1151).
      test(
        'should reject user from creating shared recipe as another user',
        () async {
          final sharedRecipe = createSharedRecipe(
            sharedByUserId: testOtherUserId,
          );

          expect(
            () => repository.createSharedRecipe(
              sharedRecipe,
              recipientIds: [testFriendId],
            ),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );

      test('should reject shared recipe with no recipients', () async {
        final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);

        expect(
          () => repository.createSharedRecipe(
            sharedRecipe,
            recipientIds: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'should allow user to view shared recipe they are member of',
        () async {
          final sharedRecipe = createSharedRecipe(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedRecipe(
            sharedRecipe,
            memberUserIds: [testUserId],
          );

          final result = await repository.getSharedRecipe(testRecipeId);

          expect(result, isNotNull);
          expect(result!.id, testRecipeId);
        },
      );

      test(
        'should reject user from viewing shared recipe not member of',
        () async {
          final sharedRecipe = createSharedRecipe(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedRecipe(
            sharedRecipe,
            memberUserIds: [testFriendId],
          );

          expect(
            () => repository.getSharedRecipe(testRecipeId),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      // Note: the create-with-members happy path moved to the emulator lane
      // (addMember uses FieldValue.arrayUnion/increment) — see
      // firebase_shared_recipe_repository_integration_test.dart (BUT-1151).
      test(
        'should get all shared recipes for user via members subcollection',
        () async {
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
          await seedSharedRecipe(recipe3, memberUserIds: [testFriendId]);

          final recipes = await repository.getSharedRecipesForUser(testUserId);

          expect(recipes.length, 2);
          expect(recipes.any((r) => r.id == 'recipe-1'), isTrue);
          expect(recipes.any((r) => r.id == 'recipe-2'), isTrue);
          expect(recipes.any((r) => r.id == 'recipe-3'), isFalse);
        },
      );

      test('should get specific shared recipe by ID', () async {
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

        final result = await repository.getSharedRecipe(testRecipeId);

        expect(result, isNotNull);
        expect(result!.id, testRecipeId);
        expect(result.recipeTitle, contains('Test Recipe'));
      });

      test('should return null for non-existent shared recipe', () async {
        final result = await repository.getSharedRecipe('non-existent');

        expect(result, isNull);
      });

      test('should delete shared recipe by creator', () async {
        final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);
        await seedSharedRecipe(sharedRecipe, memberUserIds: [testFriendId]);

        await repository.deleteSharedRecipe(testRecipeId);

        final doc = await fakeFirestore
            .collection('shared_content')
            .doc(testRecipeId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== BUT-1132: IDEMPOTENT SHARE =====

    group('BUT-1132: idempotent share', () {
      // Note: the end-to-end "createSharedRecipe twice reuses the doc" test
      // moved to the emulator lane (createSharedRecipe -> addMember uses
      // FieldValue.arrayUnion/increment) — see
      // firebase_shared_recipe_repository_integration_test.dart (BUT-1151).
      test(
        'dedup query returns existing doc id when shared_content already has matching (sharedByUserId, originalRecipeId) pair',
        () async {
          // Direct probe of the dedup query — proves the where() chain finds the
          // pre-existing doc. Does NOT call createSharedRecipe (which would hit
          // the FieldValue limitation in addMember), so this test runs.
          // Does NOT exercise the post-query consume branch — see
          // firebase_shared_recipe_repository_integration_test.dart (emulator
          // lane) for the fix-regression guard (BUT-1151).
          final preExisting = createSharedRecipe(
            id: 'pre-existing-doc',
            sharedByUserId: testUserId,
          );
          await seedSharedRecipe(preExisting, memberUserIds: [testUserId]);

          final query = await fakeFirestore
              .collection('shared_content')
              .where('sharedByUserId', isEqualTo: testUserId)
              .where('originalRecipeId', isEqualTo: testOriginalRecipeId)
              .limit(1)
              .get();

          expect(
            query.docs.length,
            equals(1),
            reason:
                'BUT-1132: dedup query must find the existing doc by (sharedByUserId, originalRecipeId)',
          );
          expect(query.docs.first.id, equals('pre-existing-doc'));
        },
      );
    });

    // ===== STATUS MANAGEMENT (SUBCOLLECTIONS) =====

    group('Status Management - Subcollections', () {
      // Note: the add/remove-metadata write tests (markAsViewed/markAsImported/
      // markAsDismissed/undismiss) moved to the emulator lane (addMetadata/
      // removeMetadata use FieldValue.serverTimestamp) — see
      // firebase_shared_recipe_repository_integration_test.dart (BUT-1151).
      // The read-side hasViewed/hasEngaged/hasDismissed tests stay here.
      test('should check if user has viewed via hasViewed()', () async {
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          viewedByUserIds: [testUserId],
        );

        final hasViewed = await repository.hasViewed(testRecipeId, testUserId);

        expect(hasViewed, isTrue);
      });

      test('should check if user has engaged via hasEngaged()', () async {
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          engagedByUserIds: [testUserId],
        );

        final hasEngaged = await repository.hasEngaged(
          testRecipeId,
          testUserId,
        );

        expect(hasEngaged, isTrue);
      });

      test('should check if user has dismissed via hasDismissed()', () async {
        final sharedRecipe = createSharedRecipe(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedRecipe(
          sharedRecipe,
          memberUserIds: [testUserId],
          dismissedByUserIds: [testUserId],
        );

        final hasDismissed = await repository.hasDismissed(
          testRecipeId,
          testUserId,
        );

        expect(hasDismissed, isTrue);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test(
        'should return 0 unread count when no counter document exists (denormalized counter)',
        () async {
          // getUnreadCountForUser reads from denormalized counter doc,
          // not from actual view subcollections. Without seeding counters
          // the count is 0.
          final recipe1 = createSharedRecipe(
            id: 'recipe-1',
            sharedByUserId: testOtherUserId,
          );
          await seedSharedRecipe(recipe1, memberUserIds: [testUserId]);

          final unreadCount = await repository.getUnreadCountForUser(
            testUserId,
          );

          expect(unreadCount, 0);
        },
      );

      test(
        'should get imported recipes using engagements subcollection',
        () async {
          final recipe1 = createSharedRecipe(
            id: 'recipe-1',
            sharedByUserId: testOtherUserId,
          );
          final recipe2 = createSharedRecipe(
            id: 'recipe-2',
            sharedByUserId: testOtherUserId,
          );

          await seedSharedRecipe(
            recipe1,
            memberUserIds: [testUserId],
            engagedByUserIds: [testUserId],
          );
          await seedSharedRecipe(recipe2, memberUserIds: [testUserId]);

          final importedRecipes = await repository.getImportedRecipesForUser(
            testUserId,
          );

          expect(importedRecipes.length, 1);
          expect(importedRecipes.first.id, 'recipe-1');
        },
      );

      test(
        'should not return non-member recipes via subcollection query',
        () async {
          final recipe1 = createSharedRecipe(
            id: 'recipe-1',
            sharedByUserId: testOtherUserId,
          );
          final recipe2 = createSharedRecipe(
            id: 'recipe-2',
            sharedByUserId: testOtherUserId,
          );

          // recipe-1 has testUserId as member, recipe-2 does not
          await seedSharedRecipe(recipe1, memberUserIds: [testUserId]);
          await seedSharedRecipe(recipe2, memberUserIds: [testFriendId]);

          final recipes = await repository.getSharedRecipesForUser(testUserId);

          expect(recipes.length, 1);
          expect(recipes.first.id, 'recipe-1');
        },
      );
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        final sharedRecipe = createSharedRecipe();

        // requireCurrentUserId() throws AuthenticationException, not PermissionDeniedException
        expect(
          () => repository.createSharedRecipe(
            sharedRecipe,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('should handle empty shared recipes list', () async {
        final recipes = await repository.getSharedRecipesForUser(testUserId);

        expect(recipes, isEmpty);
      });

      // Note: "should throw when marking non-existent recipe as viewed" moved
      // to the emulator lane (markAsViewed -> addMetadata uses
      // FieldValue.serverTimestamp) — see
      // firebase_shared_recipe_repository_integration_test.dart (BUT-1151).
    });
  });
}
