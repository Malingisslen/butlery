// test/unit/viewmodels/universal_share_dialog_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockSocialRecipeService mockSocialRecipeService;
  late MockUnifiedShoppingService mockShoppingService;
  late MockShoppingShareOperations mockSharingOperations;
  late UniversalShareDialogViewModel viewModel;

  setUp(() async {
    await TestServiceLocator.initialize();
    
    mockSocialRecipeService = MockSocialRecipeService();
    mockShoppingService = MockUnifiedShoppingService();
    mockSharingOperations = MockShoppingShareOperations();
    
    // Setup mock service structure using state configuration
    mockShoppingService.setShoppingState(
      shareOps: mockSharingOperations,
      isInitialized: true,
    );
    
    viewModel = UniversalShareDialogViewModel(
      socialRecipeService: mockSocialRecipeService,
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
      
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1', 'friend_2'],
        message: 'Try this recipe!',
        allowCollaboration: true,
      );
      
      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);
      
      verify(() => mockSocialRecipeService.shareRecipeToFriends(
        'recipe_123',
        ['friend_1', 'friend_2'],
      )).called(1);
    });

    test('should share recipe with groups successfully', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');
      
      when(() => mockSocialRecipeService.shareRecipeToGroups(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: [],
        groupIds: ['group_1', 'group_2'],
      );
      
      expect(success, isTrue);
      
      verify(() => mockSocialRecipeService.shareRecipeToGroups(
        'recipe_123',
        ['group_1', 'group_2'],
      )).called(1);
    });

    test('should share recipe with both friends and groups', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');
      
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockSocialRecipeService.shareRecipeToGroups(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
        groupIds: ['group_1'],
      );
      
      expect(success, isTrue);
      
      verify(() => mockSocialRecipeService.shareRecipeToFriends(
        'recipe_123',
        ['friend_1'],
      )).called(1);
      verify(() => mockSocialRecipeService.shareRecipeToGroups(
        'recipe_123',
        ['group_1'],
      )).called(1);
    });

    test('should handle recipe sharing error', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');
      
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenThrow(Exception('Share failed'));
      
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
      expect(viewModel.errorMessage, contains('Inga vänner eller grupper valda'));
      
      verifyNever(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()));
      verifyNever(() => mockSocialRecipeService.shareRecipeToGroups(any(), any()));
    });
  });

  group('UniversalShareDialogViewModel - Menu Sharing', () {
    test('should share menu with friends successfully', () async {
      final menu = createTestMenu();
      
      when(() => mockSocialRecipeService.shareMenuToFriends(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: ['friend_1', 'friend_2'],
        menuId: 'menu_123',
        message: 'Weekly menu plan',
      );
      
      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);
      
      verify(() => mockSocialRecipeService.shareMenuToFriends(
        'menu_123',
        ['friend_1', 'friend_2'],
      )).called(1);
    });

    test('should generate menu ID if not provided', () async {
      final menu = createTestMenu();
      
      when(() => mockSocialRecipeService.shareMenuToFriends(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: ['friend_1'],
        menuId: null, // No ID provided
      );
      
      expect(success, isTrue);
      
      // Verify a menu ID was generated (starts with 'menu_')
      final capturedArgs = verify(
        () => mockSocialRecipeService.shareMenuToFriends(
          captureAny(),
          any(),
        ),
      ).captured;
      
      expect(capturedArgs.first, startsWith('menu_'));
      expect(capturedArgs.first, contains('3d_2r')); // 3 days, 2 recipes
    });

    test('should share menu with groups successfully', () async {
      final menu = createTestMenu();
      
      when(() => mockSocialRecipeService.shareMenuToGroups(any(), any()))
          .thenAnswer((_) async => {});
      
      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: [],
        groupIds: ['group_1'],
        menuId: 'menu_123',
      );
      
      expect(success, isTrue);
      
      verify(() => mockSocialRecipeService.shareMenuToGroups(
        'menu_123',
        ['group_1'],
      )).called(1);
    });

    test('should handle menu sharing error', () async {
      final menu = createTestMenu();
      
      when(() => mockSocialRecipeService.shareMenuToFriends(any(), any()))
          .thenThrow(Exception('Network error'));
      
      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: ['friend_1'],
        menuId: 'menu_123',
      );
      
      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.errorMessage, contains('Kunde inte dela meny'));
    });

    test('should reject menu sharing with no recipients', () async {
      final menu = createTestMenu();
      
      final success = await viewModel.shareMenu(
        menu: menu,
        friendUserIds: [],
        groupIds: null,
      );
      
      expect(success, isFalse);
      expect(viewModel.errorMessage, contains('Inga vänner eller grupper valda'));
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
      
      when(() => mockSharingOperations.shareListWithFriend('list_123', 'friend_1'))
          .thenAnswer((_) async => true);
      when(() => mockSharingOperations.shareListWithFriend('list_123', 'friend_2'))
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
      expect(viewModel.errorMessage, contains('Inga vänner eller grupper valda'));
      
      verifyNever(() => mockSharingOperations.shareListWithFriend(any(), any()));
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
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenAnswer((_) async => {});
      
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
      
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenAnswer((_) async {
            await Future.delayed(Duration(milliseconds: 50));
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

    test('should track sharing state during menu share', () async {
      final menu = createTestMenu();
      
      when(() => mockSocialRecipeService.shareMenuToFriends(any(), any()))
          .thenAnswer((_) async {
            await Future.delayed(Duration(milliseconds: 50));
          });
      
      expect(viewModel.isSharing, isFalse);
      
      final future = viewModel.shareMenu(
        menu: menu,
        friendUserIds: ['friend_1'],
      );
      
      expect(viewModel.isSharing, isTrue);
      
      await future;
      
      expect(viewModel.isSharing, isFalse);
    });

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
      
      when(() => mockSocialRecipeService.shareRecipeToFriends(any(), any()))
          .thenThrow(Exception('Error'));
      
      await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );
      
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isTrue);
    });
  });

  group('UniversalShareDialogViewModel - Menu ID Generation', () {
    test('should generate unique menu IDs', () async {
      final menu1 = createTestMenu();
      final Map<String, List<Recipe>> menu2 = {
        'Monday': [RecipeFactory.build()],
        'Tuesday': <Recipe>[],
      };
      
      when(() => mockSocialRecipeService.shareMenuToFriends(any(), any()))
          .thenAnswer((_) async => {});
      
      // Share two menus without IDs
      await viewModel.shareMenu(
        menu: menu1,
        friendUserIds: ['friend_1'],
      );
      
      await Future.delayed(Duration(milliseconds: 10)); // Ensure different timestamp
      
      await viewModel.shareMenu(
        menu: menu2,
        friendUserIds: ['friend_1'],
      );
      
      // Capture generated IDs
      final capturedArgs = verify(
        () => mockSocialRecipeService.shareMenuToFriends(
          captureAny(),
          any(),
        ),
      ).captured;
      
      // IDs should be different
      expect(capturedArgs[0], isNot(equals(capturedArgs[1])));
      
      // Check format
      expect(capturedArgs[0], contains('3d_2r')); // 3 days, 2 recipes
      expect(capturedArgs[1], contains('2d_1r')); // 2 days, 1 recipe
    });
  });
}