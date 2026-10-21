// lib/repositories/firebase/firebase_comments_repository.dart

import 'package:butlery/services/attribution_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/repositories/firebase/comments/comment_creation.dart';
import 'package:butlery/repositories/firebase/comments/comment_likes_operations.dart';
import 'package:butlery/repositories/firebase/comments/comment_visibility_queries.dart';

export 'package:butlery/repositories/firebase/comments/comment_creation.dart'
    show RecipeAccessValidator;

/// Firebase implementation for recipe comments with threaded replies and like tracking.
/// Supports recipe access validation via optional [RecipeAccessValidator] constructor parameter.
class FirebaseCommentsRepository extends BaseFirebaseRepository<RecipeComment>
    with CommentLikesOperations, CommentVisibilityQueries, CommentCreation
    implements CommentsRepository {
  @override
  final RecipeAccessValidator? recipeAccessValidator;
  @override
  final RecipeOwnershipResolver? recipeOwnershipResolver;
  @override
  final AttributionSource attribution;

  FirebaseCommentsRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
    this.recipeAccessValidator,
    this.recipeOwnershipResolver,
    AttributionSource? attribution,
  }) : attribution = attribution ?? AttributionSource();

  @override
  String get collectionName => FirestoreCollections.recipeComments;

  @override
  RecipeComment fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      RecipeComment.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(RecipeComment entity) =>
      entity.toFirestore();

  @override
  String getId(RecipeComment entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
    String userId,
    RecipeComment entity,
  ) async {
    // Users can only create comments as themselves
    return entity.authorId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    RecipeComment? entity,
  ) async {
    // All authenticated users can read comments on recipes they have access to
    // The recipe-level access control is enforced separately
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    RecipeComment entity,
  ) async {
    // Users can only edit their own comments
    return entity.authorId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Users can only delete their own comments
    try {
      final comment = await read(resourceId);
      if (comment == null) return false;
      return comment.authorId == userId;
    } on PermissionDeniedException {
      return false;
    }
  }

  @override
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId) =>
      fetchVisibleComments(recipeId);

  @override
  Future<PaginatedComments> getCommentsPaginated(
    String recipeId, {
    Object? startAfterDocument,
    int limit = 50,
  }) async {
    var query = collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .limit(limit);

    if (startAfterDocument is DocumentSnapshot) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();
    final comments = snapshot.docs.map((doc) => fromFirestore(doc)).toList();

    return PaginatedComments(
      comments: comments,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<void> updateComment(String commentId, String newContent) async {
    // Validate user owns the comment
    final currentUser = requireCurrentUserId();

    // First check if comment exists and user owns it
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(commentId),
      currentUserId: currentUser,
      resourceType: 'recipe_comment',
    );

    final commentData = doc.data() as Map<String, dynamic>;
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: commentData['authorId'] ?? '',
      resourceType: 'recipe_comment',
      resourceId: commentId,
    );

    // Validate content
    if (newContent.trim().isEmpty) {
      throw SecurityViolationException(
        'Comment content cannot be empty',
      );
    }

    if (newContent.length > 2000) {
      throw SecurityViolationException(
        'Comment content exceeds maximum length of 2000 characters',
      );
    }

    await collection.doc(commentId).update({
      'text': newContent,
      'updatedAt': timestampProvider.serverTimestamp(),
      'editedAt': timestampProvider.serverTimestamp(),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'update',
      granted: true,
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    // Validate user owns the comment
    final currentUser = requireCurrentUserId();

    // First check if comment exists and user owns it
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(commentId),
      currentUserId: currentUser,
      resourceType: 'recipe_comment',
    );

    final commentData = doc.data() as Map<String, dynamic>;
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: commentData['authorId'] ?? '',
      resourceType: 'recipe_comment',
      resourceId: commentId,
    );

    final batch = firestore.batch();
    batch.delete(collection.doc(commentId));

    // Decrement parent comment's replyCount when deleting a reply
    final parentCommentId = commentData['parentCommentId'] as String?;
    if (parentCommentId != null) {
      batch.update(collection.doc(parentCommentId), {
        'replyCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();

    // BUT-1189: best-effort cleanup of backing comment-image Storage objects.
    // Non-blocking — a failed Storage delete must not fail comment deletion
    // (orphaning an image beats a failed delete; the next account-wipe sweeps it).
    await _deleteCommentImages(commentData['imageUrls']);

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'delete',
      granted: true,
    );
  }

  Future<void> _deleteCommentImages(Object? imageUrls) async {
    if (imageUrls is! List || imageUrls.isEmpty) return;
    final storage = ServiceLocator.tryGet<StorageService>();
    if (storage == null) return;
    for (final url in imageUrls.whereType<String>()) {
      try {
        await storage.deleteImage(url);
      } catch (e) {
        AppLogger.warning(
          '[Comments] comment-image cleanup failed for $url: $e',
        );
      }
    }
  }

  @override
  Future<List<RecipeComment>> getReplies(String parentCommentId) async {
    final querySnapshot = await collection
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: false)
        .limit(20)
        .get();

    return querySnapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  // BUT-1190: like operations (toggleCommentLike, getCommentLikeCount,
  // hasUserLikedComment, getCommentLikers) extracted to the
  // [CommentLikesOperations] mixin to keep this file under the 500-line limit.

  @override
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) =>
      watchVisibleComments(recipeId);

  @override
  Future<CommentStatistics> getCommentStatistics(String recipeId) async {
    // Counted from the visible comments: a count() query cannot express the
    // union of the three visibility queries.
    final comments = await fetchVisibleComments(recipeId, limit: 500);
    final topLevel = comments.where((c) => c.parentCommentId == null).length;

    return CommentStatistics(
      totalComments: topLevel,
      totalReplies: comments.length - topLevel,
      totalLikes: comments.fold(0, (total, c) => total + c.likesCount),
      lastCommentAt: comments.isEmpty ? null : comments.last.createdAt,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    // GDPR Article 20: caller must be exporting their own comments.
    // Mirrors the deleteAllByUser-style ownership guard added in BUT-498.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where('authorId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
