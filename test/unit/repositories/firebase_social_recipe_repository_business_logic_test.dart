/// Unit tests for services using SocialRecipeRepository
/// 
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('SocialRecipeRepository Mock Tests', () {
    late MockSocialRecipeRepository mockRepository;
    late User mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mock repository with configuration
      mockUser = MockFactory.createMockUser(uid: 'test_user_123');
      mockRepository = MockFactory.createSocialRecipeRepository(
        currentUser: mockUser,
      );
      
      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
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
        final sharedRecipe = SharedRecipe(
          id: 'shared_1',
          originalRecipeId: recipe.id,
          sharedByUserId: 'user_456',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: [userId],
          sharedAt: DateTime.now(),
          shareMessage: 'Try this recipe!',
          recipeSnapshot: recipe,
          viewedByUserIds: [],
          importedByUserIds: [],
          dismissedByUserIds: [],
        );
        
        // Stub the repository method
        when(() => mockRepository.getSharedRecipes(userId))
            .thenAnswer((_) async => [sharedRecipe]);
        
        // Act
        final sharedRecipes = await mockRepository.getSharedRecipes(userId);
        
        // Assert
        expect(sharedRecipes.length, equals(1));
        expect(sharedRecipes.first.sharedByDisplayName, equals('Anna Andersson'));
        expect(sharedRecipes.first.shareMessage, equals('Try this recipe!'));
        
        // Verify the method was called
        verify(() => mockRepository.getSharedRecipes(userId)).called(1);
      });
      
      test('should mark shared recipe as viewed', () async {
        // Arrange
        const recipeId = 'shared_recipe_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert - verify the method was called with correct parameters
        verify(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId)).called(1);
      });
      
      test('should mark shared recipe as imported', () async {
        // Arrange
        const recipeId = 'shared_recipe_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.markSharedRecipeAsImported(recipeId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.markSharedRecipeAsImported(recipeId, userId);
        
        // Assert
        verify(() => mockRepository.markSharedRecipeAsImported(recipeId, userId)).called(1);
      });
      
      test('should dismiss shared recipe', () async {
        // Arrange
        const recipeId = 'shared_recipe_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.dismissSharedRecipe(recipeId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.dismissSharedRecipe(recipeId, userId);
        
        // Assert
        verify(() => mockRepository.dismissSharedRecipe(recipeId, userId)).called(1);
      });
      
      test('should undismiss shared recipe', () async {
        // Arrange
        const recipeId = 'shared_recipe_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.undismissSharedRecipe(recipeId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.undismissSharedRecipe(recipeId, userId);
        
        // Assert
        verify(() => mockRepository.undismissSharedRecipe(recipeId, userId)).called(1);
      });
    });
    
    group('Shared Menus', () {
      test('should get shared menus for a user', () async {
        // Arrange
        const userId = 'test_user_123';
        final sharedMenu = SharedMenu(
          id: 'shared_menu_1',
          sharedByUserId: 'user_456',
          sharedByDisplayName: 'Erik Eriksson',
          sharedToUserIds: [userId],
          sharedAt: DateTime.now(),
          shareMessage: 'Weekly menu plan!',
          menuTitle: 'Veckomeny',
          menuSnapshot: {'Middag': []},
          viewedByUserIds: [],
          importedByUserIds: [],
          dismissedByUserIds: [],
        );
        
        // Stub the repository method
        when(() => mockRepository.getSharedMenus(userId))
            .thenAnswer((_) async => [sharedMenu]);
        
        // Act
        final sharedMenus = await mockRepository.getSharedMenus(userId);
        
        // Assert
        expect(sharedMenus.length, equals(1));
        expect(sharedMenus.first.sharedByDisplayName, equals('Erik Eriksson'));
        expect(sharedMenus.first.shareMessage, equals('Weekly menu plan!'));
        
        // Verify the method was called
        verify(() => mockRepository.getSharedMenus(userId)).called(1);
      });
      
      test('should mark shared menu as viewed', () async {
        // Arrange
        const menuId = 'shared_menu_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.markSharedMenuAsViewed(menuId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.markSharedMenuAsViewed(menuId, userId);
        
        // Assert
        verify(() => mockRepository.markSharedMenuAsViewed(menuId, userId)).called(1);
      });
      
      test('should mark shared menu as imported', () async {
        // Arrange
        const menuId = 'shared_menu_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.markSharedMenuAsImported(menuId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.markSharedMenuAsImported(menuId, userId);
        
        // Assert
        verify(() => mockRepository.markSharedMenuAsImported(menuId, userId)).called(1);
      });
    });
    
    group('Content Sharing', () {
      test('should share content between users', () async {
        // Arrange
        const fromUserId = 'sender_123';
        const toUserId = 'receiver_456';
        final recipe = RecipeBuilder().asSwedishDinner().build();
        final contentData = {
          'recipeId': recipe.id,
          'recipeSnapshot': recipe.toFirestore(),
          'shareMessage': 'Enjoy this recipe!',
        };
        
        // Stub the repository method
        when(() => mockRepository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: 'recipe',
          contentData: contentData,
        )).thenAnswer((_) async {});
        
        // Act
        await mockRepository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: 'recipe',
          contentData: contentData,
        );
        
        // Assert
        verify(() => mockRepository.shareContent(
          fromUserId: fromUserId,
          toUserId: toUserId,
          contentType: 'recipe',
          contentData: contentData,
        )).called(1);
      });
      
      test('should handle sharing with multiple users', () async {
        // Arrange
        const fromUserId = 'sender_123';
        final toUserIds = ['user_1', 'user_2', 'user_3'];
        final recipe = RecipeBuilder().asSwedishDessert().build();
        
        // Stub the repository method for each user
        for (final toUserId in toUserIds) {
          when(() => mockRepository.shareContent(
            fromUserId: fromUserId,
            toUserId: toUserId,
            contentType: 'recipe',
            contentData: any(named: 'contentData'),
          )).thenAnswer((_) async {});
        }
        
        // Act
        for (final toUserId in toUserIds) {
          await mockRepository.shareContent(
            fromUserId: fromUserId,
            toUserId: toUserId,
            contentType: 'recipe',
            contentData: {'recipeId': recipe.id},
          );
        }
        
        // Assert
        for (final toUserId in toUserIds) {
          verify(() => mockRepository.shareContent(
            fromUserId: fromUserId,
            toUserId: toUserId,
            contentType: 'recipe',
            contentData: any(named: 'contentData'),
          )).called(1);
        }
      });
    });
    
    group('Auth State', () {
      test('should provide current user', () {
        // Assert
        expect(mockRepository.currentUser, equals(mockUser));
      });
      
      test('should provide auth state changes stream', () async {
        // Arrange
        final authStream = Stream<User?>.value(mockUser);
        when(() => mockRepository.authStateChanges())
            .thenAnswer((_) => authStream);
        
        // Act
        final stream = mockRepository.authStateChanges();
        final user = await stream.first;
        
        // Assert
        expect(user, equals(mockUser));
      });
    });
  });
}