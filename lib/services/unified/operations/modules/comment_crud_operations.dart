// lib/services/unified/operations/modules/comment_crud_operations.dart

import 'dart:async';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Focused module for comment CRUD operations
/// This module handles ONLY comment content management:
/// - Comment creation and validation
/// - Comment reading and streaming
/// - Comment editing and deletion
/// - Comment threading and sorting
/// ❌ DOES NOT CONTAIN: Likes, notifications, reply counts, statistics
class CommentCrudOperations {
  final CommentsRepository _commentsRepository;
  final AnalyticsService _analyticsService;

  CommentCrudOperations({
    CommentsRepository? commentsRepository,
    AnalyticsService? analyticsService,
  })  : _commentsRepository =
            commentsRepository ?? ServiceLocator.get<CommentsRepository>(),
        _analyticsService =
            analyticsService ?? ServiceLocator.get<AnalyticsService>();

  /// Create comment — access control enforced by Firestore security rules
  Future<String?> createComment({
    required String recipeId,
    required String content,
    required String authorId,
    required String authorDisplayName,
    String? parentCommentId,
  }) async {
    AppLogger.info('💬 Creating comment for recipe $recipeId');

    if (content.trim().isEmpty) {
      throw ArgumentError('Comment content cannot be empty');
    }

    // Create comment using repository — Firestore rules enforce access
    final comment = await _commentsRepository.addComment(
      recipeId: recipeId,
      userId: authorId,
      content: content.trim(),
      parentCommentId: parentCommentId,
    );

    AppLogger.success('✅ Comment created with ID: ${comment.id}');

    // Track comment created analytics
    await _analyticsService.logCommentCreated(
      recipeId: recipeId,
      commentLength: content.trim().length,
    );

    // First-comment milestone fires at most once per user (BUT-593).
    final userService = ServiceLocator.tryGet<UserService>();
    await _analyticsService.social.logFirstCommentIfMilestone(
      userId: authorId,
      joinedAt: userService?.currentUserProfile?.joinedAt,
    );

    return comment.id;
  }

  /// Get comments for recipe with pagination
  Future<List<RecipeComment>> getComments({
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async {
    try {
      AppLogger.debug('💬 Getting comments for recipe $recipeId');

      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);

      // Sort comments to put replies after their parents
      if (includeReplies) {
        comments.sort(_sortCommentsWithReplies);
      }

      // Apply limit and before filter manually for now
      var filteredComments = comments;
      if (before != null) {
        filteredComments =
            comments.where((c) => c.createdAt.isBefore(before)).toList();
      }

      if (filteredComments.length > limit) {
        filteredComments = filteredComments.take(limit).toList();
      }

      AppLogger.debug('📋 Found ${filteredComments.length} comments');
      return filteredComments;
    } catch (e) {
      AppLogger.error('❌ Failed to get comments', e);
      return [];
    }
  }

  /// Create comment stream with automatic sorting
  Stream<List<RecipeComment>> createCommentStream({
    required String recipeId,
  }) {
    AppLogger.debug('💬 Creating comment stream for recipe $recipeId');

    return _commentsRepository.getCommentsStream(recipeId).map((comments) {
      try {
        // Sort with replies
        final sortedComments = List<RecipeComment>.from(comments);
        sortedComments.sort(_sortCommentsWithReplies);
        return sortedComments;
      } catch (e) {
        AppLogger.error('❌ Error processing comment stream', e);
        rethrow;
      }
    });
  }

  /// Edit comment content with validation
  Future<bool> editComment({
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

      // Update comment using repository method
      await _commentsRepository.updateComment(commentId, newContent.trim());

      AppLogger.success('✅ Comment edited successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to edit comment', e);
      return false;
    }
  }

  /// Delete comment with reply handling
  Future<bool> deleteComment({
    required String commentId,
    required String currentUserId,
    required bool Function(String) canDeleteValidator,
  }) async {
    try {
      AppLogger.info('🗑️ Deleting comment $commentId');

      // Delete comment using repository method
      await _commentsRepository.deleteComment(commentId);
      AppLogger.success('✅ Comment deleted successfully');

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete comment', e);
      return false;
    }
  }

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
  Future<RecipeComment?> getCommentById({
    required String commentId,
  }) async {
    try {
      return await _commentsRepository.read(commentId);
    } catch (e) {
      AppLogger.error('❌ Failed to get comment by ID', e);
      return null;
    }
  }

  /// Check if comment exists
  Future<bool> commentExists({
    required String commentId,
  }) async {
    try {
      final comment = await _commentsRepository.read(commentId);
      return comment != null;
    } catch (e) {
      AppLogger.error('❌ Failed to check comment existence', e);
      return false;
    }
  }

  /// Get comment count for recipe
  Future<int> getCommentCount({
    required String recipeId,
  }) async {
    try {
      final comments = await _commentsRepository.getCommentsForRecipe(recipeId);
      return comments.length;
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
