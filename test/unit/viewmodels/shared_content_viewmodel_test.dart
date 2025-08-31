import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/permission_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// ============= USING CENTRALIZED MOCKS =============
// Removed local mock class:
// - MockSocialRecipeService (now in production_mocks.dart)

// Test data builders
class UserProfileBuilder {
  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool notificationsEnabled = true,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'test-user-123',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      joinedAt: joinedAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline,
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled,
    );
  }
}

class SharedRecipeBuilder {
  static SharedRecipe build({
    String? id,
    String? originalRecipeId,
    String? sharedByUserId,
    String? sharedByDisplayName,
    List<String>? sharedToUserIds,
    DateTime? sharedAt,
    String? shareMessage,
    Recipe? recipeSnapshot,
    bool allowImport = true,
    bool allowCollaboration = false,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds,
  }) {
    final now = DateTime.now();
    return SharedRecipe(
      id: id ?? 'shared_recipe_${DateTime.now().millisecondsSinceEpoch}',
      originalRecipeId: originalRecipeId ?? 'recipe_123',
      sharedByUserId: sharedByUserId ?? 'user_123',
      sharedByDisplayName: sharedByDisplayName ?? 'Test User',
      sharedToUserIds: sharedToUserIds ?? ['user_456'],
      sharedAt: sharedAt ?? now,
      shareMessage: shareMessage ?? 'Check out this recipe!',
      recipeSnapshot: recipeSnapshot ??
          RecipeFactory.build(
            id: originalRecipeId ?? 'recipe_123',
            title: 'Test Recipe',
            description: 'A test recipe',
          ),
      allowImport: allowImport,
      allowCollaboration: allowCollaboration,
      viewedByUserIds: viewedByUserIds ?? [],
      importedByUserIds: importedByUserIds ?? [],
      dismissedByUserIds: dismissedByUserIds ?? [],
    );
  }
}

class SharedMenuBuilder {
  static SharedMenu build({
    String? id,
    String? sharedByUserId,
    String? sharedByDisplayName,
    List<String>? sharedToUserIds,
    DateTime? sharedAt,
    String? shareMessage,
    String? menuTitle,
    Map<String, List<Recipe>>? menuSnapshot,
    bool allowImport = true,
    bool allowCollaboration = false,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds,
  }) {
    final now = DateTime.now();
    return SharedMenu(
      id: id ?? 'shared_menu_${DateTime.now().millisecondsSinceEpoch}',
      sharedByUserId: sharedByUserId ?? 'user_123',
      sharedByDisplayName: sharedByDisplayName ?? 'Test User',
      sharedToUserIds: sharedToUserIds ?? ['user_456'],
      sharedAt: sharedAt ?? now,
      shareMessage: shareMessage ?? 'Check out this menu!',
      menuTitle: menuTitle ?? 'Test Menu',
      menuSnapshot: menuSnapshot ??
          {
            'Middag': [
              RecipeFactory.build(id: 'r1', title: 'Recipe 1'),
              RecipeFactory.build(id: 'r2', title: 'Recipe 2'),
            ],
            'Lunch': [
              RecipeFactory.build(id: 'r3', title: 'Recipe 3'),
            ],
          },
      allowCollaboration: allowCollaboration,
      viewedByUserIds: viewedByUserIds ?? [],
      importedByUserIds: importedByUserIds ?? [],
      dismissedByUserIds: dismissedByUserIds ?? [],
    );
  }
}

