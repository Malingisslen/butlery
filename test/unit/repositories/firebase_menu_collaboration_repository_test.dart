/// Comprehensive unit tests for FirebaseMenuCollaborationRepository.
///
/// Tests collaborative menu operations including collaboration management, recipe management,
/// ratings, comments, templates, and real-time features.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_menu_collaboration_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseMenuCollaborationRepository - Menu Collaboration', () {
    late FirebaseMenuCollaborationRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testOtherUserId = 'other-456';
    const testFriendId = 'friend-789';
    const testMenuId = 'menu-1';

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
      repository = FirebaseMenuCollaborationRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      // Dispose listeners before reset
      repository.disposeAllListeners();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    Recipe createTestRecipe(String id, String title) {
      return Recipe(
        core: RecipeCore(
          id: id,
          title: title,
          description: 'Recipe description',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Dinner',
          createdBy: testUserId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        type: RecipeType.personal,
      );
    }

    Map<String, List<Recipe>> createMenuSnapshot() {
      return {
        'Monday': [createTestRecipe('recipe-1', 'Monday Meal')],
        'Tuesday': [createTestRecipe('recipe-2', 'Tuesday Meal')],
      };
    }

    SharedMenu createTestMenu({
      String? id,
      String? sharedByUserId,
      String? sharedByDisplayName,
      List<String>? sharedToUserIds,
      List<String>? activeCollaboratorIds,
      bool allowCollaboration = false,
    }) {
      return SharedMenu(
        id: id ?? testMenuId,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        sharedToUserIds: sharedToUserIds ?? [testOtherUserId],
        shareMessage: 'Check out my menu',
        sharedAt: DateTime(2025, 1, 15),
        menuTitle: 'Veckomeny',
        menuSnapshot: createMenuSnapshot(),
        viewedByUserIds: [],
        engagedByUserIds: [],
        dismissedByUserIds: [],
        allowCollaboration: allowCollaboration,
        activeCollaboratorIds: activeCollaboratorIds ?? [],
      );
    }

    Future<void> seedMenu(SharedMenu menu) async {
      await fakeFirestore
          .collection('shared_menus')
          .doc(menu.id)
          .set(menu.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create menu as themselves', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject user from creating menu as another user', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testOtherUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, menu);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow owner to read their menu', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testUserId);

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow recipient to read menu shared with them', () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test(
          'should allow active collaborator to read menu if collaboration enabled',
          () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId],
          allowCollaboration: true,
          activeCollaboratorIds: [testUserId],
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject third party from reading menu', () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow owner to update their menu', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testUserId);

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test(
          'should allow active collaborator to update if collaboration enabled',
          () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId,
          allowCollaboration: true,
          activeCollaboratorIds: [testUserId],
        );

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject non-collaborator from updating menu', () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId,
          allowCollaboration: true,
          activeCollaboratorIds: [testFriendId],
        );

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testMenuId, menu);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should only allow owner to delete menu', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testUserId);
        await seedMenu(menu);

        // Act
        final hasPermission =
            await repository.validateDeletePermission(testUserId, testMenuId);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject non-owner from deleting menu', () async {
        // Arrange
        final menu = createTestMenu(sharedByUserId: testOtherUserId);
        await seedMenu(menu);

        // Act
        final hasPermission =
            await repository.validateDeletePermission(testUserId, testMenuId);

        // Assert
        expect(hasPermission, isFalse);
      });
    });

    // ===== COLLABORATION MANAGEMENT =====

    group('Collaboration Management', () {
      test('should enable collaboration with collaborators', () async {
        // Arrange
        final menu = createTestMenu();
        await seedMenu(menu);

        // Act
        final success = await repository.enableCollaboration(
          menuId: testMenuId,
          collaboratorIds: [testFriendId, testOtherUserId],
          collaboratorDisplayNames: {
            testFriendId: 'Friend',
            testOtherUserId: 'Other User',
          },
        );

        // Assert - Core functionality works, FieldValue.serverTimestamp skipped
        expect(success, isTrue);
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should check if user can collaborate on menu', () async {
        // Arrange
        final menu = createTestMenu(
          allowCollaboration: true,
          sharedToUserIds: [testUserId],
        );
        await seedMenu(menu);

        // Act
        final canCollaborate =
            await repository.canCollaborate(testMenuId, testUserId);

        // Assert
        expect(canCollaborate, isTrue);
      });

      test('should return false if collaboration not enabled', () async {
        // Arrange
        final menu = createTestMenu(
          allowCollaboration: false,
          sharedToUserIds: [testUserId],
        );
        await seedMenu(menu);

        // Act
        final canCollaborate =
            await repository.canCollaborate(testMenuId, testUserId);

        // Assert
        expect(canCollaborate, isFalse);
      });

      test('should return false if user not authorized for collaboration',
          () async {
        // Arrange
        final menu = createTestMenu(
          sharedByUserId: testOtherUserId, // Owner is someone else
          allowCollaboration: true,
          sharedToUserIds: [testFriendId], // Shared to someone else
        );
        await seedMenu(menu);

        // Act
        final canCollaborate =
            await repository.canCollaborate(testMenuId, testUserId);

        // Assert
        expect(canCollaborate, isFalse);
      });
    });

    // ===== RECIPE MANAGEMENT =====

    group('Recipe Management', () {
      test('should add recipe to collaborative menu', () async {
        // Arrange
        final menu = createTestMenu(
          allowCollaboration: true,
          sharedToUserIds: [testUserId],
        );
        await seedMenu(menu);
        final recipe = createTestRecipe('new-recipe', 'New Recipe');

        // Act
        final success = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Wednesday',
          recipe: recipe,
        );

        // Assert
        expect(success, isTrue);
      }, skip: 'Requires FieldValue.arrayUnion and serverTimestamp support');

      test('should remove recipe from collaborative menu', () async {
        // Arrange
        final menu = createTestMenu(
          allowCollaboration: true,
          sharedToUserIds: [testUserId],
        );
        await seedMenu(menu);

        // Act
        final success = await repository.removeRecipeFromMenu(
          menuId: testMenuId,
          category: 'Monday',
          recipeId: 'recipe-1',
        );

        // Assert
        expect(success, isTrue);
      }, skip: 'Requires FieldValue.arrayRemove and serverTimestamp support');
    });

    // ===== RATING SYSTEM =====

    group('Rating System', () {
      test('should rate menu with valid rating', () async {
        // Act
        final success = await repository.rateMenu(
          menuId: testMenuId,
          rating: 4.5,
          comment: 'Great menu!',
        );

        // Assert
        expect(success, isTrue);
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should reject rating below 1.0', () async {
        // Act
        final success = await repository.rateMenu(
          menuId: testMenuId,
          rating: 0.5,
        );

        // Assert
        expect(success, isFalse);
      });

      test('should reject rating above 5.0', () async {
        // Act
        final success = await repository.rateMenu(
          menuId: testMenuId,
          rating: 5.5,
        );

        // Assert
        expect(success, isFalse);
      });

      test('should get menu ratings', () async {
        // Act
        final ratings = await repository.getMenuRatings(testMenuId);

        // Assert
        expect(ratings, isA<List<Map<String, dynamic>>>());
      });

      test('should calculate average rating', () async {
        // Act
        final averageRating = await repository.getMenuAverageRating(testMenuId);

        // Assert
        expect(averageRating, isA<double>());
        expect(averageRating, greaterThanOrEqualTo(0.0));
      });
    });

    // ===== COMMENT SYSTEM =====

    group('Comment System', () {
      test('should add comment to menu', () async {
        // Act
        final success = await repository.addMenuComment(
          menuId: testMenuId,
          comment: 'Looks delicious!',
        );

        // Assert
        expect(success, isTrue);
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should get comments stream', () {
        // Act
        final stream = repository.getMenuCommentsStream(testMenuId);

        // Assert
        expect(stream, isA<Stream<List<Map<String, dynamic>>>>());
      });

      test('should toggle comment like', () async {
        // Arrange - First seed a comment
        await fakeFirestore
            .collection('menu_comments')
            .doc(testMenuId)
            .collection('comments')
            .doc('comment-1')
            .set({
          'comment': 'Test comment',
          'commentedBy': testFriendId,
          'commentedByDisplayName': 'Friend',
          'likes': 0,
          'likedBy': [],
        });

        // Act
        final success = await repository.toggleCommentLike(
          menuId: testMenuId,
          commentId: 'comment-1',
        );

        // Assert
        expect(success, isTrue);
      });

      test('should return false when toggling like on non-existent comment',
          () async {
        // Act
        final success = await repository.toggleCommentLike(
          menuId: testMenuId,
          commentId: 'non-existent',
        );

        // Assert
        expect(success, isFalse);
      });
    });

    // ===== TEMPLATE MANAGEMENT =====

    group('Template Management', () {
      test('should create menu template', () async {
        // Act
        final templateId = await repository.createMenuTemplate(
          templateName: 'Weekly Template',
          menuSnapshot: createMenuSnapshot(),
          description: 'A standard weekly menu',
          tags: ['weekly', 'standard'],
        );

        // Assert
        expect(templateId, isNotNull);
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should create menu from template', () async {
        // Arrange - Create a template first
        await fakeFirestore.collection('menu_templates').doc('template-1').set({
          'templateName': 'Test Template',
          'ownerId': testUserId,
          'ownerDisplayName': 'Test User',
          'menuSnapshot': createMenuSnapshot().map(
            (category, recipes) => MapEntry(
              category,
              recipes.map((r) => r.toFirestore()).toList(),
            ),
          ),
          'tags': ['test'],
          'isTemplate': true,
          'isPublic': false,
          'useCount': 0,
        });

        // Act
        final menuId = await repository.createMenuFromTemplate(
          templateId: 'template-1',
          menuTitle: 'My Menu from Template',
          sharedToUserIds: [testFriendId],
          shareMessage: 'Check this out!',
          enableCollaboration: true,
        );

        // Assert
        expect(menuId, isNotNull);
      }, skip: 'Requires FieldValue.increment support');
    });

    // ===== ACTIVITY LOGGING =====

    group('Activity Logging', () {
      test('should log menu activity', () async {
        // Act & Assert - Should not throw
        await repository.logMenuActivity(
          menuId: testMenuId,
          activity: {
            'operation': 'test_operation',
            'details': 'Test activity',
          },
          userId: testUserId,
          userDisplayName: 'Test User',
        );
      }, skip: 'Requires FieldValue.serverTimestamp support');
    });

    // ===== REAL-TIME OPERATIONS =====

    group('Real-time Operations', () {
      test('should start collaboration listener', () async {
        // Arrange
        final menu = createTestMenu();
        await seedMenu(menu);
        SharedMenu? receivedMenu;

        // Act
        repository.startCollaborationListener(testMenuId, (menu) {
          receivedMenu = menu;
        });

        // Give listener time to process
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(receivedMenu, isNotNull);
        expect(receivedMenu!.id, testMenuId);

        // Cleanup
        repository.stopCollaborationListener(testMenuId);
      });

      test('should stop collaboration listener', () {
        // Arrange
        final menu = createTestMenu();
        seedMenu(menu);
        repository.startCollaborationListener(testMenuId, (menu) {});

        // Act & Assert - Should not throw
        repository.stopCollaborationListener(testMenuId);
      });

      test('should dispose all listeners', () {
        // Arrange
        final menu1 = createTestMenu(id: 'menu-1');
        final menu2 = createTestMenu(id: 'menu-2');
        seedMenu(menu1);
        seedMenu(menu2);
        repository.startCollaborationListener('menu-1', (menu) {});
        repository.startCollaborationListener('menu-2', (menu) {});

        // Act & Assert - Should not throw
        repository.disposeAllListeners();
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

        // Act
        final success = await repository.rateMenu(
          menuId: testMenuId,
          rating: 4.0,
        );

        // Assert
        expect(success, isFalse);
      });

      test('should handle empty ratings list', () async {
        // Act
        final averageRating = await repository.getMenuAverageRating(testMenuId);

        // Assert
        expect(averageRating, 0.0);
      });

      test('should handle non-existent menu for collaboration check', () async {
        // Act
        final canCollaborate =
            await repository.canCollaborate('non-existent', testUserId);

        // Assert
        expect(canCollaborate, isFalse);
      });
    });

    // ===== BASE REPOSITORY IMPLEMENTATION =====

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, 'shared_menus');
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final menu = createTestMenu();

        // Act
        final id = repository.getId(menu);

        // Assert
        expect(id, testMenuId);
      });

      test('should serialize to Firestore correctly', () {
        // Arrange
        final menu = createTestMenu();

        // Act
        final data = repository.toFirestore(menu);

        // Assert
        expect(data['menuTitle'], 'Veckomeny');
        expect(data['sharedByUserId'], testUserId);
        expect(data['sharedToUserIds'], contains(testOtherUserId));
      });

      test('should deserialize from Firestore correctly', () async {
        // Arrange
        final menu = createTestMenu();
        await seedMenu(menu);

        // Act
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final result = repository.fromFirestore(doc);

        // Assert
        expect(result.id, testMenuId);
        expect(result.menuTitle, 'Veckomeny');
        expect(result.sharedByUserId, testUserId);
      });
    });
  });
}
