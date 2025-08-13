/// Unit tests for FirebaseCommentsRepository
/// 
/// Tests the comments repository that provides recipe comment management
/// and social interaction functionality.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseCommentsRepository', () {
    late FirebaseCommentsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Setup fake Firestore and mock auth
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Create repository with dependency injection
      repository = FirebaseCommentsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Add Comments', () {
      test('should add top-level comment to recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const content = 'This recipe looks amazing!';
        
        // Act
        final comment = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        );
        
        // Assert
        expect(comment, isNotNull);
        expect(comment.recipeId, equals(recipeId));
        expect(comment.authorId, equals(userId));
        expect(comment.text, equals(content));
        expect(comment.parentCommentId, isNull);
        expect(comment.likeCount, equals(0));
        expect(comment.isEdited, isFalse);
        
        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('recipe_comments')
            .doc(comment.id)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['recipeId'], equals(recipeId));
      });
      
      test('should add reply comment to parent comment', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const parentContent = 'Great recipe!';
        const replyContent = 'I agree, it tastes wonderful!';
        
        // First create parent comment
        final parent = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: parentContent,
        );
        
        // Act - Create reply
        final reply = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: replyContent,
          parentCommentId: parent.id,
        );
        
        // Assert
        expect(reply, isNotNull);
        expect(reply.parentCommentId, equals(parent.id));
        expect(reply.recipeId, equals(recipeId));
        expect(reply.text, equals(replyContent));
      });
      
      test('should throw when adding empty comment', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const emptyContent = '   '; // Whitespace only
        
        // Act & Assert
        expect(
          () async => await repository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: emptyContent,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });
      
      test('should throw when user tries to add comment for another user', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const anotherUserId = 'another_user_456';
        const content = 'Trying to comment as someone else';
        
        // Act & Assert
        expect(
          () async => await repository.addComment(
            recipeId: recipeId,
            userId: anotherUserId,
            content: content,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Get Comments', () {
      test('should get top-level comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        
        // Create multiple top-level comments
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Comment $i',
            'parentCommentId': null,
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
        }
        
        // Create some replies (should not be included)
        await fakeFirestore.collection('recipe_comments').add({
          'recipeId': recipeId,
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': 'Reply comment',
          'parentCommentId': 'parent_id',
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);
        
        // Assert
        expect(comments.length, equals(5)); // Only top-level
        expect(comments.every((c) => c.parentCommentId == null), isTrue);
        // Should be ordered by createdAt ascending
        for (int i = 0; i < comments.length - 1; i++) {
          expect(
            comments[i].createdAt.isBefore(comments[i + 1].createdAt) ||
            comments[i].createdAt.isAtSameMomentAs(comments[i + 1].createdAt),
            isTrue,
          );
        }
      });
      
      test('should limit comments to 50 for performance', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        
        // Create 60 comments
        for (int i = 0; i < 60; i++) {
          await fakeFirestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Comment $i',
            'parentCommentId': null,
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(minutes: i)),
            ),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
        }
        
        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);
        
        // Assert
        expect(comments.length, equals(50)); // Limited to 50
      });
      
      test('should get replies for a comment', () async {
        // Arrange
        const parentId = 'parent_comment_123';
        const userId = 'test_user_123';
        
        // Create replies
        for (int i = 0; i < 3; i++) {
          await fakeFirestore.collection('recipe_comments').add({
            'recipeId': 'recipe_123',
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Reply $i',
            'parentCommentId': parentId,
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
        }
        
        // Act
        final replies = await repository.getReplies(parentId);
        
        // Assert
        expect(replies.length, equals(3));
        expect(replies.every((r) => r.parentCommentId == parentId), isTrue);
      });
      
      test('should stream comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        
        // Create initial comments
        await fakeFirestore.collection('recipe_comments').add({
          'recipeId': recipeId,
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': 'Initial comment',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act
        final stream = repository.getCommentsStream(recipeId);
        
        // Assert
        final comments = await stream.first;
        expect(comments.length, equals(1));
        expect(comments.first.text, equals('Initial comment'));
      });
    });
    
    group('Update Comments', () {
      test('should update comment content', () async {
        // Arrange
        const userId = 'test_user_123';
        const originalContent = 'Original comment';
        const updatedContent = 'Updated comment with more details';
        
        // Create comment
        final docRef = await fakeFirestore.collection('recipe_comments').add({
          'recipeId': 'recipe_123',
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': originalContent,
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act
        await repository.updateComment(docRef.id, updatedContent);
        
        // Assert
        final doc = await docRef.get();
        expect(doc.data()?['text'], equals(updatedContent));
        expect(doc.data()?['editedAt'], isNotNull);
        expect(doc.data()?['updatedAt'], isNotNull);
      });
      
      test('should throw when updating empty content', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create comment
        final docRef = await fakeFirestore.collection('recipe_comments').add({
          'recipeId': 'recipe_123',
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': 'Original',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act & Assert
        expect(
          () async => await repository.updateComment(docRef.id, '  '),
          throwsA(isA<SecurityViolationException>()),
        );
      });
      
      test('should throw when user tries to update another users comment', () async {
        // Arrange
        const otherUserId = 'other_user_456';
        
        // Create comment by another user
        final docRef = await fakeFirestore.collection('recipe_comments').add({
          'recipeId': 'recipe_123',
          'authorId': otherUserId,
          'authorDisplayName': 'Other User',
          'text': 'Someone elses comment',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act & Assert
        expect(
          () async => await repository.updateComment(docRef.id, 'Try to edit'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Delete Comments', () {
      test('should delete users own comment', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create comment
        final docRef = await fakeFirestore.collection('recipe_comments').add({
          'recipeId': 'recipe_123',
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': 'Comment to delete',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act
        await repository.deleteComment(docRef.id);
        
        // Assert
        final doc = await docRef.get();
        expect(doc.exists, isFalse);
      });
      
      test('should throw when trying to delete another users comment', () async {
        // Arrange
        const otherUserId = 'other_user_456';
        
        // Create comment by another user
        final docRef = await fakeFirestore.collection('recipe_comments').add({
          'recipeId': 'recipe_123',
          'authorId': otherUserId,
          'authorDisplayName': 'Other User',
          'text': 'Someone elses comment',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act & Assert
        expect(
          () async => await repository.deleteComment(docRef.id),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Like System', () {
      test('should toggle comment like on', () async {
        // Arrange
        const userId = 'test_user_123';
        const commentId = 'comment_123';
        
        // Create comment
        await fakeFirestore.collection('recipe_comments').doc(commentId).set({
          'recipeId': 'recipe_123',
          'authorId': 'author_456',
          'authorDisplayName': 'Author User',
          'text': 'Great recipe!',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act
        await repository.toggleCommentLike(commentId, userId);
        
        // Assert
        final likeDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDoc.exists, isTrue);
        
        final commentDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        // Note: likesCount is incremented by the repository method
        expect(commentDoc.data()?['likesCount'], equals(1));
      });
      
      test('should toggle comment like off', () async {
        // Arrange
        const userId = 'test_user_123';
        const commentId = 'comment_123';
        
        // Create comment with existing like
        await fakeFirestore.collection('recipe_comments').doc(commentId).set({
          'recipeId': 'recipe_123',
          'authorId': 'author_456',
          'authorDisplayName': 'Author User',
          'text': 'Great recipe!',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
          'likesCount': 1,
        });
        
        await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .set({'likedAt': FieldValue.serverTimestamp()});
        
        // Act
        await repository.toggleCommentLike(commentId, userId);
        
        // Assert
        final likeDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDoc.exists, isFalse);
        
        final commentDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(commentDoc.data()?['likesCount'], equals(0));
      });
      
      test('should check if user has liked comment', () async {
        // Arrange
        const userId = 'test_user_123';
        const commentId = 'comment_123';
        
        // Create comment and like
        await fakeFirestore.collection('recipe_comments').doc(commentId).set({
          'recipeId': 'recipe_123',
          'authorId': 'author_456',
          'authorDisplayName': 'Author User',
          'text': 'Great recipe!',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
          'likesCount': 1,
        });
        
        await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .set({'likedAt': FieldValue.serverTimestamp()});
        
        // Act
        final hasLiked = await repository.hasUserLikedComment(commentId, userId);
        
        // Assert
        expect(hasLiked, isTrue);
      });
    });
    
    group('Comment Statistics', () {
      test('should get comment statistics for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        
        // Create comments with different like counts
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': 'user_$i',
            'authorDisplayName': 'User $i',
            'text': 'Comment $i',
            'parentCommentId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
            'likesCount': i * 2, // 0, 2, 4, 6, 8
          });
        }
        
        // Act
        final stats = await repository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(5));
        expect(stats.totalLikes, equals(20)); // 0+2+4+6+8
      });
      
      test('should handle recipe with no comments', () async {
        // Arrange
        const recipeId = 'recipe_with_no_comments';
        
        // Act
        final stats = await repository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(0));
        expect(stats.totalLikes, equals(0));
      });
    });
  });
}