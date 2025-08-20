/// Unit tests for services using CommentsRepository
/// 
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CommentsRepository Mock Tests', () {
    late MockCommentsRepository mockRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mock repository with configuration
      mockRepository = MockFactory.createCommentsRepository(
        currentUserId: 'test_user_123',
        commentsByRecipe: {},
        likesByComment: {},
        replyCounts: {},
      );
      
      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
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
        
        final expectedComment = RecipeComment(
          id: 'comment_123',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Test User',
          text: content,
          createdAt: DateTime.now(),
        );
        
        // Stub the repository method
        when(() => mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        )).thenAnswer((_) async => expectedComment);
        
        // Act
        final comment = await mockRepository.addComment(
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
        
        // Verify the method was called
        verify(() => mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        )).called(1);
      });
      
      test('should add reply comment to parent comment', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const parentCommentId = 'parent_comment_123';
        const replyContent = 'I agree, it tastes wonderful!';
        
        final expectedReply = RecipeComment(
          id: 'reply_123',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Test User',
          text: replyContent,
          parentCommentId: parentCommentId,
          createdAt: DateTime.now(),
        );
        
        // Stub the repository method
        when(() => mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: replyContent,
          parentCommentId: parentCommentId,
        )).thenAnswer((_) async => expectedReply);
        
        // Act
        final reply = await mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: replyContent,
          parentCommentId: parentCommentId,
        );
        
        // Assert
        expect(reply, isNotNull);
        expect(reply.parentCommentId, equals(parentCommentId));
        expect(reply.recipeId, equals(recipeId));
        expect(reply.text, equals(replyContent));
        
        // Verify the method was called
        verify(() => mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: replyContent,
          parentCommentId: parentCommentId,
        )).called(1);
      });
    });
    
    group('Get Comments', () {
      test('should get top-level comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        
        final comments = [
          RecipeComment(
            id: 'comment_1',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Comment 1',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          RecipeComment(
            id: 'comment_2',
            recipeId: recipeId,
            authorId: 'user_2',
            authorDisplayName: 'User 2',
            text: 'Comment 2',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ];
        
        // Stub the repository method
        when(() => mockRepository.getCommentsForRecipe(recipeId))
            .thenAnswer((_) async => comments);
        
        // Act
        final result = await mockRepository.getCommentsForRecipe(recipeId);
        
        // Assert
        expect(result.length, equals(2));
        expect(result.first.text, equals('Comment 1'));
        expect(result[1].text, equals('Comment 2'));
        expect(result.every((c) => c.parentCommentId == null), isTrue);
        
        // Verify the method was called
        verify(() => mockRepository.getCommentsForRecipe(recipeId)).called(1);
      });
      
      test('should get replies for a comment', () async {
        // Arrange
        const parentId = 'parent_comment_123';
        
        final replies = [
          RecipeComment(
            id: 'reply_1',
            recipeId: 'recipe_123',
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Reply 1',
            parentCommentId: parentId,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          RecipeComment(
            id: 'reply_2',
            recipeId: 'recipe_123',
            authorId: 'user_2',
            authorDisplayName: 'User 2',
            text: 'Reply 2',
            parentCommentId: parentId,
            createdAt: DateTime.now(),
          ),
        ];
        
        // Stub the repository method
        when(() => mockRepository.getReplies(parentId))
            .thenAnswer((_) async => replies);
        
        // Act
        final result = await mockRepository.getReplies(parentId);
        
        // Assert
        expect(result.length, equals(2));
        expect(result.every((r) => r.parentCommentId == parentId), isTrue);
        
        // Verify the method was called
        verify(() => mockRepository.getReplies(parentId)).called(1);
      });
      
      test('should stream comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        
        final comments = [
          RecipeComment(
            id: 'stream_comment_1',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Streamed comment',
            createdAt: DateTime.now(),
          ),
        ];
        
        // Stub the repository method (override default empty stream)
        when(() => mockRepository.getCommentsStream(recipeId))
            .thenAnswer((_) => Stream.value(comments));
        
        // Act
        final stream = mockRepository.getCommentsStream(recipeId);
        final result = await stream.first;
        
        // Assert
        expect(result.length, equals(1));
        expect(result.first.text, equals('Streamed comment'));
        
        // Verify the method was called
        verify(() => mockRepository.getCommentsStream(recipeId)).called(1);
      });
    });
    
    group('Update Comments', () {
      test('should update comment content', () async {
        // Arrange
        const commentId = 'comment_123';
        const updatedContent = 'Updated comment with more details';
        
        // Stub the repository method
        when(() => mockRepository.updateComment(commentId, updatedContent))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.updateComment(commentId, updatedContent);
        
        // Assert
        verify(() => mockRepository.updateComment(commentId, updatedContent)).called(1);
      });
    });
    
    group('Delete Comments', () {
      test('should delete comment', () async {
        // Arrange
        const commentId = 'comment_to_delete';
        
        // Stub the repository method
        when(() => mockRepository.deleteComment(commentId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.deleteComment(commentId);
        
        // Assert
        verify(() => mockRepository.deleteComment(commentId)).called(1);
      });
    });
    
    group('Like System', () {
      test('should toggle comment like', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.toggleCommentLike(commentId, userId))
            .thenAnswer((_) async {});
        
        // Act
        await mockRepository.toggleCommentLike(commentId, userId);
        
        // Assert
        verify(() => mockRepository.toggleCommentLike(commentId, userId)).called(1);
      });
      
      test('should get comment like count', () async {
        // Arrange
        const commentId = 'comment_123';
        const expectedLikeCount = 5;
        
        // Stub the repository method
        when(() => mockRepository.getCommentLikeCount(commentId))
            .thenAnswer((_) async => expectedLikeCount);
        
        // Act
        final likeCount = await mockRepository.getCommentLikeCount(commentId);
        
        // Assert
        expect(likeCount, equals(5));
        verify(() => mockRepository.getCommentLikeCount(commentId)).called(1);
      });
      
      test('should check if user has liked comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';
        
        // Stub the repository method
        when(() => mockRepository.hasUserLikedComment(commentId, userId))
            .thenAnswer((_) async => true);
        
        // Act
        final hasLiked = await mockRepository.hasUserLikedComment(commentId, userId);
        
        // Assert
        expect(hasLiked, isTrue);
        verify(() => mockRepository.hasUserLikedComment(commentId, userId)).called(1);
      });
    });
    
    group('Comment Statistics', () {
      test('should get comment statistics for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        
        final expectedStats = CommentStatistics(
          totalComments: 10,
          totalReplies: 5,
          totalLikes: 25,
          lastCommentAt: DateTime.now(),
        );
        
        // Stub the repository method
        when(() => mockRepository.getCommentStatistics(recipeId))
            .thenAnswer((_) async => expectedStats);
        
        // Act
        final stats = await mockRepository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(10));
        expect(stats.totalReplies, equals(5));
        expect(stats.totalLikes, equals(25));
        expect(stats.lastCommentAt, isNotNull);
        
        // Verify the method was called
        verify(() => mockRepository.getCommentStatistics(recipeId)).called(1);
      });
      
      test('should handle recipe with no comments', () async {
        // Arrange
        const recipeId = 'recipe_with_no_comments';
        
        final expectedStats = CommentStatistics(
          totalComments: 0,
          totalReplies: 0,
          totalLikes: 0,
        );
        
        // Stub the repository method
        when(() => mockRepository.getCommentStatistics(recipeId))
            .thenAnswer((_) async => expectedStats);
        
        // Act
        final stats = await mockRepository.getCommentStatistics(recipeId);
        
        // Assert
        expect(stats.totalComments, equals(0));
        expect(stats.totalReplies, equals(0));
        expect(stats.totalLikes, equals(0));
        expect(stats.lastCommentAt, isNull);
        
        // Verify the method was called
        verify(() => mockRepository.getCommentStatistics(recipeId)).called(1);
      });
    });
  });
}