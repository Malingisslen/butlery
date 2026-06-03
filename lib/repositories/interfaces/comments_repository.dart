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

  /// Add a new comment to a recipe.
  ///
  /// BUT-1049: [imageUrls] carries already-uploaded comment-image download
  /// URLs (the composer uploads to Storage before this write). Defaults to
  /// empty so the historical text-only path is unchanged.
  Future<RecipeComment> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
    List<String> imageUrls = const [],
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

  /// Export all comments authored by [userId] for GDPR Article 20.
  ///
  /// Returns raw `{id, data}` shapes (NOT typed [RecipeComment]) so the
  /// data-export pipeline can sanitize timestamps without round-tripping
  /// through the model. Implementations MUST validate that the caller
  /// owns [userId] (cannot export someone else's comments).
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = 1000,
  });
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

/// Resolves the denormalized ownership snapshot for a recipe so the comment
/// doc can carry `recipeOwnerId` + `sharedWithUserIds` and security rules
/// can enforce read access without an N+1 lookup. Callers without access to
/// the recipe ownership graph may pass null — the comment then writes
/// without these fields and reads fall back to author-only.
typedef RecipeOwnershipResolver = Future<RecipeOwnershipSnapshot?> Function(
    String recipeId);

/// Plain snapshot of the recipe-ownership fields needed to denormalize onto
/// a comment doc at write time.
class RecipeOwnershipSnapshot {
  final String recipeOwnerId;
  final List<String> sharedWithUserIds;
  const RecipeOwnershipSnapshot({
    required this.recipeOwnerId,
    this.sharedWithUserIds = const [],
  });
}
