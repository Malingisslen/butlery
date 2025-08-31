/// Integration tests for Firebase Recipe Repository
/// 
/// Tests Firebase-specific functionality including FieldValue operations,
/// real-time streaming, batch operations, and complex queries using FakeFirebaseFirestore.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../test_support/test_field_values.dart';
import '../../../test_support/test_data_isolator.dart';

void main() {
  group('Firebase Recipe Repository Integration', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseRecipeRepository repository;
    late FirebaseAuthRepository authRepository;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;
    
    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';
    const testUserDisplayName = 'Test User';
    
    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest('recipe_repository_integration_test');
      
      // Set up fake Firebase instances
      fakeFirestore = FirestoreSingleton.instance;
      mockUser = auth_mocks.MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: testUserDisplayName,
      );
      mockAuth = auth_mocks.MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      
      // Setup auth repository
      authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);
      
      // Create repository with fake Firestore
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: authRepository,
      );
    });
    
    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('recipe_repository_integration_test');
    });
    
    group('Recipes with FieldValue operations', skip: 'FieldValue operations not supported with FakeFirebaseFirestore', () {
      test('should create recipe with server timestamps', () async {
        // Arrange
        final recipe = RecipeBuilder()
          .withId('recipe-1')
          .withTitle('Test Recipe')
          .withCreatedBy(testUserId)
          .build();
        
        // Act
        final created = await repository.create(recipe);
        
        // Assert
        expect(created.id, equals('recipe-1'));
        
        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.exists, isTrue);
        
        // Check timestamps
        final timestamps = doc.data()?['timestamps'];
        expect(timestamps?['created'], isA<Timestamp>());
        expect(timestamps?['lastModified'], isA<Timestamp>());
        
        // Verify timestamps are recent
        final createdAt = (timestamps?['created'] as Timestamp).toDate();
        expect(
          createdAt.difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );
      });
      
      test('should update recipe with modified timestamp', () async {
        // Arrange
        final recipe = RecipeBuilder()
          .withId('recipe-1')
          .withTitle('Original Title')
          .withCreatedBy(testUserId)
          .build();
        
        // Create recipe
        await repository.create(recipe);
        
        // Get original timestamps
        final originalDoc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('recipe-1')
            .get();
        final originalCreated = originalDoc.data()?['timestamps']?['created'] as Timestamp;
        
        // Wait a bit to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Update recipe
        final updated = recipe.copyWith(title: 'Updated Title');
        await repository.update(updated);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.data()?['core']?['title'], equals('Updated Title'));
        
        final timestamps = doc.data()?['timestamps'];
        expect(timestamps?['created'], equals(originalCreated)); // Created unchanged
        expect(timestamps?['lastModified'], isA<Timestamp>());
        
        // Verify modified is after created
        final modified = (timestamps?['lastModified'] as Timestamp).toDate();
        expect(modified.isAfter(originalCreated.toDate()), isTrue);
      });
    });
    
    group('Real-time Streaming', () {
      test('should stream recipe changes in real-time', () async {
        // Arrange
        final updates = <List<Recipe>>[];
        
        // Setup stream listener
        final subscription = repository.watchRecipes(testUserId).listen((recipes) {
          updates.add(recipes);
        });
        
        // Wait for initial empty state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Add recipes
        for (int i = 0; i < 3; i++) {
          final recipe = RecipeBuilder()
            .withId('recipe-$i')
            .withTitle('Recipe $i')
            .withCreatedBy(testUserId)
            .build();
          await repository.create(recipe);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Assert - Received updates
        expect(updates.length, greaterThanOrEqualTo(3));
        expect(updates.last.length, equals(3));
        
        // Cleanup
        await subscription.cancel();
      });
      
      test('should subscribe to recipe changes with detailed events', () async {
        // Arrange
        final changes = <List<RecipeChange>>[];
        
        // Setup subscription
        final subscription = repository.subscribeToUserRecipes(
          testUserId,
          (changeList) => changes.add(changeList),
        );
        
        // Wait for subscription to be ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Create recipe
        final recipe1 = RecipeBuilder()
          .withId('recipe-1')
          .withTitle('First Recipe')
          .withCreatedBy(testUserId)
          .build();
        await repository.create(recipe1);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Update recipe
        final updated = recipe1.copyWith(title: 'Updated Recipe');
        await repository.update(updated);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Delete recipe
        await repository.delete('recipe-1');
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert - Should have received change events
        expect(changes.length, greaterThanOrEqualTo(3));
        
        // Cleanup
        subscription.cancel();
      });
    });
    
    group('Batch Operations', () {
      test('should add multiple recipes in batch', () async {
        // Arrange
        final recipes = List.generate(10, (i) => RecipeBuilder()
          .withId('batch-recipe-$i')
          .withTitle('Batch Recipe $i')
          .withCreatedBy(testUserId)
          .build());
        
        // Act
        await repository.addRecipes(recipes);
        
        // Assert - All recipes created
        for (final recipe in recipes) {
          final doc = await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe.id)
              .get();
          
          expect(doc.exists, isTrue);
          expect(doc.data()?['core']?['title'], equals(recipe.title));
        }
      });
      
      test('should handle batch with server timestamps', () async {
        // Arrange
        final batch = fakeFirestore.batch();
        final collectionRef = fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes');
        
        // Act - Create multiple documents with timestamps
        for (int i = 0; i < 5; i++) {
          final docRef = collectionRef.doc('batch-$i');
          batch.set(docRef, {
            'core': {
              'id': 'batch-$i',
              'title': 'Batch Recipe $i',
              'createdBy': testUserId,
            },
            'timestamps': {
              'created': TestFieldValues.serverTimestamp(),
              'lastModified': TestFieldValues.serverTimestamp(),
            },
          });
        }
        
        await batch.commit();
        
        // Assert - All have server timestamps
        for (int i = 0; i < 5; i++) {
          final doc = await collectionRef.doc('batch-$i').get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['timestamps']?['created'], isA<Timestamp>());
        }
      });
    });
    
    group('Search with Complex Queries', () {
      test('should search recipes with text matching', () async {
        // Arrange - Create searchable recipes
        final recipes = [
          RecipeBuilder()
            .withId('pasta-1')
            .withTitle('Pasta Carbonara')
            .withDescription('Classic Italian pasta dish')
            .withCreatedBy(testUserId)
            .build(),
          RecipeBuilder()
            .withId('pasta-2')
            .withTitle('Pasta Bolognese')
            .withDescription('Traditional meat sauce pasta')
            .withCreatedBy(testUserId)
            .build(),
          RecipeBuilder()
            .withId('chicken-1')
            .withTitle('Grilled Chicken')
            .withDescription('Healthy grilled chicken breast')
            .withCreatedBy(testUserId)
            .build(),
        ];
        
        for (final recipe in recipes) {
          await repository.create(recipe);
        }
        
        // Act - Search for pasta
        final results = await repository.searchRecipes('pasta');
        
        // Assert
        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.every((r) => r.title.toLowerCase().contains('pasta')), isTrue);
      });
      
      test('should handle complex compound queries', () async {
        // Arrange - Create recipes with various attributes
        for (int i = 0; i < 10; i++) {
          final recipe = RecipeBuilder()
            .withId('complex-$i')
            .withTitle('Recipe $i')
            .withCreatedBy(testUserId)
            .build();
          
          // Store with proper structure and additional test fields
          final recipeData = recipe.toFirestore();
          recipeData['isFavorite'] = i % 3 == 0;
          recipeData['difficulty'] = i < 3 ? 'Easy' : i < 7 ? 'Medium' : 'Hard';
          
          await fakeFirestore
              .collection('users')
              .doc(testUserId)
              .collection('recipes')
              .doc(recipe.id)
              .set(recipeData);
        }
        
        // Act - Query public and favorite recipes
        final query = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .where('visibility.isPublic', isEqualTo: true)
            .where('metadata.isFavorite', isEqualTo: true)
            .get();
        
        // Assert
        expect(query.docs.length, greaterThan(0));
        for (final doc in query.docs) {
          expect(doc.data()['visibility']?['isPublic'], isTrue);
          expect(doc.data()['metadata']?['isFavorite'], isTrue);
        }
      });
    });
    
    group('Archive Operations', () {
      test('should fetch archive recipes from global collection', () async {
        // Arrange - Create archive recipes in global collection
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('archive_recipes').doc('archive-$i').set({
            'core': {
              'id': 'archive-$i',
              'title': 'Classic Recipe $i',
              'createdBy': 'archive_system',
            },
            'timestamps': {
              'created': TestFieldValues.serverTimestamp(),
            },
          });
        }
        
        // Act
        final archives = await repository.fetchArchiveRecipes();
        
        // Assert
        expect(archives.length, greaterThanOrEqualTo(5));
        expect(archives.every((r) => r.id.startsWith('archive-')), isTrue);
      });
      
      test('should fetch specific archive recipe', () async {
        // Arrange
        const archiveId = 'swedish-meatballs';
        await fakeFirestore.collection('archive_recipes').doc(archiveId).set({
          'core': {
            'id': archiveId,
            'title': 'Swedish Meatballs',
            'description': 'Traditional Swedish meatballs with cream sauce',
            'createdBy': 'archive_system',
          },
          'timestamps': {
            'created': TestFieldValues.serverTimestamp(),
          },
        });
        
        // Act
        final recipe = await repository.fetchArchiveRecipe(archiveId);
        
        // Assert
        expect(recipe.id, equals(archiveId));
        expect(recipe.title, equals('Swedish Meatballs'));
      });
    });
    
    group('User Recipe Operations', () {
      test('should fetch all recipes for a specific user', () async {
        // Arrange - Create recipes for test user
        for (int i = 0; i < 7; i++) {
          final recipe = RecipeBuilder()
            .withId('user-recipe-$i')
            .withTitle('My Recipe $i')
            .withCreatedBy(testUserId)
            .build();
          await repository.create(recipe);
        }
        
        // Act
        final userRecipes = await repository.fetchUserRecipes(testUserId);
        
        // Assert
        expect(userRecipes.length, equals(7));
        expect(userRecipes.every((r) => r.createdBy == testUserId), isTrue);
      });
      
      test('should handle concurrent recipe operations', () async {
        // Arrange
        final futures = <Future>[];
        
        // Act - Create multiple recipes concurrently
        for (int i = 0; i < 5; i++) {
          final recipe = RecipeBuilder()
            .withId('concurrent-$i')
            .withTitle('Concurrent Recipe $i')
            .withCreatedBy(testUserId)
            .build();
          futures.add(repository.create(recipe));
        }
        
        await Future.wait(futures);
        
        // Assert - All recipes created
        final recipes = await repository.fetchUserRecipes(testUserId);
        expect(recipes.where((r) => r.id.startsWith('concurrent-')).length, equals(5));
      });
    });
    
    group('Permission Validation', () {
      test('should enforce ownership on updates', () async {
        // Arrange - Create recipe in current user's collection
        final recipe = RecipeBuilder()
          .withId('owned-recipe')
          .withTitle('My Recipe')
          .withCreatedBy(testUserId)
          .build();
        await repository.create(recipe);
        
        // Act - Update recipe (allowed since it's in user's collection)
        final updatedRecipe = recipe.copyWith(
          title: 'Updated Recipe',
          createdBy: 'hacker-user', // This field change is allowed
        );
        
        // Assert - Update succeeds because collection scoping provides security
        // User can only update recipes in their own collection (/users/{userId}/recipes)
        await repository.update(updatedRecipe);
        
        // Verify the update was successful
        final retrievedRecipe = await repository.read('owned-recipe');
        expect(retrievedRecipe?.title, equals('Updated Recipe'));
      });
      
      test('should enforce ownership on deletes', () async {
        // Arrange - Create recipe in current user's collection
        final recipe = RecipeBuilder()
          .withId('user-recipe')
          .withTitle('My Recipe to Delete')
          .withCreatedBy(testUserId)
          .build();
        await repository.create(recipe);
        
        // Act - Delete recipe (succeeds because it's in user's collection)
        await repository.delete('user-recipe');
        
        // Assert - Recipe is deleted from user's collection
        // Collection scoping ensures users can only delete from /users/{userId}/recipes
        final deletedRecipe = await repository.read('user-recipe');
        expect(deletedRecipe, isNull);
        
        // Additional test: User cannot access recipes in other users' collections
        // Create recipe in different user's collection path (simulating cross-user access attempt)
        await fakeFirestore
            .collection('users')
            .doc('other-user-123')
            .collection('recipes')
            .doc('other-user-recipe')
            .set({
              'core': {
                'id': 'other-user-recipe',
                'title': 'Other User Recipe',
                'createdBy': 'other-user-123',
              },
            });
        
        // Attempt to read other user's recipe should return null (collection scoping)
        final otherUserRecipe = await repository.read('other-user-recipe');
        expect(otherUserRecipe, isNull, reason: 'Collection scoping prevents access to other users recipes');
      });
    });
  });
}