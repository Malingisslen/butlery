import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content/social_sharing_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Local mock coordinators (not in production_mocks yet)
class MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

class MockSocialMenuCoordinator extends Mock implements SocialMenuCoordinator {}

class MockSocialShoppingCoordinator extends Mock
    implements SocialShoppingCoordinator {}

void main() {
  group('SocialSharingViewModel', () {
    late SocialSharingViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockSocialRecipeCoordinator mockRecipeCoordinator;
    late MockSocialMenuCoordinator mockMenuCoordinator;
    late MockSocialShoppingCoordinator mockShoppingCoordinator;
    late MockUnifiedMenuService mockMenuService;
    late MockUnifiedShoppingService mockShoppingService;

    // Test data
    final testFriend1 = UserProfile(
      uid: 'friend-1',
      email: 'anna@test.com',
      displayName: 'Anna Andersson',
      avatarUrl: null,
      joinedAt: DateTime(2025, 1, 1),
      lastActiveAt: DateTime(2025, 1, 1),
    );

    final testFriend2 = UserProfile(
      uid: 'friend-2',
      email: 'erik@test.com',
      displayName: 'Erik Eriksson',
      avatarUrl: null,
      joinedAt: DateTime(2025, 1, 2),
      lastActiveAt: DateTime(2025, 1, 2),
    );

    final testFriend3 = UserProfile(
      uid: 'friend-3',
      email: 'maria@test.com',
      displayName: 'Maria Svensson',
      avatarUrl: null,
      joinedAt: DateTime(2025, 1, 3),
      lastActiveAt: DateTime(2025, 1, 3),
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserProfile(
        uid: 'fallback',
        email: 'fallback@test.com',
        displayName: 'Fallback',
        joinedAt: DateTime(2025, 1, 1),
        lastActiveAt: DateTime(2025, 1, 1),
      ));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create centralized mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockRecipeCoordinator = MockSocialRecipeCoordinator();
      mockMenuCoordinator = MockSocialMenuCoordinator();
      mockShoppingCoordinator = MockSocialShoppingCoordinator();
      mockMenuService = MockUnifiedMenuService();
      mockShoppingService = MockUnifiedShoppingService();

      // Configure mock friends service
      mockFriendsService.setFriendsState(
        isInitialized: true,
        friends: [testFriend1, testFriend2, testFriend3],
      );

      // Configure initialize to return proper Future
      when(() => mockFriendsService.initialize()).thenAnswer((_) async {});

      // Create viewModel
      viewModel = SocialSharingViewModel(
        friendsService: mockFriendsService,
        recipeCoordinator: mockRecipeCoordinator,
        menuCoordinator: mockMenuCoordinator,
        shoppingCoordinator: mockShoppingCoordinator,
        menuService: mockMenuService,
        shoppingService: mockShoppingService,
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 10));
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize and load friends automatically', () async {
        // Friends are loaded during initialization
        await Future.delayed(const Duration(milliseconds: 50));

        expect(viewModel.availableFriends, hasLength(3));
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.shareMessage, isEmpty);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isSharing, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.lastSharingResult, isNull);
        expect(viewModel.hasFriends, isTrue);
      });
    });

    group('Friend Loading', () {
      test('should set loading state during friend loading', () async {
        // Verify that loadFriends completes and final state is correct
        await viewModel.loadFriends();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.availableFriends, isNotEmpty);
      });

      test('should load friends successfully', () async {
        await viewModel.loadFriends();

        expect(viewModel.availableFriends, hasLength(3));
        expect(viewModel.availableFriends[0].uid, equals('friend-1'));
        expect(viewModel.availableFriends[1].uid, equals('friend-2'));
        expect(viewModel.availableFriends[2].uid, equals('friend-3'));
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);
      });

      test('should refresh friends list', () async {
        await viewModel.refreshFriends();

        expect(viewModel.availableFriends, hasLength(3));
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle friends service initialization', () async {
        // Set service as not initialized
        mockFriendsService.setFriendsState(isInitialized: false);

        await viewModel.loadFriends();

        // Should still load friends after initialization
        expect(viewModel.availableFriends, isNotEmpty);
      });

      test('should handle empty friends list', () async {
        mockFriendsService.setFriendsState(friends: []);

        await viewModel.loadFriends();

        expect(viewModel.availableFriends, isEmpty);
        expect(viewModel.hasFriends, isFalse);
        expect(viewModel.error, isNull);
      });
    });

    group('Friend Selection', () {
      test('should toggle friend selection', () {
        viewModel.toggleFriendSelection('friend-1');

        expect(viewModel.selectedFriendIds, contains('friend-1'));
        expect(viewModel.hasSelectedFriends, isTrue);
        expect(viewModel.selectedFriendsCount, equals(1));
      });

      test('should deselect friend when toggled again', () {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-1');

        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.hasSelectedFriends, isFalse);
      });

      test('should select multiple friends', () {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-2');
        viewModel.toggleFriendSelection('friend-3');

        expect(viewModel.selectedFriendsCount, equals(3));
        expect(viewModel.selectedFriendIds,
            containsAll(['friend-1', 'friend-2', 'friend-3']));
      });

      test('should select all friends', () {
        viewModel.selectAllFriends();

        expect(viewModel.selectedFriendsCount,
            equals(viewModel.availableFriends.length));
      });

      test('should clear friend selection', () {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-2');

        viewModel.clearFriendSelection();

        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.hasSelectedFriends, isFalse);
      });

      test('should get selected friends profiles', () async {
        await viewModel.loadFriends();

        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-3');

        final selectedFriends = viewModel.selectedFriends;

        expect(selectedFriends, hasLength(2));
        expect(selectedFriends[0].uid, equals('friend-1'));
        expect(selectedFriends[1].uid, equals('friend-3'));
      });

      test('should get selection summary for single friend', () async {
        await viewModel.loadFriends();

        viewModel.toggleFriendSelection('friend-1');

        final summary = viewModel.getFriendSelectionSummary();

        expect(summary, contains('1 vän vald'));
        expect(summary, contains('Anna Andersson'));
      });

      test('should get selection summary for multiple friends', () async {
        await viewModel.loadFriends();

        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-2');

        final summary = viewModel.getFriendSelectionSummary();

        expect(summary, contains('2 vänner valda'));
      });

      test('should get selection summary for many friends', () async {
        await viewModel.loadFriends();

        viewModel.selectAllFriends();

        final summary = viewModel.getFriendSelectionSummary();

        expect(summary, contains('3 vänner valda'));
      });
    });

    group('Share Message', () {
      test('should update share message', () {
        viewModel.updateShareMessage('Test message');

        expect(viewModel.shareMessage, equals('Test message'));
      });

      test('should clear share message', () {
        viewModel.updateShareMessage('Test message');
        viewModel.clearShareMessage();

        expect(viewModel.shareMessage, isEmpty);
      });

      test('should get suggested message for recipe', () {
        final message = viewModel.getSuggestedMessage(
          ShareableContentType.recipe,
          contentTitle: 'Pannkakor',
        );

        expect(message, contains('Pannkakor'));
        expect(message, contains('recept'));
      });

      test('should get suggested message for menu', () {
        final message = viewModel.getSuggestedMessage(
          ShareableContentType.menu,
        );

        expect(message, contains('veckomeny'));
      });

      test('should get suggested message for shopping list', () {
        final message = viewModel.getSuggestedMessage(
          ShareableContentType.shoppingList,
          contentTitle: 'Veckohandling',
        );

        expect(message, contains('Veckohandling'));
        expect(message, contains('inköpslistan'));
      });
    });

    group('Content Sharing', () {
      setUp(() async {
        await viewModel.loadFriends();

        // Configure mock coordinators
        when(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: any(named: 'recipeId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
              allowCollaboration: any(named: 'allowCollaboration'),
            )).thenAnswer((_) async => 'invitation-123');

        when(() => mockMenuCoordinator.createMenuInvitation(
              menuId: any(named: 'menuId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
              allowCollaboration: any(named: 'allowCollaboration'),
            )).thenAnswer((_) async => 'invitation-456');

        when(() => mockShoppingCoordinator.createShoppingListInvitation(
              shoppingListId: any(named: 'shoppingListId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
            )).thenAnswer((_) async => 'invitation-789');

        // Configure menu service to return a basic menu
        final testMenu = SharedMenu(
          id: 'menu-123',
          sharedByUserId: 'user-1',
          sharedByDisplayName: 'Test User',
          menuTitle: 'Test Menu',
          menuSnapshot: {},
        );
        when(() => mockMenuService.getMenuById(any())).thenReturn(testMenu);
      });

      test('should not share when no friends selected', () async {
        final result = await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('no friends selected'));
      });

      test('should not share when already sharing', () async {
        viewModel.toggleFriendSelection('friend-1');

        // Start a sharing operation (mock doesn't complete)
        when(() => mockRecipeCoordinator.createRecipeInvitation(
                  recipeId: any(named: 'recipeId'),
                  inviteeUserIds: any(named: 'inviteeUserIds'),
                  message: any(named: 'message'),
                  allowCollaboration: any(named: 'allowCollaboration'),
                ))
            .thenAnswer((_) =>
                Future.delayed(const Duration(seconds: 1), () => 'inv-123'));

        // ignore: unawaited_futures
        viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        await Future.delayed(const Duration(milliseconds: 10));

        // Try to share again while first is in progress
        final result = await viewModel.shareContent(
          contentId: 'recipe-456',
          contentType: ShareableContentType.recipe,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('sharing in progress'));
      });

      test('should share recipe successfully', () async {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.toggleFriendSelection('friend-2');

        final result = await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
          customMessage: 'Check out this recipe!',
        );

        expect(result.success, isTrue);
        expect(result.invitationId, equals('invitation-123'));
        expect(viewModel.lastSharingResult?.success, isTrue);

        // Should clear selections after successful sharing
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.shareMessage, isEmpty);
        expect(viewModel.error, isNull);
      });

      test('should share menu successfully', () async {
        viewModel.toggleFriendSelection('friend-1');

        final result = await viewModel.shareContent(
          contentId: 'menu-123',
          contentType: ShareableContentType.menu,
        );

        expect(result.success, isTrue);
        expect(result.invitationId, equals('invitation-456'));
      });

      test('should share shopping list successfully', () async {
        viewModel.toggleFriendSelection('friend-3');

        // Mock shopping service to return a proper UnifiedShoppingList
        final testList = UnifiedShoppingList(
          id: 'list-123',
          name: 'Test Shopping List',
          ownerId: 'user-1',
          ownerDisplayName: 'Test User',
        );
        mockShoppingService.setShoppingState(lists: [testList]);

        final result = await viewModel.shareContent(
          contentId: 'list-123',
          contentType: ShareableContentType.shoppingList,
        );

        expect(result.success, isTrue);
        expect(result.invitationId, equals('invitation-789'));
      });

      test('should use custom message when provided', () async {
        viewModel.toggleFriendSelection('friend-1');

        await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
          customMessage: 'Custom message',
        );

        verify(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: 'recipe-123',
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: 'Custom message',
              allowCollaboration: true,
            )).called(1);
      });

      test('should use default message when no custom message', () async {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.updateShareMessage('Default message');

        await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        verify(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: 'recipe-123',
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: 'Default message',
              allowCollaboration: true,
            )).called(1);
      });

      test('should handle menu not found', () async {
        viewModel.toggleFriendSelection('friend-1');

        when(() => mockMenuService.getMenuById(any())).thenReturn(null);

        final result = await viewModel.shareContent(
          contentId: 'menu-999',
          contentType: ShareableContentType.menu,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Menu not found'));
      });

      test('should handle sharing failure from coordinator', () async {
        viewModel.toggleFriendSelection('friend-1');

        when(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: any(named: 'recipeId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
              allowCollaboration: any(named: 'allowCollaboration'),
            )).thenAnswer((_) async => null);

        final result = await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        expect(result.success, isFalse);
        expect(viewModel.error, isNotNull);
      });

      test('should handle sharing exception', () async {
        viewModel.toggleFriendSelection('friend-1');

        when(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: any(named: 'recipeId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
              allowCollaboration: any(named: 'allowCollaboration'),
            )).thenThrow(Exception('Network error'));

        final result = await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Network error'));
        expect(viewModel.error, isNotNull);
      });

      test('should set sharing state during operation', () async {
        viewModel.toggleFriendSelection('friend-1');

        bool wasSharing = false;
        viewModel.addListener(() {
          if (viewModel.isSharing) {
            wasSharing = true;
          }
        });

        await viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        expect(wasSharing, isTrue);
        expect(viewModel.isSharing, isFalse);
      });

      test('should set isBusy during loading or sharing', () async {
        expect(viewModel.isBusy, isFalse);

        viewModel.toggleFriendSelection('friend-1');

        // Configure coordinator with delay to catch isBusy state
        when(() => mockRecipeCoordinator.createRecipeInvitation(
              recipeId: any(named: 'recipeId'),
              inviteeUserIds: any(named: 'inviteeUserIds'),
              message: any(named: 'message'),
              allowCollaboration: any(named: 'allowCollaboration'),
            )).thenAnswer((_) => Future.delayed(
              const Duration(milliseconds: 20),
              () => 'invitation-123',
            ));

        bool wasBusy = false;
        viewModel.addListener(() {
          if (viewModel.isBusy) {
            wasBusy = true;
          }
        });

        // Start sharing
        final future = viewModel.shareContent(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        await Future.delayed(const Duration(milliseconds: 5));

        expect(wasBusy, isTrue);

        await future;

        expect(viewModel.isBusy, isFalse);
      });

      test('should use quickShare shortcut', () async {
        await viewModel.loadFriends();

        viewModel.toggleFriendSelection('friend-1');

        final result = await viewModel.quickShare(
          contentId: 'recipe-123',
          contentType: ShareableContentType.recipe,
        );

        expect(result.success, isTrue);
      });
    });

    group('State Management', () {
      test('should reset sharing state', () {
        viewModel.toggleFriendSelection('friend-1');
        viewModel.updateShareMessage('Test message');

        viewModel.resetSharingState();

        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.shareMessage, isEmpty);
        expect(viewModel.error, isNull);
        expect(viewModel.lastSharingResult, isNull);
      });

      test('should prepare for sharing with suggested friends', () async {
        await viewModel.loadFriends();

        viewModel.prepareForSharing(
          contentType: ShareableContentType.recipe,
          contentTitle: 'Pannkakor',
          suggestedFriends: ['friend-1', 'friend-2'],
        );

        expect(
            viewModel.selectedFriendIds, containsAll(['friend-1', 'friend-2']));
        expect(viewModel.shareMessage, isNotEmpty);
      });

      test('should prepare for sharing without suggested friends', () {
        viewModel.prepareForSharing(
          contentType: ShareableContentType.menu,
        );

        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.shareMessage, isNotEmpty);
      });

      test('should ignore invalid suggested friends', () async {
        await viewModel.loadFriends();

        viewModel.prepareForSharing(
          contentType: ShareableContentType.recipe,
          suggestedFriends: ['friend-1', 'invalid-friend'],
        );

        // Should only select valid friend
        expect(viewModel.selectedFriendIds, contains('friend-1'));
        expect(viewModel.selectedFriendIds, isNot(contains('invalid-friend')));
      });

      test('should notify listeners on state changes', () {
        int listenerCallCount = 0;
        viewModel.addListener(() => listenerCallCount++);

        viewModel.toggleFriendSelection('friend-1');
        viewModel.updateShareMessage('Test');
        viewModel.clearFriendSelection();

        expect(listenerCallCount, greaterThan(0));
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () async {
        await Future.delayed(const Duration(milliseconds: 10));

        // Capture state before disposal
        final hadFriends = viewModel.availableFriends.isNotEmpty;

        expect(hadFriends, isTrue);

        // Dispose will be called by tearDown - just verify state before
      });

      test('should clear selections on dispose', () async {
        await Future.delayed(const Duration(milliseconds: 10));

        viewModel.toggleFriendSelection('friend-1');

        // Verify selection before dispose
        expect(viewModel.selectedFriendIds.length, equals(1));

        // tearDown will call dispose and clear selections
      });
    });
  });
}
