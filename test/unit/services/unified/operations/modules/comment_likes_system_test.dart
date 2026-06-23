// test/unit/services/unified/operations/modules/comment_likes_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/comment_likes_system.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:get_it/get_it.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CommentLikesSystem', () {
    late MockCommentsRepository mockCommentsRepository;
    // late RecipeComment testComment; // Removed - unused

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(
        RecipeComment(
          id: 'test',
          recipeId: 'test',
          authorId: 'test',
          authorDisplayName: 'Test',
          text: 'Test',
          createdAt: DateTime.now(),
        ),
      );

      // Create mock repository
      mockCommentsRepository = MockCommentsRepository();

      // Register mock in GetIt BEFORE CommentLikesSystem class is loaded
      final getIt = GetIt.instance;
      if (getIt.isRegistered<CommentsRepository>()) {
        getIt.unregister<CommentsRepository>();
      }
      getIt.registerSingleton<CommentsRepository>(mockCommentsRepository);
    });

    setUp(() async {
      // Don't call BaseUnitTest.setupUnit() since we manually registered mocks in setUpAll
      // due to static field initialization timing issue

      // Reset mocks for each test
      reset(mockCommentsRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Unregister mock from GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<CommentsRepository>()) {
        getIt.unregister<CommentsRepository>();
      }
    });

    group('Toggle Like Operations', () {
      test('should toggle like from unliked to liked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).thenAnswer((_) async => false);
        when(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_123'),
        ).thenAnswer((_) async {});

        // Act
        final result = await CommentLikesSystem.toggleCommentLike(
          commentId: 'comment_1',
          currentUserId: 'user_123',
        );

        // Assert
        expect(result, equals('liked'));
        verify(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).called(1);
        verify(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_123'),
        ).called(1);
      });

      test('should toggle like from liked to unliked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).thenAnswer((_) async => true);
        when(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_789'),
        ).thenAnswer((_) async {});

        // Act
        final result = await CommentLikesSystem.toggleCommentLike(
          commentId: 'comment_1',
          currentUserId: 'user_789',
        );

        // Assert
        expect(result, equals('unliked'));
        verify(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).called(1);
        verify(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_789'),
        ).called(1);
      });

      test('should handle toggle error gracefully', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).thenThrow(Exception('Database error'));

        // Act
        final result = await CommentLikesSystem.toggleCommentLike(
          commentId: 'comment_1',
          currentUserId: 'user_123',
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('Like Operations', () {
      test('should like comment when not already liked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).thenAnswer((_) async => false);
        when(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_123'),
        ).thenAnswer((_) async {});

        // Act
        final success = await CommentLikesSystem.likeComment(
          commentId: 'comment_1',
          userId: 'user_123',
        );

        // Assert
        expect(success, isTrue);
        verify(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_123'),
        ).called(1);
      });

      test('should not like comment when already liked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).thenAnswer((_) async => true);

        // Act
        final success = await CommentLikesSystem.likeComment(
          commentId: 'comment_1',
          userId: 'user_789',
        );

        // Assert
        expect(success, isFalse);
        verifyNever(
          () => mockCommentsRepository.toggleCommentLike(any(), any()),
        );
      });

      test('should handle like error gracefully', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).thenThrow(Exception('Database error'));

        // Act
        final success = await CommentLikesSystem.likeComment(
          commentId: 'comment_1',
          userId: 'user_123',
        );

        // Assert
        expect(success, isFalse);
      });
    });

    group('Unlike Operations', () {
      test('should unlike comment when already liked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).thenAnswer((_) async => true);
        when(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_789'),
        ).thenAnswer((_) async {});

        // Act
        final success = await CommentLikesSystem.unlikeComment(
          commentId: 'comment_1',
          userId: 'user_789',
        );

        // Assert
        expect(success, isTrue);
        verify(
          () =>
              mockCommentsRepository.toggleCommentLike('comment_1', 'user_789'),
        ).called(1);
      });

      test('should not unlike comment when not liked', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_123',
          ),
        ).thenAnswer((_) async => false);

        // Act
        final success = await CommentLikesSystem.unlikeComment(
          commentId: 'comment_1',
          userId: 'user_123',
        );

        // Assert
        expect(success, isFalse);
        verifyNever(
          () => mockCommentsRepository.toggleCommentLike(any(), any()),
        );
      });
    });

    group('Like Queries', () {
      test('should check if user has liked comment', () async {
        // Arrange
        when(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).thenAnswer((_) async => true);

        // Act
        final hasLiked = await CommentLikesSystem.hasUserLikedComment(
          commentId: 'comment_1',
          userId: 'user_789',
        );

        // Assert
        expect(hasLiked, isTrue);
        verify(
          () => mockCommentsRepository.hasUserLikedComment(
            'comment_1',
            'user_789',
          ),
        ).called(1);
      });

      test('should get like count for comment', () async {
        // Arrange
        when(
          () => mockCommentsRepository.getCommentLikeCount('comment_1'),
        ).thenAnswer((_) async => 1);

        // Act
        final count = await CommentLikesSystem.getCommentLikeCount(
          commentId: 'comment_1',
        );

        // Assert
        expect(count, equals(1)); // testComment has 1 like
        verify(
          () => mockCommentsRepository.getCommentLikeCount('comment_1'),
        ).called(1);
      });

      test('should get list of users who liked comment', () async {
        // Arrange
        when(
          () =>
              mockCommentsRepository.getCommentLikers('comment_2', limit: 100),
        ).thenAnswer((_) async => ['user_1', 'user_2', 'user_3']);

        // Act
        final userIds = await CommentLikesSystem.getCommentLikers(
          commentId: 'comment_2',
        );

        // Assert
        expect(userIds.length, equals(3));
        expect(userIds, containsAll(['user_1', 'user_2', 'user_3']));
        verify(
          () =>
              mockCommentsRepository.getCommentLikers('comment_2', limit: 100),
        ).called(1);
      });
    });

    group('Batch Operations', () {
      test('should process multiple likes efficiently', () async {
        // Arrange
        final commentIds = ['comment_1', 'comment_2', 'comment_3'];

        for (final commentId in commentIds) {
          when(
            () => mockCommentsRepository.hasUserLikedComment(
              commentId,
              'user_123',
            ),
          ).thenAnswer((_) async => false);
          when(
            () =>
                mockCommentsRepository.toggleCommentLike(commentId, 'user_123'),
          ).thenAnswer((_) async {});
        }

        // Act
        final results = <String, bool>{};
        for (final commentId in commentIds) {
          results[commentId] = await CommentLikesSystem.likeComment(
            commentId: commentId,
            userId: 'user_123',
          );
        }

        // Assert
        expect(results.values.every((success) => success), isTrue);
        for (final commentId in commentIds) {
          verify(
            () =>
                mockCommentsRepository.toggleCommentLike(commentId, 'user_123'),
          ).called(1);
        }
      });
    });
  });
}
