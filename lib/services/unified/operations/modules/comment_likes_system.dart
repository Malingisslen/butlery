// lib/services/unified/operations/modules/comment_likes_system.dart

import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:get_it/get_it.dart';

/// Focused module for comment likes system
/// 
/// This module handles ONLY comment like functionality:
/// - Like/unlike operations with user tracking
/// - Like count management
/// - Transaction-based like toggling
/// - Like state queries
/// 
/// ❌ DOES NOT CONTAIN: Comment content, notifications, statistics, replies
class CommentLikesSystem {
  static final CommentsRepository _commentsRepository = GetIt.instance<CommentsRepository>();

  // ===== LIKE OPERATIONS =====

  /// Toggle like on comment with transaction safety
  static Future<String?> toggleCommentLike({
    required String commentId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('👍 Toggling like on comment $commentId for user $currentUserId');

      // Check current like status
      final wasLiked = await _commentsRepository.hasUserLikedComment(commentId, currentUserId);
      
      // Toggle the like
      await _commentsRepository.toggleCommentLike(commentId, currentUserId);
      
      final result = wasLiked ? 'unliked' : 'liked';
      AppLogger.success('✅ Comment $result');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to toggle comment like', e);
      return null;
    }
  }

  /// Add like to comment
  static Future<bool> likeComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      AppLogger.info('👍 Adding like to comment $commentId');

      // Check if already liked
      final alreadyLiked = await _commentsRepository.hasUserLikedComment(commentId, userId);
      
      if (!alreadyLiked) {
        await _commentsRepository.toggleCommentLike(commentId, userId);
        AppLogger.success('✅ Like added to comment');
        return true;
      }
      
      AppLogger.info('📋 Comment already liked by user');
      return false; // Already liked
    } catch (e) {
      AppLogger.error('❌ Failed to add like to comment', e);
      return false;
    }
  }

  /// Remove like from comment
  static Future<bool> unlikeComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      AppLogger.info('👎 Removing like from comment $commentId');

      // Check if currently liked
      final currentlyLiked = await _commentsRepository.hasUserLikedComment(commentId, userId);
      
      if (currentlyLiked) {
        await _commentsRepository.toggleCommentLike(commentId, userId);
        AppLogger.success('✅ Like removed from comment');
        return true;
      }
      
      AppLogger.info('📋 Comment was not liked by user');
      return false; // Not liked
    } catch (e) {
      AppLogger.error('❌ Failed to remove like from comment', e);
      return false;
    }
  }

  // ===== LIKE QUERIES =====

  /// Check if user has liked a comment
  static Future<bool> hasUserLikedComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      return await _commentsRepository.hasUserLikedComment(commentId, userId);
    } catch (e) {
      AppLogger.error('❌ Failed to check if user liked comment', e);
      return false;
    }
  }

  /// Get like count for comment
  static Future<int> getCommentLikeCount({
    required String commentId,
  }) async {
    try {
      return await _commentsRepository.getCommentLikeCount(commentId);
    } catch (e) {
      AppLogger.error('❌ Failed to get comment like count', e);
      return 0;
    }
  }

  /// Get list of users who liked a comment
  static Future<List<String>> getCommentLikers({
    required String commentId,
  }) async {
    try {
      final comment = await _commentsRepository.read(commentId);
      if (comment == null) {
        return [];
      }
      return List<String>.from(comment.likedByUserIds);
    } catch (e) {
      AppLogger.error('❌ Failed to get comment likers', e);
      return [];
    }
  }

  // ===== BULK LIKE OPERATIONS =====

  /// Get like status for multiple comments for a user
  static Future<Map<String, bool>> getBulkLikeStatus({
    required List<String> commentIds,
    required String userId,
  }) async {
    try {
      final result = <String, bool>{};

      // Process in batches to avoid overloading the repository
      const batchSize = 10;
      for (int i = 0; i < commentIds.length; i += batchSize) {
        final batch = commentIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((commentId) async {
          final liked = await hasUserLikedComment(
            commentId: commentId,
            userId: userId,
          );
          return MapEntry(commentId, liked);
        });

        final batchResults = await Future.wait(futures);
        for (final entry in batchResults) {
          result[entry.key] = entry.value;
        }
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get bulk like status', e);
      return {};
    }
  }

  /// Get like counts for multiple comments
  static Future<Map<String, int>> getBulkLikeCounts({
    required List<String> commentIds,
  }) async {
    try {
      final result = <String, int>{};

      // Process in batches to avoid overloading the repository
      const batchSize = 10;
      for (int i = 0; i < commentIds.length; i += batchSize) {
        final batch = commentIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((commentId) async {
          final count = await getCommentLikeCount(
            commentId: commentId,
          );
          return MapEntry(commentId, count);
        });

        final batchResults = await Future.wait(futures);
        for (final entry in batchResults) {
          result[entry.key] = entry.value;
        }
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get bulk like counts', e);
      return {};
    }
  }

  // ===== LIKE ANALYTICS =====

  /// Get like statistics for a recipe's comments
  static Future<Map<String, dynamic>> getRecipeLikeStatistics({
    required String recipeId,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      final totalLikes = comments.fold<int>(
        0, 
        (total, comment) => total + comment.likedByUserIds.length,
      );

      final commentsWithLikes = comments.where((c) => c.likedByUserIds.isNotEmpty).length;
      final mostLikedComment = comments.isEmpty ? null : 
          comments.reduce((a, b) => a.likedByUserIds.length > b.likedByUserIds.length ? a : b);

      return {
        'totalLikes': totalLikes,
        'totalComments': comments.length,
        'commentsWithLikes': commentsWithLikes,
        'averageLikesPerComment': comments.isEmpty ? 0.0 : totalLikes / comments.length,
        'likeEngagementRate': comments.isEmpty ? 0.0 : commentsWithLikes / comments.length,
        'mostLikedCommentId': mostLikedComment?.id,
        'mostLikedCommentLikes': mostLikedComment?.likedByUserIds.length ?? 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe like statistics', e);
      return {'error': 'Failed to calculate like statistics'};
    }
  }

  /// Get top liked comments for a recipe
  static Future<List<RecipeComment>> getTopLikedComments({
    required String recipeId,
    int limit = 5,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      // Sort by like count descending
      comments.sort((a, b) => b.likedByUserIds.length.compareTo(a.likedByUserIds.length));

      return comments.take(limit).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get top liked comments', e);
      return [];
    }
  }
}