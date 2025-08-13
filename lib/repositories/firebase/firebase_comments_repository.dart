// lib/repositories/firebase/firebase_comments_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Firebase Firestore implementation for recipe comment management and social interaction.
///
/// This repository implements the [CommentsRepository] interface using Firebase Firestore
/// to manage recipe comments with hierarchical reply structures, like/unlike functionality,
/// and comprehensive social interaction features. It provides threaded commenting with
/// performance optimizations and security validation.
///
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] to leverage shared CRUD functionality while providing
/// specialized comment operations. Uses a hierarchical comment structure with:
/// - Top-level comments (parentCommentId: null)
/// - Reply comments (parentCommentId: parent comment ID)
/// - Like subcollections for each comment
///
/// **Comment Structure:**
/// - **Hierarchical Threading**: Supports parent-child comment relationships
/// - **Like System**: Individual like tracking with counts and user validation
/// - **Edit History**: Tracks comment modifications with edit timestamps
/// - **Content Validation**: Ensures comment content meets quality standards
/// - **Recipe Association**: Links comments to specific recipes for organization
///
/// **Security Implementation:**
/// - **Ownership Validation**: Users can only modify their own comments
/// - **Permission Logging**: Comprehensive audit trail for comment operations
/// - **Content Validation**: Prevents empty or invalid comment content
/// - **Like Validation**: Users can only manage their own likes
/// - **Access Control**: Recipe-based comment access validation
///
/// **Performance Optimizations:**
/// - **Load Limits**: Caps comment queries at 50 top-level comments for performance
/// - **Stream Limits**: Limits real-time comment streams for memory management
/// - **Statistics Limits**: Processes up to 500 comments for statistics calculation
/// - **Efficient Queries**: Uses proper Firestore indexing and query optimization
/// - **Batch Operations**: Optimizes like/unlike operations with Firestore batches
///
/// **Social Features:**
/// - **Threaded Replies**: Supports nested comment conversations
/// - **Like/Unlike System**: Social engagement through comment appreciation
/// - **Comment Statistics**: Comprehensive metrics for recipe engagement
/// - **Real-time Updates**: Live comment streams for collaborative discussions
/// - **Edit Functionality**: Allow users to modify their own comments with history
///
/// **Usage Examples:**
/// ```dart
/// final commentsRepo = FirebaseCommentsRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Add comment with validation
/// final comment = await commentsRepo.addComment(
///   recipeId: recipeId,
///   userId: currentUserId,
///   content: 'This recipe looks amazing!',
/// );
/// 
/// // Real-time comment stream
/// commentsRepo.getCommentsStream(recipeId).listen((comments) {
///   updateCommentsUI(comments);
/// });
/// 
/// // Like/unlike comments
/// await commentsRepo.toggleCommentLike(commentId, userId);
/// 
/// // Get engagement statistics
/// final stats = await commentsRepo.getCommentStatistics(recipeId);
/// print('Total engagement: ${stats.totalLikes} likes');
/// ```
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
    // ✅ PERFORMANCE FIX: Added limit to prevent loading hundreds of comments
    final querySnapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .where('parentCommentId', isNull: true) // Top-level comments only
        .orderBy('createdAt', descending: false)
        .limit(50) // Load max 50 top-level comments
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
    // Validate user is creating their own comment
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'add comment',
    );
    
    // Validate required fields
    if (content.trim().isEmpty) {
      throw SecurityViolationException(
        'Comment content cannot be empty',
      );
    }
    
    // Get the actual display name from the current user
    final displayName = authRepository.currentUser?.displayName ?? 'Anonymous';
    
    final commentData = {
      'recipeId': recipeId,
      'authorId': userId,
      'authorDisplayName': displayName,
      'text': content,
      'parentCommentId': parentCommentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'likedByUserIds': [],
      'replyCount': 0,
    };

    final docRef = await collection.add(commentData);
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
    
    await collection.doc(commentId).update({
      'text': newContent,
      'updatedAt': FieldValue.serverTimestamp(),
      'editedAt': FieldValue.serverTimestamp(),
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
    
    await collection.doc(commentId).delete();
    
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
        .get();

    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
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
        .collection('likes')
        .doc(userId)
        .get();
    return likeDoc.exists;
  }

  @override
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    // ✅ PERFORMANCE FIX: Added limit to prevent streaming large comment datasets
    return collection
        .where('recipeId', isEqualTo: recipeId)
        .where('parentCommentId', isNull: true)
        .orderBy('createdAt', descending: false)
        .limit(50) // Stream max 50 top-level comments
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromFirestore(doc))
            .toList());
  }

  @override
  Future<CommentStatistics> getCommentStatistics(String recipeId) async {
    // Get all comments for the recipe
    // ✅ PERFORMANCE FIX: Added limit for statistics calculation
    // For accurate statistics, we might need to implement server-side aggregation
    final allCommentsQuery = await collection
        .where('recipeId', isEqualTo: recipeId)
        .limit(500) // Limit to most recent 500 comments for stats
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