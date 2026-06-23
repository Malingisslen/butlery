// lib/repositories/firebase/comments/comment_likes_operations.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Comment "like" operations for `FirebaseCommentsRepository`, extracted into a
/// mixin to keep the repository under the 500-line limit (BUT-1190). Likes live
/// in a per-comment `likes` subcollection; these methods own toggling and
/// querying it. Mixed `on BaseFirebaseRepository<RecipeComment>` so they retain
/// the base `collection`, `firestore`, permission, audit, and timestamp helpers
/// — same idiom as `BatchOperationsFirebaseRepository` / `UserScopedFirebaseRepository`.
mixin CommentLikesOperations on BaseFirebaseRepository<RecipeComment> {
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

    final likesCollection = collection
        .doc(commentId)
        .collection(FirestoreCollections.likes);
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

  Future<int> getCommentLikeCount(String commentId) async {
    final doc = await collection.doc(commentId).get();
    return doc.data()?['likesCount'] ?? 0;
  }

  Future<bool> hasUserLikedComment(String commentId, String userId) async {
    final likeDoc = await collection
        .doc(commentId)
        .collection(FirestoreCollections.likes)
        .doc(userId)
        .get();
    return likeDoc.exists;
  }

  Future<List<String>> getCommentLikers(
    String commentId, {
    int limit = 100,
  }) async {
    final likesSnapshot = await collection
        .doc(commentId)
        .collection(FirestoreCollections.likes)
        .orderBy('likedAt', descending: true)
        .limit(limit)
        .get();

    return likesSnapshot.docs.map((doc) => doc.id).toList();
  }
}
