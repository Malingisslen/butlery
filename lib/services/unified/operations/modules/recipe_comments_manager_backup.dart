// lib/services/unified/operations/modules/recipe_comments_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_unified.dart';
import '../../../../models/recipe_comment.dart';
import '../../../../models/permissions/resource_permission.dart';
import '../../../../core/utils/logger.dart';
import '../../../notifications/notification_service.dart';
import '../../../notifications/notification_types.dart';

/// Focused module for complete recipe comment system management
/// 
/// This module handles ONLY comment system responsibilities:
/// - Comment CRUD operations (create, read, update, delete)
/// - Comment like/unlike functionality
/// - Real-time comment streaming and updates
/// - Comment threading and reply management
/// - Comment-related notifications and alerts
/// - Comment moderation and validation
/// 
/// ❌ DOES NOT CONTAIN: Recipe sharing, member management, discovery, ratings, permissions
class RecipeCommentsManager {
  final dynamic _parent; // UnifiedRecipeService
  final NotificationService? _notificationService;
  final FirebaseFirestore _firestore;

  // Collections
  static const String _commentsCollection = 'recipe_comments';
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<List<RecipeComment>>> _commentStreams = {};

  RecipeCommentsManager(this._parent, this._notificationService, this._firestore);

  // ===== COMMENT CRUD OPERATIONS =====

