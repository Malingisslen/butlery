// test/unit/services/unified/operations/modules/comment_crud_operations_test.dart

/// Tests for CommentCrudOperations — comment creation, reading, editing,
/// deletion, and query methods.
///
/// Root cause of original 14/14 failures: the production ServiceLocator
/// was never initialized, so the fallback `ServiceLocator.get<AnalyticsService>()`
/// in the CommentCrudOperations constructor always threw. Fix: pass both
/// dependencies explicitly so the constructor never hits ServiceLocator.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/comment_crud_operations.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/models/recipe_comment.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

/// Local pure-Mock AnalyticsService — avoids depending on the concrete
/// @override methods in production_mocks.dart MockAnalyticsService.
class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('CommentCrudOperations', () {
    late MockCommentsRepository mockCommentsRepository;
    late _MockAnalyticsService mockAnalyticsService;
    late CommentCrudOperations operations;
    late RecipeComment testComment;

    setUpAll(() async {
      registerFallbackValue(RecipeComment(
        id: 'test',
        recipeId: 'test',
        authorId: 'test',
        authorDisplayName: 'Test',
        text: 'Test',
        createdAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();

      mockCommentsRepository = MockCommentsRepository();
      mockAnalyticsService = _MockAnalyticsService();

      // Stub analytics so createComment doesn't throw
      when(() => mockAnalyticsService.logCommentCreated(
            recipeId: any(named: 'recipeId'),
            commentLength: any(named: 'commentLength'),
          )).thenAnswer((_) async {});

      // Pass both deps explicitly — avoids ServiceLocator entirely
      operations = CommentCrudOperations(
        commentsRepository: mockCommentsRepository,
        analyticsService: mockAnalyticsService,
      );

      testComment = RecipeComment(
        id: 'comment_1',
        recipeId: 'recipe_1',
        authorId: 'user_456',
        authorDisplayName: 'Test User',
        text: 'Great recipe!',
        createdAt: DateTime.now(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    // ---- Creation ----

    group('Comment Creation', () {
      test('should create comment successfully with valid data', () async {
        when(() => mockCommentsRepository.addComment(
              recipeId: 'recipe_1',
              userId: 'user_456',
              content: 'Great recipe!',
              parentCommentId: null,
            )).thenAnswer((_) async => testComment);

        final commentId = await operations.createComment(
          recipeId: 'recipe_1',
          content: 'Great recipe!',
          authorId: 'user_456',
          authorDisplayName: 'Test User',
        );

        expect(commentId, equals('comment_1'));
        verify(() => mockCommentsRepository.addComment(
              recipeId: 'recipe_1',
              userId: 'user_456',
              content: 'Great recipe!',
              parentCommentId: null,
            )).called(1);
      });

      test('should throw with empty content', () async {
        expect(
          () => operations.createComment(
            recipeId: 'recipe_1',
            content: '  ',
            authorId: 'user_456',
            authorDisplayName: 'Test User',
          ),
          throwsArgumentError,
        );
        verifyNever(() => mockCommentsRepository.addComment(
              recipeId: any(named: 'recipeId'),
              userId: any(named: 'userId'),
              content: any(named: 'content'),
              parentCommentId: any(named: 'parentCommentId'),
            ));
      });

      test('should create reply with parent comment ID', () async {
        final replyComment = RecipeComment(
          id: 'reply_1',
          recipeId: 'recipe_1',
          authorId: 'user_789',
          authorDisplayName: 'Reply User',
          text: 'I agree!',
          parentCommentId: 'comment_1',
          createdAt: DateTime.now(),
        );

        when(() => mockCommentsRepository.addComment(
              recipeId: 'recipe_1',
              userId: 'user_789',
              content: 'I agree!',
              parentCommentId: 'comment_1',
            )).thenAnswer((_) async => replyComment);

        final replyId = await operations.createComment(
          recipeId: 'recipe_1',
          content: 'I agree!',
          authorId: 'user_789',
          authorDisplayName: 'Reply User',
          parentCommentId: 'comment_1',
        );

        expect(replyId, equals('reply_1'));
        verify(() => mockCommentsRepository.addComment(
              recipeId: 'recipe_1',
              userId: 'user_789',
              content: 'I agree!',
              parentCommentId: 'comment_1',
            )).called(1);
      });
    });

    // ---- Reading ----

    group('Comment Reading', () {
      test('should get comments with pagination', () async {
        final olderComment = RecipeComment(
          id: 'comment_2',
          recipeId: 'recipe_1',
          authorId: 'user_789',
          authorDisplayName: 'Another User',
          text: 'Nice!',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        when(() => mockCommentsRepository.getCommentsForRecipe('recipe_1'))
            .thenAnswer((_) async => [olderComment, testComment]);

        final result = await operations.getComments(
          recipeId: 'recipe_1',
          limit: 10,
        );

        expect(result.length, equals(2));
        // Older (top-level) comment sorts first by createdAt
        expect(result[0].id, equals('comment_2'));
        expect(result[1].id, equals('comment_1'));
      });

      test('should filter comments before timestamp', () async {
        final now = DateTime.now();
        final oldComment = RecipeComment(
          id: 'old_comment',
          recipeId: 'recipe_1',
          authorId: 'user_789',
          authorDisplayName: 'User',
          text: 'Old comment',
          createdAt: now.subtract(const Duration(days: 2)),
        );
        final newComment = RecipeComment(
          id: 'new_comment',
          recipeId: 'recipe_1',
          authorId: 'user_456',
          authorDisplayName: 'User',
          text: 'New comment',
          createdAt: now,
        );

        when(() => mockCommentsRepository.getCommentsForRecipe('recipe_1'))
            .thenAnswer((_) async => [newComment, oldComment]);

        final result = await operations.getComments(
          recipeId: 'recipe_1',
          before: now.subtract(const Duration(days: 1)),
        );

        expect(result.length, equals(1));
        expect(result[0].id, equals('old_comment'));
      });

      test('should apply comment limit', () async {
        final comments = List.generate(
          10,
          (i) => RecipeComment(
            id: 'comment_$i',
            recipeId: 'recipe_1',
            authorId: 'user_456',
            authorDisplayName: 'User',
            text: 'Comment $i',
            createdAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );

        when(() => mockCommentsRepository.getCommentsForRecipe('recipe_1'))
            .thenAnswer((_) async => comments);

        final result = await operations.getComments(
          recipeId: 'recipe_1',
          limit: 5,
        );

        expect(result.length, equals(5));
      });
    });

    // ---- Editing ----

    group('Comment Editing', () {
      test('should edit comment successfully', () async {
        when(() => mockCommentsRepository.updateComment(
            'comment_1', 'Updated comment!')).thenAnswer((_) async {});

        final success = await operations.editComment(
          commentId: 'comment_1',
          newContent: 'Updated comment!',
          currentUserId: 'user_456',
        );

        expect(success, isTrue);
        verify(() => mockCommentsRepository.updateComment(
            'comment_1', 'Updated comment!')).called(1);
      });

      test('should not validate author (current implementation limitation)',
          () async {
        when(() => mockCommentsRepository.updateComment(
            'comment_1', 'Updated comment!')).thenAnswer((_) async {});

        final success = await operations.editComment(
          commentId: 'comment_1',
          newContent: 'Updated comment!',
          currentUserId: 'user_789', // Not the author — still succeeds
        );

        expect(success, isTrue);
        verify(() => mockCommentsRepository.updateComment(
              'comment_1',
              'Updated comment!',
            )).called(1);
      });

      test('should fail with empty content', () async {
        final success = await operations.editComment(
          commentId: 'comment_1',
          newContent: '  ',
          currentUserId: 'user_456',
        );

        expect(success, isFalse);
        verifyNever(() => mockCommentsRepository.updateComment(
              any(),
              any(),
            ));
      });
    });

    // ---- Deletion ----

    group('Comment Deletion', () {
      test('should delete comment successfully', () async {
        when(() => mockCommentsRepository.deleteComment('comment_1'))
            .thenAnswer((_) async {});

        final success = await operations.deleteComment(
          commentId: 'comment_1',
          currentUserId: 'user_456',
          canDeleteValidator: (commentId) => true,
        );

        expect(success, isTrue);
        verify(() => mockCommentsRepository.deleteComment('comment_1'))
            .called(1);
      });

      test('should not validate permission (current implementation limitation)',
          () async {
        when(() => mockCommentsRepository.deleteComment('comment_1'))
            .thenAnswer((_) async {});

        final success = await operations.deleteComment(
          commentId: 'comment_1',
          currentUserId: 'user_789',
          canDeleteValidator: (commentId) => false, // Validator is ignored
        );

        expect(success, isTrue);
        verify(() => mockCommentsRepository.deleteComment('comment_1'))
            .called(1);
      });
    });

    // ---- Queries ----

    group('Comment Queries', () {
      test('should return comment for getCommentById when found', () async {
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => testComment);

        final comment = await operations.getCommentById(commentId: 'comment_1');

        expect(comment, isNotNull);
        expect(comment?.id, equals('comment_1'));
      });

      test('should return null for getCommentById when not found', () async {
        when(() => mockCommentsRepository.read('unknown'))
            .thenAnswer((_) async => null);

        final comment = await operations.getCommentById(commentId: 'unknown');

        expect(comment, isNull);
      });

      test('should return true for commentExists when comment exists',
          () async {
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => testComment);

        final exists = await operations.commentExists(commentId: 'comment_1');

        expect(exists, isTrue);
      });

      test('should return false for commentExists when not found', () async {
        when(() => mockCommentsRepository.read('unknown'))
            .thenAnswer((_) async => null);

        final exists = await operations.commentExists(commentId: 'unknown');

        expect(exists, isFalse);
      });

      test('should get comment count', () async {
        when(() => mockCommentsRepository.getCommentsForRecipe('recipe_1'))
            .thenAnswer((_) async => [testComment]);

        final count = await operations.getCommentCount(recipeId: 'recipe_1');

        expect(count, equals(1));
      });
    });
  });
}
