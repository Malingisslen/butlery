// lib/services/unified/operations/modules/comment_utilities.dart

import 'dart:async';
// Firebase imports removed - using repository pattern
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:get_it/get_it.dart';

/// Focused module for comment utilities and statistics
/// This module handles ONLY comment system utilities:
/// - Permission checking and validation
/// - Comment statistics and analytics
/// - Stream management and cleanup
/// - Reply count management
/// - Comment content validation
/// ❌ DOES NOT CONTAIN: Comment CRUD, likes, notifications, content operations
class CommentUtilities {
  static final CommentsRepository _commentsRepository =
      GetIt.instance<CommentsRepository>();

  /// Check if user can comment on recipe
  static bool canCommentOnRecipe({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Personal recipes: only owner can comment
    if (recipe.isPersonal) {
      return recipe.createdBy == currentUserId;
    }

    // Collaborative recipes: owner and members can comment
    if (recipe.isCollaborative) {
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) return true;
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ??
          false;
    }

    return false;
  }

  /// Check if current user is recipe owner or admin
  static bool isRecipeOwnerOrAdmin({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Recipe owner
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    // Check if user is admin
    final userPermission = recipe.socialData?.memberPermissions?[currentUserId];
    return userPermission == ResourcePermission.admin;
  }

  /// Check if user can delete specific comment
  static bool canDeleteComment({
    required RecipeComment comment,
    required String? currentUserId,
    required Recipe recipe,
  }) {
    if (currentUserId == null) return false;

    // User can delete their own comments
    if (comment.authorId == currentUserId) return true;

    // Recipe owner or admin can delete any comment
    return isRecipeOwnerOrAdmin(
      recipe: recipe,
      currentUserId: currentUserId,
    );
  }

  /// Check if user can edit specific comment
  static bool canEditComment({
    required RecipeComment comment,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Only comment author can edit
    return comment.authorId == currentUserId;
  }

  /// Increment reply count for parent comment
  static Future<void> incrementReplyCount({
    required String parentCommentId,
  }) async {
    try {
      // Get current comment
      final comment = await _commentsRepository.read(parentCommentId);
      if (comment != null) {
        // Update reply count - this is a simplified approach
        // In a more robust system, reply count would be managed by the repository
        final updatedComment =
            comment.copyWith(replyCount: comment.replyCount + 1);
        await _commentsRepository.update(updatedComment);
        AppLogger.debug(
            '✅ Incremented reply count for comment $parentCommentId');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to increment reply count: $e');
    }
  }

  /// Decrement reply count for parent comment
  static Future<void> decrementReplyCount({
    required String parentCommentId,
  }) async {
    try {
      // Get current comment
      final comment = await _commentsRepository.read(parentCommentId);
      if (comment != null) {
        // Update reply count - this is a simplified approach
        final newCount = comment.replyCount > 0 ? comment.replyCount - 1 : 0;
        final updatedComment = comment.copyWith(replyCount: newCount);
        await _commentsRepository.update(updatedComment);
        AppLogger.debug(
            '✅ Decremented reply count for comment $parentCommentId');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to decrement reply count: $e');
    }
  }

  /// Get reply count for comment
  static Future<int> getReplyCount({
    required String commentId,
  }) async {
    try {
      final comment = await _commentsRepository.read(commentId);
      return comment?.replyCount ?? 0;
    } catch (e) {
      AppLogger.error('❌ Failed to get reply count', e);
      return 0;
    }
  }

  /// Get comprehensive comment statistics for a recipe
  static Future<Map<String, dynamic>> getCommentStatistics({
    required String recipeId,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      final totalComments = comments.length;
      final topLevelComments =
          comments.where((c) => c.parentCommentId == null).length;
      final replies = totalComments - topLevelComments;
      final totalLikes =
          comments.fold<int>(0, (total, comment) => total + comment.likeCount);

      final uniqueCommenters = comments.map((c) => c.authorId).toSet().length;
      final deletedComments = comments.where((c) => c.isDeleted).length;
      final editedComments = comments.where((c) => c.isEdited).length;

      return {
        'total_comments': totalComments,
        'top_level_comments': topLevelComments,
        'replies': replies,
        'total_likes': totalLikes,
        'unique_commenters': uniqueCommenters,
        'deleted_comments': deletedComments,
        'edited_comments': editedComments,
        'average_likes_per_comment':
            totalComments > 0 ? (totalLikes / totalComments).round() : 0,
        'reply_rate': topLevelComments > 0
            ? (replies / topLevelComments).toDouble()
            : 0.0,
        'engagement_rate': totalComments > 0
            ? ((totalLikes + replies) / totalComments).toDouble()
            : 0.0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get comment statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  /// Get comment activity timeline for recipe
  static Future<List<Map<String, dynamic>>> getCommentActivityTimeline({
    required String recipeId,
    int limit = 50,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      // Sort by creation date descending and limit
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final limitedComments = comments.take(limit).toList();

      final activities = <Map<String, dynamic>>[];

      for (final comment in limitedComments) {
        activities.add({
          'type': 'comment_created',
          'timestamp': comment.createdAt,
          'commentId': comment.id,
          'authorId': comment.authorId,
          'authorDisplayName': comment.authorDisplayName,
          'isReply': comment.parentCommentId != null,
          'parentCommentId': comment.parentCommentId,
        });

        // Add edit activity if comment was edited
        if (comment.isEdited && comment.editedAt != null) {
          activities.add({
            'type': 'comment_edited',
            'timestamp': comment.editedAt!,
            'commentId': comment.id,
            'authorId': comment.authorId,
            'authorDisplayName': comment.authorDisplayName,
          });
        }

        // Add delete activity if comment was deleted
        if (comment.isDeleted) {
          activities.add({
            'type': 'comment_deleted',
            'timestamp': comment.createdAt, // Use createdAt as fallback
            'commentId': comment.id,
            'authorId': comment.authorId,
            'authorDisplayName': comment.authorDisplayName,
          });
        }
      }

      // Sort by timestamp descending
      activities.sort((a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      return activities;
    } catch (e) {
      AppLogger.error('❌ Failed to get comment activity timeline', e);
      return [];
    }
  }

  /// Get most active commenters for recipe
  static Future<List<Map<String, dynamic>>> getMostActiveCommenters({
    required String recipeId,
    int limit = 10,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      // Count comments by author
      final authorCounts = <String, Map<String, dynamic>>{};

      for (final comment in comments) {
        if (!authorCounts.containsKey(comment.authorId)) {
          authorCounts[comment.authorId] = {
            'authorId': comment.authorId,
            'authorDisplayName': comment.authorDisplayName,
            'commentCount': 0,
            'likeCount': 0,
            'replyCount': 0,
          };
        }

        authorCounts[comment.authorId]!['commentCount']++;
        authorCounts[comment.authorId]!['likeCount'] += comment.likeCount;

        if (comment.parentCommentId != null) {
          authorCounts[comment.authorId]!['replyCount']++;
        }
      }

      // Sort by comment count and return top commenters
      final sortedCommenters = authorCounts.values.toList()
        ..sort((a, b) =>
            (b['commentCount'] as int).compareTo(a['commentCount'] as int));

      return sortedCommenters.take(limit).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get most active commenters', e);
      return [];
    }
  }

  /// Create managed comment stream controller
  static StreamController<List<RecipeComment>> createCommentStreamController() {
    return StreamController<List<RecipeComment>>.broadcast();
  }

  /// Dispose comment stream controller safely
  static void disposeCommentStream(
      StreamController<List<RecipeComment>>? controller) {
    try {
      controller?.close();
    } catch (e) {
      AppLogger.warning('⚠️ Error disposing comment stream: $e');
    }
  }

  /// Cleanup multiple comment streams
  static void cleanupCommentStreams(
      Map<String, StreamController<List<RecipeComment>>> streams) {
    AppLogger.info('🧹 Cleaning up ${streams.length} comment streams');

    for (final controller in streams.values) {
      disposeCommentStream(controller);
    }
    streams.clear();

    AppLogger.debug('✅ All comment streams disposed');
  }

  /// Validate comment content
  static bool isValidCommentContent(String content) {
    final trimmed = content.trim();
    return trimmed.isNotEmpty && trimmed.length <= 1000;
  }

  /// Sanitize comment content
  static String sanitizeCommentContent(String content) {
    return content
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML tags
  }

  /// Extract mentions from comment content
  static List<String> extractMentions(String content) {
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  /// Check for spam patterns in comment
  static bool isLikelySpam(String content) {
    final trimmed = content.trim().toLowerCase();

    // Check for excessive repetition
    if (RegExp(r'(.)\1{10,}').hasMatch(trimmed)) return true;

    // Check for excessive caps
    final capsCount = trimmed.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (capsCount > trimmed.length * 0.7 && trimmed.length > 10) return true;

    // Check for common spam patterns
    final spamPatterns = [
      'click here',
      'free money',
      'buy now',
      'limited time',
    ];

    return spamPatterns.any((pattern) => trimmed.contains(pattern));
  }

  /// Get comment age in human readable format
  static String getCommentAge(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 30).floor()}mån';
    }
  }

  /// Generate comment permalink
  static String generateCommentPermalink({
    required String recipeId,
    required String commentId,
  }) {
    return '/recipe/$recipeId#comment-$commentId';
  }

  /// Check if comment thread is too deep
  static bool isThreadTooDeep(int depth, {int maxDepth = 3}) {
    return depth > maxDepth;
  }
}
