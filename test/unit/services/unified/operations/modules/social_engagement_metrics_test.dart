// test/unit/services/unified/operations/modules/social_engagement_metrics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/operations/modules/social_engagement_metrics.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;

void main() {
  group('SocialEngagementMetrics', () {
    late Recipe personalRecipe;
    late Recipe collaborativeRecipe;
    late Recipe complexRecipe;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create fake Firestore
      fakeFirestore = FakeFirebaseFirestore();

      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Create test data
      personalRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Simple Personal Recipe')
          .withCreatedBy('user_123')
          .withIngredients(['Salt', 'Pepper']).withInstructions(
              ['Mix', 'Cook']).build();

      // Create collaborative recipe with social data
      collaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe_2',
          title: 'Collaborative Recipe',
          description: 'A team effort',
          ingredients: ['Flour', 'Water', 'Yeast', 'Salt'],
          instructions: ['Mix ingredients', 'Knead', 'Let rise', 'Bake'],
          mealType: 'dinner',
          createdAt: DateTime.now().subtract(Duration(days: 3)),
          updatedAt: DateTime.now().subtract(Duration(days: 1)),
          createdBy: 'user_456',
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_456',
          ownerDisplayName: 'Owner',
          memberPermissions: {
            'user_456': ResourcePermission.owner,
            'user_789': ResourcePermission.editor,
            'user_101': ResourcePermission.viewer,
            'user_102': ResourcePermission.viewer,
          },
        ),
      );

      // Create complex recipe for completeness testing
      complexRecipe = RecipeBuilder()
          .withId('recipe_3')
          .withTitle('Complex Recipe')
          .withDescription('Detailed description')
          .withIngredients(List.generate(10, (i) => 'Ingredient $i'))
          .withInstructions(List.generate(8, (i) => 'Step $i'))
          .withPortions(4)
          .withTimeMinutes(60)
          .withImageUrls(['https://example.com/image.jpg']).withTags(
              ['swedish', 'dinner', 'traditional']).build();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Recipe Engagement Metrics', () {
      test('should calculate basic engagement metrics for personal recipe', () {
        // Act
        final metrics =
            SocialEngagementMetrics.calculateRecipeEngagement(personalRecipe);

        // Assert
        expect(metrics['member_count'], equals(1));
        expect(metrics['is_collaborative'], isFalse);
        expect(metrics['sharing_enabled'], isFalse);
        expect(metrics['engagement_score'], greaterThanOrEqualTo(0));
        expect(metrics['engagement_level'], isNotNull);
      });

      test('should calculate higher engagement for collaborative recipe', () {
        // Act
        final metrics = SocialEngagementMetrics.calculateRecipeEngagement(
            collaborativeRecipe);

        // Assert
        expect(metrics['member_count'], equals(5)); // 4 members + 1 owner
        expect(metrics['is_collaborative'], isTrue);
        expect(metrics['sharing_enabled'], isTrue);
        expect(metrics['engagement_score'],
            greaterThan(40)); // Multiple members contribute to score
      });

      test('should include recency in engagement score', () {
        // Arrange - Create recipe updated today
        final recentRecipe = Recipe(
          core: RecipeCore(
            id: 'recent',
            title: 'Recent Recipe',
            description: 'Updated today',
            ingredients: ['Test'],
            instructions: ['Test'],
            mealType: 'test',
            createdAt: DateTime.now().subtract(Duration(days: 10)),
            updatedAt: DateTime.now(),
            createdBy: 'user_123',
          ),
          type: RecipeType.personal,
        );

        // Act
        final metrics =
            SocialEngagementMetrics.calculateRecipeEngagement(recentRecipe);
        final factors = metrics['engagement_factors'] as Map<String, dynamic>;

        // Assert
        expect(factors['recency_contribution'], greaterThan(0));
      });

      test('should calculate engagement level correctly', () {
        // Act
        final lowEngagement =
            SocialEngagementMetrics.calculateRecipeEngagement(personalRecipe);
        final highEngagement =
            SocialEngagementMetrics.calculateRecipeEngagement(
                collaborativeRecipe);

        // Assert
        expect(lowEngagement['engagement_level'], equals('low'));
        expect(highEngagement['engagement_level'], anyOf('medium', 'high'));
      });

      test('should factor in recipe complexity', () {
        // Act
        final simpleMetrics =
            SocialEngagementMetrics.calculateRecipeEngagement(personalRecipe);
        final complexMetrics =
            SocialEngagementMetrics.calculateRecipeEngagement(complexRecipe);

        // Assert
        expect(complexMetrics['engagement_score'],
            greaterThan(simpleMetrics['engagement_score']));
      });

      test('should calculate engagement factors breakdown', () {
        // Act
        final metrics = SocialEngagementMetrics.calculateRecipeEngagement(
            collaborativeRecipe);
        final factors = metrics['engagement_factors'] as Map<String, dynamic>;

        // Assert
        expect(factors, contains('member_contribution'));
        expect(factors, contains('recency_contribution'));
        expect(factors, contains('content_contribution'));
        expect(factors, contains('completeness_contribution'));
        expect(factors['member_contribution'], greaterThan(0));
      });

      test('should handle error gracefully', () {
        // Arrange - Create recipe with null/invalid data
        final invalidRecipe = Recipe(
          core: RecipeCore(
            id: 'invalid',
            title: 'Invalid',
            description: '',
            ingredients: [],
            instructions: [],
            mealType: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: '',
          ),
          type: RecipeType.personal,
        );

        // Act
        final metrics =
            SocialEngagementMetrics.calculateRecipeEngagement(invalidRecipe);

        // Assert - Empty recipe still has base score from title
        expect(metrics['engagement_score'], greaterThanOrEqualTo(0));
        expect(metrics['engagement_level'], equals('low'));
      });
    });

    group('Recipe Completeness', () {
      test('should calculate completeness score for minimal recipe', () {
        // Arrange
        final minimalRecipe = Recipe(
          core: RecipeCore(
            id: 'minimal',
            title: 'Minimal Recipe',
            description: '',
            ingredients: [],
            instructions: [],
            mealType: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: 'user',
          ),
          type: RecipeType.personal,
        );

        // Act - Using private method through public interface
        final metrics =
            SocialEngagementMetrics.calculateRecipeEngagement(minimalRecipe);
        final factors = metrics['engagement_factors'] as Map<String, dynamic>;

        // Assert - Title is always present, so minimum score
        expect(factors['completeness_contribution'], greaterThanOrEqualTo(0));
      });

      test('should calculate completeness score for complete recipe', () {
        // Act
        final metrics =
            SocialEngagementMetrics.calculateRecipeEngagement(complexRecipe);
        final factors = metrics['engagement_factors'] as Map<String, dynamic>;

        // Assert - Complete recipe should have high completeness
        expect(factors['completeness_contribution'],
            greaterThan(4)); // Adjusted for actual scale
      });
    });

    group('User Social Statistics', () {
      test('should calculate user social stats', () async {
        // Arrange - Add user data to Firestore
        await fakeFirestore.collection('recipe_ratings').add({
          'recipeId': 'recipe_1',
          'userId': 'user_456',
          'rating': 4.5,
        });

        // Act
        final stats = await SocialEngagementMetrics.calculateUserSocialStats(
          firestore: fakeFirestore,
          userId: 'user_123',
          userRecipes: [personalRecipe, complexRecipe],
        );

        // Assert
        expect(stats['total_recipes'], equals(2));
        expect(stats['collaborative_recipes'], equals(0));
        expect(stats['personal_recipes'], equals(2));
        expect(stats['social_reach'], greaterThanOrEqualTo(0));
        expect(stats['average_engagement_score'], greaterThanOrEqualTo(0));
      });

      test('should identify social activity level for user', () async {
        // Arrange - Create collaborative recipes
        final collabRecipes = [collaborativeRecipe];

        // Act
        final stats = await SocialEngagementMetrics.calculateUserSocialStats(
          firestore: fakeFirestore,
          userId: 'creator',
          userRecipes: collabRecipes,
        );

        // Assert
        expect(stats['social_activity_level'], isNotNull);
        expect(stats['collaborative_recipes'], equals(1));
        expect(stats['social_reach'], greaterThan(0));
      });

      test('should handle user with no activity', () async {
        // Act
        final stats = await SocialEngagementMetrics.calculateUserSocialStats(
          firestore: fakeFirestore,
          userId: 'inactive',
          userRecipes: [],
        );

        // Assert
        expect(stats['total_recipes'], equals(0));
        expect(stats['collaborative_recipes'], equals(0));
        expect(stats['average_engagement_score'], equals(0));
        expect(stats['social_activity_level'], isNotNull);
      });
    });

    // Note: Social Activity Metrics test group removed
    // Methods getRecipeActivityMetrics and calculateTrendingScore don't exist in production

    // Note: Engagement Trends test group removed
    // Method analyzeEngagementTrends doesn't exist in production

    group('Error Handling', () {
      test('should handle Firestore errors gracefully', () async {
        // Arrange - Create mock that throws
        final mockFirestore = MockFirebaseFirestore();
        when(() => mockFirestore.collection(any()))
            .thenThrow(Exception('Firestore error'));

        // Act
        final stats = await SocialEngagementMetrics.calculateUserSocialStats(
          firestore: mockFirestore,
          userId: 'user_123',
          userRecipes: [
            personalRecipe
          ], // Need a recipe to trigger Firestore calls
        );

        // Assert - Firestore errors are caught in _calculateUserRatingStats
        // which returns default values; the outer method succeeds with zeroed ratings
        expect(stats['total_recipes'], equals(1));
        expect(stats['ratings_received'], equals(0));
        expect(stats['ratings_given'], equals(0));
      });

      test('should handle missing user data', () async {
        // Act - Query non-existent user
        final stats = await SocialEngagementMetrics.calculateUserSocialStats(
          firestore: fakeFirestore,
          userId: 'non_existent_user',
          userRecipes: [],
        );

        // Assert
        expect(stats['total_recipes'], equals(0));
        expect(stats['collaborative_recipes'], equals(0));
      });
    });
  });
}

// Using centralized mocks from production_mocks.dart:
// MockFirebaseFirestore
