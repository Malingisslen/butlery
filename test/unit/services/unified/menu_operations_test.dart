/// Comprehensive unit tests for Menu Operations
///
/// Tests the collaborative and social menu operations coordinators that handle
/// menu sharing, collaboration, ratings, comments, templates, and social features.
library;

// ignore_for_file: undefined_method

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_menu_operations.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/user_profile.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Using centralized mocks from production_mocks.dart:
// MockFriendsCategoriesOperations, MockFirebaseFirestore, MockCollectionReference, MockDocumentReference,
// MockDocumentSnapshot, MockQuerySnapshot, MockQueryDocumentSnapshot, MockWriteBatch, MockUnifiedMenuService

void main() {
  group('Menu Operations', () {
    late CollaborativeMenuOperations collaborativeOps;
    late SocialMenuOperations socialOps;
    late MockFirebaseFirestore mockFirestore;
    late MockPermissionService mockPermissionService;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUnifiedMenuService mockParent;
    late Recipe testRecipe;
    late Map<String, List<Recipe>> testMenu;
    late UserProfile testUser;
    late UserProfile testFriend;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(SharedMenu.create(
        sharedByUserId: 'test',
        sharedByDisplayName: 'Test',
        sharedToUserIds: [],
        menuTitle: 'Test',
        menuSnapshot: {},
      ));
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      mockFirestore = MockFirebaseFirestore();
      mockFriendsService = MockUnifiedFriendsService();
      mockParent = MockUnifiedMenuService();

      // Initialize TestServiceLocator
      await TestServiceLocator.initialize();

      // Get the existing permission service mock that was registered during initialization
      // This ensures production code uses the same instance we're configuring
      mockPermissionService =
          TestServiceLocator.get<PermissionService>() as MockPermissionService;

      final mockMenuCollaborationRepo = MockMenuCollaborationRepository();
      collaborativeOps = CollaborativeMenuOperations(
        notifyListeners: (mockParent as UnifiedMenuService).triggerNotification,
        repository: mockMenuCollaborationRepo,
      );
      socialOps = SocialMenuOperations(
        firestore: mockFirestore,
        friendsService: mockFriendsService,
      );

      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
      );

      testMenu = {
        'Huvudrätt': [testRecipe],
        'Förrätt': [],
      };

      testUser = UserProfile(
        uid: 'test-user',
        displayName: 'Test User',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      testFriend = UserProfile(
        uid: 'friend-1',
        displayName: 'Friend One',
        email: 'friend@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Configure mock permission service using state methods
      mockPermissionService.setPermissionState(
        currentUserId: testUser.uid,
        userDisplayName: testUser.displayName,
        defaultHasPermission: true,
      );

      // Debug: Verify the mock is configured correctly
      print('Mock userId: ${mockPermissionService.currentUserId}');
      print(
          'Mock displayName: ${mockPermissionService.currentUserDisplayName}');

      // Setup mock friends service
      mockFriendsService.setFriendsState(
        friends: [testFriend],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('CollaborativeMenuOperations', () {
      group('Real-time Menu Collaboration', () {
        test('should enable menu collaboration', () async {
          // Arrange
          final mockCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

          when(() => mockFirestore.collection('shared_menus'))
              .thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.update(any())).thenAnswer((_) async {});

          // Mock the snapshots() method that's called by _startMenuCollaborationListener
          when(() => mockDoc.snapshots())
              .thenAnswer((_) => Stream.value(mockSnapshot));
          when(() => mockSnapshot.exists).thenReturn(true);

          // Act
          final success = await collaborativeOps.enableMenuCollaboration(
            menuId: 'menu-1',
            collaboratorIds: ['user-1', 'user-2'],
            collaboratorDisplayNames: {
              'user-1': 'Anna',
              'user-2': 'Erik',
            },
          );

          // Assert
          expect(success, isTrue);
          verify(() => mockDoc.update(any())).called(1);
        });

        test('should add recipe to collaborative menu', () async {
          // Arrange
          final mockCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

          when(() => mockFirestore.collection('shared_menus'))
              .thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.get()).thenAnswer((_) async => mockDocSnapshot);
          when(() => mockDocSnapshot.exists).thenReturn(true);
          when(() => mockDocSnapshot.data()).thenReturn({
            'sharedByUserId': 'test-user',
            'allowCollaboration': true,
            'collaboratorIds': ['test-user'],
          });
          when(() => mockDoc.update(any())).thenAnswer((_) async {});

          final mockActivityCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockActivityDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockActivitiesCollection =
              MockCollectionReference<Map<String, dynamic>>();

          when(() => mockFirestore.collection('menu_activity'))
              .thenReturn(mockActivityCollection);
          when(() => mockActivityCollection.doc(any()))
              .thenReturn(mockActivityDoc);
          when(() => mockActivityDoc.collection('activities'))
              .thenReturn(mockActivitiesCollection);
          when(() => mockActivitiesCollection.add(any()))
              .thenAnswer((_) async => mockActivityDoc);

          // Act
          final success = await collaborativeOps.addRecipeToCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipe: testRecipe,
            suggestion: 'Perfekt för helgen!',
          );

          // Assert
          expect(success, isTrue);
        });

        test('should remove recipe from collaborative menu', () async {
          // Arrange
          final mockCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

          when(() => mockFirestore.collection('shared_menus'))
              .thenReturn(mockCollection);
          when(() => mockCollection.doc(any())).thenReturn(mockDoc);
          when(() => mockDoc.get()).thenAnswer((_) async => mockDocSnapshot);
          when(() => mockDocSnapshot.exists).thenReturn(true);
          when(() => mockDocSnapshot.data()).thenReturn({
            'sharedByUserId': 'test-user',
            'allowCollaboration': true,
            'collaboratorIds': ['test-user'],
            'menuSnapshot': {
              'Huvudrätt': [testRecipe.toFirestore()],
            },
          });
          when(() => mockDoc.update(any())).thenAnswer((_) async {});

          final mockActivityCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockActivityDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockActivitiesCollection =
              MockCollectionReference<Map<String, dynamic>>();

          when(() => mockFirestore.collection('menu_activity'))
              .thenReturn(mockActivityCollection);
          when(() => mockActivityCollection.doc(any()))
              .thenReturn(mockActivityDoc);
          when(() => mockActivityDoc.collection('activities'))
              .thenReturn(mockActivitiesCollection);
          when(() => mockActivitiesCollection.add(any()))
              .thenAnswer((_) async => mockActivityDoc);

          // Act
          final success =
              await collaborativeOps.removeRecipeFromCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipeId: 'test-recipe-1',
            reason: 'Changed plans',
          );

          // Assert
          expect(success, isTrue);
        });

        test('should fail if user not authenticated', () async {
          // Arrange
          mockPermissionService.setPermissionState(
            currentUserId: null,
            defaultHasPermission: false,
          );

          final mockMenuCollaborationRepo = MockMenuCollaborationRepository();
          mockMenuCollaborationRepo.setRepositoryState(defaultSuccess: false);
          final unauthenticatedOps = CollaborativeMenuOperations(
            notifyListeners:
                (mockParent as UnifiedMenuService).triggerNotification,
            repository: mockMenuCollaborationRepo,
          );

          // Act
          final success = await unauthenticatedOps.enableMenuCollaboration(
            menuId: 'menu-1',
            collaboratorIds: ['user-1'],
          );

          // Assert
          expect(success, isFalse);
        });
      });

      group('Resource Management', () {
        test('should dispose resources properly', () {
          // Act & Assert (no error thrown)
          collaborativeOps.dispose();
        });
      });
    });

    group('SocialMenuOperations', () {
      group('Friend-Based Menu Sharing', () {
        test('should share menu with friends', () async {
          // Arrange
          final mockSharedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockSharedMenuDoc =
              MockDocumentReference<Map<String, dynamic>>();
          final mockBatch = MockWriteBatch();

          when(() => mockFirestore.collection('sharedMenus'))
              .thenReturn(mockSharedMenusCollection);
          when(() => mockSharedMenusCollection.doc())
              .thenReturn(mockSharedMenuDoc);
          when(() => mockSharedMenuDoc.id).thenReturn('shared-menu-1');
          when(() => mockSharedMenuDoc.set(any())).thenAnswer((_) async {});
          when(() => mockFirestore.batch()).thenReturn(mockBatch);
          when(() => mockBatch.commit()).thenAnswer((_) async {});

          final mockUserSharedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockUserDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockReceivedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockReceivedMenuDoc =
              MockDocumentReference<Map<String, dynamic>>();

          when(() => mockFirestore.collection('userSharedMenus'))
              .thenReturn(mockUserSharedMenusCollection);
          when(() => mockUserSharedMenusCollection.doc(any()))
              .thenReturn(mockUserDoc);
          when(() => mockUserDoc.collection('receivedMenus'))
              .thenReturn(mockReceivedMenusCollection);
          when(() => mockReceivedMenusCollection.doc(any()))
              .thenReturn(mockReceivedMenuDoc);
          when(() => mockBatch.set(mockReceivedMenuDoc, any()))
              .thenReturn(null);

          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
            message: 'Check out this menu!',
            customTitle: 'Weekly Menu',
          );

          // Assert
          expect(success, isTrue);
        });

        test('should fail sharing empty menu', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: {},
            friendUserIds: ['friend-1'],
          );

          // Assert
          expect(success, isFalse);
        });

        test('should fail sharing with no friends', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: [],
          );

          // Assert
          expect(success, isFalse);
        });

        test('should validate friend IDs', () async {
          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['invalid-friend-id'],
          );

          // Assert
          expect(success, isFalse);
        });

        test('should fail if not authenticated', () async {
          // Arrange
          // Configure as unauthenticated
          mockPermissionService.setPermissionState(
            currentUserId: null,
            userDisplayName: null,
          );

          // Act
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
          );

          // Assert
          expect(success, isFalse);
        });
      });

      group('Group Menu Sharing', () {
        test('should share menu with group', () async {
          // Arrange
          final mockCategories = MockFriendsCategoriesOperations();
          mockCategories.setCategoriesState(categoryFriends: [testFriend]);
          when(() => mockFriendsService.categories).thenReturn(mockCategories);

          final mockSharedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockSharedMenuDoc =
              MockDocumentReference<Map<String, dynamic>>();
          final mockBatch = MockWriteBatch();

          when(() => mockFirestore.collection('sharedMenus'))
              .thenReturn(mockSharedMenusCollection);
          when(() => mockSharedMenusCollection.doc())
              .thenReturn(mockSharedMenuDoc);
          when(() => mockSharedMenuDoc.id).thenReturn('shared-menu-1');
          when(() => mockSharedMenuDoc.set(any())).thenAnswer((_) async {});
          when(() => mockFirestore.batch()).thenReturn(mockBatch);
          when(() => mockBatch.commit()).thenAnswer((_) async {});

          final mockUserSharedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockUserDoc = MockDocumentReference<Map<String, dynamic>>();
          final mockReceivedMenusCollection =
              MockCollectionReference<Map<String, dynamic>>();
          final mockReceivedMenuDoc =
              MockDocumentReference<Map<String, dynamic>>();

          when(() => mockFirestore.collection('userSharedMenus'))
              .thenReturn(mockUserSharedMenusCollection);
          when(() => mockUserSharedMenusCollection.doc(any()))
              .thenReturn(mockUserDoc);
          when(() => mockUserDoc.collection('receivedMenus'))
              .thenReturn(mockReceivedMenusCollection);
          when(() => mockReceivedMenusCollection.doc(any()))
              .thenReturn(mockReceivedMenuDoc);
          when(() => mockBatch.set(mockReceivedMenuDoc, any()))
              .thenReturn(null);

          // Act
          final success = await socialOps.shareMenuWithGroup(
            menu: testMenu,
            categoryId: 'family',
            message: 'Family dinner menu',
          );

          // Assert
          expect(success, isTrue);
        });
      });
    });
  });
}
