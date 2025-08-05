import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/auth_service.dart';
import '../../../helpers/test_service_locator.dart';
import '../../../helpers/mock_factories.dart';
// Mocks
class MockMenuService extends Mock implements MenuService {}

class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class MockSocialMenuOperations extends Mock implements SocialMenuOperations {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  late MenuViewModel sut;
  late MockMenuService mockMenuService;
  late MockUnifiedRecipeService mockRecipeService;
  late MockSocialMenuOperations mockSocialMenuOps;
  late MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(RecipeFactory.empty());
    registerFallbackValue(SharedMenuFactory.empty());
  });

  setUp(() {
    // Initialize test service locator
    // ServiceLocator is already initialized by configureTests()

    mockMenuService = MockMenuService();
    mockRecipeService = MockUnifiedRecipeService();
    mockSocialMenuOps = MockSocialMenuOperations();
    mockAuthService = MockAuthService();

    // Setup default mock behaviors
    when(() => mockAuthService.currentUserId).thenReturn(null);
    when(() => mockRecipeService.recipes).thenReturn([]);
    when(() => mockRecipeService.personalRecipes).thenReturn([]);
    when(() => mockRecipeService.addListener(any())).thenReturn(null);
    when(() => mockRecipeService.removeListener(any())).thenReturn(null);

    // Override test service locator services
    when(() => TestServiceLocator.container.get<SocialMenuOperations>())
        .thenReturn(mockSocialMenuOps);

    sut = MenuViewModel(
      menuService: mockMenuService,
      recipeService: mockRecipeService,
    );
  });

  tearDown(() {
    sut.dispose();
    // Disposal is handled by configureTests()
  });

  group('MenuViewModel - Initialization', () {
    test('should initialize with empty state', () {
      expect(sut.menu, isEmpty);
      expect(sut.hasMenu, isFalse);
      expect(sut.isGenerating, isFalse);
      expect(sut.error, isNull);
      expect(sut.savedMenus, isEmpty);
    });

    test('should have available recipes from recipe service', () {
      // Given
      final recipes = [
        RecipeFactory.build(),
        RecipeFactory.build(),
      ];
      when(() => mockRecipeService.personalRecipes).thenReturn(recipes);

      // When
      final newSut = MenuViewModel(
        menuService: mockMenuService,
        recipeService: mockRecipeService,
      );

      // Then
      expect(newSut.availableRecipes, equals(recipes));
      expect(newSut.hasAvailableRecipes, isTrue);

      newSut.dispose();
    });
  });

  group('MenuViewModel - Menu Generation', () {
    test('should generate menu from prompt', () async {
      // Given
      final recipes = List.generate(5, (i) => RecipeFactory.build());
      final generatedMenu = {
        'Måndag': [recipes[0], recipes[1]],
        'Tisdag': [recipes[2]],
        'Onsdag': [recipes[3], recipes[4]],
      };

      when(() => mockRecipeService.personalRecipes).thenReturn(recipes);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => generatedMenu);

      // When
      await sut.generateMenu('Test prompt');

      // Then
      expect(sut.hasMenu, isTrue);
      expect(sut.menu, equals(generatedMenu));
      expect(sut.error, isNull);
      expect(sut.totalRecipeCount, equals(5));
    });

    test('should handle empty prompt', () async {
      // When
      await sut.generateMenu('');

      // Then
      expect(sut.error, equals('Ange vad du vill ha för meny'));
      expect(sut.hasMenu, isFalse);
      verifyNever(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          ));
    });

    test('should handle generation errors', () async {
      // Given
      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenThrow(Exception('Network error'));

      // When
      await sut.generateMenu('Test prompt');

      // Then
      expect(sut.error, contains('Meny-generering misslyckades'));
      expect(sut.hasMenu, isFalse);
    });
  });

  group('MenuViewModel - Section Regeneration', () {
    test('should regenerate menu section', () async {
      // Given - Existing menu
      final originalRecipes = List.generate(
          5,
          (i) => RecipeFactory.build(
                id: 'original_$i',
              ));
      final newRecipes = [
        RecipeFactory.build(id: 'new_1'),
        RecipeFactory.build(id: 'new_2'),
      ];

      // Setup existing menu
      when(() => mockRecipeService.personalRecipes).thenReturn(originalRecipes);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => {
            'Måndag': [originalRecipes[0], originalRecipes[1]],
            'Tisdag': [originalRecipes[2]],
          });

      await sut.generateMenu('Initial menu');

      // Mock regeneration - regenerateSection internally uses generateMenuFromPrompt
      // with a modified prompt for the specific section
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => {
            'Måndag': newRecipes,
            'Tisdag': [originalRecipes[2]], // Keep other days unchanged
          });

      // When
      await sut.regenerateSection('Måndag');

      // Then
      expect(sut.menu['Måndag'], equals(newRecipes));
      expect(sut.menu['Tisdag']!.length, equals(1)); // Unchanged
    });

    test('should not regenerate if no menu exists', () async {
      // When
      await sut.regenerateSection('Måndag');

      // Then
      // Verify no menu service calls when no menu exists
      verifyNever(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          ));
    });
  });

  group('MenuViewModel - Menu Persistence', () {
    test('should save menu with name and comment', () async {
      // Given - Existing menu
      final menu = {
        'Måndag': [RecipeFactory.build()],
        'Tisdag': [RecipeFactory.build()],
      };

      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => menu);

      await sut.generateMenu('Test menu');

      // When
      final result = await sut.saveMenuWithNameAndComment(
        'Test Menu',
        'Test Comment',
      );

      // Then
      expect(result, isTrue);
      expect(sut.savedMenus.length, greaterThan(0));
      expect(sut.savedMenus.first.name, equals('Test Menu'));
      expect(sut.savedMenus.first.comment, equals('Test Comment'));
    });

    test('should handle save errors', () async {
      // Given - No menu to save
      final result = await sut.saveMenuWithNameAndComment(
        'Test Menu',
        'Test Comment',
      );

      // Then
      expect(result, isFalse);
      expect(sut.error, isNotNull);
    });

    test('should load saved menus', () async {
      // Given - Saved menu
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };

      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => menu);

      await sut.generateMenu('Test');
      await sut.saveMenuWithNameAndComment('Saved Menu', 'Comment');

      // When
      final loaded = await sut.loadSavedMenu(sut.savedMenus.first.key);

      // Then
      expect(loaded, isTrue);
      expect(sut.hasMenu, isTrue);
      expect(sut.menu, equals(menu));
    });
  });

  group('MenuViewModel - Social Features', () {
    test('should save and share menu with friends', () async {
      // Given
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };
      final friendIds = ['friend1', 'friend2'];

      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => menu);

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      await sut.generateMenu('Test');

      // When
      final result = await sut.saveMenuWithNameAndComment(
        'Shared Menu',
        'Great menu',
        shareWithFriends: true,
        selectedFriendIds: friendIds,
        shareMessage: 'Check this out!',
      );

      // Then
      expect(result, isTrue);
      verify(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: menu,
            friendUserIds: friendIds,
            message: 'Check this out!',
            customTitle: 'Shared Menu',
          )).called(1);
    });

    test('should import shared menu', () async {
      // Given
      final sharedMenu = SharedMenuFactory.build(
        menuSnapshot: {
          'Måndag': [RecipeFactory.build()],
          'Tisdag': [RecipeFactory.build()],
        },
      );

      when(() => mockSocialMenuOps.markMenuAsViewed(any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.importSharedMenu(sharedMenu.id);

      // Then
      expect(result, isTrue);
      expect(sut.hasMenu, isTrue);
      expect(sut.menu, equals(sharedMenu.menuSnapshot));
      verify(() => mockSocialMenuOps.markMenuAsViewed(sharedMenu.id)).called(1);
    });
  });

  group('MenuViewModel - State Management', () {
    test('should clear menu', () async {
      // Given - Existing menu
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };

      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async => menu);

      await sut.generateMenu('Test');
      expect(sut.hasMenu, isTrue);

      // When
      sut.clearMenu();

      // Then
      expect(sut.hasMenu, isFalse);
      expect(sut.menu, isEmpty);
    });

    test('should clear error', () async {
      // Given - Error state
      await sut.generateMenu(''); // Causes error
      expect(sut.error, isNotNull);

      // When
      sut.clearError();

      // Then
      expect(sut.error, isNull);
    });

    test('should track generation state', () async {
      // Given
      bool wasGenerating = false;
      sut.addListener(() {
        if (sut.isGenerating) {
          wasGenerating = true;
        }
      });

      when(() => mockRecipeService.personalRecipes).thenReturn([]);
      when(() => mockMenuService.generateMenuFromPrompt(
            any(),
            any(),
          )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return {};
      });

      // When
      await sut.generateMenu('Test');

      // Then
      expect(wasGenerating, isTrue);
      expect(sut.isGenerating, isFalse);
    });
  });
}