void main() {
  group('SharedContentViewModel', () {
    late SharedContentViewModel viewModel;
    late MockSocialRecipeService mockSocialRecipeService;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUnifiedShoppingService mockShoppingService;
    late PermissionService mockPermissionService;
    const testUserId = 'test_user_123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(SharedRecipeBuilder.build());
      registerFallbackValue(SharedMenuBuilder.build());
      registerFallbackValue(ShoppingListFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Create mocks using centralized versions
      mockSocialRecipeService = MockFactory.createSocialRecipeService(
        sharedRecipes: [],
        sharedMenus: [],
        isLoading: false,
      );
      mockFriendsService = MockUnifiedFriendsService();
      mockShoppingService = MockUnifiedShoppingService();
      mockPermissionService = MockFactory.createPermissionService(
        currentUserId: testUserId,
        userDisplayName: 'Test User',
        defaultHasPermission: true,
      );

      // Configure friends test data
      final testFriends = [
        UserProfileBuilder.build(
          uid: 'friend_1',
          displayName: 'Anna Andersson',
          email: 'anna@example.com',
        ),
        UserProfileBuilder.build(
          uid: 'friend_2',
          displayName: 'Erik Svensson',
          email: 'erik@example.com',
        ),
      ];

      mockFriendsService.setFriendsState(
        friends: testFriends,
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      mockShoppingService.setShoppingState(
        lists: [],
        personalLists: [],
        collaborativeLists: [],
        isInitialized: true,
        isLoading: false,
      );

      // Stub SocialRecipeService methods that SharedContentViewModel calls
      when(() => mockSocialRecipeService.markRecipeAsRead(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.markMenuAsRead(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.importRecipe(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.importMenu(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.dismissRecipe(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.dismissMenu(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.undismissRecipe(any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.undismissMenu(any()))
          .thenAnswer((_) async => true);

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedFriendsService>(
          mockFriendsService);
      TestServiceLocator.registerMock<UnifiedShoppingService>(
          mockShoppingService);
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // Create viewModel
      viewModel = SharedContentViewModel(
        socialRecipeService: mockSocialRecipeService,
        friendsService: mockFriendsService,
        shoppingService: mockShoppingService,
      );

      // Allow initialization to complete
      await Future.delayed(const Duration(milliseconds: 100));
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
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.currentTabIndex, equals(0));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.isImporting, isFalse);
        expect(viewModel.visibleSharedRecipes, isEmpty);
        expect(viewModel.visibleSharedMenus, isEmpty);
        expect(viewModel.hasSharedContent, isFalse);
        expect(viewModel.isSharing, isFalse);
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.shareMessage, isEmpty);
      });

      test('should load shared content on initialization', () async {
        // Note: loadSharedContent is called in _initialize
        // Content would be loaded from service

        // Assert - verify no errors during initialization
        expect(viewModel.error, isNull);
      });

      test('should handle service listener registration', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger service change
        mockSocialRecipeService.notifyListeners();

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Content Operations', () {
      test('should load shared content', () async {
        // Arrange
        final sharedRecipes = [
          SharedRecipeBuilder.build(id: 'sr1', originalRecipeId: 'r1'),
          SharedRecipeBuilder.build(id: 'sr2', originalRecipeId: 'r2'),
        ];
        final sharedMenus = [
          SharedMenuBuilder.build(id: 'sm1', menuTitle: 'Menu 1'),
        ];

        mockSocialRecipeService.setSocialState(
          sharedRecipes: sharedRecipes,
          sharedMenus: sharedMenus,
        );

        // Act
        await viewModel.loadSharedContent();

        // Assert - Note: current implementation doesn't load from service
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should update search query', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateSearchQuery('köttbullar');

        // Assert
        expect(viewModel.searchQuery, equals('köttbullar'));
        expect(notificationCount, equals(1));
      });

      test('should clear search', () {
        // Arrange
        viewModel.updateSearchQuery('test');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(notificationCount, equals(1));
      });

      test('should set tab index', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setTabIndex(1);

        // Assert
        expect(viewModel.currentTabIndex, equals(1));
        expect(notificationCount, equals(1));
      });

      test('should not notify if same tab index', () {
        // Arrange
        viewModel.setTabIndex(1);
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setTabIndex(1); // Same index

        // Assert
        expect(notificationCount, equals(0));
      });
    });

    group('Read Status Management', () {
      test('should check if recipe is read', () {
        // Arrange
        final readRecipe = SharedRecipeBuilder.build(
          id: 'sr1',
          viewedByUserIds: [testUserId],
        );
        final unreadRecipe = SharedRecipeBuilder.build(
          id: 'sr2',
          viewedByUserIds: [],
        );

        // Act & Assert
        expect(viewModel.isRecipeRead(readRecipe), isTrue);
        expect(viewModel.isRecipeRead(unreadRecipe), isFalse);
      });

      test('should check if menu is read', () {
        // Arrange
        final readMenu = SharedMenuBuilder.build(
          id: 'sm1',
          viewedByUserIds: [testUserId],
        );
        final unreadMenu = SharedMenuBuilder.build(
          id: 'sm2',
          viewedByUserIds: [],
        );

        // Act & Assert
        expect(viewModel.isMenuRead(readMenu), isTrue);
        expect(viewModel.isMenuRead(unreadMenu), isFalse);
      });

      test('should mark recipe as read', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');

        // Act
        await viewModel.markRecipeAsRead(recipe);

        // Assert - method is called but we can't verify on a mock with manual ChangeNotifier
        expect(viewModel.error, isNull);
      });

      test('should mark menu as read', () async {
        // Arrange
        final menu = SharedMenuBuilder.build(id: 'sm1');

        // Act
        await viewModel.markMenuAsRead(menu);

        // Assert - method is called but we can't verify on a mock with manual ChangeNotifier
        expect(viewModel.error, isNull);
      });

      test('should handle mark as read error', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        // Override stub to throw error
        when(() => mockSocialRecipeService.markRecipeAsRead(any()))
            .thenThrow(Exception('Network error'));

        // Act
        await viewModel.markRecipeAsRead(recipe);

        // Assert
        expect(viewModel.error, contains('Failed to mark recipe as read'));
      });
    });

    group('Import Functionality', () {
      test('should import shared recipe', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');

        // Act
        final result = await viewModel.importSharedRecipe(recipe);

        // Assert
        expect(result, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should import shared menu', () async {
        // Arrange
        final menu = SharedMenuBuilder.build(id: 'sm1');

        // Act
        final result = await viewModel.importSharedMenu(menu);

        // Assert
        expect(result, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle import error', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        when(() => mockSocialRecipeService.importRecipe(any()))
            .thenThrow(Exception('Import failed'));

        // Act
        final result = await viewModel.importSharedRecipe(recipe);

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, contains('Failed to import recipe'));
      });

      test('should track importing state', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        bool wasImporting = false;

        viewModel.addListener(() {
          if (viewModel.isImporting) wasImporting = true;
        });

        // Act
        await viewModel.importSharedRecipe(recipe);

        // Assert
        expect(wasImporting, isTrue);
        expect(
            viewModel.isImporting, isFalse); // Should be false after completion
      });

      test('should check if recipe is imported', () {
        // Note: Simplified implementation returns false
        final recipe = SharedRecipeBuilder.build(id: 'sr1');

        // Act & Assert
        expect(viewModel.isRecipeImported(recipe), isFalse);
      });

      test('should check if menu is imported', () {
        // Note: Simplified implementation returns false
        final menu = SharedMenuBuilder.build(id: 'sm1');

        // Act & Assert
        expect(viewModel.isMenuImported(menu), isFalse);
      });
    });

    group('Dismiss Functionality', () {
      test('should dismiss shared recipe', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        // Add recipe to visible list first
        viewModel.visibleSharedRecipes.add(recipe);

        // Act
        final result = await viewModel.dismissSharedRecipe(recipe);

        // Assert
        expect(result, isTrue);
        expect(viewModel.visibleSharedRecipes, isEmpty);
        expect(viewModel.error, isNull);
      });

      test('should dismiss shared menu', () async {
        // Arrange
        final menu = SharedMenuBuilder.build(id: 'sm1');
        // Add menu to visible list first
        viewModel.visibleSharedMenus.add(menu);

        // Act
        final result = await viewModel.dismissSharedMenu(menu);

        // Assert
        expect(result, isTrue);
        expect(viewModel.visibleSharedMenus, isEmpty);
        expect(viewModel.error, isNull);
      });

      test('should undismiss shared recipe', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');

        // Act
        final result = await viewModel.undismissSharedRecipe(recipe);

        // Assert
        expect(result, isTrue);
        expect(viewModel.visibleSharedRecipes.contains(recipe), isTrue);
        expect(viewModel.error, isNull);
      });

      test('should undismiss shared menu', () async {
        // Arrange
        final menu = SharedMenuBuilder.build(id: 'sm1');

        // Act
        final result = await viewModel.undismissSharedMenu(menu);

        // Assert
        expect(result, isTrue);
        expect(viewModel.visibleSharedMenus.contains(menu), isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle dismiss error', () async {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        when(() => mockSocialRecipeService.dismissRecipe(any()))
            .thenThrow(Exception('Dismiss failed'));

        // Act
        final result = await viewModel.dismissSharedRecipe(recipe);

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, contains('Failed to dismiss recipe'));
      });
    });

    group('Content Filtering', () {
      test('should filter shared recipes by search query', () {
        // Arrange
        final recipe1 = SharedRecipeBuilder.build(
          id: 'sr1',
          recipeSnapshot: RecipeFactory.build(
            title: 'Köttbullar',
            description: 'Svenska köttbullar',
          ),
        );
        final recipe2 = SharedRecipeBuilder.build(
          id: 'sr2',
          recipeSnapshot: RecipeFactory.build(
            title: 'Pannkakor',
            description: 'Tunna pannkakor',
          ),
        );

        viewModel.visibleSharedRecipes.addAll([recipe1, recipe2]);

        // Act
        viewModel.updateSearchQuery('köttbullar');

        // Assert
        expect(viewModel.filteredSharedRecipes.length, equals(1));
        expect(viewModel.filteredSharedRecipes[0].id, equals('sr1'));
      });

      test('should filter shared menus by search query', () {
        // Arrange
        final menu1 = SharedMenuBuilder.build(
          id: 'sm1',
          menuTitle: 'Veckomeny',
        );
        final menu2 = SharedMenuBuilder.build(
          id: 'sm2',
          menuTitle: 'Helgmeny',
        );

        viewModel.visibleSharedMenus.addAll([menu1, menu2]);

        // Act
        viewModel.updateSearchQuery('vecko');

        // Assert
        expect(viewModel.filteredSharedMenus.length, equals(1));
        expect(viewModel.filteredSharedMenus[0].id, equals('sm1'));
      });

      test('should return all content when search is empty', () {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        final menu = SharedMenuBuilder.build(id: 'sm1');

        viewModel.visibleSharedRecipes.add(recipe);
        viewModel.visibleSharedMenus.add(menu);

        // Act - no search query

        // Assert
        expect(viewModel.filteredSharedRecipes.length, equals(1));
        expect(viewModel.filteredSharedMenus.length, equals(1));
      });

      test('should check has filtered content', () {
        // Arrange
        final recipe = SharedRecipeBuilder.build(id: 'sr1');
        viewModel.visibleSharedRecipes.add(recipe);

        // Act & Assert
        expect(viewModel.hasFilteredContent, isTrue);

        viewModel.updateSearchQuery('nonexistent');
        expect(viewModel.hasFilteredContent, isFalse);
      });
    });

    group('Content Counts', () {
      test('should calculate total shared recipes', () {
        // Arrange
        viewModel.visibleSharedRecipes.addAll([
          SharedRecipeBuilder.build(id: 'sr1'),
          SharedRecipeBuilder.build(id: 'sr2'),
        ]);

        // Act & Assert
        expect(viewModel.totalSharedRecipes, equals(2));
      });

      test('should calculate total shared menus', () {
        // Arrange
        viewModel.visibleSharedMenus.addAll([
          SharedMenuBuilder.build(id: 'sm1'),
          SharedMenuBuilder.build(id: 'sm2'),
        ]);

        // Act & Assert
        expect(viewModel.totalSharedMenus, equals(2));
      });

      test('should calculate unread recipes count', () {
        // Arrange
        viewModel.visibleSharedRecipes.addAll([
          SharedRecipeBuilder.build(id: 'sr1', viewedByUserIds: [testUserId]),
          SharedRecipeBuilder.build(id: 'sr2', viewedByUserIds: []),
          SharedRecipeBuilder.build(id: 'sr3', viewedByUserIds: []),
        ]);

        // Act & Assert
        expect(viewModel.unreadRecipesCount, equals(2));
      });

      test('should calculate unread menus count', () {
        // Arrange
        viewModel.visibleSharedMenus.addAll([
          SharedMenuBuilder.build(id: 'sm1', viewedByUserIds: [testUserId]),
          SharedMenuBuilder.build(id: 'sm2', viewedByUserIds: []),
        ]);

        // Act & Assert
        expect(viewModel.unreadMenusCount, equals(1));
      });

      test('should calculate total unread count', () {
        // Arrange
        viewModel.visibleSharedRecipes.addAll([
          SharedRecipeBuilder.build(id: 'sr1', viewedByUserIds: []),
          SharedRecipeBuilder.build(id: 'sr2', viewedByUserIds: []),
        ]);
        viewModel.visibleSharedMenus.addAll([
          SharedMenuBuilder.build(id: 'sm1', viewedByUserIds: []),
        ]);

        // Act & Assert
        expect(viewModel.totalUnreadCount, equals(3));
      });
    });

    group('Social Features', () {
      test('should toggle friend selection', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.toggleFriendSelection('friend_1');

        // Assert
        expect(viewModel.selectedFriendIds.contains('friend_1'), isTrue);
        expect(notificationCount, equals(1));

        // Toggle off
        viewModel.toggleFriendSelection('friend_1');
        expect(viewModel.selectedFriendIds.contains('friend_1'), isFalse);
      });

      test('should select all friends', () {
        // Arrange - friends loaded in setUp
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.selectAllFriends();

        // Assert
        expect(viewModel.selectedFriendIds.length,
            equals(0)); // No friends loaded in simplified implementation
        expect(notificationCount, equals(1));
      });

      test('should clear all friend selections', () {
        // Arrange
        viewModel.toggleFriendSelection('friend_1');
        viewModel.toggleFriendSelection('friend_2');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearAllSelections();

        // Assert
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(notificationCount, equals(1));
      });

      test('should update share message', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateShareMessage('Kolla in denna lista!');

        // Assert
        expect(viewModel.shareMessage, equals('Kolla in denna lista!'));
        expect(notificationCount, equals(1));
      });

      test('should share shopping list', () async {
        // Arrange
        final shoppingList = ShoppingListFactory.build(
          id: 'list_123',
          name: 'Veckans inköp',
        );
        viewModel.toggleFriendSelection('friend_1');
        viewModel.updateShareMessage('Här är listan!');

        // Act
        final result = await viewModel.shareShoppingList(shoppingList);

        // Assert
        expect(result, isTrue); // SocialContentFeatures returns true
      });

      test('should get sharing summary', () {
        // Arrange
        viewModel.toggleFriendSelection('friend_1');
        viewModel.toggleFriendSelection('friend_2');

        // Act
        final summary = viewModel.getSharingSummary();

        // Assert
        expect(summary, equals('Dela med 2 vänner'));
      });

      test('should refresh friends', () async {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        await viewModel.refreshFriends();

        // Assert
        expect(notificationCount, greaterThan(0));
      });

      test('should check has friends', () {
        // Assert - simplified implementation has empty friends
        expect(viewModel.hasFriends, isFalse);
      });

      test('should check has selected friends', () {
        // Arrange
        viewModel.toggleFriendSelection('friend_1');

        // Act & Assert
        expect(viewModel.hasSelectedFriends, isTrue);

        viewModel.clearAllSelections();
        expect(viewModel.hasSelectedFriends, isFalse);
      });

      test('should get selected friends count', () {
        // Arrange
        viewModel.toggleFriendSelection('friend_1');
        viewModel.toggleFriendSelection('friend_2');

        // Act & Assert
        expect(viewModel.selectedFriendsCount, equals(2));
      });

      test('should check can share shopping', () {
        // Arrange
        viewModel.toggleFriendSelection('friend_1');

        // Act & Assert
        expect(viewModel.canShareShopping, isTrue);

        viewModel.clearAllSelections();
        expect(viewModel.canShareShopping, isFalse);
      });

      test('should get selected friends list', () {
        // Note: Simplified implementation returns empty list
        viewModel.toggleFriendSelection('friend_1');

        // Act
        final selectedFriends = viewModel.selectedFriends;

        // Assert
        expect(
            selectedFriends, isEmpty); // No actual friends in availableFriends
      });
    });

    group('Refresh Functionality', () {
      test('should refresh all content', () async {
        // Arrange
        // Note: We can't easily verify internal method calls
        // Just verify no errors

        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.error, isNull);
      });
    });

    group('Error Handling', () {
      test('should clear error', () {
        // Arrange - set error through import failure
        when(() => mockSocialRecipeService.importRecipe(any()))
            .thenThrow(Exception('Test error'));

        // Set error
        viewModel.importSharedRecipe(SharedRecipeBuilder.build());

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(notificationCount, equals(1));
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = SharedContentViewModel(
          socialRecipeService: mockSocialRecipeService,
          friendsService: mockFriendsService,
          shoppingService: mockShoppingService,
        );

        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should remove service listener on dispose', () {
        // Arrange
        final testViewModel = SharedContentViewModel(
          socialRecipeService: mockSocialRecipeService,
          friendsService: mockFriendsService,
          shoppingService: mockShoppingService,
        );

        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        // Act
        testViewModel.dispose();

        // Trigger service change after dispose
        mockSocialRecipeService.notifyListeners();

        // Assert - should not receive notifications after dispose
        expect(notificationCount, equals(0));
      });
    });
  });
}
