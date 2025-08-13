/// Unit tests for FirebaseSocialRecipeRepository using mock pattern
/// 
/// This tests the service layer's interaction with the repository,
/// not the Firebase implementation details.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('SocialRecipeRepository Mock Tests', () {
    late MockSocialRecipeRepository mockRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      mockRepository = MockSocialRecipeRepository();
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
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
        );
        
        when(() => mockRepository.getSharedRecipes(userId))
            .thenAnswer((_) async => [sharedRecipe]);
        
        // Act
        final result = await mockRepository.getSharedRecipes(userId);
        
        // Assert
        expect(result.length, equals(1));
        expect(result.first.sharedByDisplayName, equals('Anna Andersson'));
        verify(() => mockRepository.getSharedRecipes(userId)).called(1);
      });
      
      test('should mark shared recipe as viewed', () async {
        // Arrange
        const userId = 'test_user_123';
        const recipeId = 'shared_recipe_123';
        
        when(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.markSharedRecipeAsViewed(recipeId, userId);
        
        // Assert
        verify(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId)).called(1);
      });
      
      test('should throw permission exception for unauthorized access', () async {
        // Arrange
        const userId = 'unauthorized_user';
        const recipeId = 'shared_recipe_123';
        
        when(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId))
            .thenThrow(Exception('Permission denied'));
        
        // Act & Assert
        expect(
          () => mockRepository.markSharedRecipeAsViewed(recipeId, userId),
          throwsException,
        );
      });
    });
    
    group('Shared Menus', () {
      test('should get shared menus for a user', () async {
        // Arrange
        const userId = 'test_user_123';
        final menu = SharedMenu(
          id: 'menu_1',
          sharedByUserId: 'user_456',
          sharedByDisplayName: 'Maria Svensson',
          sharedToUserIds: [userId],
          sharedAt: DateTime.now(),
          menuTitle: 'Week 45 Menu',
          menuSnapshot: {},
        );
        
        when(() => mockRepository.getSharedMenus(userId))
            .thenAnswer((_) async => [menu]);
        
        // Act
        final result = await mockRepository.getSharedMenus(userId);
        
        // Assert
        expect(result.length, equals(1));
        expect(result.first.menuTitle, equals('Week 45 Menu'));
        verify(() => mockRepository.getSharedMenus(userId)).called(1);
      });
    });
    
    group('Content Sharing', () {
      test('should share content between users', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        final contentData = {'recipeId': 'recipe_123'};
        
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
    });
  });
}