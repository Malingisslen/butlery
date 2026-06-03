// lib/repositories/firebase/firebase_comments_repository.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase implementation for recipe comments with threaded replies and like tracking.
/// Supports recipe access validation via optional [RecipeAccessValidator] constructor parameter.
/// Callback to validate that a user has access to a recipe before commenting.
/// Returns true if the user can access the recipe.
typedef RecipeAccessValidator = Future<bool> Function(
    String recipeId, String userId);

class FirebaseCommentsRepository extends BaseFirebaseRepository<RecipeComment>
    implements CommentsRepository {
  final RecipeAccessValidator? _recipeAccessValidator;
  final RecipeOwnershipResolver? _recipeOwnershipResolver;

  FirebaseCommentsRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
    RecipeAccessValidator? recipeAccessValidator,
    RecipeOwnershipResolver? recipeOwnershipResolver,
  })  : _recipeAccessValidator = recipeAccessValidator,
        _recipeOwnershipResolver = recipeOwnershipResolver;

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
      String userId, RecipeComment entity) async {
    // Users can only create comments as themselves
    return entity.authorId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, RecipeComment? entity) async {
    // All authenticated users can read comments on recipes they have access to
    // The recipe-level access control is enforced separately
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, RecipeComment entity) async {
    // Users can only edit their own comments
    return entity.authorId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
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
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId) async {
    // ✅ PERFORMANCE FIX: Added limit to prevent loading hundreds of comments
    // ✅ REPLY FIX: Removed parentCommentId filter to load both top-level and replies
    final querySnapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .limit(50) // Load max 50 comments (including replies)
        .get();

    return querySnapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

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
  Future<RecipeComment> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
    List<String> imageUrls = const [],
  }) async {
    // Validate user is creating their own comment
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'add comment',
    );

    // Validate recipe access if validator is configured
    if (_recipeAccessValidator != null) {
      final hasAccess = await _recipeAccessValidator(recipeId, currentUser);
      if (!hasAccess) {
        throw PermissionDeniedException(
          'User does not have access to this recipe',
          resource: 'recipe',
          operation: 'comment',
          userId: currentUser,
        );
      }
    }

    // Validate required fields
    if (content.trim().isEmpty) {
      throw SecurityViolationException(
        'Comment content cannot be empty',
      );
    }

    if (content.length > 2000) {
      throw SecurityViolationException(
        'Comment content exceeds maximum length of 2000 characters',
      );
    }

    // BUT-1049: defence-in-depth cap mirroring RecipeComment.maxImageUrls and
    // the Storage/Firestore rules. The composer enforces this in the UI; this
    // is the server-side trust boundary.
    if (imageUrls.length > RecipeComment.maxImageUrls) {
      throw SecurityViolationException(
        'Comment image count exceeds maximum of ${RecipeComment.maxImageUrls}',
      );
    }

    // Get the actual display name from the current user
    final displayName = authRepository.currentUser?.displayName ?? 'Anonymous';

    // BUT-458: Resolve the recipe-ownership snapshot so we can denormalize
    // onto the comment doc. Failures are non-blocking — the comment still
    // writes (without the new fields) and rules fall back to author-only
    // read. Missing-snapshot is logged for ops visibility.
    RecipeOwnershipSnapshot? ownership;
    if (_recipeOwnershipResolver != null) {
      try {
        ownership = await _recipeOwnershipResolver(recipeId);
      } catch (e) {
        AppLogger.warning(
          '[Comments] ownership resolver failed for recipe $recipeId: $e — '
          'comment will write without denorm fields, read falls back to author-only',
        );
        ownership = null;
      }
    }

    final commentData = <String, dynamic>{
      'recipeId': recipeId,
      'authorId': userId,
      'authorDisplayName': displayName,
      'text': content,
      'parentCommentId': parentCommentId,
      'createdAt': timestampProvider.serverTimestamp(),
      'updatedAt': timestampProvider.serverTimestamp(),
      'isDeleted': false,
      'likesCount': 0,
      'replyCount': 0,
      // Always write sharedWithUserIds (even empty) so the rule's `in`
      // operator does not crash on a missing field.
      'sharedWithUserIds': ownership?.sharedWithUserIds ?? <String>[],
    };
    if (ownership?.recipeOwnerId != null) {
      commentData['recipeOwnerId'] = ownership!.recipeOwnerId;
    }
    // BUT-1049: only emit when populated so legacy text-only docs stay
    // byte-identical (empty list is interchangeable with absence on reads).
    if (imageUrls.isNotEmpty) {
      commentData['imageUrls'] = imageUrls;
    }

    // Batch write: comment + rate limit doc + parent replyCount increment
    final batch = firestore.batch();
    final docRef = collection.doc();
    batch.set(docRef, commentData);
    batch.set(
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userRateLimits)
          .doc('comments'),
      {
        'lastWrite': timestampProvider.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(clock.now().add(const Duration(days: 90))),
      },
      SetOptions(merge: true),
    );

    // Increment parent comment's replyCount when creating a reply
    if (parentCommentId != null) {
      batch.update(collection.doc(parentCommentId), {
        'replyCount': FieldValue.increment(1),
      });
    }

    await batch.commit();

    final doc = await docRef.get();

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'create',
      granted: true,
      details: 'Recipe: $recipeId',
    );

    return fromFirestore(doc);
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

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'delete',
      granted: true,
    );
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

  @override
  Future<void> toggleCommentLike(String commentId, String userId) async {
    // Validate user is toggling their own like
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'toggle comment like',
    );

    // Verify comment exists
    final commentDoc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(commentId),
      currentUserId: currentUser,
      resourceType: 'recipe_comment',
    );

    if (!commentDoc.exists) {
      throw ResourceNotFoundException(
        'Comment not found',
        resourceType: 'recipe_comment',
        resourceId: commentId,
      );
    }

    final likesCollection =
        collection.doc(commentId).collection(FirestoreCollections.likes);
    final userLikeDoc = likesCollection.doc(userId);
    final likeSnapshot = await userLikeDoc.get();

    final batch = firestore.batch();

    if (likeSnapshot.exists) {
      // Unlike - remove like and decrement count
      batch.delete(userLikeDoc);
      batch.update(collection.doc(commentId), {
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Like - add like and increment count
      batch.set(userLikeDoc, {
        'userId': userId,
        'likedAt': timestampProvider.serverTimestamp(),
      });
      batch.update(collection.doc(commentId), {
        'likesCount': FieldValue.increment(1),
      });
    }

    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: likeSnapshot.exists ? 'unlike' : 'like',
      granted: true,
    );
  }

  @override
  Future<int> getCommentLikeCount(String commentId) async {
    final doc = await collection.doc(commentId).get();
    return doc.data()?['likesCount'] ?? 0;
  }

  @override
  Future<bool> hasUserLikedComment(String commentId, String userId) async {
    final likeDoc = await collection
        .doc(commentId)
        .collection(FirestoreCollections.likes)
        .doc(userId)
        .get();
    return likeDoc.exists;
  }

  @override
  Future<List<String>> getCommentLikers(String commentId,
      {int limit = 100}) async {
    final likesSnapshot = await collection
        .doc(commentId)
        .collection(FirestoreCollections.likes)
        .orderBy('likedAt', descending: true)
        .limit(limit)
        .get();

    return likesSnapshot.docs.map((doc) => doc.id).toList();
  }

  @override
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    // ✅ PERFORMANCE FIX: Added limit to prevent streaming large comment datasets
    // ✅ REPLY FIX: Removed parentCommentId filter to stream both top-level and replies
    return collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: false)
        .limit(50) // Stream max 50 comments (including replies)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  @override
  Future<CommentStatistics> getCommentStatistics(String recipeId) async {
    // Optimized (#040): Use count() aggregation for totals - no document fetch needed
    // This reduces reads from 500 full docs to 2 count queries + 1 limited fetch

    // Count top-level comments (no parentCommentId)
    // Use isNull instead of isEqualTo: null for Firestore compatibility
    final topLevelCount = await collection
        .where('recipeId', isEqualTo: recipeId)
        .where('parentCommentId', isNull: true)
        .count()
        .get();

    // Count replies (have parentCommentId)
    // Note: Firestore doesn't support isNotEqualTo: null directly with count,
    // so we calculate replies as total - topLevel
    final totalCount =
        await collection.where('recipeId', isEqualTo: recipeId).count().get();

    final repliesCount = (totalCount.count ?? 0) - (topLevelCount.count ?? 0);

    // Fetch only for likes sum and lastCommentAt (need actual values, not just counts)
    // Limited to 500 most recent comments for performance
    final likesSnapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    int totalLikes = 0;
    DateTime? lastCommentAt;

    for (final doc in likesSnapshot.docs) {
      final data = doc.data();
      totalLikes += (data['likesCount'] as int?) ?? 0;

      // First doc is most recent due to orderBy descending
      lastCommentAt ??= (data['createdAt'] as Timestamp?)?.toDate();
    }

    return CommentStatistics(
      totalComments: topLevelCount.count ?? 0,
      totalReplies: repliesCount,
      totalLikes: totalLikes,
      lastCommentAt: lastCommentAt,
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
