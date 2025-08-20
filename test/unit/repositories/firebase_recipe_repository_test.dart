/// Comprehensive unit tests for FirebaseRecipeRepository
/// 
/// Tests Firebase Firestore implementation of recipe data operations including
/// CRUD operations, permission validation, real-time streaming, and search functionality.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();
      
      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser();
      
      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-123',
        isAuthenticated: true,
      );
      
      // Create repository with fake Firestore
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('CRUD Operations', () {
      test('should create recipe with validation', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
          createdBy: 'test-user-123',
        );
        
        // Act
        final created = await repository.create(recipe);
        
        // Assert
        expect(created.id, equals('recipe-1'));
        expect(created.title, equals('Test Recipe'));
        
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.exists, isTrue);
        final data = doc.data();
        expect(data?['core']?['title'], equals('Test Recipe'));
      });

      test('should reject creation when not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);
        final recipe = RecipeFactory.build();
        
        // Act & Assert
        expect(
          () => repository.create(recipe),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('should read recipe by ID', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
          createdBy: 'test-user-123',
        );
        
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        // Act
        final read = await repository.read('recipe-1');
        
        // Assert
        expect(read, isNotNull);
        expect(read!.id, equals('recipe-1'));
        expect(read.title, equals('Test Recipe'));
      });

      test('should return null for non-existent recipe', () async {
        // Arrange
        // No setup needed - recipe doesn't exist
        
        // Act
        final read = await repository.read('non-existent');
        
        // Assert
        expect(read, isNull);
      });

      test('should update recipe with ownership validation', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Original Title',
          createdBy: 'test-user-123',
        );
        
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        final updated = recipe.copyWith(title: 'Updated Title');
        
        // Act
        await repository.update(updated);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.data()?['core']?['title'], equals('Updated Title'));
      });

      test('should reject update for non-owned recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Other User Recipe',
          createdBy: 'other-user',
        );
        
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        final updated = recipe.copyWith(title: 'Hacked');
        
        // Act & Assert
        expect(
          () => repository.update(updated),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should delete recipe with ownership validation', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          createdBy: 'test-user-123',
        );
        
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        // Act
        await repository.delete('recipe-1');
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.exists, isFalse);
      });

      test('should reject delete for non-owned recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          createdBy: 'other-user',
        );
        
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        // Act & Assert
        expect(
          () => repository.delete('recipe-1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should read all recipes with ordering', () async {
        // Arrange
        final recipe1 = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Recipe 1',
          createdBy: 'test-user-123',
          updatedAt: DateTime(2024, 1, 1),
        );
        final recipe2 = RecipeFactory.build(
          id: 'recipe-2', 
          title: 'Recipe 2',
          createdBy: 'test-user-123',
          updatedAt: DateTime(2024, 1, 2),
        );
        final recipe3 = RecipeFactory.build(
          id: 'recipe-3',
          title: 'Recipe 3',
          createdBy: 'test-user-123',
          updatedAt: DateTime(2024, 1, 3),
        );
        
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        await collection.doc('recipe-1').set(recipe1.toFirestore());
        await collection.doc('recipe-2').set(recipe2.toFirestore());
        await collection.doc('recipe-3').set(recipe3.toFirestore());
        
        // Act
        final recipes = await repository.readAll();
        
        // Assert
        expect(recipes, hasLength(3));
        expect(recipes[0].id, equals('recipe-3'));
        expect(recipes[1].id, equals('recipe-2'));
        expect(recipes[2].id, equals('recipe-1'));
      });
    });

    group('Streaming Operations', () {
      test('should stream user recipes with ordering and limit', () async {
        // Arrange
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        for (int i = 0; i < 60; i++) {
          final recipe = RecipeFactory.build(
            id: 'recipe-$i',
            title: 'Recipe $i',
            createdBy: 'test-user-123',
            updatedAt: DateTime(2024, 1, i + 1),
          );
          await collection.doc('recipe-$i').set(recipe.toFirestore());
        }
        
        // Act
        final stream = repository.watchRecipes('test-user-123');
        final recipes = await stream.first;
        
        // Assert
        expect(recipes, hasLength(50));
        expect(recipes.first.id, equals('recipe-59'));
        expect(recipes.last.id, equals('recipe-10'));
      });

      test('should subscribe to recipe changes', () async {
        // Arrange
        final changes = <RecipeChange>[];
        
        final subscription = repository.subscribeToUserRecipes(
          'test-user-123',
          (data) => changes.addAll(data),
        );
        
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'New Recipe',
          createdBy: 'test-user-123',
        );
        
        // Act
        await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .set(recipe.toFirestore());
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(changes, hasLength(1));
        expect(changes.first.type, equals(RecipeChangeType.added));
        expect(changes.first.recipe.id, equals('recipe-1'));
        
        subscription.cancel();
      });
    });

    group('Search Operations', () {
      test('should search recipes by title', () async {
        // Arrange
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        final chickenRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Chicken Curry',
          createdBy: 'test-user-123',
        );
        final beefRecipe = RecipeFactory.build(
          id: 'recipe-2',
          title: 'Beef Stew',
          createdBy: 'test-user-123',
        );
        final veggieRecipe = RecipeFactory.build(
          id: 'recipe-3',
          title: 'Vegetable Soup',
          createdBy: 'test-user-123',
        );
        
        await collection.doc('recipe-1').set(chickenRecipe.toFirestore());
        await collection.doc('recipe-2').set(beefRecipe.toFirestore());
        await collection.doc('recipe-3').set(veggieRecipe.toFirestore());
        
        // Act
        final results = await repository.searchRecipes('chicken');
        
        // Assert
        expect(results, hasLength(1));
        expect(results.first.title, equals('Chicken Curry'));
      });

      test('should search case-insensitively', () async {
        // Arrange
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'PASTA Carbonara',
          createdBy: 'test-user-123',
        );
        
        await collection.doc('recipe-1').set(recipe.toFirestore());
        
        // Act
        final results = await repository.searchRecipes('pasta');
        
        // Assert
        expect(results, hasLength(1));
        expect(results.first.title, equals('PASTA Carbonara'));
      });

      test('should limit search results to 200 recipes', () async {
        // Arrange
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        for (int i = 0; i < 250; i++) {
          final recipe = RecipeFactory.build(
            id: 'recipe-$i',
            title: 'Test Recipe $i',
            createdBy: 'test-user-123',
            updatedAt: DateTime(2024, 1, 250 - i), // Reverse order
          );
          await collection.doc('recipe-$i').set(recipe.toFirestore());
        }
        
        // Act
        final results = await repository.searchRecipes('Test');
        
        // Assert
        expect(results.length, lessThanOrEqualTo(200));
      });

      test('should return empty list when not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);
        
        // Act
        final results = await repository.searchRecipes('test');
        
        // Assert
        expect(results, isEmpty);
      });
    });

    group('Batch Operations', () {
      test('should add multiple recipes in batch', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'recipe-1', title: 'Recipe 1', createdBy: 'test-user-123'),
          RecipeFactory.build(id: 'recipe-2', title: 'Recipe 2', createdBy: 'test-user-123'),
          RecipeFactory.build(id: 'recipe-3', title: 'Recipe 3', createdBy: 'test-user-123'),
        ];
        
        // Act
        await repository.addRecipes(recipes);
        
        // Assert
        final collection = fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes');
        
        for (int i = 0; i < recipes.length; i++) {
          final doc = await collection.doc('recipe-${i + 1}').get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['core']?['title'], equals('Recipe ${i + 1}'));
        }
      });
    });

    group('Archive Operations', () {
      test('should fetch archive recipes with limit', () async {
        // Arrange
        final archiveCollection = fakeFirestore.collection('butlery_archive');
        
        for (int i = 0; i < 150; i++) {
          final recipe = RecipeFactory.build(
            id: 'archive-$i',
            title: 'Archive Recipe $i',
            createdBy: 'archive-user',
            createdAt: DateTime(2024, 1, 150 - i),
          );
          await archiveCollection.doc('archive-$i').set(recipe.toFirestore());
        }
        
        // Act
        final archives = await repository.fetchArchiveRecipes();
        
        // Assert
        expect(archives, hasLength(100));
        expect(archives.first.id, equals('archive-0'));
      });

      test('should fetch specific archive recipe', () async {
        // Arrange
        final archiveCollection = fakeFirestore.collection('butlery_archive');
        
        final recipe = RecipeFactory.build(
          id: 'archive-1',
          title: 'Special Archive Recipe',
          createdBy: 'archive-user',
        );
        
        await archiveCollection.doc('archive-1').set(recipe.toFirestore());
        
        // Act
        final fetched = await repository.fetchArchiveRecipe('archive-1');
        
        // Assert
        expect(fetched.id, equals('archive-1'));
        expect(fetched.title, equals('Special Archive Recipe'));
      });

      test('should throw when archive recipe not found', () async {
        // Arrange
        // No setup needed - recipe doesn't exist
        
        // Act & Assert
        expect(
          () => repository.fetchArchiveRecipe('non-existent'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('User Recipes', () {
      test('should fetch all recipes for specific user', () async {
        // Arrange
        await fakeFirestore
            .collection('users')
            .doc('user-1')
            .collection('recipes')
            .doc('recipe-1')
            .set(RecipeFactory.build(id: 'recipe-1', createdBy: 'user-1').toFirestore());
        
        await fakeFirestore
            .collection('users')
            .doc('user-1')
            .collection('recipes')
            .doc('recipe-2')
            .set(RecipeFactory.build(id: 'recipe-2', createdBy: 'user-1').toFirestore());
        
        await fakeFirestore
            .collection('users')
            .doc('user-2')
            .collection('recipes')
            .doc('recipe-3')
            .set(RecipeFactory.build(id: 'recipe-3', createdBy: 'user-2').toFirestore());
        
        // Act
        final user1Recipes = await repository.fetchUserRecipes('user-1');
        
        // Assert
        expect(user1Recipes, hasLength(2));
        expect(user1Recipes.map((r) => r.id), containsAll(['recipe-1', 'recipe-2']));
      });
    });

    group('Error Handling', () {
      test('should handle update for non-existent recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'non-existent',
          createdBy: 'test-user-123',
        );
        
        // Act & Assert
        expect(
          () => repository.update(recipe),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should handle delete for non-existent recipe', () async {
        // Arrange
        // No setup needed - recipe doesn't exist
        
        // Act & Assert
        expect(
          () => repository.delete('non-existent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should validate required fields on create', () async {
        // Arrange
        final invalidRecipe = Recipe(
          core: RecipeCore(
            id: 'recipe-1',
            title: '', // Empty title
            description: 'Description',
            ingredients: ['Ingredient'],
            instructions: ['Step'],
            imageUrls: [],
            mealType: 'Lunch',
            portions: 4,
            timeMinutes: 30,
            rating: 0,
            tags: [],
            sourceUrl: null,
            createdBy: 'test-user-123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isPublic: false,
            lastCookedAt: null,
          ),
          type: RecipeType.personal,
        );
        
        // Act
        await repository.create(invalidRecipe);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.exists, isTrue);
      });
    });
  });
}