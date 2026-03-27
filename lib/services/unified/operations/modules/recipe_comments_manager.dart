// lib/services/unified/operations/modules/recipe_comments_manager.dart

import 'dart:async';
// Firebase imports removed - using repository pattern
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';

// Focused modules
import 'package:butlery/services/unified/operations/modules/comment_crud_operations.dart';
import 'package:butlery/services/unified/operations/modules/comment_likes_system.dart';
import 'package:butlery/services/unified/operations/modules/comment_notifications.dart';
import 'package:butlery/services/unified/operations/modules/comment_utilities.dart';

/// Clean facade for recipe comment system using focused modules
/// This facade provides a unified API that delegates to focused modules:
/// - CommentCrudOperations: Comment CRUD operations and streaming
/// - CommentLikesSystem: Like/unlike functionality
/// - CommentNotifications: Comment-related notifications
/// - CommentUtilities: Statistics, permissions, utilities
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class RecipeCommentsManager {
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final List<Recipe> Function() _getRecipes;
  final NotificationService? _notificationService;

  // Stream controllers for managed streams
  final Map<String, StreamController<List<RecipeComment>>> _commentStreams = {};

  // Module instances (only the ones we use as instances)
  late final CommentCrudOperations _crudOperations;

  RecipeCommentsManager({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<Recipe> Function() getRecipes,
    required NotificationService? notificationService,
  })  : _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _getRecipes = getRecipes,
        _notificationService = notificationService {
    _crudOperations = CommentCrudOperations();
  }
  String? get currentUserId => _getCurrentUserId();
  String get currentUserDisplayName => _getCurrentUserDisplayName() ?? '?';
  List<Recipe> get recipes => _getRecipes();

  Recipe? _getRecipe(String recipeId) {
    return recipes.where((r) => r.id == recipeId).firstOrNull;
  }

  /// Add comment to recipe
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('❌ User must be logged in to add comments');
      return null;
    }

    final commentId = await _crudOperations.createComment(
      recipeId: recipeId,
      content: content,
      authorId: userId,
      authorDisplayName: currentUserDisplayName,
      parentCommentId: parentCommentId,
    );

    if (commentId != null) {
      // Update reply count if this is a reply
      if (parentCommentId != null) {
        await CommentUtilities.incrementReplyCount(
          parentCommentId: parentCommentId,
        );
      }

      // Send notifications
      final recipe = _getRecipe(recipeId);
      if (recipe != null) {
        final comment = await _crudOperations.getCommentById(
          commentId: commentId,
        );

        if (comment != null) {
          await CommentNotifications.sendCommentNotifications(
            notificationService: _notificationService,
            recipe: recipe,
            comment: comment,
            mentions: mentions,
          );
        }
      }

      // Update comment streams
      _notifyCommentStreams(recipeId);
    }

    return commentId;
  }

  /// Get comments for recipe
  Future<List<RecipeComment>> getComments({
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async {
    return _crudOperations.getComments(
      recipeId: recipeId,
      limit: limit,
      before: before,
      includeReplies: includeReplies,
    );
  }

  /// Stream comments for recipe (real-time)
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    AppLogger.debug('💬 Creating comment stream for recipe $recipeId');

    // Return existing stream if it exists
    if (_commentStreams.containsKey(recipeId)) {
      return _commentStreams[recipeId]!.stream;
    }

    // Create new stream controller
    // ignore: close_sinks - disposed in dispose() via CommentUtilities.cleanupCommentStreams
    final streamController = CommentUtilities.createCommentStreamController();
    _commentStreams[recipeId] = streamController;

    // Set up stream from CommentCrudOperations
    final commentStream = _crudOperations.createCommentStream(
      recipeId: recipeId,
    );

    // Forward stream data
    final subscription = commentStream.listen(
      (comments) => streamController.add(comments),
      onError: (error) {
        AppLogger.error('❌ Comment stream error', error);
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
  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('❌ User must be logged in to edit comments');
      return false;
    }

    final result = await _crudOperations.editComment(
      commentId: commentId,
      newContent: newContent,
      currentUserId: userId,
    );

    if (result) {
      // Get comment to find recipe ID for stream update
      final comment = await _crudOperations.getCommentById(
        commentId: commentId,
      );

      if (comment != null) {
        _notifyCommentStreams(comment.recipeId);
      }
    }

    return result;
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('❌ User must be logged in to delete comments');
      return false;
    }

    // Get comment before deletion
    final comment = await _crudOperations.getCommentById(
      commentId: commentId,
    );

    if (comment == null) return false;

    final result = await _crudOperations.deleteComment(
      commentId: commentId,
      currentUserId: userId,
      canDeleteValidator: (recipeId) {
        final recipe = _getRecipe(recipeId);
        if (recipe == null) return false;
        return CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: recipe,
          currentUserId: userId,
        );
      },
    );

    if (result) {
      // Update reply count if this was a reply
      if (comment.parentCommentId != null) {
        await CommentUtilities.decrementReplyCount(
          parentCommentId: comment.parentCommentId!,
        );
      }

      // Update comment streams
      _notifyCommentStreams(comment.recipeId);
    }

    return result;
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    if (currentUserId == null) {
      AppLogger.error('❌ User must be logged in to like comments');
      return false;
    }

    final result = await CommentLikesSystem.toggleCommentLike(
      commentId: commentId,
      currentUserId: currentUserId!,
    );

    if (result != null) {
      // Get comment to find recipe ID for stream update
      final comment = await _crudOperations.getCommentById(
        commentId: commentId,
      );

      if (comment != null) {
        _notifyCommentStreams(comment.recipeId);
      }

      return true;
    }

    return false;
  }

  /// Get comment statistics for a recipe
  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async {
    return CommentUtilities.getCommentStatistics(
      recipeId: recipeId,
    );
  }

  /// Get comment activity timeline for recipe
  Future<List<Map<String, dynamic>>> getCommentActivityTimeline({
    required String recipeId,
    int limit = 50,
  }) async {
    return CommentUtilities.getCommentActivityTimeline(
      recipeId: recipeId,
      limit: limit,
    );
  }

  /// Get most active commenters for recipe
  Future<List<Map<String, dynamic>>> getMostActiveCommenters({
    required String recipeId,
    int limit = 10,
  }) async {
    return CommentUtilities.getMostActiveCommenters(
      recipeId: recipeId,
      limit: limit,
    );
  }

  /// Notify all active comment streams for a recipe
  void _notifyCommentStreams(String recipeId) {
    // The Firestore listeners will automatically update the streams
    // This method is kept for potential future use
    AppLogger.debug(
        '🔄 Comment streams will update automatically for recipe $recipeId');
  }

  /// Dispose of all comment streams
  void dispose() {
    AppLogger.info('💬 Disposing RecipeCommentsManager');

    CommentUtilities.cleanupCommentStreams(_commentStreams);

    AppLogger.debug('✅ All comment streams disposed');
  }
}
