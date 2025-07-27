// lib/services/unified/operations/modules/comment_likes_system.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_comment.dart';
import '../../../../core/utils/logger.dart';

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
  static const String _commentsCollection = 'recipe_comments';

  // ===== LIKE OPERATIONS =====

  /// Toggle like on comment with transaction safety
  static Future<String?> toggleCommentLike({
    required FirebaseFirestore firestore,
    required String commentId,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('👍 Toggling like on comment $commentId for user $currentUserId');

      // Get comment document reference
      final commentRef = firestore
          .collection(_commentsCollection)
          .doc(commentId);

      final result = await firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
        final currentLikes = List<String>.from(comment.likedByUserIds);

        if (currentLikes.contains(currentUserId)) {
          // Remove like
          currentLikes.remove(currentUserId);
          transaction.update(commentRef, {
            'likedByUserIds': currentLikes,
          });
          return 'unliked';
        } else {
          // Add like
          currentLikes.add(currentUserId);
          transaction.update(commentRef, {
            'likedByUserIds': currentLikes,
          });
          return 'liked';
        }
      });

      AppLogger.success('✅ Comment ${result == 'liked' ? 'liked' : 'unliked'}');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to toggle comment like', e);
      return null;
    }
  }

  /// Add like to comment
  static Future<bool> likeComment({
    required FirebaseFirestore firestore,
    required String commentId,
    required String userId,
  }) async {
    try {
      AppLogger.info('👍 Adding like to comment $commentId');

      final commentRef = firestore
          .collection(_commentsCollection)
          .doc(commentId);

      final result = await firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
        final currentLikes = List<String>.from(comment.likedByUserIds);

        if (!currentLikes.contains(userId)) {
          currentLikes.add(userId);
          transaction.update(commentRef, {
            'likedByUserIds': currentLikes,
          });
          return true;
        }
        
        return false; // Already liked
      });

      if (result) {
        AppLogger.success('✅ Like added to comment');
      } else {
        AppLogger.info('📋 Comment already liked by user');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to add like to comment', e);
      return false;
    }
  }

  /// Remove like from comment
  static Future<bool> unlikeComment({
    required FirebaseFirestore firestore,
    required String commentId,
    required String userId,
  }) async {
    try {
      AppLogger.info('👎 Removing like from comment $commentId');

      final commentRef = firestore
          .collection(_commentsCollection)
          .doc(commentId);

      final result = await firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
        final currentLikes = List<String>.from(comment.likedByUserIds);

        if (currentLikes.contains(userId)) {
          currentLikes.remove(userId);
          transaction.update(commentRef, {
            'likedByUserIds': currentLikes,
          });
          return true;
        }
        
        return false; // Not liked
      });

      if (result) {
        AppLogger.success('✅ Like removed from comment');
      } else {
        AppLogger.info('📋 Comment was not liked by user');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to remove like from comment', e);
      return false;
    }
  }

  // ===== LIKE QUERIES =====

  /// Check if user has liked a comment
  static Future<bool> hasUserLikedComment({
    required FirebaseFirestore firestore,
    required String commentId,
    required String userId,
  }) async {
    try {
      final commentDoc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        return false;
      }

      final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
      return comment.likedByUserIds.contains(userId);
    } catch (e) {
      AppLogger.error('❌ Failed to check if user liked comment', e);
      return false;
    }
  }

  /// Get like count for comment
  static Future<int> getCommentLikeCount({
    required FirebaseFirestore firestore,
    required String commentId,
  }) async {
    try {
      final commentDoc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        return 0;
      }

      final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
      return comment.likedByUserIds.length;
    } catch (e) {
      AppLogger.error('❌ Failed to get comment like count', e);
      return 0;
    }
  }

  /// Get list of users who liked a comment
  static Future<List<String>> getCommentLikers({
    required FirebaseFirestore firestore,
    required String commentId,
  }) async {
    try {
      final commentDoc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        return [];
      }

      final comment = RecipeComment.fromMap(commentDoc.id, commentDoc.data()!);
      return List<String>.from(comment.likedByUserIds);
    } catch (e) {
      AppLogger.error('❌ Failed to get comment likers', e);
      return [];
    }
  }

  // ===== BULK LIKE OPERATIONS =====

  /// Get like status for multiple comments for a user
  static Future<Map<String, bool>> getBulkLikeStatus({
    required FirebaseFirestore firestore,
    required List<String> commentIds,
    required String userId,
  }) async {
    try {
      final result = <String, bool>{};

      // Process in batches to avoid Firestore limits
      const batchSize = 10;
      for (int i = 0; i < commentIds.length; i += batchSize) {
        final batch = commentIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((commentId) async {
          final liked = await hasUserLikedComment(
            firestore: firestore,
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
    required FirebaseFirestore firestore,
    required List<String> commentIds,
  }) async {
    try {
      final result = <String, int>{};

      // Process in batches to avoid Firestore limits
      const batchSize = 10;
      for (int i = 0; i < commentIds.length; i += batchSize) {
        final batch = commentIds.skip(i).take(batchSize).toList();
        
        final futures = batch.map((commentId) async {
          final count = await getCommentLikeCount(
            firestore: firestore,
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
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final snapshot = await firestore
          .collection(_commentsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      final comments = snapshot.docs
          .map((doc) => RecipeComment.fromMap(doc.id, doc.data()))
          .toList();

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
    required FirebaseFirestore firestore,
    required String recipeId,
    int limit = 5,
  }) async {
    try {
      final snapshot = await firestore
          .collection(_commentsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      final comments = snapshot.docs
          .map((doc) => RecipeComment.fromMap(doc.id, doc.data()))
          .toList();

      // Sort by like count descending
      comments.sort((a, b) => b.likedByUserIds.length.compareTo(a.likedByUserIds.length));

      return comments.take(limit).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get top liked comments', e);
      return [];
    }
  }
}