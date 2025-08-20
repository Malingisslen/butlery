/// Unit tests for FirebaseSocialRecipeRepository
/// 
/// Tests the social recipe sharing repository using mocked Firebase operations
/// to avoid FieldValue type casting issues.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_social_recipe_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}
class MockUser extends Mock implements User {
  @override
  String get uid => 'test_user_123';
}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}
class FakeSharedRecipe extends Fake implements SharedRecipe {}
class FakeSharedMenu extends Fake implements SharedMenu {}

void main() {
  group('FirebaseSocialRecipeRepository', () {
    late FirebaseSocialRecipeRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockSharedRecipesCollection;
    late MockCollectionReference<Map<String, dynamic>> mockSharedMenusCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    late MockAuthRepository mockAuthRepository;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(FakeSharedRecipe());
      registerFallbackValue(FakeSharedMenu());
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockSharedRecipesCollection = MockCollectionReference<Map<String, dynamic>>();
      mockSharedMenusCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockAuthRepository = MockAuthRepository();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      mockAuth.setAuthState(currentUser: mockUser);
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection('shared_recipes')).thenReturn(mockSharedRecipesCollection);
      when(() => mockFirestore.collection('shared_menus')).thenReturn(mockSharedMenusCollection);
      when(() => mockSharedRecipesCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockSharedRecipesCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockSharedMenusCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockSharedMenusCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockDocRef.id).thenReturn('mock_doc_id');
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      
      // Setup mock document snapshot for get operations
      final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockGetSnapshot.id).thenReturn('mock_doc_id');
      when(() => mockGetSnapshot.exists).thenReturn(true);
      when(() => mockGetSnapshot.data()).thenReturn(<String, dynamic>{
        'originalRecipeId': 'recipe_1',
        'sharedByUserId': 'owner_123',
        'ownerId': 'owner_123',
        'sharedByDisplayName': 'Owner Name',
        'sharedToUserIds': ['test_user_123'],
        'sharedWith': ['test_user_123'],
        'sharedWithUserIds': ['test_user_123'],
        'sharedAt': Timestamp.now(),
        'viewedByUserIds': [],
        'importedByUserIds': [],
        'dismissedByUserIds': [],
        'recipeSnapshot': RecipeBuilder().asSwedishDinner().build().toFirestore(),
      });
      when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
      
      // Setup query mocks
      when(() => mockSharedRecipesCollection.where(any(), arrayContains: any(named: 'arrayContains')))
          .thenReturn(mockQuery);
      when(() => mockSharedMenusCollection.where(any(), arrayContains: any(named: 'arrayContains')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), arrayContains: any(named: 'arrayContains')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository with dependency injection
      repository = FirebaseSocialRecipeRepository(
        firestore: mockFirestore,
        auth: mockAuth,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Shared Recipes', () {
      test('should get shared recipes for a user', () async {
        // Arrange
        const userId = 'test_user_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Mock shared recipe document
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('shared_recipe_1');
        when(() => mockDoc.data()).thenReturn({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'user_456',
          'sharedByDisplayName': 'Anna Andersson',
          'sharedToUserIds': [userId, 'other_user'],
          'sharedWithUserIds': [userId, 'other_user'],
          'sharedAt': Timestamp.now(),
          'shareMessage': 'Try this recipe!',
          'scope': 'individual',
          'allowImport': true,
          'allowCollaboration': false,
          'viewCount': 0,
          'importCount': 0,
          'viewedByUserIds': [],
          'importedByUserIds': [],
          'dismissedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        when(() => mockDoc.exists).thenReturn(true);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final sharedRecipes = await repository.getSharedRecipes(userId);
        
        // Assert
        expect(sharedRecipes.length, equals(1));
        expect(sharedRecipes.first.sharedByDisplayName, equals('Anna Andersson'));
        expect(sharedRecipes.first.shareMessage, equals('Try this recipe!'));
      });
      
      test('should mark shared recipe as viewed', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Act
        await repository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should not allow marking recipe as viewed without permission', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Mock document with different shared users
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(recipeId);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': ['unauthorized_user'],
          'sharedWith': ['unauthorized_user'],
          'sharedWithUserIds': ['unauthorized_user'],
          'sharedAt': Timestamp.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': RecipeBuilder().asSwedishDinner().build().toFirestore(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.markSharedRecipeAsViewed(recipeId, userId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
      
      test('should mark shared recipe as imported', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Act
        await repository.markSharedRecipeAsImported(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should dismiss shared recipe', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Act
        await repository.dismissSharedRecipe(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should undismiss shared recipe', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Mock document with user already dismissed
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(recipeId);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': ['test_user_123'],
          'sharedWith': ['test_user_123'],
          'sharedWithUserIds': ['test_user_123'],
          'sharedAt': Timestamp.now(),
          'dismissedByUserIds': ['test_user_123'],
          'dismissedAt': {'test_user_123': Timestamp.now()},
          'recipeSnapshot': RecipeBuilder().asSwedishDinner().build().toFirestore(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.undismissSharedRecipe(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
    });
    
    group('Shared Menus', () {
      test('should get shared menus for a user', () async {
        // Arrange
        const userId = 'test_user_123';
        final recipe1 = RecipeBuilder().asSwedishDinner().build();
        final recipe2 = RecipeBuilder().asItalianPasta().build();
        
        // Mock shared menu document
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('shared_menu_1');
        when(() => mockDoc.data()).thenReturn({
          'sharedByUserId': 'user_456',
          'sharedByDisplayName': 'Maria Svensson',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': Timestamp.now(),
          'shareMessage': 'My weekly menu',
          'menuTitle': 'Week 45 Menu',
          'menuSnapshot': {
            'Middag': [recipe1.toFirestore(), recipe2.toFirestore()],
            'Lunch': [],
          },
          'totalRecipeCount': 2,
          'categories': ['Middag', 'Lunch'],
          'viewCount': 0,
          'importCount': 0,
          'viewedByUserIds': [],
          'importedByUserIds': [],
          'dismissedByUserIds': [],
          'allowCollaboration': false,
        });
        when(() => mockDoc.exists).thenReturn(true);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final sharedMenus = await repository.getSharedMenus(userId);
        
        // Assert
        expect(sharedMenus.length, equals(1));
        expect(sharedMenus.first.menuTitle, equals('Week 45 Menu'));
        expect(sharedMenus.first.sharedByDisplayName, equals('Maria Svensson'));
      });
      
      test('should mark shared menu as viewed', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        
        // Act
        await repository.markSharedMenuAsViewed(menuId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should mark shared menu as imported', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        
        // Act
        await repository.markSharedMenuAsImported(menuId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should dismiss shared menu', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        
        // Act
        await repository.dismissSharedMenu(menuId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should undismiss shared menu', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        
        // Mock document with user already dismissed
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(menuId);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': ['test_user_123'],
          'sharedWith': ['test_user_123'],
          'sharedWithUserIds': ['test_user_123'],
          'sharedAt': Timestamp.now(),
          'menuTitle': 'Test Menu',
          'menuSnapshot': {'Middag': [RecipeBuilder().asSwedishDinner().build().toFirestore()]},
          'dismissedByUserIds': ['test_user_123'],
          'dismissedAt': {'test_user_123': Timestamp.now()},
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.undismissSharedMenu(menuId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
    });
    
    group('Content Sharing', () {
      test('should share content between users', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        const contentType = 'recipe';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Mock add operation to return a document reference
        final mockContentCollection = MockCollectionReference<Map<String, dynamic>>();
        when(() => mockFirestore.collection('shared_content')).thenReturn(mockContentCollection);
        when(() => mockContentCollection.add(any())).thenAnswer((_) async => mockDocRef);
        
        // Act
        await repository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: contentType,
          contentData: recipe.toFirestore(),
        );
        
        // Assert
        verify(() => mockContentCollection.add(any())).called(1);
      });
      
      test('should not allow sharing content with yourself', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const contentType = 'recipe';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Act & Assert
        expect(
          () => repository.shareContent(
            fromUserId: fromUserId,
            toUserId: fromUserId, // Same as fromUserId
            contentType: contentType,
            contentData: recipe.toFirestore(),
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });
      
      test('should not allow sharing from another user account', () async {
        // Arrange
        const differentUserId = 'different_user_456';
        const toUserId = 'target_user_789';
        const contentType = 'recipe';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Act & Assert
        expect(
          () => repository.shareContent(
            fromUserId: differentUserId, // Not the authenticated user
            toUserId: toUserId,
            contentType: contentType,
            contentData: recipe.toFirestore(),
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Permission Validation', () {
      test('should validate self-operation for viewing', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Act - should not throw
        await repository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should validate read access for shared recipes', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        // Mock document with proper permissions
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(recipeId);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': Timestamp.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': RecipeBuilder().asSwedishDinner().build().toFirestore(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should handle authentication state correctly', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          userId: null,
          isAuthenticated: false,
        );
        mockAuth.setAuthState(currentUser: null);
        
        const userId = 'test_user_123';
        const recipeId = 'recipe_123';
        
        // Act & Assert - markSharedRecipeAsViewed checks authentication
        expect(
          () => repository.markSharedRecipeAsViewed(recipeId, userId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Error Handling', () {
      test('should handle missing document gracefully', () async {
        // Arrange
        const recipeId = 'non_existent_recipe';
        const userId = 'test_user_123';
        
        // Mock non-existent document
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.markSharedRecipeAsViewed(recipeId, userId),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
      
      test('should handle malformed recipe data', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock malformed shared recipe document
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('malformed_recipe');
        when(() => mockDoc.data()).thenReturn({
          // Missing required fields
          'sharedByUserId': 'user_456',
          // recipeSnapshot is null/missing
        });
        when(() => mockDoc.exists).thenReturn(true);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act & Assert - should throw due to malformed data
        expect(
          () async => await repository.getSharedRecipes(userId),
          throwsException,
        );
      });
      
      test('should validate required fields when sharing content', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        const contentType = 'recipe';
        
        // Mock add operation to return a document reference
        final mockContentCollection = MockCollectionReference<Map<String, dynamic>>();
        when(() => mockFirestore.collection('shared_content')).thenReturn(mockContentCollection);
        when(() => mockContentCollection.add(any())).thenAnswer((_) async => mockDocRef);
        
        // Act - sharing with empty content data
        await repository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: contentType,
          contentData: {}, // Empty content data
        );
        
        // Assert - should still call add even with empty content data
        verify(() => mockContentCollection.add(any())).called(1);
      });
    });
  });
}