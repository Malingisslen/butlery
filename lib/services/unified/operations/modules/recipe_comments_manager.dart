// lib/services/unified/operations/modules/recipe_comments_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_unified.dart';
import '../../../../models/recipe_comment.dart';
import '../../../../core/utils/logger.dart';
import '../../../notifications/notification_service.dart';

// Focused modules
import 'comment_crud_operations.dart';
import 'comment_likes_system.dart';
import 'comment_notifications.dart';
import 'comment_utilities.dart';

/// Clean facade for recipe comment system using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - CommentCrudOperations: Comment CRUD operations and streaming
/// - CommentLikesSystem: Like/unlike functionality
/// - CommentNotifications: Comment-related notifications
/// - CommentUtilities: Statistics, permissions, utilities
///
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class RecipeCommentsManager {
  final dynamic _parent; // UnifiedRecipeService
  final NotificationService? _notificationService;
  final FirebaseFirestore _firestore;
  
  // Stream controllers for managed streams
  final Map<String, StreamController<List<RecipeComment>>> _commentStreams = {};

  RecipeCommentsManager(this._parent, this._notificationService, this._firestore);

  // ===== GETTERS FOR VALIDATION =====

  String? get currentUserId => _parent.currentUserId;
  String get currentUserDisplayName => _parent.currentUserDisplayName ?? 'Okänd användare';
  List<Recipe> get recipes => _parent.recipes;

  Recipe? _getRecipe(String recipeId) {
    return recipes.where((r) => r.id == recipeId).firstOrNull;
  }

  // ===== COMMENT CRUD OPERATIONS (DELEGATE TO COMMENT_CRUD_OPERATIONS) =====

  /// Add comment to recipe
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  }) async {
    final commentId = await CommentCrudOperations.createComment(
      firestore: _firestore,
      recipeId: recipeId,
      content: content,
      authorId: currentUserId!,
      authorDisplayName: currentUserDisplayName,
      parentCommentId: parentCommentId,
      canCommentValidator: (recipe) => CommentUtilities.canCommentOnRecipe(
        recipe: recipe,
        currentUserId: currentUserId,
      ),
      recipeGetter: _getRecipe,
    );

    if (commentId != null) {
      // Update reply count if this is a reply
      if (parentCommentId != null) {
        await CommentUtilities.incrementReplyCount(
          firestore: _firestore,
          parentCommentId: parentCommentId,
        );
      }

      // Send notifications
      final recipe = _getRecipe(recipeId);
      if (recipe != null) {
        final comment = await CommentCrudOperations.getCommentById(
          firestore: _firestore,
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
    return CommentCrudOperations.getComments(
      firestore: _firestore,
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
    final streamController = CommentUtilities.createCommentStreamController();
    _commentStreams[recipeId] = streamController;

    // Set up stream from CommentCrudOperations
    final commentStream = CommentCrudOperations.createCommentStream(
      firestore: _firestore,
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
    final result = await CommentCrudOperations.editComment(
      firestore: _firestore,
      commentId: commentId,
      newContent: newContent,
      currentUserId: currentUserId!,
    );

    if (result) {
      // Get comment to find recipe ID for stream update
      final comment = await CommentCrudOperations.getCommentById(
        firestore: _firestore,
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
    // Get comment before deletion
    final comment = await CommentCrudOperations.getCommentById(
      firestore: _firestore,
      commentId: commentId,
    );

    if (comment == null) return false;

    final result = await CommentCrudOperations.deleteComment(
      firestore: _firestore,
      commentId: commentId,
      currentUserId: currentUserId!,
      canDeleteValidator: (recipeId) {
        final recipe = _getRecipe(recipeId);
        if (recipe == null) return false;
        return CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: recipe,
          currentUserId: currentUserId,
        );
      },
    );

    if (result) {
      // Update reply count if this was a reply
      if (comment.parentCommentId != null) {
        await CommentUtilities.decrementReplyCount(
          firestore: _firestore,
          parentCommentId: comment.parentCommentId!,
        );
      }

      // Update comment streams
      _notifyCommentStreams(comment.recipeId);
    }

    return result;
  }

  // ===== COMMENT LIKES (DELEGATE TO COMMENT_LIKES_SYSTEM) =====

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    if (currentUserId == null) {
      AppLogger.error('❌ User must be logged in to like comments');
      return false;
    }

    final result = await CommentLikesSystem.toggleCommentLike(
      firestore: _firestore,
      commentId: commentId,
      currentUserId: currentUserId!,
    );

    if (result != null) {
      // Get comment to find recipe ID for stream update
      final comment = await CommentCrudOperations.getCommentById(
        firestore: _firestore,
        commentId: commentId,
      );
      
      if (comment != null) {
        _notifyCommentStreams(comment.recipeId);
      }

      return true;
    }

    return false;
  }

  // ===== COMMENT STATISTICS (DELEGATE TO COMMENT_UTILITIES) =====

  /// Get comment statistics for a recipe
  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async {
    return CommentUtilities.getCommentStatistics(
      firestore: _firestore,
      recipeId: recipeId,
    );
  }

  /// Get comment activity timeline for recipe
  Future<List<Map<String, dynamic>>> getCommentActivityTimeline({
    required String recipeId,
    int limit = 50,
  }) async {
    return CommentUtilities.getCommentActivityTimeline(
      firestore: _firestore,
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
      firestore: _firestore,
      recipeId: recipeId,
      limit: limit,
    );
  }


  // ===== STREAM MANAGEMENT =====

  /// Notify all active comment streams for a recipe
  void _notifyCommentStreams(String recipeId) {
    // The Firestore listeners will automatically update the streams
    // This method is kept for potential future use
    AppLogger.debug('🔄 Comment streams will update automatically for recipe $recipeId');
  }

  // ===== CLEANUP =====

  /// Dispose of all comment streams
  void dispose() {
    AppLogger.info('💬 Disposing RecipeCommentsManager');
    
    CommentUtilities.cleanupCommentStreams(_commentStreams);
    
    AppLogger.debug('✅ All comment streams disposed');
  }
}