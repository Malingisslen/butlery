/// Comprehensive unit tests for FirebaseSharedMenuRepository.
///
/// **Issue #014**: Migrated to subcollection-based status tracking (removed arrays).
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

    /// Create a SharedMenu with count fields (Issue #014 - arrays removed).
    SharedMenu createSharedMenu({
      String? id,
      String? menuTitle,
      String? sharedByUserId,
      String? sharedByDisplayName,
      Map<String, List<Recipe>>? menuSnapshot,
      String? shareMessage,
      bool allowCollaboration = false,
      int? viewCount,
      int? engagementCount,
      int? dismissalCount,
    }) {
      return SharedMenu(
        id: id ?? testMenuId,
        menuTitle: menuTitle ?? 'Weekly Menu',
        menuSnapshot: menuSnapshot ?? createMenuSnapshot(),
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

    /// Seed a SharedMenu into FakeFirestore with optional subcollection data (Issue #014).
    ///
    /// This helper creates the main document and populates subcollections for testing.
    /// Use this instead of passing array parameters to createSharedMenu().
    Future<void> seedSharedMenu(
      SharedMenu sharedMenu, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
    }) async {
      // Create main document
      await fakeFirestore
          .collection('shared_content')
          .doc(sharedMenu.id)
          .set(sharedMenu.toFirestore());

      // Create subcollection documents (Issue #014)
      final menuRef =
          fakeFirestore.collection('shared_content').doc(sharedMenu.id);

      // Seed members subcollection
      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await menuRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedMenu.sharedByUserId,
            'addedAt': DateTime.now(),
            'role': 'member',
          });
        }
      }

      // Seed views subcollection
      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await menuRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now(),
          });
        }
      }

      // Seed engagements subcollection
      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await menuRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'import',
            'engagedAt': DateTime.now(),
          });
        }
      }

      // Seed dismissals subcollection
      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await menuRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now(),
          });
        }
      }
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared menu with recipients', () async {
        // Arrange
        final sharedMenu = createSharedMenu(sharedByUserId: testUserId);

        // Act & Assert - Should not throw
        final menuId = await repository.createSharedMenu(
          sharedMenu,
          recipientIds: [testFriendId],
        );

        // Verify members subcollection created (Issue #014)
        final memberDoc = await fakeFirestore
            .collection('shared_content')
            .doc(menuId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.exists, isTrue);
      });

      test('should reject user from creating shared menu as another user',
          () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Different from authenticated user
        );

        // Act & Assert
        expect(
          () => repository.createSharedMenu(
            sharedMenu,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared menu with no recipients', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testUserId, // Empty list
        );

        // Act & Assert
        expect(
          () => repository.createSharedMenu(
            sharedMenu,
            recipientIds: [], // Empty list
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared menu sent to them', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Current user is recipient
        );
        await seedSharedMenu(sharedMenu,
            memberUserIds: [testUserId]); // Current user is recipient

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
          sharedByUserId: testOtherUserId, // Current user not in list
        );
        await seedSharedMenu(sharedMenu,
            memberUserIds: [testFriendId]); // Current user not in list

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
          shareMessage: 'Check out my menu!',
        );

        // Act
        final menuId = await repository.createSharedMenu(
          sharedMenu,
          recipientIds: [testFriendId, testOtherUserId],
        );

        // Assert - Check main document
        final doc =
            await fakeFirestore.collection('shared_content').doc(menuId).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['sharedByUserId'], testUserId);
        expect(doc.data()?['menuTitle'], 'My Weekly Plan');

        // Assert - Check members subcollection (Issue #014)
        final membersSnapshot = await fakeFirestore
            .collection('shared_content')
            .doc(menuId)
            .collection('members')
            .get();
        expect(membersSnapshot.docs.length, 2);
      });

      test('should get all shared menus for user', () async {
        // Arrange - Create multiple shared menus
        final menu1 = createSharedMenu(
          id: 'menu-1',
          menuTitle: 'Menu 1',
          sharedByUserId: testOtherUserId,
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          menuTitle: 'Menu 2',
          sharedByUserId: testFriendId,
        );
        final menu3 = createSharedMenu(
          id: 'menu-3',
          menuTitle: 'Menu 3',
          sharedByUserId: testOtherUserId, // Not for current user
        );

        await seedSharedMenu(menu1, memberUserIds: [testUserId]);
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
        );
        await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

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
        );
        await seedSharedMenu(sharedMenu, memberUserIds: [testFriendId]);

        // Act
        await repository.deleteSharedMenu(testMenuId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test('should add view to subcollection', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Not yet viewed
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.addView(testMenuId, testUserId);

        // Assert - Check views subcollection (Issue #014)
        final viewDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .collection('views')
            .doc(testUserId)
            .get();
        expect(viewDoc.exists, isTrue);
        expect(viewDoc.data()?['userId'], testUserId);
      });

      test('should add engagement to subcollection', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Not yet imported
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.addEngagement(testMenuId, testUserId,
            action: 'import');

        // Assert - Check engagements subcollection (Issue #014)
        final engagementDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .collection('engagements')
            .doc(testUserId)
            .get();
        expect(engagementDoc.exists, isTrue);
        expect(engagementDoc.data()?['userId'], testUserId);
      });

      test('should add dismissal to subcollection', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.addDismissal(testMenuId, testUserId);

        // Assert - Check dismissals subcollection (Issue #014)
        final dismissalDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isTrue);
        expect(dismissalDoc.data()?['userId'], testUserId);
      });

      test('should remove dismissal from subcollection', () async {
        // Arrange
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId, // Already dismissed
        );
        await seedSharedMenu(sharedMenu);

        // Act
        await repository.removeDismissal(testMenuId, testUserId);

        // Assert - Check dismissals subcollection (Issue #014)
        final dismissalDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isFalse);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count for user', () async {
        // Arrange - Create menus, some viewed, some not
        final menu1 = createSharedMenu(
          id: 'menu-1',
          sharedByUserId: testOtherUserId, // Unread
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId, // Read
        );
        final menu3 = createSharedMenu(
          id: 'menu-3',
          sharedByUserId: testFriendId, // Unread
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
          sharedByUserId: testOtherUserId, // Imported
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId, // Not imported
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
          sharedByUserId: testOtherUserId, // Not dismissed
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId, // Dismissed
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
          () => repository.createSharedMenu(
            sharedMenu,
            recipientIds: [testFriendId],
          ),
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
        );

        // Act & Assert - Should still create successfully
        await repository.createSharedMenu(
          sharedMenu,
          recipientIds: [testFriendId],
        );
      });
    });
  });
}
