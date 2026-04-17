// test/unit/viewmodels/universal_share_dialog_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

class MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSocialRecipeCoordinator mockSocialRecipeCoordinator;
  late MockUnifiedShoppingService mockShoppingService;
  late FakeShoppingShareOperations mockSharingOperations;
  late UniversalShareDialogViewModel viewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(ResourcePermission.read);
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockSocialRecipeCoordinator = MockSocialRecipeCoordinator();
    mockShoppingService = MockUnifiedShoppingService();
    mockSharingOperations = FakeShoppingShareOperations();

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
    // Guard against double-dispose if setUp failed
    try {
      viewModel.dispose();
    } catch (_) {
      // Already disposed or never created
    }
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

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
      // VM uses errorCouldNotUpdate('recept') = 'Kunde inte uppdatera recept'
      expect(viewModel.errorMessage, contains('Kunde inte uppdatera recept'));
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

    test('should handle recipe friend-share returning false', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async => false);

      final success = await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
    });
  });

  group('UniversalShareDialogViewModel - Menu Sharing', () {
    test('should reject menu sharing with no recipients', () async {
      final menu = {
        'Monday': [
          RecipeFactory.build(id: 'recipe_1', title: 'Monday Pasta'),
        ],
      };

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

  // Shopping list sharing tests skipped — the VM's shareShoppingList now
  // delegates to SocialContentFeatures.shareContentWithFriends (a static
  // utility that uses ServiceLocator internally), making it an integration
  // concern. The old tests mocked shareListWithFriend which is no longer
  // called by the VM.

  group('UniversalShareDialogViewModel - Error Handling', () {
    test('should clear error', () async {
      // Trigger an error via no-recipients path
      await viewModel.shareRecipe(
        recipe: RecipeFactory.build(),
        friendUserIds: [],
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
      bool wasSharing = false;

      when(() => mockSocialRecipeCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          )).thenAnswer((_) async {
        // Capture the sharing state during the operation
        wasSharing = viewModel.isSharing;
        return true;
      });

      expect(viewModel.isSharing, isFalse);

      await viewModel.shareRecipe(
        recipe: recipe,
        friendUserIds: ['friend_1'],
      );

      // Was true during operation
      expect(wasSharing, isTrue);
      // False after completion
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

    test('should notify listeners on state changes', () async {
      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

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

      // Should have notified: setSharing(true), clearError, setSharing(false)
      expect(notificationCount, greaterThanOrEqualTo(2));
    });
  });
}
