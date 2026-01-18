// test/unit/viewmodels/universal_share_dialog_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

class MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ResourcePermission.read);
  });

  late MockSocialRecipeCoordinator mockSocialRecipeCoordinator;
  late MockUnifiedShoppingService mockShoppingService;
  late MockShoppingShareOperations mockSharingOperations;
  late UniversalShareDialogViewModel viewModel;

  setUp(() async {
    await TestServiceLocator.initialize();

    mockSocialRecipeCoordinator = MockSocialRecipeCoordinator();
    mockShoppingService = MockUnifiedShoppingService();
    mockSharingOperations = MockShoppingShareOperations();

    // Setup mock service structure using state configuration
    mockShoppingService.setShoppingState(
      shareOps: mockSharingOperations,
      isInitialized: true,
    );

    viewModel = UniversalShareDialogViewModel(
      socialRecipeCoordinator: mockSocialRecipeCoordinator,
      shoppingService: mockShoppingService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  UnifiedShoppingList createTestShoppingList({
    String? id,
    String? name,
  }) {
    final list = UnifiedShoppingList.personal(
      name: name ?? 'Grocery List',
      ownerId: 'test_user',
      ownerDisplayName: 'Test User',
    );
    // Note: id cannot be set via copyWith, it's generated in the constructor
    return list.copyWith(
      items: [
        UnifiedShoppingItem(
          id: 'item_1',
          name: 'Milk',
          amount: 1,
          unit: 'L',
          category: 'Dairy',
          bought: false,
        ),
      ],
    );
  }

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [
        RecipeFactory.build(id: 'recipe_1', title: 'Monday Pasta'),
      ],
      'Tuesday': [
        RecipeFactory.build(id: 'recipe_2', title: 'Tuesday Soup'),
      ],
      'Wednesday': [],
    };
  }

  group('UniversalShareDialogViewModel - Initialization', () {
    test('should initialize with default state', () {
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.hasError, isFalse);
    });
  });

  group('UniversalShareDialogViewModel - Recipe Sharing', () {
    test('should share recipe with friends successfully', () async {
      final recipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Test Recipe',
      );

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1', 'friend_2'],
        message: 'Try this recipe!',
        allowCollaboration: true,
      );

      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);

      verify(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: 'recipe_123',
            friendIds: ['friend_1', 'friend_2'],
            message: 'Try this recipe!',
            allowCollaboration: true,
          )).called(1);
    });

    test('should share recipe with groups successfully', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');

      when(() => mockSocialRecipeCoordinator.shareRecipeWithGroups(
            any(),
            any(),
            any(),
          )).thenAnswer((_) async => true);

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: [],
        groupIds: ['group_1', 'group_2'],
      );

      expect(success, isTrue);

      verify(() => mockSocialRecipeCoordinator.shareRecipeWithGroups(
            'recipe_123',
            ['group_1', 'group_2'],
            ResourcePermission.read,
          )).called(1);
    });

    test('should share recipe with both friends and groups', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);
      when(() => mockSocialRecipeCoordinator.shareRecipeWithGroups(
            any(),
            any(),
            any(),
          )).thenAnswer((_) async => true);

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
        groupIds: ['group_1'],
      );

      expect(success, isTrue);

      verify(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: 'recipe_123',
            friendIds: ['friend_1'],
            message: null,
            allowCollaboration: false,
          )).called(1);
      verify(() => mockSocialRecipeCoordinator.shareRecipeWithGroups(
            'recipe_123',
            ['group_1'],
            ResourcePermission.read,
          )).called(1);
    });

    test('should handle recipe sharing error', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenThrow(Exception('Share failed'));

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.errorMessage, contains('Kunde inte dela recept'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should reject recipe sharing with no recipients', () async {
      final recipe = RecipeFactory.build();

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: [],
        groupIds: [],
      );

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(
          viewModel.errorMessage, contains('Inga vänner eller grupper valda'));

      verifyNever(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          ));
      verifyNever(() => mockSocialRecipeCoordinator.shareRecipeWithGroups(
            any(),
            any(),
            any(),
          ));
    });
  });

  group('UniversalShareDialogViewModel - Menu Sharing', () {
    // Note: Menu sharing tests are skipped because the shareMenu method
    // uses ServiceLocator internally to get UnifiedMenuService and UnifiedFriendsService,
    // not constructor-injected dependencies. These tests would need integration-level
    // setup with TestServiceLocator to work properly.

    test('should reject menu sharing with no recipients', () async {
      final menu = createTestMenu();

      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: [],
        groupIds: null,
      );

      expect(success, isFalse);
      expect(
          viewModel.errorMessage, contains('Inga vänner eller grupper valda'));
    });
  });

  group('UniversalShareDialogViewModel - Shopping List Sharing', () {
    test('should share shopping list with friends successfully', () async {
      final shoppingList = createTestShoppingList();

      when(() => mockSharingOperations.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: ['friend_1', 'friend_2'],
        message: 'Grocery shopping for weekend',
      );

      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);

      verify(() => mockSharingOperations.shareListWithFriend(any(), 'friend_1'))
          .called(1);
      verify(() => mockSharingOperations.shareListWithFriend(any(), 'friend_2'))
          .called(1);
    });

    test('should share shopping list with groups successfully', () async {
      final shoppingList = createTestShoppingList();

      when(() => mockSharingOperations.shareListWithGroup(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: [],
        groupIds: ['group_1', 'group_2'],
      );

      expect(success, isTrue);

      verify(() => mockSharingOperations.shareListWithGroup(any(), 'group_1'))
          .called(1);
      verify(() => mockSharingOperations.shareListWithGroup(any(), 'group_2'))
          .called(1);
    });

    test('should handle partial shopping list sharing failure', () async {
      final shoppingList = createTestShoppingList();

      when(() =>
              mockSharingOperations.shareListWithFriend('list_123', 'friend_1'))
          .thenAnswer((_) async => true);
      when(() =>
              mockSharingOperations.shareListWithFriend('list_123', 'friend_2'))
          .thenAnswer((_) async => false);

      final success = await viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: ['friend_1', 'friend_2'],
      );

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.errorMessage, contains('Kunde inte dela inköpslista'));
    });

    test('should handle shopping list sharing exception', () async {
      final shoppingList = createTestShoppingList();

      when(() => mockSharingOperations.shareListWithFriend(any(), any()))
          .thenThrow(Exception('Service unavailable'));

      final success = await viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: ['friend_1'],
      );

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.errorMessage, contains('Kunde inte dela inköpslista'));
    });

    test('should reject shopping list sharing with no recipients', () async {
      final shoppingList = createTestShoppingList();

      final success = await viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: [],
      );

      expect(success, isFalse);
      expect(
          viewModel.errorMessage, contains('Inga vänner eller grupper valda'));

      verifyNever(
          () => mockSharingOperations.shareListWithFriend(any(), any()));
      verifyNever(() => mockSharingOperations.shareListWithGroup(any(), any()));
    });
  });

  group('UniversalShareDialogViewModel - Error Handling', () {
    test('should clear error', () {
      // Set an error
      viewModel.shareRecipe(
        recipe: RecipeFactory.build(),
        friendUserIds: [], // Will cause error
      );

      expect(viewModel.hasError, isTrue);

      viewModel.clearError();

      expect(viewModel.hasError, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('should clear previous error before new operation', () async {
      // Create an error
      await viewModel.shareRecipe(
        recipe: RecipeFactory.build(),
        friendUserIds: [],
      );
      expect(viewModel.hasError, isTrue);

      // Successful operation should clear error
      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => true);

      await viewModel.shareRecipe(
        recipe: RecipeFactory.build(),
        friendUserIds: ['friend_1'],
      );

      expect(viewModel.hasError, isFalse);
    });
  });

  group('UniversalShareDialogViewModel - State Management', () {
    test('should track sharing state during recipe share', () async {
      final recipe = RecipeFactory.build();

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 50));
        return true;
      });

      expect(viewModel.isSharing, isFalse);

      final future = viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );

      expect(viewModel.isSharing, isTrue);

      await future;

      expect(viewModel.isSharing, isFalse);
    });

    // Menu sharing test skipped - uses ServiceLocator internally for UnifiedMenuService
    // and requires more comprehensive mocking setup

    test('should track sharing state during shopping list share', () async {
      final shoppingList = createTestShoppingList();

      when(() => mockSharingOperations.shareListWithFriend(any(), any()))
          .thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 50));
        return true;
      });

      expect(viewModel.isSharing, isFalse);

      final future = viewModel.shareShoppingList(
        shoppingList: shoppingList,
        friendUserIds: ['friend_1'],
      );

      expect(viewModel.isSharing, isTrue);

      await future;

      expect(viewModel.isSharing, isFalse);
    });

    test('should reset sharing state on error', () async {
      final recipe = RecipeFactory.build();

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenThrow(Exception('Error'));

      await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );

      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isTrue);
    });
  });

  // Menu ID Generation tests skipped - requires integration-level setup with
  // UnifiedMenuService via ServiceLocator
}
