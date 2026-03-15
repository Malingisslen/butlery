import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/recipe_comment.dart';

/// Repository interface for recipe comment operations
abstract class CommentsRepository extends Repository<RecipeComment> {
  /// Get all comments for a recipe (limited to 50)
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId);

  /// Get comments with cursor-based pagination.
  /// Pass [startAfterDocument] from a previous call's result to load the next page.
  Future<PaginatedComments> getCommentsPaginated(
    String recipeId, {
    Object? startAfterDocument,
    int limit = 50,
  });

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

  /// Get replies to a specific comment (limited to 20)
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

/// Paginated result for comments with cursor for next page
class PaginatedComments {
  final List<RecipeComment> comments;
  final Object? lastDocument;
  final bool hasMore;

  PaginatedComments({
    required this.comments,
    this.lastDocument,
    required this.hasMore,
  });
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
