// lib/repositories/firebase/firebase_comments_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/comments_repository.dart';
import '../../models/recipe_comment.dart';
import 'base_firebase_repository.dart';

/// Firebase implementation of CommentsRepository
class FirebaseCommentsRepository extends BaseFirebaseRepository<RecipeComment>
    implements CommentsRepository {
  
  FirebaseCommentsRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'recipe_comments';

  @override
  RecipeComment fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      RecipeComment.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(RecipeComment entity) => entity.toFirestore();

  @override
  String getId(RecipeComment entity) => entity.id;

  // ===== SPECIALIZED COMMENT OPERATIONS =====

  @override
  Future<List<RecipeComment>> getCommentsForRecipe(String recipeId) async {
    final querySnapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .where('parentCommentId', isNull: true) // Top-level comments only
        .orderBy('createdAt', descending: false)
        .get();

    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
  }

  @override
  Future<RecipeComment> addComment({
    required String recipeId,
    required String userId,
    required String content,
    String? parentCommentId,
  }) async {
    final commentData = {
      'recipeId': recipeId,
      'userId': userId,
      'content': content,
      'parentCommentId': parentCommentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': false,
      'likesCount': 0,
    };

    final docRef = await collection.add(commentData);
    final doc = await docRef.get();
    return fromFirestore(doc);
  }

  @override
  Future<void> updateComment(String commentId, String newContent) async {
    await collection.doc(commentId).update({
      'content': newContent,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': true,
    });
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await collection.doc(commentId).delete();
  }

  @override
  Future<List<RecipeComment>> getReplies(String parentCommentId) async {
    final querySnapshot = await collection
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: false)
        .get();

    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
  }

  @override
  Future<void> toggleCommentLike(String commentId, String userId) async {
    final likesCollection = collection.doc(commentId).collection('likes');
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
        'likedAt': FieldValue.serverTimestamp(),
      });
      batch.update(collection.doc(commentId), {
        'likesCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
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
        .collection('likes')
        .doc(userId)
        .get();
    return likeDoc.exists;
  }

  @override
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    return collection
        .where('recipeId', isEqualTo: recipeId)
        .where('parentCommentId', isNull: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromFirestore(doc))
            .toList());
  }

  @override
  Future<CommentStatistics> getCommentStatistics(String recipeId) async {
    // Get all comments for the recipe
    final allCommentsQuery = await collection
        .where('recipeId', isEqualTo: recipeId)
        .get();

    final allComments = allCommentsQuery.docs;
    final topLevelComments = allComments.where((doc) => 
        doc.data()['parentCommentId'] == null).toList();
    final replies = allComments.where((doc) => 
        doc.data()['parentCommentId'] != null).toList();

    // Calculate total likes across all comments
    int totalLikes = 0;
    DateTime? lastCommentAt;

    for (final doc in allComments) {
      final data = doc.data();
      totalLikes += (data['likesCount'] as int?) ?? 0;
      
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && (lastCommentAt == null || createdAt.isAfter(lastCommentAt))) {
        lastCommentAt = createdAt;
      }
    }

    return CommentStatistics(
      totalComments: topLevelComments.length,
      totalReplies: replies.length,
      totalLikes: totalLikes,
      lastCommentAt: lastCommentAt,
    );
  }
}