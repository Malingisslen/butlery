/// Unit tests for FirestoreRepository
/// 
/// Tests the centralized Firestore database access layer that serves as the
/// foundation for all Firebase repositories in the application.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mock classes for Firestore components
// Note: Some Firestore classes are sealed and cannot be mocked directly
// We use them only in specific test scenarios
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {} 
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

void main() {
  group('FirestoreRepository', () {
    late FirestoreRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // TestServiceLocator is already initialized in setUpAll via BaseUnitTest.setupUnit()
      
      // Use FakeFirebaseFirestore for comprehensive testing
      fakeFirestore = FakeFirebaseFirestore();
      repository = FirestoreRepository(firestore: fakeFirestore);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Firestore Access', () {
      test('should provide access to firestore instance', () {
        // Assert
        expect(repository.firestore, isNotNull);
        expect(repository.firestore, equals(fakeFirestore));
      });
    });
    
    group('Connectivity Monitoring', () {
      test('should create connectivity stream from test collection', () {
        // Act
        final stream = repository.connectivityStream();
        
        // Assert
        expect(stream, isNotNull);
        expect(stream, isA<Stream<QuerySnapshot<Map<String, dynamic>>>>());
      });
    });
    
    group('Real-time Resources', () {
      test('should create document reference for real-time resource', () {
        // Arrange
        const resourceId = 'shared_menu_123';
        
        // Act
        final docRef = repository.realtimeResourceDoc(resourceId);
        
        // Assert
        expect(docRef, isNotNull);
        expect(docRef.id, equals(resourceId));
        expect(docRef.path, equals('realtime_resources/$resourceId'));
      });
    });
    
    group('Document Operations', () {
      test('should get document from reference', () async {
        // This test verifies the getDocument helper method
        // In a real test with mocked Firestore, we would stub the get() method
        
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();
        
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({'title': 'Test Recipe'});
        
        // Act
        final result = await repository.getDocument(mockDocRef);
        
        // Assert
        expect(result, equals(mockSnapshot));
        verify(() => mockDocRef.get()).called(1);
      });
      
      test('should set document with merge option', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final testData = {
          'title': 'Swedish Meatballs',
          'cookingTime': 45,
          'servings': 4,
        };
        
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.setDocument(mockDocRef, testData);
        
        // Assert
        verify(() => mockDocRef.set(
          testData,
          any(that: isA<SetOptions>().having(
            (options) => options.merge,
            'merge',
            true,
          )),
        )).called(1);
      });
      
      test('should delete document', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        
        when(() => mockDocRef.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.deleteDocument(mockDocRef);
        
        // Assert
        verify(() => mockDocRef.delete()).called(1);
      });
    });
    
    group('User Collections', () {
      test('should create reference to user recipes collection', () {
        // Arrange
        const userId = 'test_user_123';
        
        // Act
        final collection = repository.userRecipesCollection(userId);
        
        // Assert
        expect(collection, isNotNull);
        expect(collection.path, equals('users/$userId/recipes'));
      });
      
      test('should handle nested user collection paths correctly', () {
        // Arrange
        const userId = 'swedish_chef_456';
        
        // Act
        final recipesCollection = repository.userRecipesCollection(userId);
        
        // Assert
        expect(recipesCollection.path, contains('users'));
        expect(recipesCollection.path, contains(userId));
        expect(recipesCollection.path, contains('recipes'));
      });
    });
    
    group('Generic Collection Access', () {
      test('should provide access to any collection by path', () {
        // Arrange
        const collectionPath = 'shared_shopping_lists';
        
        // Act
        final collection = repository.collection(collectionPath);
        
        // Assert
        expect(collection, isNotNull);
        expect(collection.path, equals(collectionPath));
      });
      
      test('should handle nested collection paths', () {
        // Arrange
        const nestedPath = 'groups/group_123/members';
        
        // Act
        final collection = repository.collection(nestedPath);
        
        // Assert
        expect(collection, isNotNull);
        expect(collection.path, equals(nestedPath));
      });
    });
    
    group('Generic Document Access', () {
      test('should provide access to any document by path', () {
        // Arrange
        const documentPath = 'recipes/recipe_abc';
        
        // Act
        final docRef = repository.doc(documentPath);
        
        // Assert
        expect(docRef, isNotNull);
        expect(docRef.path, equals(documentPath));
      });
      
      test('should handle deeply nested document paths', () {
        // Arrange
        const nestedPath = 'users/user_123/menus/menu_456/items/item_789';
        
        // Act
        final docRef = repository.doc(nestedPath);
        
        // Assert
        expect(docRef, isNotNull);
        expect(docRef.path, equals(nestedPath));
      });
    });
    
    group('Integration Patterns', () {
      test('should support user-scoped recipe operations', () async {
        // This test demonstrates the typical usage pattern for user recipes
        
        // Arrange
        const userId = 'chef_123';
        const recipeId = 'recipe_456';
        
        // Act
        final userRecipes = repository.userRecipesCollection(userId);
        final recipeDoc = userRecipes.doc(recipeId);
        
        // Assert - verify the paths are constructed correctly
        expect(userRecipes.path, equals('users/$userId/recipes'));
        expect(recipeDoc.path, equals('users/$userId/recipes/$recipeId'));
      });
      
      test('should support collaborative resource patterns', () {
        // This test demonstrates usage for real-time collaborative features
        
        // Arrange
        const menuId = 'shared_menu_789';
        const shoppingListId = 'list_abc';
        
        // Act
        final menuDoc = repository.realtimeResourceDoc(menuId);
        final listDoc = repository.realtimeResourceDoc(shoppingListId);
        
        // Assert
        expect(menuDoc.path, equals('realtime_resources/$menuId'));
        expect(listDoc.path, equals('realtime_resources/$shoppingListId'));
      });
    });
    
    group('Error Handling', () {
      test('should propagate Firestore exceptions', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        
        when(() => mockDocRef.get()).thenAnswer((_) async => throw 
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions',
          ),
        );
        
        // Act & Assert
        expect(
          () => repository.getDocument(mockDocRef),
          throwsA(isA<FirebaseException>()),
        );
      });
      
      test('should handle network errors appropriately', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        
        when(() => mockDocRef.delete()).thenAnswer((_) async => throw 
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Network error',
          ),
        );
        
        // Act & Assert
        expect(
          () => repository.deleteDocument(mockDocRef),
          throwsA(
            allOf(
              isA<FirebaseException>(),
              predicate<FirebaseException>((e) => e.code == 'unavailable'),
            ),
          ),
        );
      });
    });
  });
}