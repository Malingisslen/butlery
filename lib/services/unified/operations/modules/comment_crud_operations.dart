// lib/services/unified/operations/modules/comment_crud_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_unified.dart';
import '../../../../models/recipe_comment.dart';
import '../../../../core/utils/logger.dart';

/// Focused module for comment CRUD operations
/// 
/// This module handles ONLY comment content management:
/// - Comment creation and validation
/// - Comment reading and streaming
/// - Comment editing and deletion
/// - Comment threading and sorting
/// 
/// ❌ DOES NOT CONTAIN: Likes, notifications, reply counts, statistics
class CommentCrudOperations {
  static const String _commentsCollection = 'recipe_comments';

  // ===== COMMENT CREATION =====

  /// Create comment with validation
  static Future<String?> createComment({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String content,
    required String authorId,
    required String authorDisplayName,
    String? parentCommentId,
    required bool Function(Recipe) canCommentValidator,
    required Recipe? Function(String) recipeGetter,
  }) async {
    try {
      AppLogger.info('💬 Creating comment for recipe $recipeId');

      if (content.trim().isEmpty) {
        AppLogger.error('❌ Comment content cannot be empty');
        return null;
      }

      // Validate recipe exists and user has access
      final recipe = recipeGetter(recipeId);
      if (recipe == null) {
        AppLogger.error('❌ Cannot add comment: Recipe not found');
        return null;
      }

      if (!canCommentValidator(recipe)) {
        AppLogger.error('❌ User does not have permission to comment on this recipe');
        return null;
      }

      // Create comment object
      final comment = RecipeComment.create(
        recipeId: recipeId,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        text: content.trim(),
        parentCommentId: parentCommentId,
      );

      // Save to Firestore
      final docRef = await firestore
          .collection(_commentsCollection)
          .add(comment.toFirestore());

      final commentId = docRef.id;
      AppLogger.success('✅ Comment created with ID: $commentId');

      return commentId;
    } catch (e) {
      AppLogger.error('❌ Failed to create comment', e);
      return null;
    }
  }

  // ===== COMMENT READING =====

  /// Get comments for recipe with pagination
  static Future<List<RecipeComment>> getComments({
    required FirebaseFirestore firestore,
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async {
    try {
      AppLogger.debug('💬 Getting comments for recipe $recipeId');

      Query query = firestore
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

  /// Create comment stream with automatic sorting
  static Stream<List<RecipeComment>> createCommentStream({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) {
    AppLogger.debug('💬 Creating comment stream for recipe $recipeId');

    return firestore
        .collection(_commentsCollection)
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      try {
        final comments = snapshot.docs
            .map((doc) => RecipeComment.fromFirestore(doc))
            .toList();
        
        // Sort with replies
        comments.sort(_sortCommentsWithReplies);
        
        return comments;
      } catch (e) {
        AppLogger.error('❌ Error processing comment stream', e);
        rethrow;
      }
    });
  }

  // ===== COMMENT EDITING =====

  /// Edit comment content with validation
  static Future<bool> editComment({
    required FirebaseFirestore firestore,
    required String commentId,
    required String newContent,
    required String currentUserId,
  }) async {
    try {
      AppLogger.info('✏️ Editing comment $commentId');

      if (newContent.trim().isEmpty) {
        AppLogger.error('❌ Comment content cannot be empty');
        return false;
      }

      // Get existing comment
      final commentDoc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.error('❌ Comment not found');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check if user can edit this comment
      if (comment.authorId != currentUserId) {
        AppLogger.error('❌ User can only edit their own comments');
        return false;
      }

      // Update comment
      await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .update({
        'content': newContent.trim(),
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Comment edited successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to edit comment', e);
      return false;
    }
  }

  // ===== COMMENT DELETION =====

  /// Delete comment with reply handling
  static Future<bool> deleteComment({
    required FirebaseFirestore firestore,
    required String commentId,
    required String currentUserId,
    required bool Function(String) canDeleteValidator,
  }) async {
    try {
      AppLogger.info('🗑️ Deleting comment $commentId');

      // Get existing comment
      final commentDoc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.error('❌ Comment not found');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check if user can delete this comment
      if (comment.authorId != currentUserId && !canDeleteValidator(comment.recipeId)) {
        AppLogger.error('❌ User can only delete their own comments or if they own the recipe');
        return false;
      }

      // Check if comment has replies
      final repliesQuery = await firestore
          .collection(_commentsCollection)
          .where('parentCommentId', isEqualTo: commentId)
          .limit(1)
          .get();

      if (repliesQuery.docs.isNotEmpty) {
        // Don't delete comment with replies, just mark as deleted
        await firestore
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
        await firestore
            .collection(_commentsCollection)
            .doc(commentId)
            .delete();
        
        AppLogger.success('✅ Comment deleted completely');
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete comment', e);
      return false;
    }
  }

  // ===== COMMENT UTILITIES =====

  /// Sort comments to show replies after their parents
  static int _sortCommentsWithReplies(RecipeComment a, RecipeComment b) {
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

  /// Get comment by ID
  static Future<RecipeComment?> getCommentById({
    required FirebaseFirestore firestore,
    required String commentId,
  }) async {
    try {
      final doc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();
      
      if (!doc.exists) return null;
      
      return RecipeComment.fromFirestore(doc);
    } catch (e) {
      AppLogger.error('❌ Failed to get comment by ID', e);
      return null;
    }
  }

  /// Check if comment exists
  static Future<bool> commentExists({
    required FirebaseFirestore firestore,
    required String commentId,
  }) async {
    try {
      final doc = await firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();
      
      return doc.exists;
    } catch (e) {
      AppLogger.error('❌ Failed to check comment existence', e);
      return false;
    }
  }

  /// Get comment count for recipe
  static Future<int> getCommentCount({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final snapshot = await firestore
          .collection(_commentsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      AppLogger.error('❌ Failed to get comment count', e);
      return 0;
    }
  }

  /// Validate comment content
  static bool isValidCommentContent(String content) {
    return content.trim().isNotEmpty && content.trim().length <= 1000;
  }
}