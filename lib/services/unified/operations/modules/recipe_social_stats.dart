// lib/services/unified/operations/modules/recipe_social_stats.dart

import 'package:collection/collection.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart'
    hide RatingStatistics;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

// Focused modules
import 'package:butlery/services/unified/operations/modules/recipe_rating_system.dart';
import 'package:butlery/services/unified/operations/modules/social_engagement_metrics.dart';
import 'package:butlery/services/unified/operations/modules/rating_statistics.dart';
import 'package:butlery/services/unified/operations/modules/rating_notifications.dart';

/// Clean facade for recipe social statistics using focused modules
/// This facade provides a unified API that delegates to focused modules:
/// - RecipeRatingSystem: Individual rating operations and validation
/// - SocialEngagementMetrics: Engagement scoring and social statistics
/// - RatingStatistics: Rating aggregation and top-rated queries
/// - RatingNotifications: Rating notification management
/// ❌ DOES NOT CONTAIN: Complex implementation details, direct Firebase operations
class RecipeSocialStats {
  final UnifiedRecipeService _parent;
  final FirestoreRepository _firestoreRepository;
  final NotificationService? _notificationService;

  // Module instances (only the ones we use as instances)
  late final RecipeRatingSystem _ratingSystem;

  RecipeSocialStats(this._parent, RatingsRepository ratingsRepository,
      this._firestoreRepository, this._notificationService) {
    _ratingSystem = RecipeRatingSystem();
  }
  String? get currentUserId => _parent.currentUserId;
  String get currentUserDisplayName =>
      _parent.currentUserDisplayName ?? 'Okänd användare';
  List<Recipe> get recipes => _parent.recipes;

  Recipe? _getRecipe(String recipeId) {
    return recipes.where((r) => r.id == recipeId).firstOrNull;
  }

