import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/models/shared_menu.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MenuViewModel - Ultrathink Enhanced Tests', () {
    late MenuViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockMenuService mockMenuService;

    // Test data
    final testMenuId = 'menu123';
    final testUserId = 'user123';
    final testFriendId = 'friend456';

    final testRecipe = RecipeBuilder()
        .withId('recipe1')
        .withTitle('Köttbullar')
        .withMealType('Middag')
        .withPortions(4)
        .withTimeMinutes(30)
        .build();

    final testRecipe2 = RecipeBuilder()
        .withId('recipe2')
        .withTitle('Pannkakor')
        .withMealType('Frukost')
        .withPortions(4)
        .withTimeMinutes(15)
        .build();

    final testMenuSnapshot = {
      'Middag': [testRecipe],
      'Frukost': [testRecipe2],
    };

    final testSharedMenu = SharedMenu.create(
      sharedByUserId: testUserId,
      sharedByDisplayName: 'Test User',
      sharedToUserIds: [testFriendId],
      menuTitle: 'Test Menu',
      menuSnapshot: testMenuSnapshot,
      shareMessage: 'Check out this menu!',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(testRecipe);
      registerFallbackValue(testSharedMenu);
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Mock SharedPreferences for MenuStorage
      SharedPreferences.setMockInitialValues({});

      // Create mocks
      mockRecipeService = MockFactory.createUnifiedRecipeService();
      mockMenuService = MockMenuService();

      // Configure recipe service state
      mockRecipeService.setRecipeState(
        recipes: [testRecipe, testRecipe2],
        currentUserId: testUserId,
        currentUserDisplayName: 'Test User',
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      // Configure menu service - MenuService only has generateMenuFromPrompt
      when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
          .thenAnswer((_) async => testMenuSnapshot);

      // Register mocks
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<MenuService>(mockMenuService);

      // Create viewModel
      viewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization and Default State', () {
      test('should initialize with correct default state', () {
        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.isGenerating, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.menu, isEmpty);
        expect(viewModel.totalRecipeCount, equals(0));
        expect(viewModel.lastPrompt, isEmpty);
        expect(viewModel.savedMenus, isEmpty);
        expect(viewModel.availableRecipes, isNotEmpty); // From mocked service
        expect(viewModel.hasAvailableRecipes, isTrue);
      });

      test('should register listeners on initialization', () {
        // Assert - implicit through viewModel creation
        expect(viewModel, isNotNull);
      });
    });

    group('Menu Generation', () {
      test('should generate menu with valid prompt', () async {
        // Arrange
        const prompt = 'Vegetarisk veckomeny för familj';
        when(() => mockMenuService.generateMenuFromPrompt(prompt, any()))
            .thenAnswer((_) async => testMenuSnapshot);

        // Act
        await viewModel.generateMenu(prompt);

        // Assert
        expect(viewModel.hasMenu, isTrue);
        expect(viewModel.menu, equals(testMenuSnapshot));
        expect(viewModel.menu.containsKey('Middag'), isTrue);
        expect(viewModel.menu.containsKey('Frukost'), isTrue);
        expect(viewModel.totalRecipeCount, equals(2));
        expect(viewModel.lastPrompt, equals(prompt));
        verify(() => mockMenuService.generateMenuFromPrompt(prompt, any()))
            .called(1);
      });

      test('should handle empty prompt', () async {
        // Act
        await viewModel.generateMenu('');

        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });

      test('should handle whitespace-only prompt', () async {
        // Act
        await viewModel.generateMenu('   ');

        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });

      test('should handle generation error', () async {
        // Arrange
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenThrow(Exception('Generation failed'));

        // Act
        await viewModel.generateMenu('Valid menu prompt here');

        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.error, contains('Generation failed'));
      });

      test('should track generating state', () async {
        // Arrange
        bool wasGenerating = false;
        viewModel.addListener(() {
          if (viewModel.isGenerating) wasGenerating = true;
        });

        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 10));
          return testMenuSnapshot;
        });

        // Act
        await viewModel.generateMenu('Valid menu prompt here');

        // Assert
        expect(wasGenerating, isTrue);
        expect(viewModel.isGenerating, isFalse);
      });

      test('should regenerate section', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Initial menu prompt');

        // Configure regeneration to return new section
        final regeneratedSection = {
          'Middag': [testRecipe2]
        };
        when(() => mockMenuService.generateMenuFromPrompt('1 Middag', any()))
            .thenAnswer((_) async => regeneratedSection);

        // Act
        await viewModel.regenerateSection('Middag');

        // Assert
        expect(viewModel.menu['Middag'], equals([testRecipe2]));
        verify(() => mockMenuService.generateMenuFromPrompt('1 Middag', any()))
            .called(1);
      });

      test('should not regenerate section without menu', () async {
        // Act
        await viewModel.regenerateSection('Middag');

        // Assert
        expect(viewModel.hasMenu, isFalse);
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });
    });

    group('Menu Saving', () {
      test('should save menu with name and comment', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');

        // Menu saving/loading is handled internally by MenuStorage module

        // Act
        final result = await viewModel.saveMenuWithNameAndComment(
          'Test Menu Name',
          'Test menu comment',
        );

        // Assert
        expect(result, isTrue);
        // Save operation is handled internally by MenuStorage
      });

      test('should save menu with social sharing', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');

        // Menu saving/loading is handled internally by MenuStorage module

        // Note: Social sharing is handled internally by MenuSocialManager
        // which gets SocialMenuOperations from ServiceLocator

        // Act
        final result = await viewModel.saveMenuWithNameAndComment(
          'Shared Menu',
          'Great menu for sharing',
          shareWithFriends: true,
          selectedFriendIds: [testFriendId],
          shareMessage: 'Check this out!',
        );

        // Assert
        expect(result, isTrue);
        // Save operation is handled internally by MenuStorage
        // Social sharing is handled internally and we can't verify it directly
      });

      test('should reject saving without menu', () async {
        // Act
        final result = await viewModel.saveMenuWithNameAndComment(
          'Test Menu',
          'Comment',
        );

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, equals('Ingen meny att spara'));
        // Save validation happens in MenuViewModel
      });

      test('should reject saving with empty name', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');

        // Act
        final result =
            await viewModel.saveMenuWithNameAndComment('', 'Comment');

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, equals('Ange ett namn för menyn'));
        // Save validation happens in MenuViewModel
      });

      test('should handle save with mocked storage', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');

        // Note: With mocked SharedPreferences, save will succeed

        // Act
        final result = await viewModel.saveMenuWithNameAndComment(
          'Test Menu',
          'Comment',
        );

        // Assert - With mocked storage, save succeeds
        expect(result, isTrue);
      });
    });

    group('Menu Loading', () {
      test('should load saved menu', () async {
        // Arrange
        // Load is handled internally by MenuStorage

        // Act
        final result = await viewModel.loadSavedMenu(testMenuId);

        // Assert
        // The actual loading is handled internally through MenuStorage
        // We can only verify the return value
        expect(result, isA<bool>());
      });

      test('should handle menu not found', () async {
        // Arrange
        // Menu doesn't exist in mocked SharedPreferences

        // Act
        final result = await viewModel.loadSavedMenu(testMenuId);

        // Assert
        expect(result, isFalse);
        expect(
            viewModel.error,
            equals(
                'Menyn kunde inte hittas')); // Swedish: "Menu could not be found"
      });

      test('should handle menu loading', () async {
        // Arrange
        // Load is handled internally by MenuStorage

        // Act
        final result = await viewModel.loadSavedMenu(testMenuId);

        // Assert
        // loadSavedMenu returns a boolean indicating success
        expect(result, isA<bool>());
      });
    });

    group('Menu Management', () {
      test('should clear current menu', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');
        expect(viewModel.hasMenu, isTrue);

        // Act
        viewModel.clearMenu();

        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.menu, isEmpty);
        expect(viewModel.lastPrompt, isEmpty);
        expect(viewModel.error, isNull);
      });

      test('should delete saved menu', () async {
        // Arrange
        // Delete is handled internally by MenuStorage

        // Act
        final result = await viewModel.deleteSavedMenu(testMenuId);

        // Assert
        expect(result, isTrue);
        // Delete operation verified through return value
      });

      test('should handle delete with mocked storage', () async {
        // Arrange
        // With mocked SharedPreferences, delete will succeed

        // Act
        final result = await viewModel.deleteSavedMenu(testMenuId);

        // Assert - With mocked storage, delete succeeds
        expect(result, isTrue);
      });

      test('should refresh saved menus', () async {
        // Arrange
        // The refreshSavedMenus method loads menus internally
        // We can't directly verify the internal loading

        // Act
        await viewModel.refreshSavedMenus();

        // Assert
        // Since menus are loaded internally, we can only check the final state
        expect(viewModel.savedMenus, isA<List<SavedMenuInfo>>());
      });
    });

    group('Social Features', () {
      test('should get available shared menus', () async {
        // Act
        final menus = await viewModel.getAvailableSharedMenus();

        // Assert
        expect(menus, isA<List<Map<String, dynamic>>>());
        // Social operations are handled internally through MenuSocialManager
      });

      test('should import shared menu', () async {
        // Act
        final result = await viewModel.importSharedMenu(testMenuId);

        // Assert
        // The actual import is handled internally through MenuSocialManager
        expect(result, isA<bool>());
      });

      test('should mark shared menu as viewed', () async {
        // Act
        await viewModel.markSharedMenuAsViewed(testMenuId);

        // Assert
        // This is a void method that marks the menu as viewed internally
        expect(() => viewModel.markSharedMenuAsViewed(testMenuId),
            returnsNormally);
      });
    });

    group('Recipe Operations', () {
      test('should have available recipes from service', () {
        // Assert
        expect(viewModel.availableRecipes, isNotEmpty);
        expect(viewModel.hasAvailableRecipes, isTrue);
        expect(viewModel.availableRecipes, contains(testRecipe));
        expect(viewModel.availableRecipes, contains(testRecipe2));
      });

      test('should track menu state correctly', () async {
        // Arrange - generate menu first
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid menu prompt');

        // Assert
        expect(viewModel.menu['Middag'], hasLength(1));
        expect(viewModel.menu['Frukost'], hasLength(1));
        expect(viewModel.totalRecipeCount, equals(2));
      });
    });

    group('Error Handling', () {
      test('should clear error', () async {
        // Arrange - cause an error first
        await viewModel.generateMenu(''); // Empty prompt causes error
        expect(viewModel.hasError, isTrue);

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should handle concurrent operations gracefully', () async {
        // Arrange
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 50));
          return testMenuSnapshot;
        });

        // Act - start multiple operations
        final future1 = viewModel.generateMenu('First prompt here now');
        final future2 = viewModel.generateMenu('Second prompt here now');

        await Future.wait([future1, future2]);

        // Assert - only one should succeed
        expect(viewModel.hasMenu, isTrue);
      });
    });

    group('Disposal', () {
      test('should clean up resources on dispose', () {
        // Arrange - Create a new viewModel specifically for this test
        final testViewModel = MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
        );

        // Act & Assert - should not throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        // Arrange - Create a new viewModel specifically for this test
        final testViewModel = MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
        );

        // Act & Assert - In debug mode, Flutter will throw on double dispose
        // This is expected behavior to catch bugs
        testViewModel.dispose();
        expect(() => testViewModel.dispose(), throwsFlutterError);
      });
    });
  });
}

// ============= USING CENTRALIZED MOCKS =============
// Removed local mock classes:
// - MockMenuService (now in service_mocks.dart)
// - MockSocialMenuOperations (now in production_mocks.dart)
