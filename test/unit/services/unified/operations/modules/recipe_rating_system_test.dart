// test/unit/services/unified/operations/modules/recipe_rating_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_rating_system.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/providers/application_provider.dart' as app_provider;
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeRatingSystem', () {
    late MockRatingsRepository mockRatingsRepository;
    late RecipeRatingSystem ratingSystem;
    late Recipe testRecipe;
    
    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockRatingsRepository = MockRatingsRepository();
      
      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();
      
      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());
      
      // Create rating system instance
      ratingSystem = RecipeRatingSystem(
        ratingsRepository: mockRatingsRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });
    
    group('Core Rating Operations', () {
      test('should rate recipe successfully with valid rating', () async {
        // Arrange
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 4.5,
          review: 'Great recipe!',
        )).thenAnswer((_) async {});
        
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: 'Great recipe!',
          canRateValidator: (_) => true,
          recipeGetter: (id) => id == 'recipe_1' ? testRecipe : null,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRatingsRepository.rateRecipe(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 4.5,
          review: 'Great recipe!',
        )).called(1);
      });
      
      test('should rate recipe without review', () async {
        // Arrange
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 3.0,
          review: null,
        )).thenAnswer((_) async {});
        
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 3.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: null,
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should trim review text before saving', () async {
        // Arrange
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: 'Trimmed review',
        )).thenAnswer((_) async {});
        
        // Act
        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: '  Trimmed review  ',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        verify(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: 'Trimmed review',
        )).called(1);
      });
    });
    
    group('Rating Validation', () {
      test('should reject rating below 1.0', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 0.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        ));
      });
      
      test('should reject rating above 5.0', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 5.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should reject NaN rating', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: double.nan,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should reject infinite rating', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: double.infinity,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should accept boundary ratings (1.0 and 5.0)', () async {
        // Arrange
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        )).thenAnswer((_) async {});
        
        // Act - Test 1.0
        final result1 = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 1.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Act - Test 5.0
        final result5 = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 5.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result1, isTrue);
        expect(result5, isTrue);
      });
    });
    
    group('Permission Validation', () {
      test('should fail if recipe not found', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'nonexistent',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => null, // Recipe not found
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should fail if user lacks permission to rate', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => false, // No permission
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should use validator and getter callbacks correctly', () async {
        // Arrange
        var validatorCalled = false;
        var getterCalled = false;
        
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        )).thenAnswer((_) async {});
        
        // Act
        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (recipe) {
            validatorCalled = true;
            expect(recipe, equals(testRecipe));
            return true;
          },
          recipeGetter: (id) {
            getterCalled = true;
            expect(id, equals('recipe_1'));
            return testRecipe;
          },
        );
        
        // Assert
        expect(validatorCalled, isTrue);
        expect(getterCalled, isTrue);
      });
    });
    
    group('Get Rating Operations', () {
      test('should get user rating for recipe', () async {
        // Arrange
        final testRating = RecipeRating(
          id: 'rating_1',
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 4.5,
          review: 'Great!',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(() => mockRatingsRepository.getUserRating('recipe_1', 'user_123'))
            .thenAnswer((_) async => testRating);
        
        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );
        
        // Assert
        expect(rating, equals(testRating));
      });
      
      test('should handle null user rating', () async {
        // Arrange
        when(() => mockRatingsRepository.getUserRating('recipe_1', 'user_123'))
            .thenAnswer((_) async => null);
        
        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );
        
        // Assert
        expect(rating, isNull);
      });
      
      test('should get all ratings for recipe', () async {
        // Arrange
        final ratings = [
          RecipeRating(
            id: 'rating_1',
            recipeId: 'recipe_1',
            userId: 'user_1',
            rating: 4.5,
            review: 'Great!',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RecipeRating(
            id: 'rating_2',
            recipeId: 'recipe_1',
            userId: 'user_2',
            rating: 3.0,
            review: 'Good',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        
        when(() => mockRatingsRepository.getRecipeRatings('recipe_1'))
            .thenAnswer((_) async => ratings);
        
        // Act
        final result = await ratingSystem.getRecipeRatings(recipeId: 'recipe_1');
        
        // Assert
        expect(result.length, equals(2));
        expect(result, equals(ratings));
      });
      
      test('should return empty list on error', () async {
        // Arrange
        when(() => mockRatingsRepository.getRecipeRatings('recipe_1'))
            .thenThrow(Exception('Failed'));
        
        // Act
        final result = await ratingSystem.getRecipeRatings(recipeId: 'recipe_1');
        
        // Assert
        expect(result, isEmpty);
      });
    });
    
    group('Update Rating Operations', () {
      test('should update existing rating', () async {
        // Arrange
        final existingRating = RecipeRating(
          id: 'rating_1',
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 4.0,
          review: 'Good',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(() => mockRatingsRepository.getUserRating('recipe_1', 'user_123'))
            .thenAnswer((_) async => existingRating);
        
        when(() => mockRatingsRepository.updateRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 5.0,
          review: 'Amazing!',
        )).thenAnswer((_) async {});
        
        // Act
        final result = await ratingSystem.updateRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 5.0,
          review: 'Amazing!',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRatingsRepository.updateRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 5.0,
          review: 'Amazing!',
        )).called(1);
      });
      
      test('should validate rating value on update', () async {
        // Act
        final result = await ratingSystem.updateRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 6.0, // Invalid
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Delete Rating Operations', () {
      test('should delete rating', () async {
        // Arrange
        when(() => mockRatingsRepository.removeRating('recipe_1', 'user_123'))
            .thenAnswer((_) async {});
        
        // Act
        final result = await ratingSystem.deleteRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRatingsRepository.removeRating('recipe_1', 'user_123')).called(1);
      });
      
      test('should handle delete errors gracefully', () async {
        // Arrange
        when(() => mockRatingsRepository.removeRating('recipe_1', 'user_123'))
            .thenThrow(Exception('Delete failed'));
        
        // Act
        final result = await ratingSystem.deleteRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Error Handling', () {
      test('should handle repository errors gracefully', () async {
        // Arrange
        when(() => mockRatingsRepository.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        )).thenThrow(Exception('Repository error'));
        
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should handle getUserRating errors', () async {
        // Arrange
        when(() => mockRatingsRepository.getUserRating(any(), any()))
            .thenThrow(Exception('Failed'));
        
        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );
        
        // Assert
        expect(rating, isNull);
      });
    });
  });
}

// Mock classes
class MockRatingsRepository extends Mock implements RatingsRepository {}