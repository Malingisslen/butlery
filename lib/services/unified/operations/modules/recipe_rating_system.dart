// lib/services/unified/operations/modules/recipe_rating_system.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Focused module for recipe rating system
/// This module handles ONLY recipe rating operations:
/// - Recipe rating creation and validation
/// - User rating queries and management
/// - Rating permission checking
/// - Individual rating data operations
/// ❌ DOES NOT CONTAIN: Statistics aggregation, social metrics, notifications, top-rated queries
class RecipeRatingSystem {
  final RatingsRepository _ratingsRepository;
  final AnalyticsService _analyticsService;

  RecipeRatingSystem({
    RatingsRepository? ratingsRepository,
    AnalyticsService? analyticsService,
  })  : _ratingsRepository =
            ratingsRepository ?? ServiceLocator.get<RatingsRepository>(),
        _analyticsService =
            analyticsService ?? ServiceLocator.get<AnalyticsService>();

  /// Rate a recipe with validation
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
    required String currentUserId,
    required String currentUserDisplayName,
    String? review,
    required bool Function(Recipe) canRateValidator,
    required Recipe? Function(String) recipeGetter,
  }) async {
    try {
      AppLogger.info('⭐ Rating recipe $recipeId with $rating stars');

      if (rating < 1.0 || rating > 5.0 || rating.isNaN || rating.isInfinite) {
        AppLogger.error('❌ Rating must be between 1.0 and 5.0');
        return false;
      }

      // Find the recipe
      final recipe = recipeGetter(recipeId);
      if (recipe == null) {
        AppLogger.error('❌ Cannot rate recipe: Recipe not found');
        return false;
      }

      // Check if user has permission to rate this recipe
      if (!canRateValidator(recipe)) {
        AppLogger.error('❌ User does not have permission to rate this recipe');
        return false;
      }

      // Get previous rating for analytics
      final previousRating =
          await _ratingsRepository.getUserRating(recipeId, currentUserId);

      // Create or update rating using repository
      await _ratingsRepository.rateRecipe(
        recipeId: recipeId,
        userId: currentUserId,
        rating: rating,
        review: review?.trim(),
      );

      AppLogger.success('✅ Recipe rated successfully');

      // Track recipe rated analytics
      await _analyticsService.logRecipeRated(
        recipeId: recipeId,
        rating: rating.round(),
        previousRating: previousRating?.rating.round(),
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to rate recipe', e);
      return false;
    }
  }

  /// Get user's rating for a specific recipe
  Future<RecipeRating?> getUserRating({
    required String recipeId,
    required String userId,
  }) async {
    try {
      return await _ratingsRepository.getUserRating(recipeId, userId);
    } catch (e) {
      AppLogger.error('❌ Failed to get user rating', e);
      return null;
    }
  }

  /// Get ratings for a recipe with pagination support
  /// **Issue #007 Fix:** Adds pagination to prevent timeouts with 10K+ ratings
  /// - [limit] Maximum ratings to return (default: 100)
  /// - [startAfter] Cursor for pagination (from last document)
  Future<List<RecipeRating>> getRecipeRatings({
    required String recipeId,
    int limit = 100,
    dynamic startAfter,
  }) async {
    try {
      AppLogger.debug(
          '📊 Getting ratings for recipe $recipeId (limit: $limit)');
      return await _ratingsRepository.getRecipeRatings(
        recipeId,
        limit: limit,
        startAfter: startAfter,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe ratings', e);
      return [];
    }
  }

  /// Update existing rating
  Future<bool> updateRating({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    try {
      AppLogger.info('✏️ Updating rating for recipe $recipeId');

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('❌ Rating must be between 1.0 and 5.0');
        return false;
      }

      // Check if rating exists
      final existingRating =
          await _ratingsRepository.getUserRating(recipeId, userId);
      if (existingRating == null) {
        AppLogger.error('❌ Cannot update: Rating not found');
        return false;
      }

      // Update rating using repository
      await _ratingsRepository.updateRating(
        recipeId: recipeId,
        userId: userId,
        rating: rating,
        review: review?.trim(),
      );

      AppLogger.success('✅ Rating updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update rating', e);
      return false;
    }
  }

  /// Delete user's rating for a recipe
  Future<bool> deleteRating({
    required String recipeId,
    required String userId,
  }) async {
    try {
      AppLogger.info('🗑️ Deleting rating for recipe $recipeId');

      await _ratingsRepository.removeRating(recipeId, userId);

      AppLogger.success('✅ Rating deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete rating', e);
      return false;
    }
  }

  /// Get rating count for a recipe
  Future<int> getRatingCount({
    required String recipeId,
  }) async {
    try {
      final statistics = await _ratingsRepository.getRatingStatistics(recipeId);
      return statistics.totalRatings;
    } catch (e) {
      AppLogger.error('❌ Failed to get rating count', e);
      return 0;
    }
  }

  /// Check if user has rated a recipe
  Future<bool> hasUserRated({
    required String recipeId,
    required String userId,
  }) async {
    try {
      final rating = await _ratingsRepository.getUserRating(recipeId, userId);
      return rating != null;
    } catch (e) {
      AppLogger.error('❌ Failed to check if user has rated', e);
      return false;
    }
  }

  /// Get ratings given by a specific user
  Future<List<RecipeRating>> getUserGivenRatings({
    required String userId,
    int? limit,
  }) async {
    try {
      AppLogger.debug('📊 Getting ratings given by user ${userId.maskedUserId}');
      final ratings = await _ratingsRepository.getUserRatings(userId);

      if (limit != null && ratings.length > limit) {
        return ratings.take(limit).toList();
      }

      AppLogger.debug('📋 Found ${ratings.length} ratings given by user');
      return ratings;
    } catch (e) {
      AppLogger.error('❌ Failed to get user given ratings', e);
      return [];
    }
  }

  /// Get ratings received for user's recipes
  Future<List<RecipeRating>> getUserReceivedRatings({
    required List<String> userRecipeIds,
    int? limit,
  }) async {
    try {
      AppLogger.debug(
          '📊 Getting ratings received for ${userRecipeIds.length} recipes');

      final allRatings = <RecipeRating>[];

      // Process in batches using repository bulk method
      const batchSize = 10;
      for (int i = 0; i < userRecipeIds.length; i += batchSize) {
        final batch = userRecipeIds.skip(i).take(batchSize).toList();

        for (final recipeId in batch) {
          final ratings = await _ratingsRepository.getRecipeRatings(recipeId);
          allRatings.addAll(ratings);
        }
      }

      // Sort by creation date (most recent first)
      allRatings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit if specified
      final result =
          limit != null ? allRatings.take(limit).toList() : allRatings;

      AppLogger.debug('📋 Found ${result.length} ratings received');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get user received ratings', e);
      return [];
    }
  }

  /// Validate rating value
  static bool isValidRating(double rating) {
    return rating >= 1.0 && rating <= 5.0;
  }

  /// Validate review content
  static bool isValidReview(String? review) {
    if (review == null) return true; // Reviews are optional
    final trimmed = review.trim();
    return trimmed.length <= 1000; // Max 1000 characters
  }

  /// Sanitize review content
  static String? sanitizeReview(String? review) {
    if (review == null) return null;
    final trimmed = review.trim();
    if (trimmed.isEmpty) return null;

    // Basic sanitization - remove excessive whitespace
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if user can rate a specific recipe
  static bool canUserRateRecipe({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Can't rate own recipe
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    if (ownerId == currentUserId) return false;

    // For personal recipes, can't rate unless you're the owner (already excluded above)
    if (recipe.isPersonal) return false;

    // For collaborative recipes, must be a member
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ??
          false;
    }

    return false;
  }

  /// Check if user can view recipe's ratings
  static bool canUserViewRatings({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Always can view own recipes' ratings
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    if (ownerId == currentUserId) return true;

    // For personal recipes, only owner has access
    if (recipe.isPersonal) return false;

    // For collaborative recipes, members have access
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ??
          false;
    }

    return false;
  }

  /// Check if user can edit/delete their rating
  static bool canUserEditRating({
    required String ratingUserId,
    required String? currentUserId,
  }) {
    return currentUserId != null && ratingUserId == currentUserId;
  }

  /// Format rating for display
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  /// Get star representation of rating
  static String getStarRepresentation(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;

    String stars = '⭐' * fullStars;
    if (hasHalfStar && fullStars < 5) {
      stars += '✨'; // Half star representation
    }

    return stars;
  }

  /// Get rating category
  static String getRatingCategory(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    if (rating >= 2.0) return 'Below Average';
    return 'Poor';
  }

  /// Check if rating is recent
  static bool isRecentRating(DateTime? createdAt, {int daysThreshold = 7}) {
    if (createdAt == null) return false;

    final now = DateTime.now();
    final daysDifference = now.difference(createdAt).inDays;

    return daysDifference <= daysThreshold;
  }

  /// Get rating statistics for a recipe
  Future<RatingStatistics> getRatingStatistics({
    required String recipeId,
  }) async {
    try {
      return await _ratingsRepository.getRatingStatistics(recipeId);
    } catch (e) {
      AppLogger.error('❌ Failed to get rating statistics', e);
      return RatingStatistics(
        recipeId: recipeId,
        averageRating: 0.0,
        totalRatings: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }
  }
}
