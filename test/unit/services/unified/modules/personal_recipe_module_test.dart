/// Comprehensive unit tests for PersonalRecipeModule
/// 
/// Tests the personal recipe module that handles CRUD operations, content management,
/// validation, caching, and import/export functionality for individual recipes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  group('PersonalRecipeModule', () {
    late PersonalRecipeModule module;
    late MockRecipeRepository mockRepository;
    late MockUserRepository mockUserRepository;
    late MockJsonCacheHelper mockCacheHelper;
    late MockRecipeServiceAdapter mockServiceAdapter;
    late Recipe testRecipe;
    
    // Callback functions
    String? currentUserId;
    String? currentUserDisplayName;
    String? lastError;
    int notifyListenersCalled = 0;
    
    setUpAll(() {
      // Centralized fallback values already registered via TestServiceLocator
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks using centralized infrastructure
      mockRepository = MockRecipeRepository();
      mockUserRepository = MockUserRepository();
      mockCacheHelper = MockJsonCacheHelper();
      mockServiceAdapter = MockRecipeServiceAdapter();
      
      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      lastError = null;
      notifyListenersCalled = 0;
      
      module = PersonalRecipeModule(
        recipeRepository: mockRepository,
        userRepository: mockUserRepository,
        getCacheHelper: () => mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) => lastError = error,
        notifyListeners: () => notifyListenersCalled++,
        getServiceAdapter: () => mockServiceAdapter,
      );
      
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
        createdBy: 'test-user-123',
      );
      
      // Setup mock cache helper
      when(() => mockCacheHelper.setCurrentUser(any())).thenReturn(null);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Personal Recipe CRUD', () {
      test('should create personal recipe successfully', () async {
        // Arrange
        when(() => mockCacheHelper.saveJson(any(), any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.createRecipe(any())).thenAnswer((_) async => 'new-recipe-id');
        
        // Act
        final recipeId = await module.createPersonalRecipe(
          title: 'Nya Köttbullar',
          description: 'Med lingonsylt',
          ingredients: ['500g köttfärs', '1 ägg', '1 dl ströbröd'],
          instructions: ['Blanda', 'Forma bollar', 'Stek'],
          mealType: 'Lunch',
          portions: 4,
          timeMinutes: 30,
        );
        
        // Assert
        expect(recipeId, equals('new-recipe-id'));
        verify(() => mockCacheHelper.saveJson(any(), any())).called(1);
        verify(() => mockServiceAdapter.createRecipe(any())).called(1);
      });
      
      test('should fail creation with empty title', () async {
        // Act
        final recipeId = await module.createPersonalRecipe(
          title: '',
          ingredients: ['test'],
          instructions: ['test'],
        );
        
        // Assert
        expect(recipeId, isNull);
        expect(lastError, equals('Receptnamn kan inte vara tomt'));
      });
      
      test('should fail creation when not authenticated', () async {
        // Arrange
        currentUserId = null;
        
        // Act
        final recipeId = await module.createPersonalRecipe(
          title: 'Test Recipe',
          ingredients: ['test'],
          instructions: ['test'],
        );
        
        // Assert
        expect(recipeId, isNull);
        expect(lastError, equals('Du måste vara inloggad'));
      });
      
      test('should update personal recipe successfully', () async {
        // Arrange
        when(() => mockCacheHelper.saveJson(any(), any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.updateRecipe(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await module.updatePersonalRecipe(testRecipe);
        
        // Assert
        expect(success, isTrue);
        verify(() => mockCacheHelper.saveJson(any(), any())).called(1);
        verify(() => mockServiceAdapter.updateRecipe(any())).called(1);
      });
      
      test('should fail updating non-personal recipe', () async {
        // Arrange
        final collaborativeRecipe = Recipe.collaborative(
          title: 'Shared Recipe',
          description: 'Test description',
          ingredients: ['test'],
          instructions: ['test'],
          mealType: 'Lunch',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        );
        
        // Act
        final success = await module.updatePersonalRecipe(collaborativeRecipe);
        
        // Assert
        expect(success, isFalse);
        expect(lastError, equals('Kan bara uppdatera personliga recept'));
      });
      
      test('should delete personal recipe successfully', () async {
        // Arrange
        when(() => mockCacheHelper.delete(any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.deleteRecipe(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await module.deletePersonalRecipe('test-recipe-1');
        
        // Assert
        expect(success, isTrue);
        verify(() => mockCacheHelper.delete('test-recipe-1')).called(1);
        verify(() => mockServiceAdapter.deleteRecipe('test-recipe-1')).called(1);
      });
      
      test('should mark recipe as cooked', () async {
        // Act
        final success = await module.markRecipeAsCooked('test-recipe-1');
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Recipe Content Operations', () {
      test('should add ingredient to recipe', () async {
        // Act
        final success = await module.addIngredient('test-recipe-1', '2 dl mjölk');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update ingredient at index', () async {
        // Act
        final success = await module.updateIngredient('test-recipe-1', 0, '600g köttfärs');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove ingredient at index', () async {
        // Act
        final success = await module.removeIngredient('test-recipe-1', 1);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should add instruction to recipe', () async {
        // Act
        final success = await module.addInstruction('test-recipe-1', 'Servera med potatismos');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update instruction at index', () async {
        // Act
        final success = await module.updateInstruction('test-recipe-1', 0, 'Blanda försiktigt');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove instruction at index', () async {
        // Act
        final success = await module.removeInstruction('test-recipe-1', 2);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should fail content operations when not authenticated', () async {
        // Arrange
        currentUserId = null;
        
        // Act
        final addIngredient = await module.addIngredient('test-recipe-1', 'test');
        final updateIngredient = await module.updateIngredient('test-recipe-1', 0, 'test');
        final removeIngredient = await module.removeIngredient('test-recipe-1', 0);
        
        // Assert
        expect(addIngredient, isFalse);
        expect(updateIngredient, isFalse);
        expect(removeIngredient, isFalse);
        expect(lastError, equals('Du måste vara inloggad'));
      });
    });
    
    group('Validation', () {
      test('should validate valid recipe data', () {
        // Act
        final isValid = module.validateRecipeData(
          title: 'Test Recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
        );
        
        // Assert
        expect(isValid, isTrue);
      });
      
      test('should reject empty title', () {
        // Act
        final isValid = module.validateRecipeData(
          title: '  ',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
        );
        
        // Assert
        expect(isValid, isFalse);
        expect(lastError, equals('Receptnamn kan inte vara tomt'));
      });
      
      test('should reject empty ingredients', () {
        // Act
        final isValid = module.validateRecipeData(
          title: 'Test Recipe',
          ingredients: [],
          instructions: ['step 1'],
        );
        
        // Assert
        expect(isValid, isFalse);
        expect(lastError, equals('Recept måste ha minst en ingrediens'));
      });
      
      test('should reject empty instructions', () {
        // Act
        final isValid = module.validateRecipeData(
          title: 'Test Recipe',
          ingredients: ['ingredient 1'],
          instructions: [],
        );
        
        // Assert
        expect(isValid, isFalse);
        expect(lastError, equals('Recept måste ha minst en instruktion'));
      });
      
      test('should check if recipe belongs to current user', () {
        // Act
        final isOwn = module.isOwnRecipe(testRecipe);
        
        // Assert
        expect(isOwn, isTrue);
      });
      
      test('should detect recipe not owned by user', () {
        // Arrange
        final otherRecipe = RecipeFactory.build(
          createdBy: 'other-user-456',
        );
        
        // Act
        final isOwn = module.isOwnRecipe(otherRecipe);
        
        // Assert
        expect(isOwn, isFalse);
      });
    });
    
    group('Cache Operations', () {
      test('should load cached personal recipes', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys()).thenAnswer((_) async => ['recipe-1', 'recipe-2']);
        when(() => mockCacheHelper.loadJson('recipe-1'))
            .thenAnswer((_) async => testRecipe.toJson());
        when(() => mockCacheHelper.loadJson('recipe-2'))
            .thenAnswer((_) async => null);
        
        // Act
        final cachedRecipes = await module.loadCachedPersonalRecipes();
        
        // Assert
        expect(cachedRecipes.length, equals(1));
        expect(cachedRecipes.first.id, equals(testRecipe.id));
      });
      
      test('should handle cache loading errors', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys()).thenThrow(Exception('Cache error'));
        
        // Act
        final cachedRecipes = await module.loadCachedPersonalRecipes();
        
        // Assert
        expect(cachedRecipes, isEmpty);
      });
      
      test('should delete corrupted cached recipes', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys()).thenAnswer((_) async => ['corrupt-recipe']);
        when(() => mockCacheHelper.loadJson('corrupt-recipe'))
            .thenAnswer((_) async => {'invalid': 'data'});
        when(() => mockCacheHelper.delete('corrupt-recipe')).thenAnswer((_) async => true);
        
        // Act
        final cachedRecipes = await module.loadCachedPersonalRecipes();
        
        // Assert
        expect(cachedRecipes, isEmpty);
        verify(() => mockCacheHelper.delete('corrupt-recipe')).called(1);
      });
    });
    
    group('Repository Operations', () {
      test('should get personal recipes stream', () {
        // Arrange
        when(() => mockRepository.watchRecipes(any())).thenAnswer((_) => Stream.value([]));
        
        // Act
        final stream = module.getPersonalRecipesStream();
        
        // Assert
        expect(stream, isNotNull);
        verify(() => mockRepository.watchRecipes('test-user-123')).called(1);
      });
      
      test('should return null stream when not authenticated', () {
        // Arrange
        currentUserId = null;
        
        // Act
        final stream = module.getPersonalRecipesStream();
        
        // Assert
        expect(stream, isNull);
      });
      
      test('should get personal recipes list', () async {
        // Arrange
        when(() => mockRepository.fetchUserRecipes(any()))
            .thenAnswer((_) async => [testRecipe]);
        
        // Act
        final recipes = await module.getPersonalRecipesList();
        
        // Assert
        expect(recipes, isNotNull);
        expect(recipes!.length, equals(1));
        verify(() => mockRepository.fetchUserRecipes('test-user-123')).called(1);
      });
      
      test('should handle repository fetch errors', () async {
        // Arrange
        when(() => mockRepository.fetchUserRecipes(any()))
            .thenAnswer((_) async => throw Exception('Fetch error'));
        
        // Act
        final recipes = await module.getPersonalRecipesList();
        
        // Assert
        expect(recipes, isNull);
      });
    });
    
    group('Import/Export Functionality', () {
      test('should import recipes from data', () async {
        // Arrange
        final recipesData = [
          testRecipe.toJson(),
          RecipeFactory.build(id: 'recipe-2').toJson(),
        ];
        
        when(() => mockCacheHelper.saveJson(any(), any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.createRecipe(any())).thenAnswer((_) async => 'imported-id');
        
        // Act
        final importedIds = await module.importRecipesFromData(recipesData);
        
        // Assert
        expect(importedIds.length, equals(2));
        expect(notifyListenersCalled, equals(1));
      });
      
      test('should handle import errors gracefully', () async {
        // Arrange
        final invalidData = [
          {'invalid': 'data'},
        ];
        
        // Act
        final importedIds = await module.importRecipesFromData(invalidData);
        
        // Assert
        expect(importedIds, isEmpty);
      });
      
      test('should export personal recipes', () async {
        // Arrange
        // Create a personal recipe that belongs to the current user
        final personalRecipe = Recipe.personal(
          title: 'Personal Recipe',
          description: 'Test personal recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Lunch',
          createdBy: 'test-user-123', // Must match currentUserId
        );
        
        when(() => mockCacheHelper.getAllKeys()).thenAnswer((_) async => ['recipe-1']);
        when(() => mockCacheHelper.loadJson('recipe-1'))
            .thenAnswer((_) async => personalRecipe.toJson());
        
        // Act
        final exportedData = await module.exportPersonalRecipes();
        
        // Assert
        expect(exportedData.length, equals(1));
        expect(exportedData.first['core'], isNotNull);
        expect(exportedData.first['core']['id'], isNotNull);
        expect(exportedData.first['core']['title'], equals('Personal Recipe'));
      });
      
      test('should fail import when not authenticated', () async {
        // Arrange
        currentUserId = null;
        
        // Act
        final importedIds = await module.importRecipesFromData([testRecipe.toJson()]);
        
        // Assert
        expect(importedIds, isEmpty);
        expect(lastError, equals('Du måste vara inloggad för att importera recept'));
      });
    });
    
    group('Utility Methods', () {
      test('should create success result', () {
        // Act
        final result = module.createSuccessResult('Operation successful');
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Operation successful'));
      });
      
      test('should create failure result', () {
        // Act
        final result = module.createFailureResult('Operation failed');
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.message, equals('Operation failed'));
      });
      
      test('should clear error', () {
        // Act
        module.clearError();
        
        // Assert
        // No error thrown, method exists
      });
    });
    
    group('Edge Cases', () {
      test('should handle null cache helper responses', () async {
        // Arrange
        when(() => mockCacheHelper.getAllKeys()).thenAnswer((_) async => ['recipe-1']);
        when(() => mockCacheHelper.loadJson('recipe-1')).thenAnswer((_) async => null);
        
        // Act
        final cachedRecipes = await module.loadCachedPersonalRecipes();
        
        // Assert
        expect(cachedRecipes, isEmpty);
      });
      
      test('should remove from cache if service creation fails', () async {
        // Arrange
        when(() => mockCacheHelper.saveJson(any(), any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.createRecipe(any())).thenAnswer((_) async => null);
        when(() => mockCacheHelper.delete(any())).thenAnswer((_) async => true);
        
        // Act
        final recipeId = await module.createPersonalRecipe(
          title: 'Test Recipe',
          ingredients: ['test'],
          instructions: ['test'],
        );
        
        // Assert
        expect(recipeId, isNull);
        verify(() => mockCacheHelper.delete(any())).called(1);
      });
      
      test('should handle special characters in recipe title', () async {
        // Arrange
        when(() => mockCacheHelper.saveJson(any(), any())).thenAnswer((_) async => true);
        when(() => mockServiceAdapter.createRecipe(any())).thenAnswer((_) async => 'new-id');
        
        // Act
        final recipeId = await module.createPersonalRecipe(
          title: 'Räksmörgås & Ost',
          ingredients: ['räkor', 'ost'],
          instructions: ['montera'],
        );
        
        // Assert
        expect(recipeId, equals('new-id'));
      });
    });
  });
}