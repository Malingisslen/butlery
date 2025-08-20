// test/unit/services/unified/operations/modules/rating_statistics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/operations/modules/rating_statistics.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RatingStatistics', () {
    late FakeFirebaseFirestore fakeFirestore;
    late Recipe testRecipe;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();
      
      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });
    
    group('Rating Statistics Calculation', () {
      test('should calculate statistics for empty ratings', () {
        // Arrange
        final ratings = <Map<String, dynamic>>[];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['count'], equals(0));
        expect(stats['average'], equals(0.0));
        expect(stats['distribution'], equals({1: 0, 2: 0, 3: 0, 4: 0, 5: 0}));
        expect(stats['reviews'], isEmpty);
        expect(stats['recent_reviews'], isEmpty);
        expect(stats['review_count'], equals(0));
        expect(stats['review_percentage'], equals(0));
      });
      
      test('should calculate average rating correctly', () {
        // Arrange
        final ratings = [
          {'rating': 5.0, 'review': 'Excellent!', 'createdAt': Timestamp.now()},
          {'rating': 4.0, 'review': 'Good', 'createdAt': Timestamp.now()},
          {'rating': 3.0, 'review': null, 'createdAt': Timestamp.now()},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['count'], equals(3));
        expect(stats['average'], equals(4.0)); // (5+4+3)/3 = 4.0
      });
      
      test('should calculate rating distribution correctly', () {
        // Arrange
        final ratings = [
          {'rating': 5.0, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 5.0, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 4.0, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 3.0, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 1.0, 'review': null, 'createdAt': Timestamp.now()},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['distribution'], equals({
          1: 1,
          2: 0,
          3: 1,
          4: 1,
          5: 2,
        }));
      });
      
      test('should extract reviews from ratings', () {
        // Arrange
        final now = Timestamp.now();
        final ratings = [
          {'rating': 5.0, 'review': 'Amazing!', 'createdAt': now},
          {'rating': 4.0, 'review': '', 'createdAt': now}, // Empty review
          {'rating': 3.0, 'review': null, 'createdAt': now}, // No review
          {'rating': 4.5, 'review': 'Very good', 'createdAt': now},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['review_count'], equals(2)); // Only non-empty reviews
        expect(stats['reviews'].length, equals(2));
      });
      
      test('should calculate review percentage', () {
        // Arrange
        final ratings = [
          {'rating': 5.0, 'review': 'Great!', 'createdAt': Timestamp.now()},
          {'rating': 4.0, 'review': 'Good', 'createdAt': Timestamp.now()},
          {'rating': 3.0, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 2.0, 'review': null, 'createdAt': Timestamp.now()},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['review_percentage'], equals(50)); // 2 reviews out of 4 ratings
      });
      
      test('should sort reviews by date (most recent first)', () {
        // Arrange
        final oldDate = Timestamp.fromDate(DateTime.now().subtract(Duration(days: 7)));
        final midDate = Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3)));
        final newDate = Timestamp.now();
        
        final ratings = [
          {'rating': 3.0, 'review': 'Old review', 'createdAt': oldDate},
          {'rating': 5.0, 'review': 'New review', 'createdAt': newDate},
          {'rating': 4.0, 'review': 'Mid review', 'createdAt': midDate},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        final reviews = stats['reviews'] as List;
        
        // Assert
        expect(reviews[0]['review'], equals('New review'));
        expect(reviews[1]['review'], equals('Mid review'));
        expect(reviews[2]['review'], equals('Old review'));
      });
      
      test('should get recent reviews (max 5)', () {
        // Arrange
        final ratings = List.generate(10, (i) => {
          'rating': 4.0,
          'review': 'Review $i',
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(Duration(days: 10 - i))
          ),
        });
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        final recentReviews = stats['recent_reviews'] as List;
        
        // Assert
        expect(recentReviews.length, equals(5));
        expect(recentReviews[0]['review'], equals('Review 9')); // Most recent
      });
      
      test('should round average to 1 decimal place', () {
        // Arrange
        final ratings = [
          {'rating': 4.3, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 4.7, 'review': null, 'createdAt': Timestamp.now()},
          {'rating': 3.8, 'review': null, 'createdAt': Timestamp.now()},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['average'], equals(4.3)); // (4.3+4.7+3.8)/3 = 4.26... → 4.3
      });
    });
    
    group('Recipe Statistics', () {
      test('should get comprehensive recipe statistics', () async {
        // Arrange
        await fakeFirestore.collection('recipe_ratings').add({
          'recipeId': 'recipe_1',
          'userId': 'user_1',
          'userDisplayName': 'User 1',
          'rating': 5.0,
          'review': 'Excellent!',
          'createdAt': Timestamp.now(),
        });
        
        await fakeFirestore.collection('recipe_ratings').add({
          'recipeId': 'recipe_1',
          'userId': 'user_2',
          'userDisplayName': 'User 2',
          'rating': 4.0,
          'review': null,
          'createdAt': Timestamp.now(),
        });
        
        // Act
        final stats = await RatingStatistics.getRecipeStatistics(
          firestore: fakeFirestore,
          recipeId: 'recipe_1',
          recipe: testRecipe,
        );
        
        // Assert
        expect(stats['ratings']['count'], equals(2));
        expect(stats['ratings']['average'], equals(4.5));
        expect(stats['recipe'], isNotNull);
        expect(stats['recipe']['id'], equals('recipe_1'));
      });
      
      test('should handle recipe with no ratings', () async {
        // Act
        final stats = await RatingStatistics.getRecipeStatistics(
          firestore: fakeFirestore,
          recipeId: 'recipe_without_ratings',
          recipe: testRecipe,
        );
        
        // Assert
        expect(stats['ratings']['count'], equals(0));
        expect(stats['ratings']['average'], equals(0.0));
      });
    });
    
    group('Top Rated Recipes', () {
      test('should get top rated recipes', () async {
        // Arrange - Add rating statistics for multiple recipes
        await fakeFirestore.collection('recipe_social_stats').doc('recipe_1').set({
          'recipeId': 'recipe_1',
          'averageRating': 4.8,
          'ratingCount': 50,
          'lastUpdated': Timestamp.now(),
        });
        
        await fakeFirestore.collection('recipe_social_stats').doc('recipe_2').set({
          'recipeId': 'recipe_2',
          'averageRating': 4.2,
          'ratingCount': 30,
          'lastUpdated': Timestamp.now(),
        });
        
        await fakeFirestore.collection('recipe_social_stats').doc('recipe_3').set({
          'recipeId': 'recipe_3',
          'averageRating': 4.9,
          'ratingCount': 10,
          'lastUpdated': Timestamp.now(),
        });
        
        final recipe1 = RecipeBuilder().withId('recipe_1').build();
        final recipe2 = RecipeBuilder().withId('recipe_2').build();
        final recipe3 = RecipeBuilder().withId('recipe_3').build();
        
        // Act
        final topRated = await RatingStatistics.getTopRatedRecipes(
          firestore: fakeFirestore,
          accessibleRecipes: [recipe1, recipe2, recipe3],
          minRatingCount: 5,
          limit: 2,
        );
        
        // Assert
        expect(topRated.length, equals(2));
        expect((topRated[0]['recipe'] as Recipe).id, equals('recipe_3')); // Highest average
        expect((topRated[1]['recipe'] as Recipe).id, equals('recipe_1')); // Second highest
      });
      
      test('should filter by minimum rating count', () async {
        // Arrange
        await fakeFirestore.collection('recipe_social_stats').doc('recipe_1').set({
          'recipeId': 'recipe_1',
          'averageRating': 5.0,
          'ratingCount': 2, // Below minimum
          'lastUpdated': Timestamp.now(),
        });
        
        await fakeFirestore.collection('recipe_social_stats').doc('recipe_2').set({
          'recipeId': 'recipe_2',
          'averageRating': 4.5, // Above default minRating of 4.0
          'ratingCount': 20, // Above minimum
          'lastUpdated': Timestamp.now(),
        });
        
        final recipe1 = RecipeBuilder().withId('recipe_1').build();
        final recipe2 = RecipeBuilder().withId('recipe_2').build();
        
        // Act
        final topRated = await RatingStatistics.getTopRatedRecipes(
          firestore: fakeFirestore,
          accessibleRecipes: [recipe1, recipe2],
          minRatingCount: 10,
          minRating: 4.0, // Explicit to be clear
          limit: 10,
        );
        
        // Assert
        expect(topRated.length, equals(1));
        expect((topRated[0]['recipe'] as Recipe).id, equals('recipe_2'));
      });
      
      test('should respect limit parameter', () async {
        // Arrange - Add many recipes
        final recipes = <Recipe>[];
        for (int i = 0; i < 10; i++) {
          await fakeFirestore.collection('recipe_social_stats').doc('recipe_$i').set({
            'recipeId': 'recipe_$i',
            'averageRating': 4.0 + (i * 0.1),
            'ratingCount': 15,
            'lastUpdated': Timestamp.now(),
          });
          recipes.add(RecipeBuilder().withId('recipe_$i').build());
        }
        
        // Act
        final topRated = await RatingStatistics.getTopRatedRecipes(
          firestore: fakeFirestore,
          accessibleRecipes: recipes,
          minRatingCount: 10,
          limit: 3,
        );
        
        // Assert
        expect(topRated.length, equals(3));
      });
    });
    
    group('Rating Trends', () {
      test('should calculate rating trends over time', () {
        // Arrange - Create ratings over different time periods
        final now = DateTime.now();
        final ratings = <Map<String, dynamic>>[];
        
        // Recent ratings (last 7 days)
        for (int i = 0; i < 5; i++) {
          ratings.add({
            'recipeId': 'recipe_1',
            'userId': 'user_$i',
            'rating': 4.5,
            'createdAt': Timestamp.fromDate(now.subtract(Duration(days: i))),
          });
        }
        
        // Older ratings (30 days ago)
        for (int i = 5; i < 8; i++) {
          ratings.add({
            'recipeId': 'recipe_1',
            'userId': 'user_$i',
            'rating': 3.0,
            'createdAt': Timestamp.fromDate(now.subtract(Duration(days: 30 + i))),
          });
        }
        
        // Act
        final trends = RatingStatistics.calculateRatingTrends(ratings);
        
        // Assert
        expect(trends['recent_average'], greaterThan(0));
        expect(trends['direction'], isNotNull);
      });
    });
    
    group('Error Handling', () {
      test('should handle null timestamps gracefully', () {
        // Arrange
        final ratings = [
          {'rating': 5.0, 'review': 'Great!', 'createdAt': null},
          {'rating': 4.0, 'review': 'Good', 'createdAt': Timestamp.now()},
        ];
        
        // Act
        final stats = RatingStatistics.calculateRatingStatistics(ratings);
        
        // Assert
        expect(stats['reviews'].length, equals(2));
      });
      
      test('should handle Firestore errors gracefully', () async {
        // Arrange - Create a mock Firestore that throws errors
        final mockFirestore = MockFirebaseFirestore();
        when(() => mockFirestore.collection(any()))
            .thenThrow(Exception('Firestore error'));
        
        // Act
        final stats = await RatingStatistics.getRecipeStatistics(
          firestore: mockFirestore,
          recipeId: 'recipe_1',
          recipe: testRecipe,
        );
        
        // Assert
        expect(stats['error'], equals('Failed to calculate statistics'));
      });
    });
    
    // Note: updateRecipeAggregateStats method doesn't exist in production code
    // This test group is removed as it tests non-existent functionality
  });
}

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}