/// Integration tests for Firebase Recipe Repository
/// 
/// Tests actual Firebase operations with emulator including FieldValue operations,
/// real-time streaming, batch operations, and complex queries.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import '../setup/firebase_test_setup.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('Firebase Recipe Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseRecipeRepository repository;
    late AuthRepository mockAuthRepository;
    late User testUser;
    
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
      firestore = FirebaseFirestore.instance;
    });
    
    setUp(() async {
      await FirebaseTestSetup.clearEmulatorData();
      
      // Create test user
      testUser = await FirebaseTestSetup.createTestUser(
        email: 'test@example.com',
        password: 'test123',
      );
      
      // Setup mock auth repository
      mockAuthRepository = MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: testUser.uid,
        user: testUser,
      );
      
      // Create repository with Firebase emulator
      repository = FirebaseRecipeRepository(
        firestore: firestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      await FirebaseAuth.instance.signOut();
    });
    
    group('Recipes with FieldValue.serverTimestamp', () {
      test('should create recipe with server timestamps', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
          createdBy: testUser.uid,
        );
        
        // Act
        final created = await repository.create(recipe);
        
        // Assert
        expect(created.id, equals('recipe-1'));
        
        // Verify in Firestore
        final doc = await firestore
            .collection('users')
            .doc(testUser.uid)
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
        final recipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Original Title',
          createdBy: testUser.uid,
        );
        
        // Create recipe
        await repository.create(recipe);
        
        // Get original timestamps
        final originalDoc = await firestore
            .collection('users')
            .doc(testUser.uid)
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
        final doc = await firestore
            .collection('users')
            .doc(testUser.uid)
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
        final subscription = repository.watchRecipes(testUser.uid).listen((recipes) {
          updates.add(recipes);
        });
        
        // Wait for initial empty state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Add recipes
        for (int i = 0; i < 3; i++) {
          final recipe = RecipeFactory.build(
            id: 'recipe-$i',
            title: 'Recipe $i',
            createdBy: testUser.uid,
          );
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
          testUser.uid,
          (changeList) => changes.add(changeList),
        );
        
        // Wait for subscription to be ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Create recipe
        final recipe1 = RecipeFactory.build(
          id: 'recipe-1',
          title: 'First Recipe',
          createdBy: testUser.uid,
        );
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
        final recipes = List.generate(10, (i) => RecipeFactory.build(
          id: 'batch-recipe-$i',
          title: 'Batch Recipe $i',
          createdBy: testUser.uid,
        ));
        
        // Act
        await repository.addRecipes(recipes);
        
        // Assert - All recipes created
        for (final recipe in recipes) {
          final doc = await firestore
              .collection('users')
              .doc(testUser.uid)
              .collection('recipes')
              .doc(recipe.id)
              .get();
          
          expect(doc.exists, isTrue);
          expect(doc.data()?['core']?['title'], equals(recipe.title));
        }
      });
      
      test('should handle batch with server timestamps', () async {
        // Arrange
        final batch = firestore.batch();
        final collectionRef = firestore
            .collection('users')
            .doc(testUser.uid)
            .collection('recipes');
        
        // Act - Create multiple documents with timestamps
        for (int i = 0; i < 5; i++) {
          final docRef = collectionRef.doc('batch-$i');
          batch.set(docRef, {
            'core': {
              'id': 'batch-$i',
              'title': 'Batch Recipe $i',
              'createdBy': testUser.uid,
            },
            'timestamps': {
              'created': FieldValue.serverTimestamp(),
              'lastModified': FieldValue.serverTimestamp(),
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
          RecipeFactory.build(
            id: 'pasta-1',
            title: 'Pasta Carbonara',
            description: 'Classic Italian pasta dish',
            createdBy: testUser.uid,
          ),
          RecipeFactory.build(
            id: 'pasta-2',
            title: 'Pasta Bolognese',
            description: 'Traditional meat sauce pasta',
            createdBy: testUser.uid,
          ),
          RecipeFactory.build(
            id: 'chicken-1',
            title: 'Grilled Chicken',
            description: 'Healthy grilled chicken breast',
            createdBy: testUser.uid,
          ),
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
          final recipe = RecipeFactory.build(
            id: 'complex-$i',
            title: 'Recipe $i',
            createdBy: testUser.uid,
            isPublic: i % 2 == 0,
          );
          
          // Store with proper structure and additional test fields
          final recipeData = recipe.toFirestore();
          recipeData['isFavorite'] = i % 3 == 0;
          recipeData['difficulty'] = i < 3 ? 'Easy' : i < 7 ? 'Medium' : 'Hard';
          
          await firestore
              .collection('users')
              .doc(testUser.uid)
              .collection('recipes')
              .doc(recipe.id)
              .set(recipeData);
        }
        
        // Act - Query public and favorite recipes
        final query = await firestore
            .collection('users')
            .doc(testUser.uid)
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
          await firestore.collection('archive_recipes').doc('archive-$i').set({
            'core': {
              'id': 'archive-$i',
              'title': 'Classic Recipe $i',
              'createdBy': 'archive_system',
            },
            'timestamps': {
              'created': FieldValue.serverTimestamp(),
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
        await firestore.collection('archive_recipes').doc(archiveId).set({
          'core': {
            'id': archiveId,
            'title': 'Swedish Meatballs',
            'description': 'Traditional Swedish meatballs with cream sauce',
            'createdBy': 'archive_system',
          },
          'timestamps': {
            'created': FieldValue.serverTimestamp(),
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
          final recipe = RecipeFactory.build(
            id: 'user-recipe-$i',
            title: 'My Recipe $i',
            createdBy: testUser.uid,
          );
          await repository.create(recipe);
        }
        
        // Act
        final userRecipes = await repository.fetchUserRecipes(testUser.uid);
        
        // Assert
        expect(userRecipes.length, equals(7));
        expect(userRecipes.every((r) => r.createdBy == testUser.uid), isTrue);
      });
      
      test('should handle concurrent recipe operations', () async {
        // Arrange
        final futures = <Future>[];
        
        // Act - Create multiple recipes concurrently
        for (int i = 0; i < 5; i++) {
          final recipe = RecipeFactory.build(
            id: 'concurrent-$i',
            title: 'Concurrent Recipe $i',
            createdBy: testUser.uid,
          );
          futures.add(repository.create(recipe));
        }
        
        await Future.wait(futures);
        
        // Assert - All recipes created
        final recipes = await repository.fetchUserRecipes(testUser.uid);
        expect(recipes.where((r) => r.id.startsWith('concurrent-')).length, equals(5));
      });
    });
    
    group('Permission Validation', () {
      test('should enforce ownership on updates', () async {
        // Arrange - Create recipe
        final recipe = RecipeFactory.build(
          id: 'owned-recipe',
          title: 'My Recipe',
          createdBy: testUser.uid,
        );
        await repository.create(recipe);
        
        // Act - Try to update with different owner
        final hackedRecipe = recipe.copyWith(createdBy: 'hacker-user');
        
        // Assert - Should fail
        expect(
          () => repository.update(hackedRecipe),
          throwsException,
        );
      });
      
      test('should enforce ownership on deletes', () async {
        // Arrange - Create recipe with different owner in Firestore
        await firestore
            .collection('users')
            .doc(testUser.uid)
            .collection('recipes')
            .doc('other-recipe')
            .set({
              'core': {
                'id': 'other-recipe',
                'title': 'Not My Recipe',
                'createdBy': 'other-user',
              },
            });
        
        // Act & Assert - Should fail to delete
        expect(
          () => repository.delete('other-recipe'),
          throwsException,
        );
      });
    });
  });
}