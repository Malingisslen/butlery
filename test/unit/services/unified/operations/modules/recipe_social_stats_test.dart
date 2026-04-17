// Unit tests for RecipeSocialStats
//
// Tests the facade for recipe rating, social engagement, and statistics.
// Requires production ServiceLocator bridge because RecipeRatingSystem
// constructor calls ServiceLocator.get() for RatingsRepository and
// AnalyticsService.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/modules/recipe_social_stats.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeSocialStats', () {
    late RecipeSocialStats stats;
    late FakeFirestoreRepository mockFirestoreRepository;
    late MockNotificationService mockNotificationService;
    late MockRatingsRepository mockRatingsRepository;
    late Recipe testRecipe;
    late Recipe anotherRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Bridge so RecipeRatingSystem can call ServiceLocator.get<T>()
      production.ServiceLocator.initialize(DIContainer());

      mockFirestoreRepository = FakeFirestoreRepository();
      mockNotificationService = MockNotificationService();
      mockRatingsRepository = MockRatingsRepository();

      testRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe_1',
          title: 'Test Recipe',
          description: 'A test recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          rating: 4.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_789': ResourcePermission.viewer,
          },
        ),
      );

      anotherRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe_2',
          title: 'Another Recipe',
          description: 'Another test recipe',
          ingredients: ['ingredient 2'],
          instructions: ['step 2'],
          mealType: 'Middag',
          createdBy: 'user_456',
          rating: 3.8,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
        socialData: RecipeSocialData(
          ownerId: 'user_456',
          ownerDisplayName: 'Another Owner',
        ),
      );

      stats = RecipeSocialStats(
        getCurrentUserId: () => 'user_789',
        getCurrentUserDisplayName: () => 'Test User',
        getRecipes: () => [testRecipe, anotherRecipe],
        ratingsRepository: mockRatingsRepository,
        firestoreRepository: mockFirestoreRepository,
        notificationService: mockNotificationService,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Utility Methods', () {
      test('should format rating to one decimal', () {
        expect(stats.formatRating(4.567), equals('4.6'));
        expect(stats.formatRating(3.0), equals('3.0'));
        expect(stats.formatRating(5.0), equals('5.0'));
      });

      test('should get star representation', () {
        final stars = stats.getStarRepresentation(4.5);
        expect(stars, contains('⭐'));
      });

      test('should get rating category', () {
        expect(stats.getRatingCategory(4.5), equals('Excellent'));
        expect(stats.getRatingCategory(4.0), equals('Very Good'));
        expect(stats.getRatingCategory(3.5), equals('Good'));
        expect(stats.getRatingCategory(3.0), equals('Average'));
        expect(stats.getRatingCategory(2.0), equals('Below Average'));
        expect(stats.getRatingCategory(1.0), equals('Poor'));
      });
    });

    group('User Context', () {
      test('should return current user ID', () {
        expect(stats.currentUserId, equals('user_789'));
      });

      test('should return current user display name', () {
        expect(stats.currentUserDisplayName, equals('Test User'));
      });

      test('should return recipes list', () {
        expect(stats.recipes, hasLength(2));
      });
    });

    group('Rating Operations', () {
      test('should fail rating when user not logged in', () async {
        final unauthStats = RecipeSocialStats(
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          getRecipes: () => [testRecipe],
          ratingsRepository: mockRatingsRepository,
          firestoreRepository: mockFirestoreRepository,
          notificationService: mockNotificationService,
        );

        final result = await unauthStats.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
        );
        expect(result, isFalse);
      });

      test('should fail remove rating when user not logged in', () async {
        final unauthStats = RecipeSocialStats(
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          getRecipes: () => [testRecipe],
          ratingsRepository: mockRatingsRepository,
          firestoreRepository: mockFirestoreRepository,
          notificationService: mockNotificationService,
        );

        final result = await unauthStats.removeRating('recipe_1');
        expect(result, isFalse);
      });

      test('should return null user rating when not logged in', () async {
        final unauthStats = RecipeSocialStats(
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          getRecipes: () => [testRecipe],
          ratingsRepository: mockRatingsRepository,
          firestoreRepository: mockFirestoreRepository,
          notificationService: mockNotificationService,
        );

        final rating = await unauthStats.getUserRating('recipe_1');
        expect(rating, isNull);
      });
    });

    group('Recipe Stats', () {
      test('should return error for non-existent recipe', () async {
        final result = await stats.getRecipeStats('nonexistent');
        expect(result['error'], equals('Recipe not found'));
      });

      test('should return engagement insights for existing recipe', () {
        final insights = stats.getEngagementInsights('recipe_1');
        expect(insights, isA<Map<String, dynamic>>());
        expect(insights.containsKey('error'), isFalse);
      });

      test('should return error for non-existent recipe insights', () {
        final insights = stats.getEngagementInsights('nonexistent');
        expect(insights['error'], equals('Recipe not found'));
      });
    });

    group('Social Stats', () {
      test('should fail user social stats when not logged in', () async {
        final unauthStats = RecipeSocialStats(
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          getRecipes: () => [],
          ratingsRepository: mockRatingsRepository,
          firestoreRepository: mockFirestoreRepository,
          notificationService: mockNotificationService,
        );

        final result = await unauthStats.getUserSocialStats();
        expect(result['error'], equals('No current user'));
      });
    });

    group('Recipe Comparison', () {
      test('should compare engagement between two recipes', () {
        final result = stats.compareRecipeEngagement('recipe_1', 'recipe_2');
        expect(result, isA<Map<String, dynamic>>());
      });

      test('should return error when recipe not found', () {
        final result = stats.compareRecipeEngagement('recipe_1', 'nonexistent');
        expect(result['error'], isNotNull);
      });
    });
  });
}
