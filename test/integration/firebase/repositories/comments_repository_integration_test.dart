/// Integration tests for Firebase Comments Repository
/// 
/// Tests actual Firebase operations with emulator including FieldValue operations,
/// server timestamps, and real-time streams.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import '../setup/firebase_test_setup.dart';
import '../../../infrastructure/factories/mock_factory.dart';

void main() {
  group('Firebase Comments Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseCommentsRepository repository;
    late AuthRepository mockAuthRepository;
    late User testUser;
    
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
      firestore = FirebaseFirestore.instance;
    });
    
    setUp(() async {
      await FirebaseTestSetup.clearEmulatorData();
      
      // Create test user
      testUser = await FirebaseTestSetup.createTestUser(
        email: 'test@example.com',
        password: 'test123',
      );
      
      // Setup mock auth repository
      mockAuthRepository = MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: testUser.uid,
        user: testUser,
      );
      
      // Create repository with Firebase emulator
      repository = FirebaseCommentsRepository(
        firestore: firestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      await FirebaseAuth.instance.signOut();
    });
    
    group('Comments with FieldValue.serverTimestamp', () {
      test('should create comment with server timestamp', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;
        const content = 'This is a test comment';
        
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
        
        // Verify in Firestore
        final doc = await firestore
            .collection('recipe_comments')
            .doc(comment.id)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['createdAt'], isA<Timestamp>());
        
        // Verify timestamp is close to current time
        final timestamp = doc.data()?['createdAt'] as Timestamp;
        expect(
          timestamp.toDate().difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );
      });
      
      test('should update comment with editedAt timestamp', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;
        const originalContent = 'Original comment';
        const updatedContent = 'Updated comment';
        
        // Create comment
        final comment = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: originalContent,
        );
        
        // Act
        await repository.updateComment(comment.id, updatedContent);
        
        // Assert
        final doc = await firestore
            .collection('recipe_comments')
            .doc(comment.id)
            .get();
        
        expect(doc.data()?['text'], equals(updatedContent));
        expect(doc.data()?['editedAt'], isA<Timestamp>());
        expect(doc.data()?['updatedAt'], isA<Timestamp>());
        
        // Verify editedAt is after createdAt
        final createdAt = (doc.data()?['createdAt'] as Timestamp).toDate();
        final editedAt = (doc.data()?['editedAt'] as Timestamp).toDate();
        expect(editedAt.isAfter(createdAt), isTrue);
      });
      
      test('should stream comments with proper timestamp ordering', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;
        
        // Create comments with server timestamps
        for (int i = 0; i < 3; i++) {
          await firestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Comment $i',
            'parentCommentId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
          
          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Act
        final stream = repository.getCommentsStream(recipeId);
        final comments = await stream.first;
        
        // Assert
        expect(comments.length, equals(3));
        
        // Verify comments are ordered by createdAt ascending
        for (int i = 0; i < comments.length - 1; i++) {
          expect(
            comments[i].createdAt.isBefore(comments[i + 1].createdAt) ||
            comments[i].createdAt.isAtSameMomentAs(comments[i + 1].createdAt),
            isTrue,
          );
        }
      });
    });
    
    group('Like System with Transactions', () {
      test('should toggle like with transaction and increment counter', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const commentId = 'comment_123';
        final userId = testUser.uid;
        
        // Create comment
        await firestore.collection('recipe_comments').doc(commentId).set({
          'recipeId': recipeId,
          'authorId': 'author_456',
          'authorDisplayName': 'Author User',
          'text': 'Great recipe!',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
          'likesCount': 0,
        });
        
        // Act - Toggle like on
        await repository.toggleCommentLike(commentId, userId);
        
        // Assert - Like added
        final likeDoc = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDoc.exists, isTrue);
        
        final commentDoc = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(commentDoc.data()?['likesCount'], equals(1));
        
        // Act - Toggle like off
        await repository.toggleCommentLike(commentId, userId);
        
        // Assert - Like removed
        final likeDocAfter = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDocAfter.exists, isFalse);
        
        final commentDocAfter = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(commentDocAfter.data()?['likesCount'], equals(0));
      });
      
      test('should handle concurrent likes correctly', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const commentId = 'comment_for_concurrent';
        
        // Create comment
        await firestore.collection('recipe_comments').doc(commentId).set({
          'recipeId': recipeId,
          'authorId': 'author_456',
          'authorDisplayName': 'Author User',
          'text': 'Test concurrent likes!',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
          'likesCount': 0,
        });
        
        // Act - Multiple users like concurrently
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(repository.toggleCommentLike(commentId, 'user_$i'));
        }
        await Future.wait(futures);
        
        // Assert - All likes counted correctly
        final commentDoc = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(commentDoc.data()?['likesCount'], equals(5));
        
        // Verify like subcollection
        final likes = await firestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .get();
        expect(likes.docs.length, equals(5));
      });
    });
    
    group('Reply System with Counters', () {
      test('should increment reply count when adding reply', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const parentId = 'parent_comment';
        final userId = testUser.uid;
        
        // Create parent comment
        await firestore.collection('recipe_comments').doc(parentId).set({
          'recipeId': recipeId,
          'authorId': userId,
          'authorDisplayName': 'Test User',
          'text': 'Parent comment',
          'parentCommentId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'likedByUserIds': [],
          'replyCount': 0,
          'isDeleted': false,
        });
        
        // Act - Add replies
        for (int i = 0; i < 3; i++) {
          await repository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: 'Reply $i',
            parentCommentId: parentId,
          );
        }
        
        // Assert - Reply count updated
        final parentDoc = await firestore
            .collection('recipe_comments')
            .doc(parentId)
            .get();
        expect(parentDoc.data()?['replyCount'], equals(3));
        
        // Verify replies exist
        final replies = await firestore
            .collection('recipe_comments')
            .where('parentCommentId', isEqualTo: parentId)
            .get();
        expect(replies.docs.length, equals(3));
      });
    });
    
    group('Batch Operations', () {
      test('should handle batch comment creation', () async {
        // Arrange
        const recipeId = 'recipe_batch_test';
        final userId = testUser.uid;
        final batch = firestore.batch();
        
        // Act - Create multiple comments in batch
        for (int i = 0; i < 10; i++) {
          final docRef = firestore.collection('recipe_comments').doc();
          batch.set(docRef, {
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Batch comment $i',
            'parentCommentId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
        }
        
        await batch.commit();
        
        // Assert - All comments created
        final comments = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .get();
        
        expect(comments.docs.length, equals(10));
        
        // Verify all have server timestamps
        for (final doc in comments.docs) {
          expect(doc.data()['createdAt'], isA<Timestamp>());
        }
      });
    });
    
    group('Complex Queries', () {
      test('should query comments with multiple conditions', () async {
        // Arrange
        const recipeId = 'recipe_complex_query';
        final userId = testUser.uid;
        
        // Create mix of comments
        for (int i = 0; i < 10; i++) {
          await firestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': i % 2 == 0 ? userId : 'other_user',
            'authorDisplayName': i % 2 == 0 ? 'Test User' : 'Other User',
            'text': 'Comment $i',
            'parentCommentId': i < 5 ? null : 'parent_id',
            'createdAt': FieldValue.serverTimestamp(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': i % 3 == 0,
            'likesCount': i,
          });
        }
        
        // Act - Query top-level, non-deleted comments by test user
        final query = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .where('authorId', isEqualTo: userId)
            .where('parentCommentId', isNull: true)
            .where('isDeleted', isEqualTo: false)
            .get();
        
        // Assert
        expect(query.docs.length, equals(2)); // Comments 2 and 4
        
        // Act - Query most liked comments
        final popularQuery = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .where('likesCount', isGreaterThanOrEqualTo: 5)
            .orderBy('likesCount', descending: true)
            .get();
        
        // Assert
        expect(popularQuery.docs.length, equals(5)); // Comments 5-9
        expect(popularQuery.docs.first.data()['likesCount'], equals(9));
      });
    });
    
    group('Real-time Updates', () {
      test('should receive real-time comment updates', () async {
        // Arrange
        const recipeId = 'recipe_realtime';
        final userId = testUser.uid;
        
        // Setup stream listener
        final streamController = repository.getCommentsStream(recipeId);
        final updates = <List<RecipeComment>>[];
        
        final subscription = streamController.listen((comments) {
          updates.add(comments);
        });
        
        // Wait for initial empty state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act - Add comments
        for (int i = 0; i < 3; i++) {
          await repository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: 'Realtime comment $i',
          );
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Assert - Received updates
        expect(updates.length, greaterThanOrEqualTo(3));
        expect(updates.last.length, equals(3));
        
        // Cleanup
        await subscription.cancel();
      });
    });
  });
}