  /// Rate a recipe
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
    String? review,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('❌ User must be logged in to rate recipes');
      return false;
    }

    final result = await _ratingSystem.rateRecipe(
      recipeId: recipeId,
      rating: rating,
      currentUserId: userId,
      currentUserDisplayName: currentUserDisplayName,
      review: review,
      canRateValidator: _canRateRecipe,
      recipeGetter: _getRecipe,
    );

    if (result) {
      // Update aggregated rating using RatingStatistics
      await RatingStatistics.updateRecipeRatingAggregate(
        firestore: _firestoreRepository.firestore,
        recipeId: recipeId,
      );

      // Send notification using RatingNotifications
      final recipe = _getRecipe(recipeId);
      if (recipe != null) {
        final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
        if (ownerId != userId) {
          await RatingNotifications.sendRatingNotification(
            notificationService: _notificationService,
            recipe: recipe,
            rating: rating,
            raterName: currentUserDisplayName,
            review: review,
          );
        }
      }

      // Log rating for analytics
      _logRatingAction(
        recipeId: recipeId,
        rating: rating,
        hasReview: review?.isNotEmpty ?? false,
      );
    }

    return result;
  }

  /// Remove the current user's rating for a recipe
  Future<bool> removeRating(String recipeId) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('User must be logged in to remove rating');
      return false;
    }

    final result = await _ratingSystem.deleteRating(
      recipeId: recipeId,
      userId: userId,
    );

    if (result) {
      // Re-aggregate after removal
      await RatingStatistics.updateRecipeRatingAggregate(
        firestore: _firestoreRepository.firestore,
        recipeId: recipeId,
      );
    }

    return result;
  }

  /// Get user's rating for a specific recipe
  Future<Map<String, dynamic>?> getUserRating(String recipeId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final rating = await _ratingSystem.getUserRating(
      recipeId: recipeId,
      userId: userId,
    );

    if (rating == null) return null;

    return {
      'id': rating.id,
      'recipeId': rating.recipeId,
      'userId': rating.userId,
      'rating': rating.rating,
      'review': rating.review,
      'createdAt': rating.createdAt,
      'updatedAt': rating.updatedAt,
    };
  }

  /// Get recipe rating statistics
  Future<Map<String, dynamic>> getRecipeStats(String recipeId) async {
    final recipe = _getRecipe(recipeId);
    if (recipe == null) {
      AppLogger.warning('⚠️ Recipe not found for statistics');
      return {'error': 'Recipe not found'};
    }

    try {
      // Get comprehensive statistics using RatingStatistics
      final stats = await RatingStatistics.getRecipeStatistics(
        firestore: _firestoreRepository.firestore,
        recipeId: recipeId,
        recipe: recipe,
      );

      // Add social engagement metrics using SocialEngagementMetrics
      final socialMetrics =
          SocialEngagementMetrics.calculateRecipeEngagement(recipe);

      // Combine statistics with social metrics
      final result = {
        ...stats,
        'social': socialMetrics,
      };

      AppLogger.debug('📋 Generated comprehensive recipe statistics');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  /// Get top-rated recipes
  Future<List<Map<String, dynamic>>> getTopRatedRecipes({
    int limit = 10,
    double minRating = 4.0,
    int minRatingCount = 3,
  }) async {
    // Get accessible recipes
    final allRecipes = recipes;
    final accessibleRecipes = allRecipes.where((recipe) {
      return _hasAccessToRecipe(recipe);
    }).toList();

    return RatingStatistics.getTopRatedRecipes(
      firestore: _firestoreRepository.firestore,
      accessibleRecipes: accessibleRecipes,
      limit: limit,
      minRating: minRating,
      minRatingCount: minRatingCount,
    );
  }

  /// Get social statistics for user
  Future<Map<String, dynamic>> getUserSocialStats() async {
    final userId = currentUserId;
    if (userId == null) {
      return {'error': 'No current user'};
    }

    // Get user's recipes
    final allRecipes = recipes;
    final userRecipes = allRecipes.where((r) {
      final ownerId = r.socialData?.ownerId ?? r.core.createdBy;
      return ownerId == userId;
    }).toList();

    return SocialEngagementMetrics.calculateUserSocialStats(
      firestore: _firestoreRepository.firestore,
      userId: userId,
      userRecipes: userRecipes,
    );
  }

  /// Get top engaging recipes
  Future<List<Map<String, dynamic>>> getTopEngagingRecipes({
    int limit = 10,
  }) async {
    return SocialEngagementMetrics.getTopEngagingRecipes(
      recipes: recipes,
      limit: limit,
      currentUserId: currentUserId,
    );
  }

  /// Get engagement insights for recipe
  Map<String, dynamic> getEngagementInsights(String recipeId) {
    final recipe = _getRecipe(recipeId);
    if (recipe == null) {
      return {'error': 'Recipe not found'};
    }

    return SocialEngagementMetrics.getEngagementInsights(recipe);
  }

  /// Check if user can rate a recipe
  bool _canRateRecipe(Recipe recipe) {
    return RecipeRatingSystem.canUserRateRecipe(
      recipe: recipe,
      currentUserId: currentUserId,
    );
  }

  /// Check if user has access to view recipe stats
  bool _hasAccessToRecipe(Recipe recipe) {
    return RecipeRatingSystem.canUserViewRatings(
      recipe: recipe,
      currentUserId: currentUserId,
    );
  }

  /// Update multiple rating aggregates
  Future<void> updateMultipleRatingAggregates(List<String> recipeIds) async {
    return RatingStatistics.updateMultipleRatingAggregates(
      firestore: _firestoreRepository.firestore,
      recipeIds: recipeIds,
    );
  }

  /// Get statistics for multiple recipes
  Future<Map<String, Map<String, dynamic>>> getMultipleRecipeStatistics(
    List<String> recipeIds,
  ) async {
    final recipeMap = <String, Recipe>{};

    for (final recipeId in recipeIds) {
      final recipe = _getRecipe(recipeId);
      if (recipe != null) {
        recipeMap[recipeId] = recipe;
      }
    }

    return RatingStatistics.getMultipleRecipeStatistics(
      firestore: _firestoreRepository.firestore,
      recipeMap: recipeMap,
    );
  }

  /// Analyze rating distribution for recipe
  Future<Map<String, dynamic>> analyzeRatingDistribution(
      String recipeId) async {
    try {
      final ratings = await _ratingSystem.getRecipeRatings(
        recipeId: recipeId,
      );

      // Convert RecipeRating objects to Map format
      final ratingsData = ratings
          .map((rating) => {
                'rating': rating.rating,
                'review': rating.review,
                'createdAt': rating.createdAt,
                'userId': rating.userId,
              })
          .toList();

      final stats = RatingStatistics.calculateRatingStatistics(ratingsData);
      final distribution = stats['distribution'] as Map<int, int>;

      return RatingStatistics.analyzeRatingDistribution(distribution);
    } catch (e) {
      AppLogger.error('❌ Failed to analyze rating distribution', e);
      return {'error': 'Failed to analyze distribution'};
    }
  }

  /// Get rating trends for recipe
  Future<Map<String, dynamic>> getRatingTrends(String recipeId) async {
    try {
      final ratings = await _ratingSystem.getRecipeRatings(
        recipeId: recipeId,
      );

      // Convert RecipeRating objects to Map format
      final ratingsData = ratings
          .map((rating) => {
                'rating': rating.rating,
                'review': rating.review,
                'createdAt': rating.createdAt,
                'userId': rating.userId,
              })
          .toList();

      return RatingStatistics.calculateRatingTrends(ratingsData);
    } catch (e) {
      AppLogger.error('❌ Failed to get rating trends', e);
      return {'error': 'Failed to calculate trends'};
    }
  }

  /// Send rating milestone notification
  Future<void> sendRatingMilestone({
    required String recipeId,
    required int totalRatings,
    required double averageRating,
  }) async {
    final recipe = _getRecipe(recipeId);
    if (recipe == null) return;

    await RatingNotifications.sendRatingMilestoneNotification(
      notificationService: _notificationService,
      recipe: recipe,
      totalRatings: totalRatings,
      averageRating: averageRating,
    );
  }

  /// Send first rating notification
  Future<void> sendFirstRatingNotification({
    required String recipeId,
    required double rating,
    String? review,
  }) async {
    final recipe = _getRecipe(recipeId);
    if (recipe == null) return;

    await RatingNotifications.sendFirstRatingNotification(
      notificationService: _notificationService,
      recipe: recipe,
      rating: rating,
      raterName: currentUserDisplayName,
      review: review,
    );
  }

  /// Log rating action for analytics
  void _logRatingAction({
    required String recipeId,
    required double rating,
    required bool hasReview,
  }) {
    try {
      AppLogger.info('📊 Rating action logged: $rating stars');
      // Future analytics implementation would log detailed data:
      // final logData = {
      //   'recipeId': recipeId,
      //   'rating': rating,
      //   'hasReview': hasReview,
      //   'userId': currentUserId,
      //   'timestamp': DateTime.now().toIso8601String(),
      // };
      // Analytics.logEvent('recipe_rated', logData);
    } catch (e) {
      AppLogger.warning('⚠️ Failed to log rating action: $e');
    }
  }

  /// Format rating for display
  String formatRating(double rating) {
    return RecipeRatingSystem.formatRating(rating);
  }

  /// Get star representation
  String getStarRepresentation(double rating) {
    return RecipeRatingSystem.getStarRepresentation(rating);
  }

  /// Get rating category
  String getRatingCategory(double rating) {
    return RecipeRatingSystem.getRatingCategory(rating);
  }

  /// Compare recipe engagement
  Map<String, dynamic> compareRecipeEngagement(
      String recipeId1, String recipeId2) {
    final recipe1 = _getRecipe(recipeId1);
    final recipe2 = _getRecipe(recipeId2);

    if (recipe1 == null || recipe2 == null) {
      return {'error': 'One or both recipes not found'};
    }

    return SocialEngagementMetrics.compareRecipeEngagement(recipe1, recipe2);
  }
}
