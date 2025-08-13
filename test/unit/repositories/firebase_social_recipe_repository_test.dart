/// Unit tests for FirebaseSocialRecipeRepository
/// 
/// Tests the social recipe sharing repository that manages recipe and menu sharing
/// with engagement tracking and permission validation.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase/firebase_social_recipe_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('FirebaseSocialRecipeRepository', () {
    late FirebaseSocialRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;
    late MockFirebaseAuth mockAuth;
    late FakeUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Setup fake Firestore and mocks
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      mockAuth = MockFirebaseAuth();
      mockUser = FakeUser(uid: 'test_user_123');
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      // No need to stub mockUser.uid - FakeUser now has the correct uid
      
      // Create repository with dependency injection
      repository = FirebaseSocialRecipeRepository(
        firestore: fakeFirestore,
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
        
        // Add shared recipes to Firestore
        await fakeFirestore.collection('shared_recipes').add({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'user_456',
          'sharedByDisplayName': 'Anna Andersson',
          'sharedToUserIds': [userId, 'other_user'],
          'sharedWithUserIds': [userId, 'other_user'], // Include both fields for compatibility
          'sharedAt': DateTime.now(),
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
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId], // Include for permission check
          'sharedAt': DateTime.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act
        await repository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_recipes').doc(recipeId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['viewedByUserIds'], contains(userId));
        expect(data['viewedAt']?[userId], isNotNull);
      });
      
      test('should not allow marking recipe as viewed without permission', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        const unauthorizedUser = 'unauthorized_user';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document (not shared with test user)
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [unauthorizedUser],
          'sharedWith': [unauthorizedUser],
          'sharedAt': DateTime.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
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
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId],
          'sharedAt': DateTime.now(),
          'importedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act
        await repository.markSharedRecipeAsImported(recipeId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_recipes').doc(recipeId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['importedByUserIds'], contains(userId));
        expect(data['importedAt']?[userId], isNotNull);
      });
      
      test('should dismiss shared recipe', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId],
          'sharedAt': DateTime.now(),
          'dismissedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act
        await repository.dismissSharedRecipe(recipeId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_recipes').doc(recipeId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['dismissedByUserIds'], contains(userId));
        expect(data['dismissedAt']?[userId], isNotNull);
      });
      
      test('should undismiss shared recipe', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document with user already dismissed
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId],
          'sharedAt': DateTime.now(),
          'dismissedByUserIds': [userId],
          'dismissedAt': {userId: DateTime.now()},
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act
        await repository.undismissSharedRecipe(recipeId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_recipes').doc(recipeId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['dismissedByUserIds'], isNot(contains(userId)));
        expect(data['dismissedAt']?[userId], isNull);
      });
    });
    
    group('Shared Menus', () {
      test('should get shared menus for a user', () async {
        // Arrange
        const userId = 'test_user_123';
        final recipe1 = RecipeBuilder().asSwedishDinner().build();
        final recipe2 = RecipeBuilder().asItalianPasta().build();
        
        // Add shared menu to Firestore
        await fakeFirestore.collection('shared_menus').add({
          'sharedByUserId': 'user_456',
          'sharedByDisplayName': 'Maria Svensson',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId], // Include both fields for compatibility
          'sharedAt': DateTime.now(),
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
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared menu document
        await fakeFirestore.collection('shared_menus').doc(menuId).set({
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': DateTime.now(),
          'menuTitle': 'Test Menu',
          'menuSnapshot': {'Middag': [recipe.toFirestore()]},
          'viewedByUserIds': [],
        });
        
        // Act
        await repository.markSharedMenuAsViewed(menuId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_menus').doc(menuId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['viewedByUserIds'], contains(userId));
        expect(data['viewedAt']?[userId], isNotNull);
      });
      
      test('should mark shared menu as imported', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared menu document
        await fakeFirestore.collection('shared_menus').doc(menuId).set({
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': DateTime.now(),
          'menuTitle': 'Test Menu',
          'menuSnapshot': {'Middag': [recipe.toFirestore()]},
          'importedByUserIds': [],
        });
        
        // Act
        await repository.markSharedMenuAsImported(menuId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_menus').doc(menuId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['importedByUserIds'], contains(userId));
        expect(data['importedAt']?[userId], isNotNull);
      });
      
      test('should dismiss shared menu', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared menu document
        await fakeFirestore.collection('shared_menus').doc(menuId).set({
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': DateTime.now(),
          'menuTitle': 'Test Menu',
          'menuSnapshot': {'Middag': [recipe.toFirestore()]},
          'dismissedByUserIds': [],
        });
        
        // Act
        await repository.dismissSharedMenu(menuId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_menus').doc(menuId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['dismissedByUserIds'], contains(userId));
        expect(data['dismissedAt']?[userId], isNotNull);
      });
      
      test('should undismiss shared menu', () async {
        // Arrange
        const userId = 'test_user_123';
        const menuId = 'shared_menu_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared menu document with user already dismissed
        await fakeFirestore.collection('shared_menus').doc(menuId).set({
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWithUserIds': [userId],
          'sharedAt': DateTime.now(),
          'menuTitle': 'Test Menu',
          'menuSnapshot': {'Middag': [recipe.toFirestore()]},
          'dismissedByUserIds': [userId],
          'dismissedAt': {userId: DateTime.now()},
        });
        
        // Act
        await repository.undismissSharedMenu(menuId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_menus').doc(menuId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['dismissedByUserIds'], isNot(contains(userId)));
        expect(data['dismissedAt']?[userId], isNull);
      });
    });
    
    group('Content Sharing', () {
      test('should share content between users', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        final contentData = {
          'recipeId': 'recipe_123',
          'recipeName': 'Swedish Meatballs',
          'message': 'Try this recipe!',
        };
        
        // Act
        await repository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: 'recipe',
          contentData: contentData,
        );
        
        // Assert
        final sharedContent = await fakeFirestore
            .collection('shared_content')
            .where('fromUserId', isEqualTo: fromUserId)
            .where('toUserId', isEqualTo: toUserId)
            .get();
        
        expect(sharedContent.docs.length, equals(1));
        final data = sharedContent.docs.first.data();
        expect(data['contentType'], equals('recipe'));
        expect(data['contentData'], equals(contentData));
        expect(data['status'], equals('pending'));
      });
      
      test('should not allow sharing content with yourself', () async {
        // Arrange
        const userId = 'test_user_123';
        final contentData = {'recipeId': 'recipe_123'};
        
        // Act & Assert
        expect(
          () => repository.shareContent(
            fromUserId: userId,
            toUserId: userId,
            contentType: 'recipe',
            contentData: contentData,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });
      
      test('should not allow sharing from another user account', () async {
        // Arrange
        const anotherUserId = 'another_user_456';
        const toUserId = 'target_user_789';
        final contentData = {'recipeId': 'recipe_123'};
        
        // Act & Assert
        expect(
          () => repository.shareContent(
            fromUserId: anotherUserId, // Trying to share from another user's account
            toUserId: toUserId,
            contentType: 'recipe',
            contentData: contentData,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Permission Validation', () {
      test('should validate self-operation for viewing', () async {
        // Arrange
        const anotherUserId = 'another_user_456';
        const recipeId = 'shared_recipe_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [anotherUserId],
          'sharedWith': [anotherUserId],
          'sharedAt': DateTime.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act & Assert - User cannot mark another user's view
        expect(
          () => repository.markSharedRecipeAsViewed(recipeId, anotherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
      
      test('should validate read access for shared recipes', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document owned by user
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': userId, // User is the owner
          'ownerId': userId,
          'sharedByDisplayName': 'Test User',
          'sharedToUserIds': ['another_user'],
          'sharedWith': ['another_user'],
          'sharedAt': DateTime.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Act - Owner can mark their own recipe as viewed
        await repository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        final doc = await fakeFirestore.collection('shared_recipes').doc(recipeId).get();
        final data = doc.data() as Map<String, dynamic>;
        expect(data['viewedByUserIds'], contains(userId));
      });
      
      test('should handle authentication state correctly', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        
        // Create shared recipe document
        await fakeFirestore.collection('shared_recipes').doc(recipeId).set({
          'originalRecipeId': 'recipe_1',
          'sharedByUserId': 'owner_123',
          'ownerId': 'owner_123',
          'sharedByDisplayName': 'Owner Name',
          'sharedToUserIds': [userId],
          'sharedWith': [userId],
          'sharedAt': DateTime.now(),
          'viewedByUserIds': [],
          'recipeSnapshot': recipe.toFirestore(),
        });
        
        // Clear auth state
        mockAuthRepository.setAuthState(userId: null);
        
        // Act & Assert - Should throw permission denied when not authenticated
        expect(
          () => repository.markSharedRecipeAsViewed(recipeId, userId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Error Handling', () {
      test('should handle missing document gracefully', () async {
        // Arrange
        const userId = 'test_user_123';
        const nonExistentRecipeId = 'non_existent_recipe';
        
        // Act & Assert
        expect(
          () => repository.markSharedRecipeAsViewed(nonExistentRecipeId, userId),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
      
      test('should handle malformed recipe data', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Add malformed shared recipe with null recipeSnapshot
        await fakeFirestore.collection('shared_recipes').add({
          'sharedWithUserIds': [userId],
          'sharedByUserId': 'user_456',
          'sharedByDisplayName': 'Test User',
          'recipeSnapshot': null, // Null will cause parsing error
        });
        
        // Act & Assert
        expect(
          () => repository.getSharedRecipes(userId),
          throwsException,
        );
      });
      
      test('should validate required fields when sharing content', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        
        // Act & Assert - Empty contentData is allowed
        await expectLater(
          repository.shareContent(
            fromUserId: fromUserId,
            toUserId: toUserId,
            contentType: 'recipe',
            contentData: {},
          ),
          completes, // Empty contentData is allowed, but requires other fields
        );
      });
    });
  });
}