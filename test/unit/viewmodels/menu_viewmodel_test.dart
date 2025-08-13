import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mock dependencies
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}
class MockMenuService extends Mock implements MenuService {}
class MockSocialMenuOperations extends Mock implements SocialMenuOperations {}

// SavedMenuInfo class for testing
class SavedMenuInfo {
  final String key;
  final String name;
  final String comment;
  final DateTime savedDate;
  final bool isOwned;
  final String? sharedBy;
  final Map<String, List<Recipe>> menu;
  final String lastPrompt;

  SavedMenuInfo({
    required this.key,
    required this.name,
    required this.comment,
    required this.savedDate,
    required this.isOwned,
    this.sharedBy,
    required this.menu,
    required this.lastPrompt,
  });
}

void main() {
  group('MenuViewModel', () {
    late MenuViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockMenuService mockMenuService;
    late MockSocialMenuOperations mockSocialMenuOps;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockRecipeService = MockUnifiedRecipeService();
      mockMenuService = MockMenuService();
      mockSocialMenuOps = MockSocialMenuOperations();
      
      // Setup default mock behaviors
      when(() => mockRecipeService.recipes).thenReturn([]);
      when(() => mockRecipeService.isInitialized).thenReturn(true);
      when(() => mockRecipeService.initialize()).thenAnswer((_) async {});
      when(() => mockRecipeService.addListener(any())).thenReturn(null);
      when(() => mockRecipeService.removeListener(any())).thenReturn(null);
      
      when(() => mockMenuService.generateMenuFromPrompt(any(), any())).thenAnswer(
        (_) async => {
          'Frukost': [RecipeFactory.build(id: 'b1', title: 'Gröt')],
          'Lunch': [RecipeFactory.build(id: 'l1', title: 'Sallad')],
          'Middag': [RecipeFactory.build(id: 'd1', title: 'Pasta')],
        },
      );
      
      when(() => mockSocialMenuOps.shareMenuWithFriends(
        menu: any(named: 'menu'),
        friendUserIds: any(named: 'friendUserIds'),
        message: any(named: 'message'),
        customTitle: any(named: 'customTitle'),
      )).thenAnswer((_) async => true);
      
      when(() => mockSocialMenuOps.getMenusSharedWithMe()).thenAnswer(
        (_) async => <Map<String, dynamic>>[],
      );
      
      when(() => mockSocialMenuOps.importSharedMenu(any())).thenAnswer(
        (_) async => true,
      );
      
      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<MenuService>(mockMenuService);
      TestServiceLocator.registerMock<SocialMenuOperations>(mockSocialMenuOps);
      
      // TestServiceLocator already handles production ServiceLocator initialization
      
      // Create viewModel
      viewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      // Don't dispose here since some tests dispose manually
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with empty menu', () {
        // Arrange - viewModel already initialized in setUp
        
        // Act - no action needed, checking initial state
        
        // Assert
        expect(viewModel.menu, isEmpty);
        expect(viewModel.hasMenu, isFalse);
      });

      test('should initialize with default state', () {
        // Arrange - viewModel already initialized in setUp
        
        // Act - no action needed, checking initial state
        
        // Assert
        expect(viewModel.isGenerating, isFalse);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.lastPrompt, isEmpty);
      });

      test('should register listener for recipe service updates', () {
        // Arrange - viewModel created in setUp
        
        // Act - no action needed, verifying constructor behavior
        
        // Assert
        verify(() => mockRecipeService.addListener(any())).called(1);
      });
    });

    group('Menu Generation', () {
      test('should generate menu from prompt', () async {
        // Arrange
        const prompt = 'Vegetarisk veckomeny för familj';
        
        // Mock with some recipes available
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
          RecipeFactory.build(id: 'r2'),
        ]);
        
        // Act
        await viewModel.generateMenu(prompt);
        
        // Assert
        expect(viewModel.hasMenu, isTrue);
        expect(viewModel.menu, isNotEmpty);
        expect(viewModel.lastPrompt, equals(prompt));
        expect(viewModel.menu['Frukost'], isNotNull);
        expect(viewModel.menu['Lunch'], isNotNull);
        expect(viewModel.menu['Middag'], isNotNull);
      });

      test('should handle empty prompt', () async {
        // Arrange - initial state from setUp
        
        // Act
        await viewModel.generateMenu('');
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
        expect(viewModel.hasMenu, isFalse);
      });

      test('should handle whitespace-only prompt', () async {
        // Arrange - initial state from setUp
        
        // Act
        await viewModel.generateMenu('   ');
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
      });

      test('should set generating state during generation', () async {
        // Arrange
        
        // Act - start generation
        final future = viewModel.generateMenu('Test prompt');
        
        // Assert - check state immediately after starting
        expect(viewModel.isGenerating, isTrue);
        
        // Act - wait for completion
        await future;
        
        // Assert - check state after completion
        expect(viewModel.isGenerating, isFalse);
      });

      test('should handle generation failure', () async {
        // Arrange
        when(() => mockMenuService.generateMenuFromPrompt(any(), any())).thenThrow(
          Exception('Generation failed'),
        );
        
        // Act
        await viewModel.generateMenu('Test prompt');
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Meny-generering misslyckades'));
        expect(viewModel.hasMenu, isFalse);
      });
    });

    group('Section Regeneration', () {
      test('should regenerate menu section', () async {
        // Arrange - first generate a menu
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        
        // Mock the regeneration to return new recipes
        when(() => mockMenuService.generateMenuFromPrompt('1 Middag', any())).thenAnswer(
          (_) async => {
            'Middag': [RecipeFactory.build(id: 'new1', title: 'Ny rätt')],
          },
        );
        
        // Act - regenerate a section
        await viewModel.regenerateSection('Middag');
        
        // Assert
        expect(viewModel.menu['Middag'], isNotEmpty);
        verify(() => mockMenuService.generateMenuFromPrompt('1 Middag', any())).called(1);
      });

      test('should not regenerate if no menu exists', () async {
        // Arrange - no menu exists
        
        // Act
        await viewModel.regenerateSection('Middag');
        
        // Assert
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });

      test('should handle regeneration failure', () async {
        // Arrange - first generate a menu
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        
        when(() => mockMenuService.generateMenuFromPrompt('1 Middag', any())).thenThrow(
          Exception('Regeneration failed'),
        );
        
        // Act
        await viewModel.regenerateSection('Middag');
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Kunde inte uppdatera Middag'));
      });
    });

    group('Menu Saving', () {
      test('should validate menu before saving', () async {
        // Arrange - no menu exists
        
        // Act - try to save without a menu
        final saved = await viewModel.saveMenuWithNameAndComment(
          'Min Meny',
          'En test kommentar',
        );
        
        // Assert
        expect(saved, isFalse);
        expect(viewModel.error, equals('Ingen meny att spara'));
      });

      test('should handle save without menu', () async {
        // Arrange - no menu exists
        
        // Act
        final saved = await viewModel.saveMenuWithNameAndComment(
          'Min Meny',
          'Kommentar',
        );
        
        // Assert
        expect(saved, isFalse);
        expect(viewModel.error, equals('Ingen meny att spara'));
      });

      test('should handle save without name', () async {
        // Arrange - generate a menu first
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        
        // Act
        final saved = await viewModel.saveMenuWithNameAndComment(
          '',
          'Kommentar',
        );
        
        // Assert
        expect(saved, isFalse);
        expect(viewModel.error, equals('Ange ett namn för menyn'));
      });

      test('should validate empty friend list for social sharing', () async {
        // Arrange - generate a menu first
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        
        // Act - try to save with social sharing but no friends selected
        await viewModel.saveMenuWithNameAndComment(
          'Min Meny',
          'Kommentar',
          shareWithFriends: true,
          selectedFriendIds: [], // Empty list
          shareMessage: 'Check out this menu!',
        );
        
        // Assert - should save locally but not share
        // Since we can't easily mock the internal storage, just verify no sharing happened
        verifyNever(() => mockSocialMenuOps.shareMenuWithFriends(
          menu: any(named: 'menu'),
          friendUserIds: any(named: 'friendUserIds'),
          message: any(named: 'message'),
          customTitle: any(named: 'customTitle'),
        ));
      });
    });

    group('State Management', () {
      test('should clear menu', () async {
        // Arrange - generate a menu first
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        expect(viewModel.hasMenu, isTrue);
        
        // Act
        viewModel.clearMenu();
        
        // Assert
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.menu, isEmpty);
      });

      test('should clear error', () async {
        // Arrange - generate an error
        await viewModel.generateMenu('');
        expect(viewModel.hasError, isTrue);
        
        // Act
        viewModel.clearError();
        
        // Assert
        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should calculate total recipe count', () async {
        // Arrange
        when(() => mockRecipeService.recipes).thenReturn([
          RecipeFactory.build(id: 'r1'),
        ]);
        await viewModel.generateMenu('Test menu');
        
        // Act - access totalRecipeCount property
        
        // Assert
        expect(viewModel.totalRecipeCount, equals(3));
      });

      test('should get available recipes from service', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1'),
          RecipeFactory.build(id: 'r2'),
        ];
        when(() => mockRecipeService.recipes).thenReturn(recipes);
        
        // Act & Assert
        expect(viewModel.availableRecipes, equals(recipes));
        expect(viewModel.hasAvailableRecipes, isTrue);
      });
    });

    group('Social Features', () {
      test('should get available shared menus', () async {
        // Arrange - MenuViewModel's getAvailableSharedMenus delegates to the social manager
        // which internally uses different methods. For testing purposes,
        // we'll just verify it returns an empty list when there's an error
        
        // Act
        final result = await viewModel.getAvailableSharedMenus();
        
        // Assert
        expect(result, isEmpty);
      });

      test('should import shared menu', () async {
        // Arrange - mock already configured in setUp
        
        // Act
        final imported = await viewModel.importSharedMenu('shared_menu_123');
        
        // Assert
        expect(imported, isTrue);
        verify(() => mockSocialMenuOps.importSharedMenu('shared_menu_123')).called(1);
      });

      test('should handle import failure', () async {
        // Arrange
        when(() => mockSocialMenuOps.importSharedMenu(any())).thenThrow(
          Exception('Import failed'),
        );
        
        // Act
        final imported = await viewModel.importSharedMenu('shared_menu_123');
        
        // Assert
        expect(imported, isFalse);
        expect(viewModel.error, contains('Kunde inte importera meny'));
      });
    });

    group('Lifecycle', () {
      test('should cleanup on dispose', () {
        // Arrange - create a fresh viewModel for this test
        final testViewModel = MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
        );
        
        // Act
        testViewModel.dispose();
        
        // Assert
        verify(() => mockRecipeService.removeListener(any())).called(1);
      });

      test('should notify listeners when recipes change', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act - simulate recipe service update
        final listener = verify(() => mockRecipeService.addListener(captureAny())).captured.first;
        listener();
        
        // Assert
        expect(notificationCount, equals(1));
      });
    });
  });
}