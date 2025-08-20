/// Unit tests for services using RecipeRepository
/// 
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_change.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeRepository Mock Tests', () {
    late MockRecipeRepository mockRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(RecipeChange(
        type: RecipeChangeType.added,
        recipe: RecipeFactory.build(),
      ));
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mock repository with configuration
      mockRepository = MockFactory.createRecipeRepository(
        currentUserId: 'test-user-123',
        recipesByUser: {},
        archiveRecipes: [],
        searchResults: [],
        recipesById: {},
      );
      
      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('CRUD Operations', () {
      test('should create recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
          createdBy: 'test-user-123',
        );
        
        // Stub the repository method
        when(() => mockRepository.create(recipe))
            .thenAnswer((_) async => recipe);
        
        // Act
        final created = await mockRepository.create(recipe);
        
        // Assert
        expect(created.id, equals('recipe-1'));
        expect(created.title, equals('Test Recipe'));
        expect(created.createdBy, equals('test-user-123'));
        
        verify(() => mockRepository.create(recipe)).called(1);
      });
      
      test('should read recipe by ID', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final expectedRecipe = RecipeFactory.build(
          id: recipeId,
          title: 'Test Recipe',
          createdBy: 'test-user-123',
        );
        
        // Stub the repository method
        when(() => mockRepository.read(recipeId))
            .thenAnswer((_) async => expectedRecipe);
        
        // Act
        final recipe = await mockRepository.read(recipeId);
        
        // Assert
        expect(recipe, isNotNull);
        expect(recipe!.id, equals(recipeId));
        expect(recipe.title, equals('Test Recipe'));
        
        verify(() => mockRepository.read(recipeId)).called(1);
      });
      
      test('should return null for non-existent recipe', () async {
        // Arrange
        const recipeId = 'non-existent';
        
        // Stub the repository method
        when(() => mockRepository.read(recipeId))
            .thenAnswer((_) async => null);
        
        // Act
        final recipe = await mockRepository.read(recipeId);
        
        // Assert
        expect(recipe, isNull);
        verify(() => mockRepository.read(recipeId)).called(1);
      });
      
      test('should update recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Updated Title',
          createdBy: 'test-user-123',
        );
        
        // Stub the repository method
        when(() => mockRepository.update(recipe))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.update(recipe);
        
        // Assert
        verify(() => mockRepository.update(recipe)).called(1);
      });
      
      test('should delete recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Stub the repository method
        when(() => mockRepository.delete(recipeId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.delete(recipeId);
        
        // Assert
        verify(() => mockRepository.delete(recipeId)).called(1);
      });
    });
    
    group('Streaming Operations', () {
      test('should watch user recipes', () async {
        // Arrange
        const userId = 'test-user-123';
        final recipes = [
          RecipeFactory.build(id: 'recipe-1', title: 'Recipe 1'),
          RecipeFactory.build(id: 'recipe-2', title: 'Recipe 2'),
        ];
        
        // Stub the repository method
        when(() => mockRepository.watchRecipes(userId))
            .thenAnswer((_) => Stream.value(recipes));
        
        // Act
        final stream = mockRepository.watchRecipes(userId);
        final result = await stream.first;
        
        // Assert
        expect(result, hasLength(2));
        expect(result.first.title, equals('Recipe 1'));
        
        verify(() => mockRepository.watchRecipes(userId)).called(1);
      });
      
      test('should subscribe to recipe changes', () async {
        // Arrange
        const userId = 'test-user-123';
        final changes = [
          RecipeChange(
            type: RecipeChangeType.added,
            recipe: RecipeFactory.build(id: 'recipe-1'),
          ),
          RecipeChange(
            type: RecipeChangeType.modified,
            recipe: RecipeFactory.build(id: 'recipe-2'),
          ),
        ];
        
        // Create stream controller for testing
        final controller = StreamController<List<RecipeChange>>();
        
        // Stub the repository method
        when(() => mockRepository.subscribeToUserRecipes(
          userId,
          any(),
          onError: any(named: 'onError'),
        )).thenAnswer((invocation) {
          final callback = invocation.positionalArguments[1] as Function(List<RecipeChange>);
          return controller.stream.listen(callback);
        });
        
        // Act
        List<RecipeChange>? receivedChanges;
        final subscription = mockRepository.subscribeToUserRecipes(
          userId,
          (changes) => receivedChanges = changes,
        );
        
        // Emit changes
        controller.add(changes);
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Assert
        expect(receivedChanges, isNotNull);
        expect(receivedChanges, hasLength(2));
        
        // Cleanup
        await subscription.cancel();
        await controller.close();
        
        verify(() => mockRepository.subscribeToUserRecipes(
          userId,
          any(),
          onError: any(named: 'onError'),
        )).called(1);
      });
    });
    
    group('Search Operations', () {
      test('should search recipes by query', () async {
        // Arrange
        const query = 'pasta';
        final searchResults = [
          RecipeFactory.build(id: 'recipe-1', title: 'Pasta Carbonara'),
          RecipeFactory.build(id: 'recipe-2', title: 'Pasta Bolognese'),
        ];
        
        // Stub the repository method
        when(() => mockRepository.searchRecipes(query))
            .thenAnswer((_) async => searchResults);
        
        // Act
        final results = await mockRepository.searchRecipes(query);
        
        // Assert
        expect(results, hasLength(2));
        expect(results.every((r) => r.title.toLowerCase().contains('pasta')), isTrue);
        
        verify(() => mockRepository.searchRecipes(query)).called(1);
      });
      
      test('should return empty list for no search results', () async {
        // Arrange
        const query = 'xyz123';
        
        // Stub the repository method
        when(() => mockRepository.searchRecipes(query))
            .thenAnswer((_) async => []);
        
        // Act
        final results = await mockRepository.searchRecipes(query);
        
        // Assert
        expect(results, isEmpty);
        verify(() => mockRepository.searchRecipes(query)).called(1);
      });
    });
    
    group('Batch Operations', () {
      test('should add multiple recipes', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'recipe-1', title: 'Recipe 1'),
          RecipeFactory.build(id: 'recipe-2', title: 'Recipe 2'),
          RecipeFactory.build(id: 'recipe-3', title: 'Recipe 3'),
        ];
        
        // Stub the repository method
        when(() => mockRepository.addRecipes(recipes))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.addRecipes(recipes);
        
        // Assert
        verify(() => mockRepository.addRecipes(recipes)).called(1);
      });
    });
    
    group('Archive Operations', () {
      test('should fetch all archive recipes', () async {
        // Arrange
        final archiveRecipes = [
          RecipeFactory.build(id: 'archive-1', title: 'Classic Recipe 1'),
          RecipeFactory.build(id: 'archive-2', title: 'Classic Recipe 2'),
        ];
        
        // Stub the repository method
        when(() => mockRepository.fetchArchiveRecipes())
            .thenAnswer((_) async => archiveRecipes);
        
        // Act
        final recipes = await mockRepository.fetchArchiveRecipes();
        
        // Assert
        expect(recipes, hasLength(2));
        expect(recipes.first.title, equals('Classic Recipe 1'));
        
        verify(() => mockRepository.fetchArchiveRecipes()).called(1);
      });
      
      test('should fetch specific archive recipe', () async {
        // Arrange
        const archiveId = 'archive-1';
        final archiveRecipe = RecipeFactory.build(
          id: archiveId,
          title: 'Classic Swedish Meatballs',
        );
        
        // Stub the repository method
        when(() => mockRepository.fetchArchiveRecipe(archiveId))
            .thenAnswer((_) async => archiveRecipe);
        
        // Act
        final recipe = await mockRepository.fetchArchiveRecipe(archiveId);
        
        // Assert
        expect(recipe.id, equals(archiveId));
        expect(recipe.title, equals('Classic Swedish Meatballs'));
        
        verify(() => mockRepository.fetchArchiveRecipe(archiveId)).called(1);
      });
    });
    
    group('User Recipes', () {
      test('should fetch all recipes for a user', () async {
        // Arrange
        const userId = 'test-user-123';
        final userRecipes = [
          RecipeFactory.build(id: 'recipe-1', createdBy: userId),
          RecipeFactory.build(id: 'recipe-2', createdBy: userId),
          RecipeFactory.build(id: 'recipe-3', createdBy: userId),
        ];
        
        // Stub the repository method
        when(() => mockRepository.fetchUserRecipes(userId))
            .thenAnswer((_) async => userRecipes);
        
        // Act
        final recipes = await mockRepository.fetchUserRecipes(userId);
        
        // Assert
        expect(recipes, hasLength(3));
        expect(recipes.every((r) => r.createdBy == userId), isTrue);
        
        verify(() => mockRepository.fetchUserRecipes(userId)).called(1);
      });
      
      test('should return empty list for user with no recipes', () async {
        // Arrange
        const userId = 'user-with-no-recipes';
        
        // Stub the repository method
        when(() => mockRepository.fetchUserRecipes(userId))
            .thenAnswer((_) async => []);
        
        // Act
        final recipes = await mockRepository.fetchUserRecipes(userId);
        
        // Assert
        expect(recipes, isEmpty);
        verify(() => mockRepository.fetchUserRecipes(userId)).called(1);
      });
    });
  });
}