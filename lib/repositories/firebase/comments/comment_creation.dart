// lib/repositories/firebase/comments/comment_creation.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/repositories/firebase/rate_limit_stamp.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/attribution_source.dart';

/// Callback to validate that a user has access to a recipe before commenting.
/// Returns true if the user can access the recipe.
typedef RecipeAccessValidator =
    Future<bool> Function(String recipeId, String userId);

/// Creating a comment: the online write, which Firestore's own queue carries
/// through an outage, and the write the offline upload queue makes once a
/// comment's photos are in Storage (BUT-2294).
mixin CommentCreation on BaseFirebaseRepository<RecipeComment> {
  RecipeAccessValidator? get recipeAccessValidator;
  RecipeOwnershipResolver? get recipeOwnershipResolver;
  AttributionSource get attribution;

  Future<RecipeComment> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
    List<String> imageUrls = const [],
  }) async {
    final currentUser = await _validate(
      recipeId: recipeId,
      userId: userId,
      content: content,
      imageUrls: imageUrls,
    );
    final ownership = await _resolveOwnership(recipeId);
    final commentData = _commentData(
      recipeId: recipeId,
      userId: userId,
      content: content,
      parentCommentId: parentCommentId,
      imageUrls: imageUrls,
      ownership: ownership,
    );

    if (await _hasUnsentComment(userId)) {
      throw const CommentAwaitingSendException();
    }

    final docRef = collection.doc();
    final batch = _commentBatch(
      docRef,
      commentData,
      userId: userId,
      parentCommentId: parentCommentId,
    );

    // BUT-2363: offline the commit settles only when the server answers, so
    // the comment form stayed busy for the whole outage.
    await awaitOrLeaveQueued(batch.commit(), what: 'comment ${docRef.id}');

    // From the cache, which holds the comment either way.
    final doc = await docRef.get(const GetOptions(source: Source.cache));

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'create',
      granted: true,
      details: 'Recipe: $recipeId',
    );

    return fromFirestore(doc);
  }

  /// The write the upload queue makes for a comment whose photos are in
  /// Storage, under the id the queue fixed when the comment was written, so a
  /// try that got through is not repeated (see [ownCommentExists]). Waits for
  /// the server, since the queue must know the comment is there before it lets
  /// the photos go. The recipe's ownership must resolve: a comment written
  /// without it is readable by its author alone, and the queue cannot tell the
  /// user so afterwards.
  Future<RecipeComment> createQueuedComment({
    required String commentId,
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
    List<String> imageUrls = const [],
  }) async {
    final currentUser = await _validate(
      recipeId: recipeId,
      userId: userId,
      content: content,
      imageUrls: imageUrls,
    );
    final ownership = await _resolveOwnership(recipeId);
    if (recipeOwnershipResolver != null && ownership == null) {
      throw StateError('The recipe ownership of a queued comment is unknown');
    }
    final docRef = collection.doc(commentId);
    final batch = _commentBatch(
      docRef,
      _commentData(
        recipeId: recipeId,
        userId: userId,
        content: content,
        parentCommentId: parentCommentId,
        imageUrls: imageUrls,
        ownership: ownership,
      ),
      userId: userId,
      parentCommentId: parentCommentId,
    );

    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_comment',
      operation: 'create',
      granted: true,
      details: 'Recipe: $recipeId (queued)',
    );

    return fromFirestore(await docRef.get());
  }

  /// Whether the signed-in user's comment [commentId] is on the server,
  /// which a cached answer cannot say.
  Future<bool> ownCommentExists(String commentId) async {
    final userId = requireCurrentUserId();
    final found = await collection
        .where('authorId', isEqualTo: userId)
        .where(FieldPath.documentId, isEqualTo: commentId)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    return found.docs.isNotEmpty;
  }

  Future<String> _validate({
    required String recipeId,
    required String userId,
    required String content,
    required List<String> imageUrls,
  }) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'add comment',
    );

    final validator = recipeAccessValidator;
    if (validator != null) {
      final hasAccess = await validator(recipeId, currentUser);
      if (!hasAccess) {
        throw PermissionDeniedException(
          'User does not have access to this recipe',
          resource: 'recipe',
          operation: 'comment',
          userId: currentUser,
        );
      }
    }

    if (content.trim().isEmpty) {
      throw SecurityViolationException('Comment content cannot be empty');
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
    return currentUser;
  }

  /// BUT-458: the recipe-ownership snapshot denormalized onto the comment.
  /// A failure is non-blocking here — the comment still writes (without the
  /// new fields) and rules fall back to author-only read. Missing-snapshot is
  /// logged for ops visibility.
  Future<RecipeOwnershipSnapshot?> _resolveOwnership(String recipeId) async {
    final resolver = recipeOwnershipResolver;
    if (resolver == null) return null;
    try {
      return await resolver(recipeId);
    } catch (e) {
      AppLogger.warning(
        '[Comments] ownership resolver failed for recipe $recipeId: $e — '
        'comment will write without denorm fields, read falls back to author-only',
      );
      return null;
    }
  }

  Map<String, dynamic> _commentData({
    required String recipeId,
    required String userId,
    required String content,
    required String? parentCommentId,
    required List<String> imageUrls,
    required RecipeOwnershipSnapshot? ownership,
  }) {
    final commentData = <String, dynamic>{
      'recipeId': recipeId,
      'authorId': userId,
      'authorDisplayName': attribution.displayName,
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
    return commentData;
  }

  /// Comment + rate limit doc + parent replyCount increment.
  WriteBatch _commentBatch(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> commentData, {
    required String userId,
    required String? parentCommentId,
  }) {
    final batch = firestore.batch();
    batch.set(docRef, commentData);
    stampRateLimit(
      batch,
      firestore,
      userId: userId,
      type: 'comments',
      guardedDocId: docRef.id,
      timestampProvider: timestampProvider,
    );

    // Increment parent comment's replyCount when creating a reply
    if (parentCommentId != null) {
      batch.update(collection.doc(parentCommentId), {
        'replyCount': FieldValue.increment(1),
      });
    }
    return batch;
  }

  /// BUT-2363: whether a comment of [userId]'s is still in Firestore's
  /// offline queue. Every comment batch writes the burst stamp, so the cached
  /// stamp has pending writes exactly while one is unsent; read from the
  /// device's cache, it survives a restart and belongs to one account.
  Future<bool> _hasUnsentComment(String userId) async {
    try {
      final stamp = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userRateLimits)
          .doc('comments')
          .get(const GetOptions(source: Source.cache));
      return stamp.metadata.hasPendingWrites;
    } on FirebaseException {
      // Not in the cache: nothing of this account's is queued here.
      return false;
    }
  }
}
