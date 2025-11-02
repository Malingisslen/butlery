/// Comprehensive unit tests for FirebaseSharedMenuRepository.
///
/// Tests shared menu operations including create, read, status management (viewed/imported/dismissed),
/// permission validation, and copy-on-write collaboration support.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSharedMenuRepository - Shared Menu Management', () {
    late FirebaseSharedMenuRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testOtherUserId = 'other-user-456';
    const testFriendId = 'friend-789';
    const testMenuId = 'shared-menu-1';

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
      repository = FirebaseSharedMenuRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
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
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
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
        'Wednesday': [createTestRecipe('recipe-3', 'Wednesday Meal')],
      };
    }

    SharedMenu createSharedMenu({
      String? id,
      String? menuTitle,
      String? sharedByUserId,
      String? sharedByDisplayName,
      List<String>? sharedToUserIds,
      Map<String, List<Recipe>>? menuSnapshot,
      String? shareMessage,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
      bool allowCollaboration = false,
    }) {
      return SharedMenu(
        id: id ?? testMenuId,
        menuTitle: menuTitle ?? 'Weekly Menu',
        menuSnapshot: menuSnapshot ?? createMenuSnapshot(),
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

    Future<void> seedSharedMenu(SharedMenu sharedMenu) async {
      await fakeFirestore
          .collection('shared_menus')
          .doc(sharedMenu.id)
          .set(sharedMenu.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared menu as themselves', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert - Should not throw
        await repository.createSharedMenu(sharedMenu);
      });

      test('should reject user from creating shared menu as another user',
          () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Different from authenticated user
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert
        expect(
          () => repository.createSharedMenu(sharedMenu),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared menu with no recipients', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testUserId,
          sharedToUserIds: [], // Empty list
        );

        // Act & Assert
        expect(
          () => repository.createSharedMenu(sharedMenu),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared menu sent to them', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId], // Current user is recipient
        );
        await seedSharedMenu(sharedMenu);

        // Act
        final result = await repository.getSharedMenu(testMenuId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testMenuId);
      });

      test('should reject user from viewing shared menu not sent to them',
          () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Current user not in list
        );
        await seedSharedMenu(sharedMenu);

        // Act & Assert
        expect(
          () => repository.getSharedMenu(testMenuId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test('should create shared menu successfully', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          id: 'new-menu',
          menuTitle: 'My Weekly Plan',
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId, testOtherUserId],
          shareMessage: 'Check out my menu!',
        );

        // Act
        await repository.createSharedMenu(sharedMenu);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc('new-menu')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['sharedByUserId'], testUserId);
        expect(doc.data()?['menuTitle'], 'My Weekly Plan');
      });

      test('should get all shared menus for user', () async {
        // Arrange - Create multiple shared menus
        final menu1 = createSharedMenu(
          id: 'menu-1',
          menuTitle: 'Menu 1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          menuTitle: 'Menu 2',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
        );
        final menu3 = createSharedMenu(
          id: 'menu-3',
          menuTitle: 'Menu 3',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Not for current user
        );

        await seedSharedMenu(menu1);
        await seedSharedMenu(menu2);
        await seedSharedMenu(menu3);

        // Act
        final menus = await repository.getSharedMenusForUser(testUserId);

        // Assert
        expect(menus.length, 2);
        expect(menus.any((m) => m.id == 'menu-1'), isTrue);
        expect(menus.any((m) => m.id == 'menu-2'), isTrue);
        expect(menus.any((m) => m.id == 'menu-3'), isFalse);
      });

      test('should get specific shared menu by ID', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          menuTitle: 'Weekly Plan',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        await seedSharedMenu(sharedMenu);

        // Act
        final result = await repository.getSharedMenu(testMenuId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testMenuId);
        expect(result.menuTitle, 'Weekly Plan');
      });

      test('should return null for non-existent shared menu', () async {
        // Act
        final result = await repository.getSharedMenu('non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should delete shared menu by creator', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testUserId, // Creator
          sharedToUserIds: [testFriendId],
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.deleteSharedMenu(testMenuId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test('should mark shared menu as viewed', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Not yet viewed
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.markAsViewed(testMenuId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final viewedByUserIds =
            List<String>.from(doc.data()?['viewedByUserIds'] ?? []);
        expect(viewedByUserIds, contains(testUserId));
      });

      test('should mark shared menu as imported', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not yet imported
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.markAsImported(testMenuId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final importedByUserIds =
            List<String>.from(doc.data()?['importedByUserIds'] ?? []);
        expect(importedByUserIds, contains(testUserId));
      });

      test('should mark shared menu as dismissed', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [],
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.markAsDismissed(testMenuId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, contains(testUserId));
      });

      test('should undismiss shared menu', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Already dismissed
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.undismiss(testMenuId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, isNot(contains(testUserId)));
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count for user', () async {
        // Arrange - Create menus, some viewed, some not
        final menu1 = createSharedMenu(
          id: 'menu-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [testUserId], // Read
        );
        final menu3 = createSharedMenu(
          id: 'menu-3',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );

        await seedSharedMenu(menu1);
        await seedSharedMenu(menu2);
        await seedSharedMenu(menu3);

        // Act
        final unreadCount = await repository.getUnreadCountForUser(testUserId);

        // Assert
        expect(unreadCount, 2); // menu-1 and menu-3 are unread
      });

      test('should get imported menus for user', () async {
        // Arrange
        final menu1 = createSharedMenu(
          id: 'menu-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [testUserId], // Imported
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not imported
        );

        await seedSharedMenu(menu1);
        await seedSharedMenu(menu2);

        // Act
        final importedMenus =
            await repository.getImportedMenusForUser(testUserId);

        // Assert
        expect(importedMenus.length, 1);
        expect(importedMenus.first.id, 'menu-1');
      });

      test('should filter out dismissed menus from user query', () async {
        // Arrange
        final menu1 = createSharedMenu(
          id: 'menu-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [], // Not dismissed
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Dismissed
        );

        await seedSharedMenu(menu1);
        await seedSharedMenu(menu2);

        // Act
        final menus = await repository.getSharedMenusForUser(testUserId);

        // Assert
        expect(menus.length, 1);
        expect(menus.first.id, 'menu-1');
        expect(menus.any((m) => m.id == 'menu-2'), isFalse);
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

        final sharedMenu = createSharedMenu();

        // Act & Assert
        expect(
          () => repository.createSharedMenu(sharedMenu),
          throwsA(isA<Exception>()), // AuthenticationException
        );
      });

      test('should handle empty shared menus list', () async {
        // Act - No menus seeded
        final menus = await repository.getSharedMenusForUser(testUserId);

        // Assert
        expect(menus, isEmpty);
      });

      test('should handle menu with empty snapshot', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          menuSnapshot: {}, // Empty snapshot
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert - Should still create successfully
        await repository.createSharedMenu(sharedMenu);
      });
    });
  });
}
