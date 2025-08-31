import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/user_builder.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart' as app;

// Using centralized mocks from production_mocks.dart:
// MockUnifiedFriendsService, MockFriendsCategoriesOperations, MockFirestoreRepository,
// MockCollectionReference, MockDocumentReference, MockDocumentSnapshot, MockQuerySnapshot,
// MockQueryDocumentSnapshot, MockQuery, MockWriteBatch

void main() {
  group('SocialMenuOperations with Centralized Mocks', () {
    late SocialMenuOperations operations;
    late MockUnifiedFriendsService mockFriendsService;
    late MockFirestoreRepository mockFirestoreRepository;
    late MockCollectionReference<Map<String, dynamic>>
        mockSharedMenusCollection;
    late MockCollectionReference<Map<String, dynamic>>
        mockUserSharedMenusCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockWriteBatch mockBatch;
    late MockFriendsCategoriesOperations mockCategoriesOperations;
    // Additional typed mocks for Firestore operations
    late MockDocumentReference<Map<String, dynamic>> mockFriend1Doc;
    late MockDocumentReference<Map<String, dynamic>> mockFriend2Doc;
    late MockCollectionReference<Map<String, dynamic>> mockFriend1ReceivedMenus;
    late MockCollectionReference<Map<String, dynamic>> mockFriend2ReceivedMenus;
    late MockDocumentReference<Map<String, dynamic>> mockFriend1MenuDoc;
    late MockDocumentReference<Map<String, dynamic>> mockFriend2MenuDoc;
    // mockMenuDoc removed - unused in current tests
    late MockDocumentSnapshot<Map<String, dynamic>> mockSharedMenuDoc;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    // Additional mocks needed by various tests
    late MockDocumentReference<Map<String, dynamic>> mockUserMenusDoc;
    late MockCollectionReference<Map<String, dynamic>>
        mockReceivedMenusCollection;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FieldValue.serverTimestamp());
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create centralized mocks
      mockFirestoreRepository = MockFirestoreRepository();
      mockSharedMenusCollection =
          MockCollectionReference<Map<String, dynamic>>();
      mockUserSharedMenusCollection =
          MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockFriendsService = MockUnifiedFriendsService();
      mockCategoriesOperations = MockFriendsCategoriesOperations();
      // Initialize additional typed mocks
      mockFriend1Doc = MockDocumentReference<Map<String, dynamic>>();
      mockFriend2Doc = MockDocumentReference<Map<String, dynamic>>();
      mockFriend1ReceivedMenus =
          MockCollectionReference<Map<String, dynamic>>();
      mockFriend2ReceivedMenus =
          MockCollectionReference<Map<String, dynamic>>();
      mockFriend1MenuDoc = MockDocumentReference<Map<String, dynamic>>();
      mockFriend2MenuDoc = MockDocumentReference<Map<String, dynamic>>();
      // mockMenuDoc removed - unused in current tests
      mockSharedMenuDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      // Additional mocks for various test methods
      mockUserMenusDoc = MockDocumentReference<Map<String, dynamic>>();
      mockReceivedMenusCollection =
          MockCollectionReference<Map<String, dynamic>>();

      // MockFirestoreRepository provides FakeFirebaseFirestore
      // Configure basic mock interactions only when needed per test

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

      // Configure friends service with test friends
      mockFriendsService.setFriendsState(
        friends: [
          UserBuilder().withId('friend-1').withName('Anna').build(),
          UserBuilder().withId('friend-2').withName('Erik').build(),
        ],
      );

      // Configure categories operations with test data using configuration method
      mockCategoriesOperations.setCategoriesState(
        categoryFriends: [
          UserBuilder().withId('friend-1').withName('Friend One').build(),
          UserBuilder().withId('friend-2').withName('Friend Two').build(),
        ],
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
      test('should share menu with friends', () async {
        // Arrange - Setup nested collection structure for user shared menus
        // Using pre-declared typed mocks from setUp

        when(() => mockUserSharedMenusCollection.doc('friend-1')).thenReturn(
            mockFriend1Doc as DocumentReference<Map<String, dynamic>>);
        when(() => mockUserSharedMenusCollection.doc('friend-2')).thenReturn(
            mockFriend2Doc as DocumentReference<Map<String, dynamic>>);
        when(() => mockFriend1Doc.collection('receivedMenus')).thenReturn(
            mockFriend1ReceivedMenus
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockFriend2Doc.collection('receivedMenus')).thenReturn(
            mockFriend2ReceivedMenus
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockFriend1ReceivedMenus.doc('generated-menu-id'))
            .thenReturn(
                mockFriend1MenuDoc as DocumentReference<Map<String, dynamic>>);
        when(() => mockFriend2ReceivedMenus.doc('generated-menu-id'))
            .thenReturn(
                mockFriend2MenuDoc as DocumentReference<Map<String, dynamic>>);

        // Act
        final result = await operations.shareMenuWithFriends(
          menu: testMenu,
          friendUserIds: ['friend-1', 'friend-2'],
          message: 'Check out my weekly menu!',
          customTitle: 'Weekly Menu Plan',
        );

        // Assert
        expect(result, isTrue);

        // Verify the shared menu document was created
        verify(() => mockDocRef.set(any())).called(1);

        // Verify batch commit was called
        verify(() => mockBatch.commit()).called(1);
      });

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

        // Verify no Firebase operations were called
        verifyNever(() => mockDocRef.set(any()));
        verifyNever(() => mockBatch.commit());
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

        // Verify no Firebase operations were called
        verifyNever(() => mockDocRef.set(any()));
        verifyNever(() => mockBatch.commit());
      });
    });

    group('Menu Sharing with Groups', () {
      test('should share menu with friend category', () async {
        // Arrange - Setup for friend category sharing
        // Using pre-declared typed mocks from setUp

        when(() => mockUserSharedMenusCollection.doc('friend-1')).thenReturn(
            mockFriend1Doc as DocumentReference<Map<String, dynamic>>);
        when(() => mockUserSharedMenusCollection.doc('friend-2')).thenReturn(
            mockFriend2Doc as DocumentReference<Map<String, dynamic>>);
        when(() => mockFriend1Doc.collection('receivedMenus')).thenReturn(
            mockFriend1ReceivedMenus
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockFriend2Doc.collection('receivedMenus')).thenReturn(
            mockFriend2ReceivedMenus
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockFriend1ReceivedMenus.doc('generated-menu-id'))
            .thenReturn(
                mockFriend1MenuDoc as DocumentReference<Map<String, dynamic>>);
        when(() => mockFriend2ReceivedMenus.doc('generated-menu-id'))
            .thenReturn(
                mockFriend2MenuDoc as DocumentReference<Map<String, dynamic>>);

        // Act
        final result = await operations.shareMenuWithGroup(
          menu: testMenu,
          categoryId: 'family-category',
          message: 'Family dinner menu',
          customTitle: 'Family Meals',
        );

        // Assert
        expect(result, isTrue);

        // Verify the operations were called
        verify(() => mockDocRef.set(any())).called(1);
        verify(() => mockBatch.commit()).called(1);
      });

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

        // Verify no Firebase operations were called
        verifyNever(() => mockDocRef.set(any()));
        verifyNever(() => mockBatch.commit());
      });
    });

    group('Shared Menu Management', () {
      test('should get menus shared by current user', () async {
        // Arrange
        // Using pre-declared typed mocks from setUp
        final mockDocSnapshot =
            MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(() => mockSharedMenusCollection.where('sharedByUserId',
                isEqualTo: 'test-user-123'))
            .thenReturn(mockQuery as Query<Map<String, dynamic>>);
        when(() => mockQuery.where('isActive', isEqualTo: true))
            .thenReturn(mockQuery as Query<Map<String, dynamic>>);
        when(() => mockQuery.orderBy('sharedAt', descending: true))
            .thenReturn(mockQuery as Query<Map<String, dynamic>>);
        when(() => mockQuery.get()).thenAnswer((_) async =>
            mockQuerySnapshot as QuerySnapshot<Map<String, dynamic>>);

        when(() => mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);
        when(() => mockDocSnapshot.id).thenReturn('menu-id-1');
        when(() => mockDocSnapshot.data()).thenReturn({
          'title': 'My Menu',
          'sharedAt': DateTime.now().toIso8601String(),
          'totalRecipes': 5,
          'sharedWithUserIds': ['friend-1'],
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

      test('should import shared menu', () async {
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();
        final mockUserMenusDoc = MockDocumentReference();
        final mockReceivedMenusCollection = MockCollectionReference();
        final mockReceivedMenuDoc = MockDocumentReference();

        when(() => mockSharedMenusCollection.doc('menu-to-import'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(true);
        when(() => mockMenuDoc.data()).thenReturn({
          'sharedWithUserIds': ['test-user-123'],
          'title': 'Menu to Import',
        });

        when(() => mockUserSharedMenusCollection.doc('test-user-123'))
            .thenReturn(
                mockUserMenusDoc as DocumentReference<Map<String, dynamic>>);
        when(() => mockUserMenusDoc.collection('receivedMenus')).thenReturn(
            mockReceivedMenusCollection
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockReceivedMenusCollection.doc('menu-to-import'))
            .thenReturn(mockReceivedMenuDoc);
        when(() => mockReceivedMenuDoc.update(any())).thenAnswer((_) async {});

        // Act
        final result = await operations.importSharedMenu('menu-to-import');

        // Assert
        expect(result, isTrue);

        // Verify update was called
        verify(() => mockReceivedMenuDoc.update(any())).called(1);
      });

      test('should delete shared menu by owner', () async {
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();

        when(() => mockSharedMenusCollection.doc('menu-to-delete'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(true);
        when(() => mockMenuDoc.data()).thenReturn({
          'sharedByUserId': 'test-user-123',
          'isActive': true,
          'title': 'My Menu to Delete',
        });
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        // Act
        final result = await operations.deleteSharedMenu('menu-to-delete');

        // Assert
        expect(result, isTrue);

        // Verify soft delete update was called
        verify(() => mockDocRef.update(any())).called(1);
      });

      test('should not delete menu by non-owner', () async {
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();

        when(() => mockSharedMenusCollection.doc('menu-to-delete'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(true);
        when(() => mockMenuDoc.data()).thenReturn({
          'sharedByUserId': 'other-user',
          'isActive': true,
          'title': 'Someone Else Menu',
        });

        // Act
        final result = await operations.deleteSharedMenu('menu-to-delete');

        // Assert
        expect(result, isFalse);

        // Verify no update was called
        verifyNever(() => mockDocRef.update(any()));
      });

      test('should mark menu as viewed', () async {
        // Arrange
        final mockUserMenusDoc = MockDocumentReference();
        final mockReceivedMenusCollection = MockCollectionReference();
        final mockReceivedMenuDoc = MockDocumentReference();

        when(() => mockUserSharedMenusCollection.doc('test-user-123'))
            .thenReturn(
                mockUserMenusDoc as DocumentReference<Map<String, dynamic>>);
        when(() => mockUserMenusDoc.collection('receivedMenus')).thenReturn(
            mockReceivedMenusCollection
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockReceivedMenusCollection.doc('menu-to-view'))
            .thenReturn(mockReceivedMenuDoc);
        when(() => mockReceivedMenuDoc.update(any())).thenAnswer((_) async {});

        // Act
        await operations.markMenuAsViewed('menu-to-view');

        // Assert
        final captured =
            verify(() => mockReceivedMenuDoc.update(captureAny())).captured;
        expect(captured.length, equals(1));
        final updateData = Map<String, dynamic>.from(captured.first as Map);
        expect(updateData['isViewed'], isTrue);
        expect(updateData['viewedAt'], isA<FieldValue>());
      });

      test('should get menus shared with current user', () async {
        // Arrange
        // Using pre-declared typed mocks from setUp
        final mockReceivedDoc =
            MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(() => mockUserSharedMenusCollection.doc('test-user-123'))
            .thenReturn(
                mockUserMenusDoc as DocumentReference<Map<String, dynamic>>);
        when(() => mockUserMenusDoc.collection('receivedMenus')).thenReturn(
            mockReceivedMenusCollection
                as CollectionReference<Map<String, dynamic>>);
        when(() => mockReceivedMenusCollection.orderBy('sharedAt',
            descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async =>
            mockQuerySnapshot as QuerySnapshot<Map<String, dynamic>>);

        when(() => mockQuerySnapshot.docs).thenReturn([mockReceivedDoc]);
        when(() => mockReceivedDoc.data()).thenReturn({
          'sharedMenuId': 'shared-menu-123',
          'sharedAt': DateTime.now().toIso8601String(),
          'isViewed': false,
          'isImported': false,
        });

        when(() => mockSharedMenusCollection.doc('shared-menu-123'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer((_) async =>
            mockSharedMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockSharedMenuDoc.exists).thenReturn(true);
        when(() => mockSharedMenuDoc.data()).thenReturn({
          'isActive': true,
          'title': 'Friend\'s Menu',
          'sharedByDisplayName': 'Friend Name',
          'sharedByAvatarUrl': 'https://example.com/avatar.jpg',
          'totalRecipes': 8,
          'description': 'A great menu shared by friend',
        });

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
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();

        when(() => mockSharedMenusCollection.doc('non-existent'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(false);

        // Act
        final menuData = await operations.getSharedMenuData('non-existent');

        // Assert
        expect(menuData, isNull);
      });

      test('should return null for inactive shared menu', () async {
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();

        when(() => mockSharedMenusCollection.doc('inactive-menu'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(true);
        when(() => mockMenuDoc.data()).thenReturn({
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
        // Arrange
        final mockMenuDoc = MockDocumentSnapshot();

        when(() => mockSharedMenusCollection.doc('restricted-menu'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer(
            (_) async => mockMenuDoc as DocumentSnapshot<Map<String, dynamic>>);
        when(() => mockMenuDoc.exists).thenReturn(true);
        when(() => mockMenuDoc.data()).thenReturn({
          'isActive': true,
          'sharedWithUserIds': ['other-user-123'], // Current user not in list
          'title': 'Restricted Menu',
        });

        // Act
        final menuData = await operations.getSharedMenuData('restricted-menu');

        // Assert
        expect(menuData, isNull);
      });

      test('should handle Firebase exceptions gracefully', () async {
        // Arrange
        when(() => mockSharedMenusCollection.doc(any())).thenThrow(
            FirebaseException(plugin: 'firestore', code: 'permission-denied'));

        // Act
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
                as MockPermissionService;
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
