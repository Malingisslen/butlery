import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/recipe_comment.dart';

/// Repository interface for recipe comment operations
abstract class CommentsRepository extends Repository<RecipeComment> {
  /// Get all comments for a recipe
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId);

  /// Add a new comment to a recipe
  Future<RecipeComment> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
  });

  /// Update an existing comment
  Future<void> updateComment(String commentId, String newContent);

  /// Delete a comment
  Future<void> deleteComment(String commentId);

  /// Get replies to a specific comment
  Future<List<RecipeComment>> getReplies(String parentCommentId);

  /// Like or unlike a comment
  Future<void> toggleCommentLike(String commentId, String userId);

  /// Get like count for a comment
  Future<int> getCommentLikeCount(String commentId);

  /// Check if user has liked a comment
  Future<bool> hasUserLikedComment(String commentId, String userId);

  /// Get list of user IDs who liked a comment (from likes subcollection)
  Future<List<String>> getCommentLikers(String commentId, {int limit = 100});

  /// Get comments stream for real-time updates
  Stream<List<RecipeComment>> getCommentsStream(String recipeId);

  /// Get comment statistics for a recipe
  Future<CommentStatistics> getCommentStatistics(String recipeId);
}

/// Statistics for recipe comments
class CommentStatistics {
  final int totalComments;
  final int totalReplies;
  final int totalLikes;
  final DateTime? lastCommentAt;

  CommentStatistics({
    required this.totalComments,
    required this.totalReplies,
    required this.totalLikes,
    this.lastCommentAt,
  });
}
