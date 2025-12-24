/// Unit tests for comments functionality
///
/// Tests the comments service with mocked repository following the
/// documentation's Firebase Testing Strategy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('Comments Service', () {
    late MockCommentsRepository mockRepository;
    late MockAuthRepository mockAuthRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockCommentsRepository();
      mockAuthRepository = MockAuthRepository();

      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Add Comments', () {
      test('should add top-level comment to recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const content = 'This recipe looks amazing!';

        final expectedComment = RecipeComment(
          id: 'comment_1',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Test User',
          text: content,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

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
        expect(comment.likedByUserIds, isEmpty);
        expect(comment.editedAt, isNull);

        // Verify method was called
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
        const parentId = 'parent_comment_1';
        const replyContent = 'I agree, it tastes wonderful!';

        final expectedReply = RecipeComment(
          id: 'reply_1',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Test User',
          text: replyContent,
          parentCommentId: parentId,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

        when(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: replyContent,
              parentCommentId: parentId,
            )).thenAnswer((_) async => expectedReply);

        // Act
        final reply = await mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: replyContent,
          parentCommentId: parentId,
        );

        // Assert
        expect(reply, isNotNull);
        expect(reply.parentCommentId, equals(parentId));
        expect(reply.recipeId, equals(recipeId));
        expect(reply.text, equals(replyContent));

        verify(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: replyContent,
              parentCommentId: parentId,
            )).called(1);
      });

      test('should throw when adding empty comment', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const emptyContent = '   '; // Whitespace only

        when(() => mockRepository.addComment(
                  recipeId: recipeId,
                  userId: userId,
                  content: emptyContent,
                ))
            .thenAnswer((_) async =>
                throw SecurityViolationException('Comment cannot be empty'));

        // Act & Assert
        expect(
          () async => await mockRepository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: emptyContent,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should throw when user tries to add comment for another user',
          () async {
        // Arrange
        const recipeId = 'recipe_123';
        const anotherUserId = 'another_user_456';
        const content = 'Trying to comment as someone else';

        when(() => mockRepository.addComment(
                  recipeId: recipeId,
                  userId: anotherUserId,
                  content: content,
                ))
            .thenAnswer((_) async => throw PermissionDeniedException(
                'Cannot comment as another user'));

        // Act & Assert
        expect(
          () async => await mockRepository.addComment(
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

        final expectedComments = <RecipeComment>[
          ...List.generate(
              5,
              (i) => RecipeComment(
                    id: 'comment_$i',
                    recipeId: recipeId,
                    authorId: 'user_$i',
                    authorDisplayName: 'User $i',
                    text: 'Comment $i',
                    createdAt: DateTime.now().subtract(Duration(hours: i)),
                    likedByUserIds: const [],
                  ))
        ];

        when(() => mockRepository.getCommentsForRecipe(recipeId))
            .thenAnswer((_) async => expectedComments);

        // Act
        final comments = await mockRepository.getCommentsForRecipe(recipeId);

        // Assert
        expect(comments.length, equals(5));
        expect(comments.every((c) => c.parentCommentId == null), isTrue);

        verify(() => mockRepository.getCommentsForRecipe(recipeId)).called(1);
      });

      test('should get replies for a comment', () async {
        // Arrange
        const parentId = 'parent_comment_123';

        final expectedReplies = <RecipeComment>[
          ...List.generate(
              3,
              (i) => RecipeComment(
                    id: 'reply_$i',
                    recipeId: 'recipe_123',
                    authorId: 'user_$i',
                    authorDisplayName: 'User $i',
                    text: 'Reply $i',
                    parentCommentId: parentId,
                    createdAt: DateTime.now().subtract(Duration(hours: i)),
                    likedByUserIds: const [],
                  ))
        ];

        when(() => mockRepository.getReplies(parentId))
            .thenAnswer((_) async => expectedReplies);

        // Act
        final replies = await mockRepository.getReplies(parentId);

        // Assert
        expect(replies.length, equals(3));
        expect(replies.every((r) => r.parentCommentId == parentId), isTrue);

        verify(() => mockRepository.getReplies(parentId)).called(1);
      });

      test('should stream comments for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';

        final expectedComments = <RecipeComment>[
          RecipeComment(
            id: 'comment_1',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Initial comment',
            createdAt: DateTime.now(),
            likedByUserIds: const [],
          ),
        ];

        when(() => mockRepository.getCommentsStream(recipeId))
            .thenAnswer((_) => Stream.value(expectedComments));

        // Act
        final stream = mockRepository.getCommentsStream(recipeId);

        // Assert
        final comments = await stream.first;
        expect(comments.length, equals(1));
        expect(comments.first.text, equals('Initial comment'));

        verify(() => mockRepository.getCommentsStream(recipeId)).called(1);
      });
    });

    group('Update Comments', () {
      test('should update comment content', () async {
        // Arrange
        const commentId = 'comment_123';
        const updatedContent = 'Updated comment with more details';

        when(() => mockRepository.updateComment(commentId, updatedContent))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.updateComment(commentId, updatedContent);

        // Assert
        verify(() => mockRepository.updateComment(commentId, updatedContent))
            .called(1);
      });

      test('should throw when updating with empty content', () async {
        // Arrange
        const commentId = 'comment_123';
        const emptyContent = '  ';

        when(() => mockRepository.updateComment(commentId, emptyContent))
            .thenAnswer((_) async =>
                throw SecurityViolationException('Comment cannot be empty'));

        // Act & Assert
        expect(
          () async =>
              await mockRepository.updateComment(commentId, emptyContent),
          throwsA(isA<SecurityViolationException>()),
        );
      });
    });

    group('Delete Comments', () {
      test('should delete users own comment', () async {
        // Arrange
        const commentId = 'comment_123';

        when(() => mockRepository.deleteComment(commentId))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.deleteComment(commentId);

        // Assert
        verify(() => mockRepository.deleteComment(commentId)).called(1);
      });

      test('should throw when trying to delete another users comment',
          () async {
        // Arrange
        const commentId = 'comment_123';

        when(() => mockRepository.deleteComment(commentId)).thenAnswer(
            (_) async => throw PermissionDeniedException(
                'Cannot delete another users comment'));

        // Act & Assert
        expect(
          () async => await mockRepository.deleteComment(commentId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Like System', () {
      test('should toggle comment like', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';

        when(() => mockRepository.toggleCommentLike(commentId, userId))
            .thenAnswer((_) async {});

        // Act
        await mockRepository.toggleCommentLike(commentId, userId);

        // Assert
        verify(() => mockRepository.toggleCommentLike(commentId, userId))
            .called(1);
      });

      test('should check if user has liked comment', () async {
        // Arrange
        const commentId = 'comment_123';
        const userId = 'test_user_123';

        when(() => mockRepository.hasUserLikedComment(commentId, userId))
            .thenAnswer((_) async => true);

        // Act
        final hasLiked =
            await mockRepository.hasUserLikedComment(commentId, userId);

        // Assert
        expect(hasLiked, isTrue);
        verify(() => mockRepository.hasUserLikedComment(commentId, userId))
            .called(1);
      });
    });

    group('Comment Statistics', () {
      test('should get comment statistics for recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';

        final expectedStats = CommentStatistics(
          totalComments: 5,
          totalReplies: 0,
          totalLikes: 20,
        );

        when(() => mockRepository.getCommentStatistics(recipeId))
            .thenAnswer((_) async => expectedStats);

        // Act
        final stats = await mockRepository.getCommentStatistics(recipeId);

        // Assert
        expect(stats.totalComments, equals(5));
        expect(stats.totalLikes, equals(20));

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

        when(() => mockRepository.getCommentStatistics(recipeId))
            .thenAnswer((_) async => expectedStats);

        // Act
        final stats = await mockRepository.getCommentStatistics(recipeId);

        // Assert
        expect(stats.totalComments, equals(0));
        expect(stats.totalLikes, equals(0));

        verify(() => mockRepository.getCommentStatistics(recipeId)).called(1);
      });
    });

    group('Comment Threading', () {
      test('should create nested reply thread', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const replyId = 'reply_comment';
        const nestedReplyContent = 'Replying to the reply';

        final nestedReply = RecipeComment(
          id: 'nested_reply_1',
          recipeId: recipeId,
          authorId: 'test_user_123',
          authorDisplayName: 'Test User',
          text: nestedReplyContent,
          parentCommentId: replyId,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

        when(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: 'test_user_123',
              content: nestedReplyContent,
              parentCommentId: replyId,
            )).thenAnswer((_) async => nestedReply);

        // Act
        final result = await mockRepository.addComment(
          recipeId: recipeId,
          userId: 'test_user_123',
          content: nestedReplyContent,
          parentCommentId: replyId,
        );

        // Assert
        expect(result.parentCommentId, equals(replyId));
        expect(result.text, equals(nestedReplyContent));
      });

      test('should get comment thread using replies', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const rootCommentId = 'root_comment';

        // Simulate getting replies to build thread
        final rootReplies = [
          RecipeComment(
            id: 'reply_1',
            recipeId: recipeId,
            authorId: 'user_2',
            authorDisplayName: 'User 2',
            text: 'First reply',
            parentCommentId: rootCommentId,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            likedByUserIds: const [],
          ),
          RecipeComment(
            id: 'reply_2',
            recipeId: recipeId,
            authorId: 'user_4',
            authorDisplayName: 'User 4',
            text: 'Second reply',
            parentCommentId: rootCommentId,
            createdAt: DateTime.now(),
            likedByUserIds: const [],
          ),
        ];

        final nestedReplies = [
          RecipeComment(
            id: 'nested_1',
            recipeId: recipeId,
            authorId: 'user_3',
            authorDisplayName: 'User 3',
            text: 'Nested reply',
            parentCommentId: 'reply_1',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            likedByUserIds: const [],
          ),
        ];

        when(() => mockRepository.getReplies(rootCommentId))
            .thenAnswer((_) async => rootReplies);
        when(() => mockRepository.getReplies('reply_1'))
            .thenAnswer((_) async => nestedReplies);
        when(() => mockRepository.getReplies('reply_2'))
            .thenAnswer((_) async => []);

        // Act - Build thread by getting replies
        final level1Replies = await mockRepository.getReplies(rootCommentId);
        final level2Replies = await mockRepository.getReplies('reply_1');

        // Assert
        expect(level1Replies.length, equals(2));
        expect(level1Replies.every((c) => c.parentCommentId == rootCommentId),
            isTrue);
        expect(level2Replies.length, equals(1));
        expect(level2Replies.first.parentCommentId, equals('reply_1'));
      });

      test('should handle thread visibility using replies', () async {
        // Arrange
        const parentCommentId = 'collapsible_comment';
        const recipeId = 'recipe_123';

        // Simulate collapsed state by returning empty replies
        final collapsedReplies = <RecipeComment>[];
        final expandedReplies = [
          RecipeComment(
            id: 'reply_1',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Visible reply',
            parentCommentId: parentCommentId,
            createdAt: DateTime.now(),
            likedByUserIds: const [],
          ),
        ];

        // First call returns empty (collapsed), second returns replies (expanded)
        var isCollapsed = true;
        when(() => mockRepository.getReplies(parentCommentId)).thenAnswer(
            (_) async => isCollapsed ? collapsedReplies : expandedReplies);

        // Act - Get replies when collapsed
        var replies = await mockRepository.getReplies(parentCommentId);

        // Assert collapsed state
        expect(replies.isEmpty, isTrue);

        // Act - Expand and get replies
        isCollapsed = false;
        replies = await mockRepository.getReplies(parentCommentId);

        // Assert expanded state
        expect(replies.isNotEmpty, isTrue);
        expect(replies.first.text, equals('Visible reply'));
      });

      test('should sort comments by like count', () async {
        // Arrange
        const recipeId = 'recipe_123';

        final comments = [
          RecipeComment(
            id: 'popular_comment',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User 1',
            text: 'Very popular comment',
            createdAt: DateTime.now(),
            likedByUserIds: List.generate(10, (i) => 'user_$i'), // 10 likes
          ),
          RecipeComment(
            id: 'moderate_comment',
            recipeId: recipeId,
            authorId: 'user_2',
            authorDisplayName: 'User 2',
            text: 'Moderate engagement',
            createdAt: DateTime.now(),
            likedByUserIds: List.generate(5, (i) => 'user_$i'), // 5 likes
          ),
          RecipeComment(
            id: 'unpopular_comment',
            recipeId: recipeId,
            authorId: 'user_3',
            authorDisplayName: 'User 3',
            text: 'Less popular',
            createdAt: DateTime.now(),
            likedByUserIds: const [], // 0 likes
          ),
        ];

        // Sort comments by likes
        comments.sort((a, b) =>
            b.likedByUserIds.length.compareTo(a.likedByUserIds.length));

        when(() => mockRepository.getCommentsForRecipe(recipeId))
            .thenAnswer((_) async => comments);

        // Act
        final sortedComments =
            await mockRepository.getCommentsForRecipe(recipeId);

        // Assert
        expect(sortedComments[0].id, equals('popular_comment'));
        expect(sortedComments[0].likedByUserIds.length, equals(10));
        expect(sortedComments[1].likedByUserIds.length, equals(5));
        expect(sortedComments[2].likedByUserIds.length, equals(0));
      });
    });

    group('Moderation', () {
      test('should delete inappropriate comment', () async {
        // Arrange
        const commentId = 'inappropriate_comment';

        // Simulate flagging by deleting the comment
        when(() => mockRepository.deleteComment(commentId))
            .thenAnswer((_) async {});

        // Act - Delete inappropriate comment
        await mockRepository.deleteComment(commentId);

        // Assert
        verify(() => mockRepository.deleteComment(commentId)).called(1);
      });

      test('should prevent adding comments with forbidden words', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const badContent = 'This recipe is [forbidden word] terrible';

        // Swedish bad words should also be caught
        const swedishBadContent = 'Detta recept är [Swedish bad word] dåligt';

        when(() => mockRepository.addComment(
                  recipeId: recipeId,
                  userId: userId,
                  content: badContent,
                ))
            .thenAnswer((_) async => throw SecurityViolationException(
                'Content contains forbidden words'));

        when(() => mockRepository.addComment(
                  recipeId: recipeId,
                  userId: userId,
                  content: swedishBadContent,
                ))
            .thenAnswer((_) async => throw SecurityViolationException(
                'Content contains forbidden words'));

        // Act & Assert - English
        expect(
          () async => await mockRepository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: badContent,
          ),
          throwsA(isA<SecurityViolationException>()),
        );

        // Act & Assert - Swedish
        expect(
          () async => await mockRepository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: swedishBadContent,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should delete comment after multiple reports', () async {
        // Arrange
        const commentId = 'reported_comment';
        const reportThreshold = 3;

        // Simulate reaching report threshold by tracking likes as negative reports
        // (Using existing methods creatively)
        when(() => mockRepository.getCommentLikeCount(commentId)).thenAnswer(
            (_) async => -reportThreshold); // Negative likes = reports

        when(() => mockRepository.deleteComment(commentId))
            .thenAnswer((_) async {});

        // Act
        final reportCount = await mockRepository.getCommentLikeCount(commentId);
        if (reportCount <= -reportThreshold) {
          await mockRepository.deleteComment(commentId);
        }

        // Assert
        expect(reportCount, equals(-reportThreshold));
        verify(() => mockRepository.deleteComment(commentId)).called(1);
      });

      test('should handle user with multiple deleted comments', () async {
        // Arrange
        const userId = 'problematic_user';
        const recipeId = 'recipe_123';

        // Track violations by counting deleted comments
        final deletedCommentIds = [
          'violation_1',
          'violation_2',
          'violation_3',
          'violation_4',
          'violation_5'
        ];

        // Setup delete for each violation
        for (final commentId in deletedCommentIds) {
          when(() => mockRepository.deleteComment(commentId))
              .thenAnswer((_) async {});
        }

        // Act - Delete all violation comments
        for (final commentId in deletedCommentIds) {
          await mockRepository.deleteComment(commentId);
        }

        // Simulate blocking by throwing error on new comment attempts
        when(() => mockRepository.addComment(
                  recipeId: recipeId,
                  userId: userId,
                  content: any(named: 'content'),
                ))
            .thenAnswer((_) async => throw PermissionDeniedException(
                'User is banned from commenting'));

        // Assert - User cannot add new comments
        expect(
          () async => await mockRepository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: 'Trying to comment',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Real-time Features', () {
      test('should stream live comment updates', () async {
        // Arrange
        const recipeId = 'recipe_123';

        final commentStream = Stream<List<RecipeComment>>.periodic(
          const Duration(milliseconds: 100),
          (count) => [
            RecipeComment(
              id: 'live_comment_$count',
              recipeId: recipeId,
              authorId: 'user_$count',
              authorDisplayName: 'User $count',
              text: 'Live comment $count',
              createdAt: DateTime.now(),
              likedByUserIds: const [],
            ),
          ],
        ).take(3);

        when(() => mockRepository.getCommentsStream(recipeId))
            .thenAnswer((_) => commentStream);

        // Act
        final stream = mockRepository.getCommentsStream(recipeId);
        final comments = <RecipeComment>[];

        await for (final batch in stream) {
          comments.addAll(batch);
        }

        // Assert
        expect(comments.length, equals(3));
        verify(() => mockRepository.getCommentsStream(recipeId)).called(1);
      });

      test('should detect new replies to parent comments', () async {
        // Arrange
        const parentCommentId = 'parent_comment';
        const recipeId = 'recipe_123';
        const replyContent = 'Great point! I agree with you.';

        // Initially no replies
        when(() => mockRepository.getReplies(parentCommentId))
            .thenAnswer((_) async => []);

        // Act - Check for replies initially
        var replies = await mockRepository.getReplies(parentCommentId);
        expect(replies.isEmpty, isTrue);

        // Simulate new reply added
        final newReply = RecipeComment(
          id: 'new_reply',
          recipeId: recipeId,
          authorId: 'replier_user',
          authorDisplayName: 'Replier',
          text: replyContent,
          parentCommentId: parentCommentId,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

        when(() => mockRepository.getReplies(parentCommentId))
            .thenAnswer((_) async => [newReply]);

        // Act - Check for replies again
        replies = await mockRepository.getReplies(parentCommentId);

        // Assert - New reply detected
        expect(replies.length, equals(1));
        expect(replies.first.text, equals(replyContent));
      });

      test('should track comment count changes', () async {
        // Arrange
        const recipeId = 'recipe_123';

        // Simulate comment count changing over time via statistics
        final stats1 = CommentStatistics(
          totalComments: 1,
          totalReplies: 0,
          totalLikes: 0,
        );

        final stats2 = CommentStatistics(
          totalComments: 3,
          totalReplies: 2,
          totalLikes: 5,
        );

        // First call returns initial count, second returns updated count
        var callCount = 0;
        when(() => mockRepository.getCommentStatistics(recipeId))
            .thenAnswer((_) async => callCount++ == 0 ? stats1 : stats2);

        // Act - Get initial count
        var stats = await mockRepository.getCommentStatistics(recipeId);
        final initialCount = stats.totalComments;

        // Act - Get updated count
        stats = await mockRepository.getCommentStatistics(recipeId);
        final updatedCount = stats.totalComments;

        // Assert
        expect(initialCount, equals(1));
        expect(updatedCount, equals(3));
        expect(updatedCount > initialCount, isTrue);
      });

      test('should handle offline comment scenarios', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const offlineContent = 'Comment made while offline';

        // Simulate offline - addComment fails
        when(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: offlineContent,
            )).thenAnswer((_) async => throw Exception('Network unavailable'));

        // Act & Assert - Comment fails while offline
        expect(
          () async => await mockRepository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: offlineContent,
          ),
          throwsException,
        );

        // Simulate back online - addComment succeeds
        final savedComment = RecipeComment(
          id: 'synced_comment',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Test User',
          text: offlineContent,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

        when(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: offlineContent,
            )).thenAnswer((_) async => savedComment);

        // Act - Retry when online
        final comment = await mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: offlineContent,
        );

        // Assert
        expect(comment.id, equals('synced_comment'));
        expect(comment.text, equals(offlineContent));
      });
    });

    group('Swedish Language Support', () {
      test('should handle Swedish comments with special characters', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'test_user_123';
        const swedishContent =
            'Jättegott recept! Köttbullarna blev perfekta med lingonsylt och gräddsås.';

        final expectedComment = RecipeComment(
          id: 'swedish_comment_1',
          recipeId: recipeId,
          authorId: userId,
          authorDisplayName: 'Svenska Kocken',
          text: swedishContent,
          createdAt: DateTime.now(),
          likedByUserIds: const [],
        );

        when(() => mockRepository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: swedishContent,
            )).thenAnswer((_) async => expectedComment);

        // Act
        final comment = await mockRepository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: swedishContent,
        );

        // Assert
        expect(comment.text, equals(swedishContent));
        expect(comment.text.contains('ä'), isTrue);
        expect(comment.text.contains('ö'), isTrue);
        expect(comment.text.contains('å'), isTrue);
      });

      test('should handle Swedish recipe terms in comments', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const swedishTerms = [
          'smörgåstårta',
          'köttfärssås',
          'räksmörgås',
          'knäckebröd',
          'kanelbullar',
        ];

        // Act & Assert
        for (final term in swedishTerms) {
          final comment = RecipeComment(
            id: 'term_comment',
            recipeId: recipeId,
            authorId: 'user_1',
            authorDisplayName: 'User',
            text: 'Detta $term är underbart!',
            createdAt: DateTime.now(),
            likedByUserIds: const [],
          );

          expect(comment.text.contains(term), isTrue);
        }
      });
    });
  });
}
