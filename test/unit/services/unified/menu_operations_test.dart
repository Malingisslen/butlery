/// Unit tests for Menu Operations (collaborative + social).
///
/// Tests the collaborative and social menu operations coordinators that
/// handle menu sharing, collaboration and social features. Firestore
/// interactions run against `FakeFirebaseFirestore`; mocktail mocks are
/// reserved for service interfaces (UnifiedFriendsService, etc.).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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

void main() {
  group('Menu Operations', () {
    late CollaborativeMenuOperations collaborativeOps;
    late SocialMenuOperations socialOps;
    late FakeFirebaseFirestore fakeFirestore;
    late FakePermissionService mockPermissionService;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUnifiedMenuService mockParent;
    late MockMenuCollaborationRepository mockMenuCollaborationRepo;
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
      fakeFirestore = FakeFirebaseFirestore();
      mockFriendsService = MockUnifiedFriendsService();
      mockParent = MockUnifiedMenuService();

      await TestServiceLocator.initialize();

      mockPermissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;

      mockMenuCollaborationRepo = MockMenuCollaborationRepository();
      collaborativeOps = CollaborativeMenuOperations(
        notifyListeners: (mockParent as UnifiedMenuService).triggerNotification,
        repository: mockMenuCollaborationRepo,
      );
      socialOps = SocialMenuOperations(
        firestore: fakeFirestore,
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

      mockPermissionService.setPermissionState(
        currentUserId: testUser.uid,
        userDisplayName: testUser.displayName,
        defaultHasPermission: true,
      );

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
          // The repository's stub default is `true`; no extra setup required.
          final success = await collaborativeOps.enableMenuCollaboration(
            menuId: 'menu-1',
            collaboratorIds: ['user-1', 'user-2'],
            collaboratorDisplayNames: {
              'user-1': 'Anna',
              'user-2': 'Erik',
            },
          );

          expect(success, isTrue);
        });

        test('should add recipe to collaborative menu', () async {
          final success = await collaborativeOps.addRecipeToCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipe: testRecipe,
            suggestion: 'Perfekt för helgen!',
          );

          expect(success, isTrue);
        });

        test('should remove recipe from collaborative menu', () async {
          final success =
              await collaborativeOps.removeRecipeFromCollaborativeMenu(
            menuId: 'menu-1',
            category: 'Huvudrätt',
            recipeId: 'test-recipe-1',
            reason: 'Changed plans',
          );

          expect(success, isTrue);
        });
      });

      group('Resource Management', () {
        test('should dispose resources properly', () {
          collaborativeOps.dispose();
        });
      });
    });

    group('SocialMenuOperations', () {
      group('Friend-Based Menu Sharing', () {
        test('should fail sharing empty menu', () async {
          final success = await socialOps.shareMenuWithFriends(
            menu: {},
            friendUserIds: ['friend-1'],
          );

          expect(success, isFalse);

          // No shared_content docs should have been written.
          final sharedDocs =
              await fakeFirestore.collection('shared_content').get();
          expect(sharedDocs.docs, isEmpty);
        });

        test('should fail sharing with no friends', () async {
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: [],
          );

          expect(success, isFalse);
        });

        test('should validate friend IDs', () async {
          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['invalid-friend-id'],
          );

          expect(success, isFalse);
          final sharedDocs =
              await fakeFirestore.collection('shared_content').get();
          expect(sharedDocs.docs, isEmpty);
        });

        test('should fail if not authenticated', () async {
          mockPermissionService.setPermissionState(
            currentUserId: null,
            userDisplayName: null,
          );

          final success = await socialOps.shareMenuWithFriends(
            menu: testMenu,
            friendUserIds: ['friend-1'],
          );

          expect(success, isFalse);
        });
      });
    });
  });
}
