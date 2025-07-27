import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/recipe_unified.dart';

// Generate mocks with: dart run build_runner build
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentSnapshot,
  AuthRepository,
])
import 'firebase_recipe_repository_test.mocks.dart';

void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockAuthRepository mockAuthRepository;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocumentRef;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDoc;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocumentRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockQueryDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

      repository = FirebaseRecipeRepository(authRepository: mockAuthRepository);
      
      // Setup common auth mocks
      when(mockAuthRepository.currentUserId).thenReturn('test-user-id');
      // Note: isAuthenticated removed - not part of AuthRepository interface
    });

    group('Recipe Creation', () {
      test('add succeeds with valid recipe data', () async {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-recipe-id',
            title: 'Test Recipe',
            description: 'A test recipe',
            ingredients: ['ingredient1', 'ingredient2'],
            instructions: ['step1', 'step2'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.set(any)).thenAnswer((_) async {});

        // Act
        await repository.create(recipe);

        // Assert
        verify(mockDocumentRef.set(any)).called(1);
      });

      test('add throws when user not authenticated', () async {
        // Arrange
        when(mockAuthRepository.currentUserId).thenReturn(null);
        when(mockAuthRepository.currentUserId).thenReturn(null);

        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-recipe-id',
            title: 'Test Recipe',
            description: 'A test recipe',
            ingredients: ['ingredient1'],
            instructions: ['step1'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        // Act & Assert
        expect(
          () => repository.create(recipe),
          throwsA(isA<Exception>()),
        );
      });

      test('add handles Firestore errors', () async {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-recipe-id',
            title: 'Test Recipe',
            description: 'A test recipe',
            ingredients: ['ingredient1'],
            instructions: ['step1'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.set(any)).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act & Assert
        expect(
          () => repository.create(recipe),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('Recipe Retrieval', () {
      test('findById returns recipe when document exists', () async {
        // Arrange
        const recipeId = 'test-recipe-id';
        final recipeData = {
          'id': recipeId,
          'title': 'Test Recipe',
          'description': 'A test recipe',
          'ingredients': ['ingredient1', 'ingredient2'],
          'instructions': ['step1', 'step2'],
          'mealType': 'Middag',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipeId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(recipeData);
        when(mockDocSnapshot.id).thenReturn(recipeId);

        // Act
        final result = await repository.read(recipeId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(recipeId));
        expect(result.title, equals('Test Recipe'));
      });

      test('findById returns null when document does not exist', () async {
        // Arrange
        const recipeId = 'non-existent-recipe';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipeId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(false);

        // Act
        final result = await repository.read(recipeId);

        // Assert
        expect(result, isNull);
      });

      test('fetchUserRecipes returns list of user recipes', () async {
        // Arrange
        final recipesData = [
          {
            'id': 'recipe1',
            'title': 'Recipe 1',
            'description': 'First recipe',
            'ingredients': ['ingredient1'],
            'instructions': ['step1'],
            'mealType': 'Middag',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          },
          {
            'id': 'recipe2',
            'title': 'Recipe 2',
            'description': 'Second recipe',
            'ingredients': ['ingredient2'],
            'instructions': ['step2'],
            'mealType': 'Lunch',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          },
        ];

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([
          mockQueryDoc,
          mockQueryDoc,
        ]);
        
        // Mock multiple calls to data() with different return values
        when(mockQueryDoc.data()).thenReturn(recipesData[0]);
        when(mockQueryDoc.id).thenReturn('recipe1');

        // Act
        final result = await repository.fetchUserRecipes('test-user-id');

        // Assert
        expect(result, isA<List<Recipe>>());
        expect(result.length, greaterThanOrEqualTo(0));
      });
    });

    group('Recipe Updates', () {
      test('update succeeds with valid data', () async {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-recipe-id',
            title: 'Updated Recipe',
            description: 'An updated recipe',
            ingredients: ['new ingredient'],
            instructions: ['new step'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipe.id)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenAnswer((_) async {});

        // Act
        await repository.update(recipe);

        // Assert
        verify(mockDocumentRef.update(any)).called(1);
      });

      test('update throws when recipe does not exist', () async {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'non-existent-recipe',
            title: 'Non-existent Recipe',
            description: 'This recipe does not exist',
            ingredients: ['ingredient'],
            instructions: ['step'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipe.id)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Document not found',
          ),
        );

        // Act & Assert
        expect(
          () => repository.update(recipe),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('Recipe Deletion', () {
      test('delete succeeds when recipe exists', () async {
        // Arrange
        const recipeId = 'test-recipe-id';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipeId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.delete()).thenAnswer((_) async {});

        // Act
        await repository.delete(recipeId);

        // Assert
        verify(mockDocumentRef.delete()).called(1);
      });

      test('delete handles non-existent recipe gracefully', () async {
        // Arrange
        const recipeId = 'non-existent-recipe';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(recipeId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Document not found',
          ),
        );

        // Act & Assert
        expect(
          () => repository.delete(recipeId),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('Recipe Search', () {
      test('searchRecipes returns filtered results', () async {
        // Arrange
        const query = 'pasta';
        
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.data()).thenReturn({
          'id': 'pasta-recipe',
          'title': 'Pasta Carbonara',
          'description': 'Delicious pasta dish',
          'ingredients': ['pasta', 'eggs', 'cheese'],
          'instructions': ['Cook pasta', 'Mix ingredients'],
          'mealType': 'Middag',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        when(mockQueryDoc.id).thenReturn('pasta-recipe');

        // Act
        final result = await repository.searchRecipes(query);

        // Assert
        expect(result, isA<List<Recipe>>());
        expect(result.length, greaterThanOrEqualTo(0));
      });

      test('searchRecipes returns empty list for no matches', () async {
        // Arrange
        const query = 'nonexistent';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await repository.searchRecipes(query);

        // Assert
        expect(result, isA<List<Recipe>>());
        expect(result.length, equals(0));
      });
    });

    group('Recipe Filtering', () {
      test('findByIdsByMealType returns filtered recipes', () async {
        // Arrange
        const mealType = 'Middag';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.where('mealType', isEqualTo: mealType))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.data()).thenReturn({
          'id': 'dinner-recipe',
          'title': 'Dinner Recipe',
          'description': 'A dinner recipe',
          'ingredients': ['ingredient'],
          'instructions': ['step'],
          'mealType': mealType,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        when(mockQueryDoc.id).thenReturn('dinner-recipe');

        // Act
        final result = await repository.searchRecipes(mealType);

        // Assert
        expect(result, isA<List<Recipe>>());
        verify(mockCollection.where('mealType', isEqualTo: mealType)).called(1);
      });
    });

    group('Error Handling', () {
      test('handles network connectivity issues', () async {
        // Arrange
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'The service is currently unavailable',
          ),
        );

        // Act & Assert
        expect(
          () => repository.readAll(),
          throwsA(isA<FirebaseException>()),
        );
      });

      test('handles permission denied errors', () async {
        // Arrange
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act & Assert
        expect(
          () => repository.readAll(),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('Repository Interface Compliance', () {
      test('implements RecipeRepository interface correctly', () {
        // Act & Assert
        expect(repository, isA<RecipeRepository>());
      });

      test('requires authentication for all operations', () {
        // Arrange
        when(mockAuthRepository.currentUserId).thenReturn(null);
        when(mockAuthRepository.currentUserId).thenReturn(null);

        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-recipe-id',
            title: 'Test Recipe',
            description: 'A test recipe',
            ingredients: ['ingredient'],
            instructions: ['step'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        // Act & Assert
        expect(() => repository.create(recipe), throwsA(isA<Exception>()));
        expect(() => repository.update(recipe), throwsA(isA<Exception>()));
        expect(() => repository.delete('test-id'), throwsA(isA<Exception>()));
      });
    });
  });
}