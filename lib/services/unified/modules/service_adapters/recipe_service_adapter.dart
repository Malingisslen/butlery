// lib/services/unified/modules/service_adapters/recipe_service_adapter.dart

import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service adapter that provides repository pattern access for UnifiedRecipeService modules
/// 
/// This adapter abstracts Firebase operations through repository interfaces,
/// allowing modules to follow clean architecture principles while maintaining
/// backward compatibility with existing code.
class RecipeServiceAdapter {
  final RecipeRepository _recipeRepository;
  final CommentsRepository _commentsRepository;
  final RatingsRepository _ratingsRepository;
  final NotificationsRepository _notificationsRepository;

  RecipeServiceAdapter({
    RecipeRepository? recipeRepository,
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    NotificationsRepository? notificationsRepository,
  }) : _recipeRepository = recipeRepository ?? sl<RecipeRepository>(),
       _commentsRepository = commentsRepository ?? sl<CommentsRepository>(),
       _ratingsRepository = ratingsRepository ?? sl<RatingsRepository>(),
       _notificationsRepository = notificationsRepository ?? sl<NotificationsRepository>();

  // ===== RECIPE OPERATIONS =====

  /// Create a new recipe using repository pattern
  Future<String?> createRecipe(Recipe recipe) async {
    try {
      final createdRecipe = await _recipeRepository.create(recipe);
      AppLogger.success('✅ Recipe created via repository: ${createdRecipe.id}');
      return createdRecipe.id;
    } catch (e) {
      AppLogger.error('❌ Failed to create recipe via repository', e);
      return null;
    }
  }

  /// Update an existing recipe using repository pattern
  Future<bool> updateRecipe(Recipe recipe) async {
    try {
      await _recipeRepository.update(recipe);
      AppLogger.success('✅ Recipe updated via repository: ${recipe.id}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update recipe via repository', e);
      return false;
    }
  }

  /// Delete a recipe using repository pattern
  Future<bool> deleteRecipe(String recipeId) async {
    try {
      await _recipeRepository.delete(recipeId);
      AppLogger.success('✅ Recipe deleted via repository: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete recipe via repository', e);
      return false;
    }
  }

  /// Get recipe by ID using repository pattern
  Future<Recipe?> getRecipeById(String recipeId) async {
    try {
      // Use base repository method if available, otherwise implement lookup
      // This is a temporary solution until the repository interface is expanded
      AppLogger.warning('⚠️ getById not implemented in RecipeRepository');
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe by ID via repository', e);
      return null;
    }
  }

  /// Get recipes for user using repository pattern
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    try {
      return await _recipeRepository.fetchUserRecipes(userId);
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes for user via repository', e);
      return [];
    }
  }

  /// Search recipes using repository pattern
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      return await _recipeRepository.searchRecipes(query);
    } catch (e) {
      AppLogger.error('❌ Failed to search recipes via repository', e);
      return [];
    }
  }

  // ===== COMMENT OPERATIONS =====

  /// Add comment to recipe using repository pattern
  Future<RecipeComment?> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      return await _commentsRepository.addComment(
        recipeId: recipeId,
        userId: userId,
        content: content,
        parentCommentId: parentCommentId,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to add comment via repository', e);
      return null;
    }
  }

  /// Get comments for recipe using repository pattern
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId) async {
    try {
      return await _commentsRepository.getCommentsForRecipe(recipeId);
    } catch (e) {
      AppLogger.error('❌ Failed to get comments via repository', e);
      return [];
    }
  }

  // ===== RATING OPERATIONS =====

  /// Rate recipe using repository pattern
  Future<bool> rateRecipe({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    try {
      await _ratingsRepository.rateRecipe(
        recipeId: recipeId,
        userId: userId,
        rating: rating,
        review: review,
      );
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to rate recipe via repository', e);
      return false;
    }
  }

  /// Get rating statistics using repository pattern
  Future<RatingStatistics> getRatingStatistics(String recipeId) async {
    try {
      return await _ratingsRepository.getRatingStatistics(recipeId);
    } catch (e) {
      AppLogger.error('❌ Failed to get rating statistics via repository', e);
      return RatingStatistics(
        recipeId: recipeId,
        averageRating: 0.0,
        totalRatings: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }
  }

  // ===== NOTIFICATION OPERATIONS =====

  /// Send notification using repository pattern
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationsRepository.sendNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to send notification via repository', e);
    }
  }

  // ===== BATCH OPERATIONS =====

  /// Get bulk rating statistics using repository pattern
  Future<Map<String, RatingStatistics>> getBulkRatingStatistics(List<String> recipeIds) async {
    try {
      return await _ratingsRepository.getBulkRatingStatistics(recipeIds);
    } catch (e) {
      AppLogger.error('❌ Failed to get bulk rating statistics via repository', e);
      return {};
    }
  }

  // ===== STREAM OPERATIONS =====

  /// Get comments stream using repository pattern
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    return _commentsRepository.getCommentsStream(recipeId);
  }

  /// Get rating statistics stream using repository pattern
  Stream<RatingStatistics> getRatingStatisticsStream(String recipeId) {
    return _ratingsRepository.getRatingStatisticsStream(recipeId);
  }
}