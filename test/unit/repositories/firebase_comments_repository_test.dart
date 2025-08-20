/// Unit tests for FirebaseCommentsRepository
/// 
/// Tests the comments repository using mocked Firebase operations
/// to avoid FieldValue type casting issues.
library;

// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}

void main() {
  group('FirebaseCommentsRepository', () {
    late FirebaseCommentsRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockDocRef.id).thenReturn('mock_comment_id');
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      // Setup mock document snapshot for get operations
      final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockGetSnapshot.id).thenReturn('mock_comment_id');
      when(() => mockGetSnapshot.exists).thenReturn(true);
      when(() => mockGetSnapshot.data()).thenReturn(<String, dynamic>{
        'recipeId': 'recipe_123',
        'authorId': 'test_user_123',
        'text': 'Test comment',
        'createdAt': Timestamp.now(),
        'likedByUserIds': [],
      });
      when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), isNull: any(named: 'isNull')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isNull: any(named: 'isNull')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository with dependency injection
      repository = FirebaseCommentsRepository(
        firestore: mockFirestore,
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
        
        // Override the get() mock for this test to return the correct content
        final mockCommentSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockCommentSnapshot.id).thenReturn('mock_comment_id');
        when(() => mockCommentSnapshot.exists).thenReturn(true);
        when(() => mockCommentSnapshot.data()).thenReturn(<String, dynamic>{
          'recipeId': recipeId,
          'authorId': userId,
          'text': content,
          'createdAt': Timestamp.now(),
          'likedByUserIds': [],
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockCommentSnapshot);
        
        when(() => mockDocRef.set(any())).thenAnswer((invocation) async {
          final data = invocation.positionalArguments[0] as Map<String, dynamic>;
          expect(data['recipeId'], equals(recipeId));
          expect(data['authorId'], equals(userId));
          expect(data['text'], equals(content));
          expect(data['parentCommentId'], isNull);
          expect(data['likedByUserIds'], isEmpty);
        });
        
        // Act
        final comment = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        );
        
        // Assert
        expect(comment, isNotNull);
        expect(comment.id, equals('mock_comment_id'));
        expect(comment.recipeId, equals(recipeId));
        expect(comment.authorId, equals(userId));
        expect(comment.text, equals(content));
        expect(comment.parentCommentId, isNull);
        
        verify(() => mockCollection.add(any())).called(1);
      });
      
      test('should add reply comment with parent ID', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const parentId = 'parent_comment_id';
        const content = 'Great point!';
        
        // Override the get() mock for this test to include parentCommentId
        final mockReplySnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockReplySnapshot.id).thenReturn('mock_comment_id');
        when(() => mockReplySnapshot.exists).thenReturn(true);
        when(() => mockReplySnapshot.data()).thenReturn(<String, dynamic>{
          'recipeId': recipeId,
          'authorId': userId,
          'text': content,
          'parentCommentId': parentId,
          'createdAt': Timestamp.now(),
          'likedByUserIds': [],
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockReplySnapshot);
        
        when(() => mockDocRef.set(any())).thenAnswer((invocation) async {
          final data = invocation.positionalArguments[0] as Map<String, dynamic>;
          expect(data['parentCommentId'], equals(parentId));
        });
        
        // Act
        final comment = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
          parentCommentId: parentId,
        );
        
        // Assert
        expect(comment.parentCommentId, equals(parentId));
        verify(() => mockCollection.add(any())).called(1);
      });
      
      test('should throw when adding empty comment', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const emptyContent = '   ';
        
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
      
      test('should throw when user tries to comment as another user', () async {
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
      test('should get comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'comment_1',
            'recipeId': recipeId,
            'authorId': 'user_1',
            'text': 'Comment 1',
            'parentCommentId': null,
            'createdAt': Timestamp.now(),
            'likedByUserIds': [],
            'editedAt': null,
          }),
          _createMockQueryDocumentSnapshot({
            'id': 'comment_2',
            'recipeId': recipeId,
            'authorId': 'user_2',
            'text': 'Comment 2',
            'parentCommentId': null,
            'createdAt': Timestamp.now(),
            'likedByUserIds': ['user_3'],
            'editedAt': null,
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);
        
        // Assert
        expect(comments.length, equals(2));
        expect(comments[0].text, equals('Comment 1'));
        expect(comments[1].text, equals('Comment 2'));
        
        verify(() => mockCollection.where('recipeId', isEqualTo: recipeId)).called(1);
        verify(() => mockQuery.orderBy('createdAt', descending: false)).called(1);
      });
      
      test('should get replies for a comment', () async {
        // Arrange
        const parentId = 'parent_comment_123';
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'reply_1',
            'recipeId': 'recipe_123',
            'authorId': 'user_1',
            'text': 'Reply 1',
            'parentCommentId': parentId,
            'createdAt': Timestamp.now(),
            'likedByUserIds': [],
            'editedAt': null,
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final replies = await repository.getReplies(parentId);
        
        // Assert
        expect(replies.length, equals(1));
        expect(replies[0].parentCommentId, equals(parentId));
        
        verify(() => mockCollection.where('parentCommentId', isEqualTo: parentId)).called(1);
      });
      
      test('should get comment stream for recipe', () {
        // Arrange
        const recipeId = 'recipe_123';
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'comment_1',
            'recipeId': recipeId,
            'authorId': 'user_1',
            'text': 'Streaming comment',
            'parentCommentId': null,
            'createdAt': Timestamp.now(),
            'likedByUserIds': [],
            'editedAt': null,
          }),
        ];
        
        final mockSnapshots = Stream.value(mockQuerySnapshot);
        when(() => mockQuery.snapshots()).thenAnswer((_) => mockSnapshots);
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act & Assert
        final stream = repository.getCommentsStream(recipeId);
        stream.listen(expectAsync1((comments) {
          expect(comments.length, equals(1));
          expect(comments[0].text, equals('Streaming comment'));
          verify(() => mockCollection.where('recipeId', isEqualTo: recipeId)).called(1);
        }));
      });
    });
    
    group('Update Comments', () {
      test('should update comment text', () async {
        // Arrange
        const commentId = 'comment_123';
        const newText = 'Updated comment text';
        const userId = 'test_user_123';
        
        // Mock getting existing comment to verify ownership
        final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockGetSnapshot.id).thenReturn(commentId);
        when(() => mockGetSnapshot.exists).thenReturn(true);
        when(() => mockGetSnapshot.data()).thenReturn({
          'authorId': userId,
          'text': 'Original text',
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
        
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateComment(commentId, newText);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should throw when updating another user\'s comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const newText = 'Updated text';
        
        // Mock getting existing comment with different author
        final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockGetSnapshot.id).thenReturn(commentId);
        when(() => mockGetSnapshot.exists).thenReturn(true);
        when(() => mockGetSnapshot.data()).thenReturn({
          'authorId': 'another_user_456',
          'text': 'Original text',
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
        
        // Act & Assert
        expect(
          () async => await repository.updateComment(commentId, newText),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Delete Comments', () {
      test('should soft delete comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';
        
        // Mock getting existing comment to verify ownership
        final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockGetSnapshot.id).thenReturn(commentId);
        when(() => mockGetSnapshot.exists).thenReturn(true);
        when(() => mockGetSnapshot.data()).thenReturn({
          'authorId': userId,
          'text': 'Comment to delete',
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
        
        // Act
        await repository.deleteComment(commentId);
        
        // Assert
        verify(() => mockDocRef.delete()).called(1);
      });
    });
    
    group('Like Comments', () {
      test('should toggle like on comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';
        
        // Mock like subcollection
        final mockLikesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockLikeDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockLikeSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockCollection.doc(commentId)).thenReturn(mockDocRef);
        when(() => mockDocRef.collection('likes')).thenReturn(mockLikesCollection);
        when(() => mockLikesCollection.doc(userId)).thenReturn(mockLikeDoc);
        when(() => mockLikeDoc.get()).thenAnswer((_) async => mockLikeSnapshot);
        when(() => mockLikeSnapshot.exists).thenReturn(false); // Not liked yet
        
        
        // Mock comment exists check
        final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockGetSnapshot.id).thenReturn(commentId);
        when(() => mockGetSnapshot.exists).thenReturn(true);
        when(() => mockGetSnapshot.data()).thenReturn({
          'authorId': 'some_user',
          'text': 'Comment text',
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
        
        // Act
        await repository.toggleCommentLike(commentId, userId);
        
        // Assert - just verify batch was committed
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should check if user has liked comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';
        
        // Mock like subcollection
        final mockLikesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockLikeDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockLikeSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockCollection.doc(commentId)).thenReturn(mockDocRef);
        when(() => mockDocRef.collection('likes')).thenReturn(mockLikesCollection);
        when(() => mockLikesCollection.doc(userId)).thenReturn(mockLikeDoc);
        when(() => mockLikeDoc.get()).thenAnswer((_) async => mockLikeSnapshot);
        when(() => mockLikeSnapshot.exists).thenReturn(true);
        
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
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'c1',
            'parentCommentId': null,
            'likesCount': 5,
            'createdAt': Timestamp.now(),
          }),
          _createMockQueryDocumentSnapshot({
            'id': 'c2',
            'parentCommentId': null,
            'likesCount': 3,
            'createdAt': Timestamp.now(),
          }),
          _createMockQueryDocumentSnapshot({
            'id': 'c3',
            'parentCommentId': 'c1',
            'likesCount': 1,
            'createdAt': Timestamp.now(),
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final stats = await repository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(2)); // 2 top-level comments
        expect(stats.totalReplies, equals(1)); // 1 reply
        expect(stats.totalLikes, equals(9)); // 5 + 3 + 1
        verify(() => mockCollection.where('recipeId', isEqualTo: recipeId)).called(1);
      });
      
      test('should handle recipe with no comments', () async {
        // Arrange
        const recipeId = 'recipe_123';
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        // Act
        final stats = await repository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(0));
        expect(stats.totalReplies, equals(0));
        expect(stats.totalLikes, equals(0));
      });
    });
  });
}

// Helper function to create mock query document snapshots
MockQueryDocumentSnapshot<Map<String, dynamic>> _createMockQueryDocumentSnapshot(
  Map<String, dynamic> data,
) {
  final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
  when(() => mockDoc.id).thenReturn(data['id'] ?? 'mock_id');
  when(() => mockDoc.data()).thenReturn(data);
  when(() => mockDoc.exists).thenReturn(true);
  return mockDoc;
}