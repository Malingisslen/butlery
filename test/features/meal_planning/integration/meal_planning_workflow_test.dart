import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
// Menu repository not needed - MenuService doesn't use a repository
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockMenuService extends Mock implements MenuService {}

class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}
// MockMenuRepository not needed

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockMenuService mockMenuService;
  late MockUnifiedRecipeService mockRecipeService;
  // MockMenuRepository not needed

  setUpAll(() {
    registerFallbackValue(RecipeFactory.empty());
    registerFallbackValue(SharedMenuFactory.empty());
  });

  setUp(() async {
    // Setup test environment
    // ServiceLocator is already initialized by configureTests()

    // Create mocks
    mockMenuService = MockMenuService();
    mockRecipeService = MockUnifiedRecipeService();
    // MockMenuRepository initialization not needed

    // Setup SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Disposal is handled by configureTests()
  });

  group('Meal Planning Workflow Integration Tests', () {
    testWidgets('Complete meal planning workflow', (tester) async {
      // Given - Prepare test data
      final testRecipes = List.generate(
          7,
          (i) => RecipeFactory.build(
                id: 'recipe_$i',
                title: 'Test Recipe $i',
                tags: i % 2 == 0 ? ['vegetarisk'] : ['kött'],
                timeMinutes: 30 + (i * 5),
              ));

      // Mock recipe service behavior
      when(() => mockRecipeService.recipes).thenReturn(testRecipes);
      when(() => mockRecipeService.personalRecipes).thenReturn(testRecipes);

      // Expected generated menu
      final generatedMenu = {
        'Måndag': [testRecipes[0], testRecipes[1]],
        'Tisdag': [testRecipes[2]],
        'Onsdag': [testRecipes[3], testRecipes[4]],
        'Torsdag': [testRecipes[5]],
        'Fredag': [testRecipes[6]],
      };

      // Mock menu generation
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => generatedMenu);

      // Step 1: Initialize meal planning
      final menuViewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      expect(menuViewModel.menu, isEmpty);
      expect(menuViewModel.hasMenu, isFalse);

      // Step 2: Generate menu with AI prompt
      await menuViewModel.generateMenu(
        'Vegetarisk veckomeny för familj med barn som gillar pasta',
      );

      expect(menuViewModel.isGenerating, isFalse);
      expect(menuViewModel.hasMenu, isTrue);
      expect(menuViewModel.menu.length, equals(5));
      expect(menuViewModel.error, isNull);

      // Verify generation was called with correct parameters
      verify(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).called(1);

      // Step 3: Regenerate specific day
      // generateMenuSection is not part of the public API
      // Using generateMenuFromPrompt to simulate section regeneration
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => {
            'Måndag': [testRecipes[0], testRecipes[1]],
          });

      await menuViewModel.regenerateSection('Måndag');

      expect(menuViewModel.isGenerating, isFalse);
      expect(menuViewModel.error, isNull);

      // Step 4: Save menu with name and comment
      final savedMenu = await menuViewModel.saveMenuWithNameAndComment(
        'Vegetarisk Veckomeny',
        'Barnvänlig och näringsrik',
      );

      expect(savedMenu, isTrue);
      expect(menuViewModel.savedMenus.length, greaterThan(0));

      // Step 5: Share menu with friends
      final sharedSuccess = await menuViewModel.saveMenuWithNameAndComment(
        'Delad Veckomeny',
        'Perfekt för barnfamiljer',
        shareWithFriends: true,
        selectedFriendIds: ['friend1', 'friend2'],
        shareMessage: 'Kolla in min vegetariska veckomeny!',
      );

      expect(sharedSuccess, isTrue);

      // Step 6: Clear menu for new generation
      menuViewModel.clearMenu();

      expect(menuViewModel.hasMenu, isFalse);
      expect(menuViewModel.menu, isEmpty);
    });

    testWidgets('Menu modification and recipe replacement workflow',
        (tester) async {
      // Given - Menu with existing recipes
      final originalRecipes = List.generate(
          3,
          (i) => RecipeFactory.build(
                id: 'original_$i',
                title: 'Original Recipe $i',
              ));

      final replacementRecipe = RecipeFactory.build(
        id: 'replacement_1',
        title: 'Replacement Recipe',
      );

      final existingMenu = {
        'Måndag': [originalRecipes[0]],
        'Tisdag': [originalRecipes[1], originalRecipes[2]],
      };

      // Mock services
      when(() => mockRecipeService.recipes)
          .thenReturn([...originalRecipes, replacementRecipe]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => existingMenu);

      // Initialize with existing menu
      final menuViewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
      );

      await menuViewModel.generateMenu('Test menu');

      expect(menuViewModel.menu['Måndag']!.length, equals(1));
      expect(menuViewModel.menu['Tisdag']!.length, equals(2));

      // Replace recipe in specific day
      // Using generateMenuFromPrompt to simulate section regeneration
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => {
            'Måndag': [replacementRecipe],
          });

      await menuViewModel.regenerateSection('Måndag');

      expect(menuViewModel.menu['Måndag']!.first.id, equals('replacement_1'));

      // Add recipe to existing day (manual modification would be through UI)
      // This would typically be done through direct menu manipulation in the UI

      // Save modified menu
      final saved = await menuViewModel.saveMenuWithNameAndComment(
        'Modified Menu',
        'Updated with new recipes',
      );

      expect(saved, isTrue);
    });

    testWidgets('Shared menu import workflow', (tester) async {
      // Given - Shared menu from friend
      final sharedRecipes = List.generate(
          3,
          (i) => RecipeFactory.build(
                id: 'shared_$i',
                title: 'Shared Recipe $i',
              ));

      final sharedMenu = SharedMenuFactory.build(
        id: 'shared_menu_123',
        sharedByUserId: 'friend_user',
        sharedByDisplayName: 'Vän Vänsson',
        menuTitle: 'Vännens Veckomeny',
        menuSnapshot: {
          'Måndag': [sharedRecipes[0]],
          'Tisdag': [sharedRecipes[1]],
          'Onsdag': [sharedRecipes[2]],
        },
      );

      // Mock services
      when(() => mockRecipeService.recipes).thenReturn([]);

      // Initialize menu ViewModel
      final menuViewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
      );

      // Import shared menu
      final imported = await menuViewModel.importSharedMenu(
        sharedMenu.id,
      );

      expect(imported, isTrue);
      expect(menuViewModel.hasMenu, isTrue);
      expect(menuViewModel.menu.length, equals(3));

      // Verify imported recipes match shared menu
      expect(
          menuViewModel.menu['Måndag']!.first.title, equals('Shared Recipe 0'));
      expect(
          menuViewModel.menu['Tisdag']!.first.title, equals('Shared Recipe 1'));
      expect(
          menuViewModel.menu['Onsdag']!.first.title, equals('Shared Recipe 2'));

      // Save imported menu with modifications
      final saved = await menuViewModel.saveMenuWithNameAndComment(
        'Imported from ${sharedMenu.sharedByDisplayName}',
        'Great menu from my friend!',
      );

      expect(saved, isTrue);
    });
  });
}