  /// Add comment to recipe
  /// 
  /// Creates a new comment with automatic notifications to recipe members
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  }) async {
    try {
      AppLogger.info('💬 Adding comment to recipe $recipeId');

      if (content.trim().isEmpty) {
        AppLogger.error('❌ Comment content cannot be empty');
        return null;
      }

      // Validate recipe exists and user has access
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.error('❌ Cannot add comment: Recipe not found');
        return null;
      }

      if (!_canCommentOnRecipe(recipe)) {
        AppLogger.error('❌ User does not have permission to comment on this recipe');
        return null;
      }

      // Create comment object
      final comment = RecipeComment.create(
        recipeId: recipeId,
        authorId: _parent.currentUserId!,
        authorDisplayName: _parent.currentUserDisplayName ?? 'Okänd användare',
        text: content.trim(),
        parentCommentId: parentCommentId,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(_commentsCollection)
          .add(comment.toFirestore());

      final commentId = docRef.id;
      AppLogger.success('✅ Comment added with ID: $commentId');

      // Update reply count if this is a reply
      if (parentCommentId != null) {
        await _incrementReplyCount(parentCommentId);
      }

      // Send notifications
      await _sendCommentNotifications(
        recipe: recipe,
        comment: comment,
        mentions: mentions,
      );

      // Update comment streams
      _notifyCommentStreams(recipeId);

      return commentId;
    } catch (e) {
      AppLogger.error('❌ Failed to add comment', e);
      return null;
    }
  }

  /// Get comments for recipe
  /// 
  /// Returns paginated list of comments with proper threading
  Future<List<RecipeComment>> getComments({
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async {
    try {
      AppLogger.debug('💬 Getting comments for recipe $recipeId');

      Query query = _firestore
          .collection(_commentsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (before != null) {
        query = query.where('createdAt', isLessThan: Timestamp.fromDate(before));
      }

      final snapshot = await query.get();
      final comments = snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();

      // Sort comments to put replies after their parents
      if (includeReplies) {
        comments.sort(_sortCommentsWithReplies);
      }

      AppLogger.debug('📋 Found ${comments.length} comments');
      return comments;
    } catch (e) {
      AppLogger.error('❌ Failed to get comments', e);
      return [];
    }
  }

  /// Stream comments for recipe (real-time)
  /// 
  /// Returns a stream of comments that updates in real-time
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    AppLogger.debug('💬 Creating comment stream for recipe $recipeId');

    // Return existing stream if it exists
    if (_commentStreams.containsKey(recipeId)) {
      return _commentStreams[recipeId]!.stream;
    }

    // Create new stream controller
    final streamController = StreamController<List<RecipeComment>>.broadcast();
    _commentStreams[recipeId] = streamController;

    // Set up Firestore listener
    final subscription = _firestore
        .collection(_commentsCollection)
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          final comments = snapshot.docs
              .map((doc) => RecipeComment.fromFirestore(doc))
              .toList();
          
          // Sort with replies
          comments.sort(_sortCommentsWithReplies);
          
          streamController.add(comments);
        } catch (e) {
          AppLogger.error('❌ Error in comment stream', e);
          streamController.addError(e);
        }
      },
      onError: (error) {
        AppLogger.error('❌ Firestore comment stream error', error);
        streamController.addError(error);
      },
    );

    // Clean up when stream is closed
    streamController.onCancel = () {
      subscription.cancel();
      _commentStreams.remove(recipeId);
    };

    return streamController.stream;
  }

  /// Edit comment
  /// 
  /// Updates comment content with edit timestamp
  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async {
    try {
      AppLogger.info('✏️ Editing comment $commentId');

      if (newContent.trim().isEmpty) {
        AppLogger.error('❌ Comment content cannot be empty');
        return false;
      }

      // Get existing comment
      final commentDoc = await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.error('❌ Comment not found');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check if user can edit this comment
      if (comment.authorId != _parent.currentUserId) {
        AppLogger.error('❌ User can only edit their own comments');
        return false;
      }

      // Update comment
      await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .update({
        'content': newContent.trim(),
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Comment edited successfully');

      // Update comment streams
      _notifyCommentStreams(comment.recipeId);

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to edit comment', e);
      return false;
    }
  }

  /// Delete comment
  /// 
  /// Removes comment and handles replies appropriately
  Future<bool> deleteComment(String commentId) async {
    try {
      AppLogger.info('🗑️ Deleting comment $commentId');

      // Get existing comment
      final commentDoc = await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.error('❌ Comment not found');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check if user can delete this comment
      if (comment.authorId != _parent.currentUserId && !_isRecipeOwnerOrAdmin(comment.recipeId)) {
        AppLogger.error('❌ User can only delete their own comments or if they own the recipe');
        return false;
      }

      // Check if comment has replies
      final repliesQuery = await _firestore
          .collection(_commentsCollection)
          .where('parentCommentId', isEqualTo: commentId)
          .limit(1)
          .get();

      if (repliesQuery.docs.isNotEmpty) {
        // Don't delete comment with replies, just mark as deleted
        await _firestore
            .collection(_commentsCollection)
            .doc(commentId)
            .update({
          'content': '[Kommentar borttagen]',
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
        
        AppLogger.info('📋 Comment marked as deleted (has replies)');
      } else {
        // Delete comment completely
        await _firestore
            .collection(_commentsCollection)
            .doc(commentId)
            .delete();
        
        AppLogger.success('✅ Comment deleted completely');

        // Update reply count if this was a reply
        if (comment.parentCommentId != null) {
          await _decrementReplyCount(comment.parentCommentId!);
        }
      }

      // Update comment streams
      _notifyCommentStreams(comment.recipeId);

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete comment', e);
      return false;
    }
  }

  // ===== COMMENT LIKES =====

  /// Toggle like on comment
  /// 
  /// Adds or removes like from comment with user tracking
  Future<bool> toggleCommentLike(String commentId) async {
    try {
      AppLogger.info('👍 Toggling like on comment $commentId');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('❌ User must be logged in to like comments');
        return false;
      }

      // Get comment document
      final commentRef = _firestore
          .collection(_commentsCollection)
          .doc(commentId);

      final result = await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final comment = RecipeComment.fromFirestore(commentDoc);
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

      // Update comment streams
      final commentDoc = await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();
      
      if (commentDoc.exists) {
        final comment = RecipeComment.fromFirestore(commentDoc);
        _notifyCommentStreams(comment.recipeId);
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to toggle comment like', e);
      return false;
    }
  }

  // ===== REPLY MANAGEMENT =====

  /// Increment reply count for parent comment
  Future<void> _incrementReplyCount(String parentCommentId) async {
    try {
      await _firestore
          .collection(_commentsCollection)
          .doc(parentCommentId)
          .update({
        'replyCount': FieldValue.increment(1),
      });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to increment reply count: $e');
    }
  }

  /// Decrement reply count for parent comment
  Future<void> _decrementReplyCount(String parentCommentId) async {
    try {
      await _firestore
          .collection(_commentsCollection)
          .doc(parentCommentId)
          .update({
        'replyCount': FieldValue.increment(-1),
      });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to decrement reply count: $e');
    }
  }

  // ===== COMMENT NOTIFICATIONS =====

  /// Send notifications for new comments
  Future<void> _sendCommentNotifications({
    required Recipe recipe,
    required RecipeComment comment,
    List<String>? mentions,
  }) async {
    if (_notificationService == null) return;

    try {
      // Collect notification targets (recipe members excluding commenter)
      final targetUserIds = <String>[];
      
      // Add recipe owner
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId != null && ownerId != comment.authorId) {
        targetUserIds.add(ownerId);
      }
      
      // Add recipe members
      final memberIds = recipe.socialData?.memberPermissions?.keys ?? [];
      for (final memberId in memberIds) {
        if (memberId != comment.authorId && !targetUserIds.contains(memberId)) {
          targetUserIds.add(memberId);
        }
      }

      // Add mentioned users
      if (mentions != null) {
        for (final mentionedUserId in mentions) {
          if (mentionedUserId != comment.authorId && !targetUserIds.contains(mentionedUserId)) {
            targetUserIds.add(mentionedUserId);
          }
        }
      }

      if (targetUserIds.isEmpty) {
        AppLogger.debug('📋 No users to notify for comment');
        return;
      }

      // Send comment notification (batchable to prevent spam)
      await _notificationService.sendBatchableNotification(
        targetUserIds: targetUserIds,
        strategy: NotificationStrategy.recipeComment,
        variables: {
          'commenterName': comment.authorDisplayName,
          'recipeName': recipe.title,
          'commentPreview': _truncateComment(comment.text),
        },
        additionalData: {
          'recipeId': recipe.id,
          'commentId': comment.id,
          'action': 'comment_added',
          'commenterId': comment.authorId,
        },
      );

      AppLogger.info('📬 Sent comment notifications to ${targetUserIds.length} users');
    } catch (e) {
      AppLogger.error('❌ Failed to send comment notifications', e);
    }
  }

  // ===== HELPER METHODS =====

  /// Check if user can comment on recipe
  bool _canCommentOnRecipe(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    // Personal recipes: only owner can comment
    if (recipe.isPersonal) {
      return recipe.createdBy == currentUserId;
    }

    // Collaborative recipes: owner and members can comment
    if (recipe.isCollaborative) {
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) return true;
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
    }

    return false;
  }

  /// Check if current user is recipe owner or admin
  bool _isRecipeOwnerOrAdmin(String recipeId) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    final recipe = _parent.recipes
        .where((r) => r.id == recipeId)
        .firstOrNull;
    
    if (recipe == null) return false;

    // Recipe owner
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    // Check if user is admin
    final userPermission = recipe.socialData?.memberPermissions?[currentUserId];
    return userPermission == ResourcePermission.admin;
  }

  /// Sort comments to show replies after their parents
  int _sortCommentsWithReplies(RecipeComment a, RecipeComment b) {
    // If both are top-level comments, sort by date
    if (a.parentCommentId == null && b.parentCommentId == null) {
      return a.createdAt.compareTo(b.createdAt);
    }
    
    // If one is a reply and one is not, prioritize the parent
    if (a.parentCommentId == null && b.parentCommentId != null) {
      return -1;
    }
    if (a.parentCommentId != null && b.parentCommentId == null) {
      return 1;
    }
    
    // If both are replies, sort by date
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Truncate comment for notification preview
  String _truncateComment(String content, {int maxLength = 50}) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Notify all active comment streams for a recipe
  void _notifyCommentStreams(String recipeId) {
    // The Firestore listeners will automatically update the streams
    // This method is kept for potential future use
    AppLogger.debug('🔄 Comment streams will update automatically for recipe $recipeId');
  }

  // ===== COMMENT STATISTICS =====

  /// Get comment statistics for a recipe
  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async {
    try {
      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      final comments = snapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();

      final totalComments = comments.length;
      final topLevelComments = comments.where((c) => c.parentCommentId == null).length;
      final replies = totalComments - topLevelComments;
      final totalLikes = comments.fold<int>(0, (itemCount, comment) => itemCount + comment.likedByUserIds.length);
      
      final uniqueCommenters = comments.map((c) => c.authorId).toSet().length;

      return {
        'total_comments': totalComments,
        'top_level_comments': topLevelComments,
        'replies': replies,
        'total_likes': totalLikes,
        'unique_commenters': uniqueCommenters,
        'average_likes_per_comment': totalComments > 0 ? (totalLikes / totalComments).round() : 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get comment statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  // ===== CLEANUP =====

  /// Dispose of all comment streams
  void dispose() {
    AppLogger.info('💬 Disposing RecipeCommentsManager');
    
    for (final controller in _commentStreams.values) {
      controller.close();
    }
    _commentStreams.clear();
    
    AppLogger.debug('✅ All comment streams disposed');
  }
}