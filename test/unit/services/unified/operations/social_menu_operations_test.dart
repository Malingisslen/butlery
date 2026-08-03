import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../test_support/fake_field_value_platform.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/user_builder.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart' as app;

// Using centralized mocks from production_mocks.dart:
// MockUnifiedFriendsService, MockFriendsCategoriesOperations, FakeFirestoreRepository.
// Firestore interactions run against the FakeFirebaseFirestore exposed by
// FakeFirestoreRepository — no hand-rolled SDK mocks needed.

void main() {
  group('SocialMenuOperations with Centralized Mocks', () {
    late SocialMenuOperations operations;
    late MockUnifiedFriendsService mockFriendsService;
    late FakeFirestoreRepository mockFirestoreRepository;
    late MockFriendsCategoriesOperations mockCategoriesOperations;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;

    setUpAll(() async {
      // BEFORE the bootstrap — see the helper's own note. Without it every
      // `shared_content` write in this file throws inside the fake and lands
      // nothing, which is what the two share tests below used to be skipped for.
      installFakeFieldValuePlatform();
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FieldValue.serverTimestamp());
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to TestServiceLocator
      app.ServiceLocator.reset();
      app.ServiceLocator.initialize(MockDIContainer());

      // Create centralized mocks
      mockFirestoreRepository = FakeFirestoreRepository();
      mockFriendsService = MockUnifiedFriendsService();
      mockCategoriesOperations = MockFriendsCategoriesOperations();

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Swedish Meatballs')
          .build();

      testMenu = {
        'Main Course': [testRecipe],
        'Dessert': [
          RecipeBuilder()
              .withId('recipe-456')
              .withTitle('Princess Cake')
              .build(),
        ],
      };

      // Configure friends service with test friends and wire categories ops
      mockFriendsService.setFriendsState(
        friends: [
          UserBuilder().withId('friend-1').withName('Anna').build(),
          UserBuilder().withId('friend-2').withName('Erik').build(),
        ],
        categories: mockCategoriesOperations,
      );

      // Configure categories operations with test data using configuration method
      mockCategoriesOperations.setCategoriesState(
        categoryFriends: [
          UserBuilder().withId('friend-1').withName('Friend One').build(),
          UserBuilder().withId('friend-2').withName('Friend Two').build(),
        ],
        friendsByCategory: {
          'family-category': [
            UserBuilder().withId('friend-1').withName('Friend One').build(),
            UserBuilder().withId('friend-2').withName('Friend Two').build(),
          ],
        },
        categoryByName: FriendCategory(
          id: 'family-category',
          name: 'Family',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Create operations instance
      operations = SocialMenuOperations(
        firestore: mockFirestoreRepository.firestore,
        friendsService: mockFriendsService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with firestore and friends service', () {
        // Assert
        expect(operations, isNotNull);
      });

      test('should have authenticated user in PermissionService', () {
        // Check that PermissionService is properly configured
        final permissionService = app.ServiceLocator.get<PermissionService>();
        expect(permissionService.isAuthenticated, isTrue);
        expect(permissionService.currentUserId, equals('test-user-123'));
        expect(permissionService.currentUser, isNotNull);
        expect(permissionService.currentUser?.uid, equals('test-user-123'));
      });
    });

    group('Menu Sharing with Friends', () {
      test(
        'should share menu with friends',
        () async {
          // Act — prod code writes directly to FakeFirebaseFirestore
          final result = await operations.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1', 'friend-2'],
            message: 'Check out my weekly menu!',
            customTitle: 'Weekly Menu Plan',
          );

          // Assert
          expect(result, isTrue);

          // Verify shared menu doc was created in FakeFirestore
          final firestore = mockFirestoreRepository.firestore;
          final sharedDocs = await firestore.collection('shared_content').get();
          expect(sharedDocs.docs, hasLength(1));
          expect(sharedDocs.docs.first.data()['title'], 'Weekly Menu Plan');
        },
      );

      /// BUT-1775, mirror of the `recipe_sharing_manager` case: the name
      /// persisted here lands on a document every recipient reads AND verbatim
      /// in their Article-15 export, so it must be the PROFILE name — the one
      /// `on-profile-updated.ts` renames and account deletion scrubs — not the
      /// Firebase Auth handle `PermissionService.currentUser` synthesizes.
      ///
      /// Both write sites are asserted: the `shared_content` document and the
      /// per-recipient record under `user_shared_menus`. The batch leg is a
      /// second call site with its own copy of the value and was unasserted.
      /// BUT-1775, the branch the test above cannot reach. Every other call in
      /// this suite passes `customTitle`, so the DEFAULT title — which is
      /// persisted on the shared document, rendered to every recipient, and
      /// exported verbatim — was built by a line no test executed. Reverting it
      /// to the Auth-sourced `currentUser.displayName` reddened nothing, and
      /// that value is the one copy neither `on-profile-updated.ts` nor the
      /// deletion cascade can ever reach.
      test(
        'the DEFAULT title uses the profile name, never the Auth handle',
        () async {
          final userService = app.ServiceLocator.get<UserService>();
          when(
            () => (userService as MockUserService).profileDisplayName,
          ).thenReturn('Malin i appen');

          final result = await operations.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
            // No customTitle — this is the whole point.
          );
          expect(result, isTrue);

          final firestore = mockFirestoreRepository.firestore;
          final sharedDocs = await firestore.collection('shared_content').get();
          expect(sharedDocs.docs, isNotEmpty);
          final title = sharedDocs.docs.first.data()['title'] as String;

          expect(
            title,
            contains('Malin i appen'),
            reason: 'the default title must come from the profile name',
          );
          expect(
            title,
            isNot(contains('Test User')),
            reason:
                'the Auth-sourced display name must never be persisted here — '
                'no rename propagator or deletion cascade reaches a title',
          );
        },
      );

      test(
        'stamps the PROFILE display name on BOTH menu-share writes (BUT-1775)',
        () async {
          final userService = app.ServiceLocator.get<UserService>();
          when(
            () => (userService as MockUserService).profileDisplayName,
          ).thenReturn('Malin i appen');

          final result = await operations.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
            customTitle: 'Weekly Menu Plan',
          );
          expect(result, isTrue);

          final firestore = mockFirestoreRepository.firestore;
          final sharedDocs = await firestore.collection('shared_content').get();
          expect(
            sharedDocs.docs,
            isNotEmpty,
            reason: 'the shared_content write is the subject of this test',
          );
          expect(
            sharedDocs.docs.first.data()['sharedByDisplayName'],
            'Malin i appen',
          );
          // The membership spelling firestore.rules' recipient branch and the
          // GDPR export both read. Writing only `sharedWithUserIds` made the
          // row unreadable by the very people it was shared with.
          expect(
            sharedDocs.docs.first.data()['sharedToUserIds'],
            contains('friend-1'),
          );

          final records = await firestore
              .collection('user_shared_menus')
              .doc('friend-1')
              .collection('received_menus')
              .get();
          expect(records.docs, isNotEmpty);
          expect(
            records.docs.first.data()['sharedByDisplayName'],
            'Malin i appen',
          );
        },
      );

      test('should not share empty menu', () async {
        // Act
        final result = await operations.shareMenuWithFriends(
          menu: {},
          friendUserIds: ['friend-1'],
          message: 'Empty menu',
          customTitle: 'Empty Menu',
        );

        // Assert
        expect(result, isFalse);

        // No shared_content doc should have landed in Firestore.
        final sharedDocs = await mockFirestoreRepository.firestore
            .collection('shared_content')
            .get();
        expect(sharedDocs.docs, isEmpty);
      });

      test('should not share with non-friends', () async {
        // Act
        final result = await operations.shareMenuWithFriends(
          menu: testMenu,
          friendUserIds: ['stranger-1', 'stranger-2'],
          message: 'Check out my menu!',
          customTitle: 'Test Menu',
        );

        // Assert
        expect(result, isFalse);

        final sharedDocs = await mockFirestoreRepository.firestore
            .collection('shared_content')
            .get();
        expect(sharedDocs.docs, isEmpty);
      });
    });

    group('Menu Sharing with Groups', () {
      test(
        'should share menu with friend category',
        () async {
          // Act — prod code writes directly to FakeFirebaseFirestore
          final result = await operations.shareMenuWithGroup(
            menu: testMenu,
            categoryId: 'family-category',
            message: 'Family dinner menu',
            customTitle: 'Family Meals',
          );

          // Assert
          expect(result, isTrue);

          // Verify shared menu doc was created in FakeFirestore
          final firestore = mockFirestoreRepository.firestore;
          final sharedDocs = await firestore.collection('shared_content').get();
          expect(sharedDocs.docs, hasLength(1));
          expect(sharedDocs.docs.first.data()['title'], 'Family Meals');
        },
      );

      test('should not share with empty category', () async {
        // Act
        final result = await operations.shareMenuWithGroup(
          menu: testMenu,
          categoryId: 'empty-category',
          message: 'Test message',
          customTitle: 'Test Menu',
        );

        // Assert
        expect(result, isFalse);

        final sharedDocs = await mockFirestoreRepository.firestore
            .collection('shared_content')
            .get();
        expect(sharedDocs.docs, isEmpty);
      });
    });

    group('Shared Menu Management', () {
      test('should get menus shared by current user', () async {
        // Arrange — seed FakeFirebaseFirestore directly (prod code queries
        // the real firestore instance, not mock collection chains)
        final firestore = mockFirestoreRepository.firestore;

        await firestore.collection('shared_content').doc('menu-id-1').set({
          'contentType': 'menu',
          'title': 'My Menu',
          'sharedAt': DateTime.now().toIso8601String(),
          'totalRecipes': 5,
          'sharedByUserId': 'test-user-123',
          'sharedWithUserIds': ['friend-1'],
          'isActive': true,
          'description': 'Test menu',
        });

        // Act
        final menus = await operations.getMenusSharedByMe();

        // Assert
        expect(menus, isA<List<Map<String, dynamic>>>());
        expect(menus.length, equals(1));
        expect(menus.first['title'], equals('My Menu'));
        expect(menus.first['totalRecipes'], equals(5));
      });

      test(
        'should import shared menu',
        () async {
          // Arrange — seed FakeFirebaseFirestore directly
          final firestore = mockFirestoreRepository.firestore;

          await firestore
              .collection('shared_content')
              .doc('menu-to-import')
              .set({
                'sharedWithUserIds': ['test-user-123'],
                'title': 'Menu to Import',
                'isActive': true,
              });

          // Create the user's received-menu pointer so .update() works
          await firestore
              .collection('user_shared_menus')
              .doc('test-user-123')
              .collection('received_menus')
              .doc('menu-to-import')
              .set({
                'sharedMenuId': 'menu-to-import',
                'isImported': false,
              });

          // Act
          final result = await operations.importSharedMenu('menu-to-import');

          // Assert
          expect(result, isTrue);

          // Verify the document was updated
          final updatedDoc = await firestore
              .collection('user_shared_menus')
              .doc('test-user-123')
              .collection('received_menus')
              .doc('menu-to-import')
              .get();
          expect(updatedDoc.data()!['isImported'], isTrue);
        },
      );

      test(
        'should delete shared menu by owner',
        () async {
          // Arrange — seed FakeFirebaseFirestore
          final firestore = mockFirestoreRepository.firestore;

          await firestore
              .collection('shared_content')
              .doc('menu-to-delete')
              .set({
                'sharedByUserId': 'test-user-123',
                'isActive': true,
                'title': 'My Menu to Delete',
              });

          // Act
          final result = await operations.deleteSharedMenu('menu-to-delete');

          // Assert
          expect(result, isTrue);

          // Verify soft delete
          final updatedDoc = await firestore
              .collection('shared_content')
              .doc('menu-to-delete')
              .get();
          expect(updatedDoc.data()!['isActive'], isFalse);
        },
      );

      test('should not delete menu by non-owner', () async {
        // Arrange — seed FakeFirebaseFirestore
        final firestore = mockFirestoreRepository.firestore;

        await firestore.collection('shared_content').doc('menu-to-delete').set({
          'sharedByUserId': 'other-user',
          'isActive': true,
          'title': 'Someone Else Menu',
        });

        // Act
        final result = await operations.deleteSharedMenu('menu-to-delete');

        // Assert
        expect(result, isFalse);

        // Verify document was NOT modified (still active)
        final doc = await firestore
            .collection('shared_content')
            .doc('menu-to-delete')
            .get();
        expect(doc.data()!['isActive'], isTrue);
      });

      test('should mark menu as viewed', () async {
        // Arrange — seed FakeFirebaseFirestore
        final firestore = mockFirestoreRepository.firestore;

        await firestore
            .collection('user_shared_menus')
            .doc('test-user-123')
            .collection('received_menus')
            .doc('menu-to-view')
            .set({
              'sharedMenuId': 'menu-to-view',
              'isViewed': false,
            });

        // Act
        await operations.markMenuAsViewed('menu-to-view');

        // Assert
        final updatedDoc = await firestore
            .collection('user_shared_menus')
            .doc('test-user-123')
            .collection('received_menus')
            .doc('menu-to-view')
            .get();
        expect(updatedDoc.data()!['isViewed'], isTrue);
      });

      test('should get menus shared with current user', () async {
        // Arrange — seed FakeFirebaseFirestore
        final firestore = mockFirestoreRepository.firestore;

        // Create a received-menu pointer for the current user
        await firestore
            .collection('user_shared_menus')
            .doc('test-user-123')
            .collection('received_menus')
            .doc('pointer-1')
            .set({
              'sharedMenuId': 'shared-menu-123',
              'sharedAt': DateTime.now().toIso8601String(),
              'isViewed': false,
              'isImported': false,
            });

        // Create the actual shared menu document
        await firestore.collection('shared_content').doc('shared-menu-123').set(
          {
            'isActive': true,
            'title': 'Friend\'s Menu',
            'sharedByDisplayName': 'Friend Name',
            'sharedByAvatarUrl': 'https://example.com/avatar.jpg',
            'totalRecipes': 8,
            'description': 'A great menu shared by friend',
          },
        );

        // Act
        final menus = await operations.getMenusSharedWithMe();

        // Assert
        expect(menus, isA<List<Map<String, dynamic>>>());
        expect(menus.length, equals(1));
        expect(menus.first['id'], equals('shared-menu-123'));
        expect(menus.first['title'], equals('Friend\'s Menu'));
        expect(menus.first['sharedByDisplayName'], equals('Friend Name'));
        expect(menus.first['totalRecipes'], equals(8));
        expect(menus.first['isViewed'], isFalse);
        expect(menus.first['isImported'], isFalse);
      });

      // REMOVED: This test uses Recipe.fromJson which requires complete recipe data
      // and should be tested in integration tests with Firebase emulator
      /*test('should get shared menu data with recipes', () async {
        // This test attempts to parse Recipe objects from JSON which
        // requires complete recipe data structures and is better
        // suited for integration testing
      });*/

      test('should return null for non-existent shared menu', () async {
        // Act — document doesn't exist in FakeFirebaseFirestore
        final menuData = await operations.getSharedMenuData('non-existent');

        // Assert
        expect(menuData, isNull);
      });

      test('should return null for inactive shared menu', () async {
        // Arrange — seed inactive menu
        final firestore = mockFirestoreRepository.firestore;
        await firestore.collection('shared_content').doc('inactive-menu').set({
          'isActive': false,
          'sharedWithUserIds': ['test-user-123'],
          'title': 'Inactive Menu',
        });

        // Act
        final menuData = await operations.getSharedMenuData('inactive-menu');

        // Assert
        expect(menuData, isNull);
      });

      test('should return null when user has no access to menu', () async {
        // Arrange — seed menu without current user access
        final firestore = mockFirestoreRepository.firestore;
        await firestore.collection('shared_content').doc('restricted-menu').set(
          {
            'isActive': true,
            'sharedWithUserIds': ['other-user-123'],
            'title': 'Restricted Menu',
          },
        );

        // Act
        final menuData = await operations.getSharedMenuData('restricted-menu');

        // Assert
        expect(menuData, isNull);
      });

      test('should handle Firebase exceptions gracefully', () async {
        // Act — document doesn't exist, deleteSharedMenu returns false
        final result = await operations.deleteSharedMenu('any-menu');

        // Assert
        expect(result, isFalse);
      });

      test('should handle null friendUserIds gracefully', () async {
        // Act
        final result = await operations.shareMenuWithFriends(
          menu: testMenu,
          friendUserIds: [],
          message: 'Test message',
        );

        // Assert
        expect(result, isFalse);
      });

      test('should handle unauthenticated user gracefully', () async {
        // Arrange
        final mockPermissionService =
            TestServiceLocator.get<PermissionService>()
                as FakePermissionService;
        mockPermissionService.setPermissionState(
          currentUserId: null,
          userDisplayName: null,
        );

        // Act
        final shareResult = await operations.shareMenuWithFriends(
          menu: testMenu,
          friendUserIds: ['friend-1'],
        );
        final importResult = await operations.importSharedMenu('menu-123');
        final deleteResult = await operations.deleteSharedMenu('menu-123');
        final sharedByMe = await operations.getMenusSharedByMe();
        final sharedWithMe = await operations.getMenusSharedWithMe();
        final menuData = await operations.getSharedMenuData('menu-123');

        // Assert
        expect(shareResult, isFalse);
        expect(importResult, isFalse);
        expect(deleteResult, isFalse);
        expect(sharedByMe, isEmpty);
        expect(sharedWithMe, isEmpty);
        expect(menuData, isNull);

        // Restore authenticated state for other tests
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user-123',
          userDisplayName: 'Test User',
        );
      });
    });
  });
}
