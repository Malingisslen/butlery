/// Comprehensive unit tests for FirebaseSharedMenuRepository.
///
/// **Issue #014**: Migrated to subcollection-based status tracking (removed arrays).
///
/// Tests shared menu operations including create, read, status management (viewed/imported/dismissed),
/// permission validation, and copy-on-write collaboration support.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clock/clock.dart';
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
    late FakeAuthRepository mockAuthRepo;
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
      fakeFirestore = FakeFirebaseFirestore();

      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

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

    /// Seeds a SharedMenu into FakeFirestore with optional subcollection data.
    /// Includes 'contentType': 'menu' discriminator required by
    /// getSharedContentForUserViaSubcollection filtering.
    Future<void> seedSharedMenu(
      SharedMenu sharedMenu, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
    }) async {
      // Create main document with contentType discriminator
      final data = sharedMenu.toFirestore();
      data['contentType'] = 'menu';
      await fakeFirestore
          .collection('shared_content')
          .doc(sharedMenu.id)
          .set(data);

      final menuRef = fakeFirestore
          .collection('shared_content')
          .doc(sharedMenu.id);

      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await menuRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedMenu.sharedByUserId,
            'addedAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'member',
          });
        }
      }

      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await menuRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await menuRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'import',
            'engagedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await menuRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test(
        'should allow user to create shared menu with recipients',
        () async {
          final sharedMenu = createSharedMenu(sharedByUserId: testUserId);

          final menuId = await repository.createSharedMenu(
            sharedMenu,
            recipientIds: [testFriendId],
          );

          final memberDoc = await fakeFirestore
              .collection('shared_content')
              .doc(menuId)
              .collection('members')
              .doc(testFriendId)
              .get();
          expect(memberDoc.exists, isTrue);

          // BUT-1798: `sharedToUserIds` is the SOLE membership field the GDPR
          // export and the group queries scope on, denormalized here via
          // arrayUnion. A member row without it is invisible to both.
          final menuDoc = await fakeFirestore
              .collection('shared_content')
              .doc(menuId)
              .get();
          expect(
            menuDoc.data()?['sharedToUserIds'],
            equals([testUserId, testFriendId]),
          );
        },
      );

      test('re-adding an existing member neither resets addedAt nor '
          'double-counts their unread badge', () async {
        // BUT-1152. Arrange - one recipient, added once by createSharedMenu.
        final sharedMenu = createSharedMenu(sharedByUserId: testUserId);
        final menuId = await repository.createSharedMenu(
          sharedMenu,
          recipientIds: [testFriendId],
        );
        final firstAddedAt =
            (await fakeFirestore
                    .collection('shared_content')
                    .doc(menuId)
                    .collection('members')
                    .doc(testFriendId)
                    .get())
                .data()?['addedAt'];

        // Act - add the same person a second time
        await repository.addMember(menuId, testFriendId, addedBy: testUserId);

        // Assert - their original join stamp survives...
        final memberDoc = await fakeFirestore
            .collection('shared_content')
            .doc(menuId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.data()?['addedAt'], equals(firstAddedAt));

        // ...and arrayUnion did not seat them twice.
        final menuDoc = await fakeFirestore
            .collection('shared_content')
            .doc(menuId)
            .get();
        expect(
          menuDoc.data()?['sharedToUserIds'],
          equals([testUserId, testFriendId]),
        );

        // ...and the recipient's unread badge counted the share ONCE. Read the
        // counter document directly: getUnreadCountForUser refuses to answer
        // for anyone but the signed-in user.
        final counters = await fakeFirestore
            .collection('users')
            .doc(testFriendId)
            .collection('counters')
            .doc('shared_content')
            .get();
        expect(counters.data()?['unreadSharedMenus'], equals(1));
        expect(counters.data()?['totalSharedContent'], equals(1));
      });

      test(
        'should reject user from creating shared menu as another user',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );

          expect(
            () => repository.createSharedMenu(
              sharedMenu,
              recipientIds: [testFriendId],
            ),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );

      test('should reject shared menu with no recipients', () async {
        final sharedMenu = createSharedMenu(sharedByUserId: testUserId);

        expect(
          () => repository.createSharedMenu(
            sharedMenu,
            recipientIds: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared menu sent to them', () async {
        final sharedMenu = createSharedMenu(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

        final result = await repository.getSharedMenu(testMenuId);

        expect(result, isNotNull);
        expect(result!.id, testMenuId);
      });

      test(
        'should reject user from viewing shared menu not sent to them',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(sharedMenu, memberUserIds: [testFriendId]);

          expect(
            () => repository.getSharedMenu(testMenuId),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test(
        'should create shared menu successfully',
        () async {
          final sharedMenu = createSharedMenu(
            id: 'new-menu',
            menuTitle: 'My Weekly Plan',
            sharedByUserId: testUserId,
            shareMessage: 'Check out my menu!',
          );

          final menuId = await repository.createSharedMenu(
            sharedMenu,
            recipientIds: [testFriendId, testOtherUserId],
          );

          final doc = await fakeFirestore
              .collection('shared_content')
              .doc(menuId)
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['sharedByUserId'], testUserId);
          expect(doc.data()?['menuTitle'], 'My Weekly Plan');

          final membersSnapshot = await fakeFirestore
              .collection('shared_content')
              .doc(menuId)
              .collection('members')
              .get();
          expect(membersSnapshot.docs.length, 2);
        },
      );

      test('should get all shared menus for user', () async {
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
          sharedByUserId: testOtherUserId,
        );

        await seedSharedMenu(menu1, memberUserIds: [testUserId]);
        await seedSharedMenu(menu2, memberUserIds: [testUserId]);
        await seedSharedMenu(menu3, memberUserIds: [testFriendId]);

        final menus = await repository.getSharedMenusForUser(testUserId);

        expect(menus.length, 2);
        expect(menus.any((m) => m.id == 'menu-1'), isTrue);
        expect(menus.any((m) => m.id == 'menu-2'), isTrue);
        expect(menus.any((m) => m.id == 'menu-3'), isFalse);
      });

      test('should get specific shared menu by ID', () async {
        final sharedMenu = createSharedMenu(
          menuTitle: 'Weekly Plan',
          sharedByUserId: testOtherUserId,
        );
        await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

        final result = await repository.getSharedMenu(testMenuId);

        expect(result, isNotNull);
        expect(result!.id, testMenuId);
        expect(result.menuTitle, 'Weekly Plan');
      });

      test('should return null for non-existent shared menu', () async {
        final result = await repository.getSharedMenu('non-existent');

        expect(result, isNull);
      });

      test('should delete shared menu by creator', () async {
        final sharedMenu = createSharedMenu(sharedByUserId: testUserId);
        await seedSharedMenu(sharedMenu, memberUserIds: [testFriendId]);

        await repository.deleteSharedMenu(testMenuId);

        final doc = await fakeFirestore
            .collection('shared_content')
            .doc(testMenuId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test(
        'should add view to subcollection',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

          await repository.addView(testMenuId, testUserId);

          final viewDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testMenuId)
              .collection('views')
              .doc(testUserId)
              .get();
          expect(viewDoc.exists, isTrue);
          expect(viewDoc.data()?['userId'], testUserId);

          // The serverTimestamp sentinel resolved rather than dropping the
          // field, and the row carries its 90-day TTL stamp.
          expect(viewDoc.data()?['timestamp'], isNotNull);
          expect(
            (viewDoc.data()!['expireAt'] as Timestamp).toDate(),
            isSameTtlAs(const Duration(days: 90)),
          );
        },
      );

      test(
        'should add engagement to subcollection',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

          await repository.addEngagement(
            testMenuId,
            testUserId,
            action: 'import',
          );

          final engagementDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testMenuId)
              .collection('engagements')
              .doc(testUserId)
              .get();
          expect(engagementDoc.exists, isTrue);
          expect(engagementDoc.data()?['userId'], testUserId);

          // The caller's extra payload rides along with the metadata row.
          expect(engagementDoc.data()?['action'], 'import');
          expect(engagementDoc.data()?['timestamp'], isNotNull);
        },
      );

      test(
        'should add dismissal to subcollection',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(sharedMenu, memberUserIds: [testUserId]);

          await repository.addDismissal(testMenuId, testUserId);

          final dismissalDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testMenuId)
              .collection('dismissals')
              .doc(testUserId)
              .get();
          expect(dismissalDoc.exists, isTrue);
          expect(dismissalDoc.data()?['userId'], testUserId);
          expect(dismissalDoc.data()?['timestamp'], isNotNull);
        },
      );

      test(
        'should remove dismissal from subcollection',
        () async {
          final sharedMenu = createSharedMenu(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(
            sharedMenu,
            memberUserIds: [testUserId],
            dismissedByUserIds: [testUserId],
          );

          await repository.removeDismissal(testMenuId, testUserId);

          final dismissalDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testMenuId)
              .collection('dismissals')
              .doc(testUserId)
              .get();
          expect(dismissalDoc.exists, isFalse);
        },
      );
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test(
        'should return 0 unread count when no counter document exists (denormalized counter)',
        () async {
          // getUnreadCountForUser reads from denormalized counter doc,
          // not from actual view subcollections. Without seeding counters
          // the count is 0.
          final menu1 = createSharedMenu(
            id: 'menu-1',
            sharedByUserId: testOtherUserId,
          );
          await seedSharedMenu(menu1, memberUserIds: [testUserId]);

          final unreadCount = await repository.getUnreadCountForUser(
            testUserId,
          );

          expect(unreadCount, 0);
        },
      );

      test('should get imported menus for user', () async {
        final menu1 = createSharedMenu(
          id: 'menu-1',
          sharedByUserId: testOtherUserId,
        );
        final menu2 = createSharedMenu(
          id: 'menu-2',
          sharedByUserId: testOtherUserId,
        );

        await seedSharedMenu(
          menu1,
          memberUserIds: [testUserId],
          engagedByUserIds: [testUserId],
        );
        await seedSharedMenu(menu2, memberUserIds: [testUserId]);

        final importedMenus = await repository.getImportedMenusForUser(
          testUserId,
        );

        expect(importedMenus.length, 1);
        expect(importedMenus.first.id, 'menu-1');
      });

      test(
        'should not return non-member menus via subcollection query',
        () async {
          final menu1 = createSharedMenu(
            id: 'menu-1',
            sharedByUserId: testOtherUserId,
          );
          final menu2 = createSharedMenu(
            id: 'menu-2',
            sharedByUserId: testOtherUserId,
          );

          // menu-1 has testUserId as member, menu-2 does not
          await seedSharedMenu(menu1, memberUserIds: [testUserId]);
          await seedSharedMenu(menu2, memberUserIds: [testFriendId]);

          final menus = await repository.getSharedMenusForUser(testUserId);

          expect(menus.length, 1);
          expect(menus.first.id, 'menu-1');
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

        final sharedMenu = createSharedMenu();

        // requireCurrentUserId() throws AuthenticationException
        expect(
          () => repository.createSharedMenu(
            sharedMenu,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('should handle empty shared menus list', () async {
        final menus = await repository.getSharedMenusForUser(testUserId);

        expect(menus, isEmpty);
      });

      test('should handle menu with empty snapshot', () async {
        final sharedMenu = createSharedMenu(
          menuSnapshot: {},
          sharedByUserId: testUserId,
        );

        final menuId = await repository.createSharedMenu(
          sharedMenu,
          recipientIds: [testFriendId],
        );

        // An empty week is still a shareable menu: the document and its
        // recipient both land.
        final stored = await repository.getSharedMenu(menuId);
        expect(stored, isNotNull);
        expect(stored!.menuSnapshot, isEmpty);
        final memberDoc = await fakeFirestore
            .collection('shared_content')
            .doc(menuId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.exists, isTrue);
      });
    });
  });
}

/// Matches a TTL stamp sitting [ttl] ahead of now, with a minute of slack for
/// the gap between the write and the assertion.
Matcher isSameTtlAs(Duration ttl) {
  final expected = clock.now().add(ttl);
  return predicate<DateTime>(
    (actual) => actual.difference(expected).abs() < const Duration(minutes: 1),
    'a TTL stamp ~$ttl from now',
  );
}
