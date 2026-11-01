// test/unit/services/unified/operations/modules/comment_crud_operations_test.dart

/// Tests for CommentCrudOperations — comment creation, reading, editing,
/// deletion, and query methods.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/comment_crud_operations.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:butlery/services/user_service.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

/// Local pure-Mock AnalyticsService — avoids depending on the concrete
/// @override methods in production_mocks.dart MockAnalyticsService.
class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockSocialEventsTracker extends Mock implements SocialEventsTracker {}

class _MockUserService extends Mock implements UserService {}

class _StubBlockedUserFilter implements BlockedUserFilter {
  _StubBlockedUserFilter(this._blocked);

  final Set<String> _blocked;

  @override
  Future<Set<String>> currentBlockedIds() async => _blocked;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CommentCrudOperations', () {
    late MockCommentsRepository mockCommentsRepository;
    late _MockAnalyticsService mockAnalyticsService;
    late _MockUserService mockUserService;
    late _MockSocialEventsTracker mockSocialTracker;
    late CommentCrudOperations operations;
    late RecipeComment testComment;

    setUpAll(() async {
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
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();

      mockCommentsRepository = MockCommentsRepository();
      mockAnalyticsService = _MockAnalyticsService();

      // Stub analytics so createComment doesn't throw
      when(
        () => mockAnalyticsService.logCommentCreated(
          recipeId: any(named: 'recipeId'),
          commentLength: any(named: 'commentLength'),
        ),
      ).thenAnswer((_) async {});

      // Comment creation also reaches into `.social.logFirstCommentIfMilestone`
      // (BUT-593). Stub the tracker so the milestone path is a no-op in this
      // suite — milestone behavior itself is covered in
      // social_events_tracker_milestone_test.dart.
      mockSocialTracker = _MockSocialEventsTracker();
      when(
        () => mockSocialTracker.logFirstCommentIfMilestone(
          userId: any(named: 'userId'),
          joinedAt: any(named: 'joinedAt'),
        ),
      ).thenAnswer((_) async => false);
      when(() => mockAnalyticsService.social).thenReturn(mockSocialTracker);

      mockUserService = _MockUserService();
      when(() => mockUserService.currentUserProfile).thenReturn(null);

      operations = CommentCrudOperations(
        commentsRepository: mockCommentsRepository,
        analyticsService: mockAnalyticsService,
        userService: mockUserService,
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
        when(
          () => mockCommentsRepository.addComment(
            recipeId: 'recipe_1',
            userId: 'user_456',
            content: 'Great recipe!',
            parentCommentId: null,
          ),
        ).thenAnswer((_) async => testComment);

        final commentId = await operations.createComment(
          recipeId: 'recipe_1',
          content: 'Great recipe!',
          authorId: 'user_456',
          authorDisplayName: 'Test User',
        );

        expect(commentId, equals('comment_1'));
        verify(
          () => mockCommentsRepository.addComment(
            recipeId: 'recipe_1',
            userId: 'user_456',
            content: 'Great recipe!',
            parentCommentId: null,
          ),
        ).called(1);
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
        verifyNever(
          () => mockCommentsRepository.addComment(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            parentCommentId: any(named: 'parentCommentId'),
          ),
        );
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

        when(
          () => mockCommentsRepository.addComment(
            recipeId: 'recipe_1',
            userId: 'user_789',
            content: 'I agree!',
            parentCommentId: 'comment_1',
          ),
        ).thenAnswer((_) async => replyComment);

        final replyId = await operations.createComment(
          recipeId: 'recipe_1',
          content: 'I agree!',
          authorId: 'user_789',
          authorDisplayName: 'Reply User',
          parentCommentId: 'comment_1',
        );

        expect(replyId, equals('reply_1'));
        verify(
          () => mockCommentsRepository.addComment(
            recipeId: 'recipe_1',
            userId: 'user_789',
            content: 'I agree!',
            parentCommentId: 'comment_1',
          ),
        ).called(1);
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

        when(
          () => mockCommentsRepository.getCommentsForRecipe('recipe_1'),
        ).thenAnswer((_) async => [olderComment, testComment]);

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

        when(
          () => mockCommentsRepository.getCommentsForRecipe('recipe_1'),
        ).thenAnswer((_) async => [newComment, oldComment]);

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

        when(
          () => mockCommentsRepository.getCommentsForRecipe('recipe_1'),
        ).thenAnswer((_) async => comments);

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
        when(
          () => mockCommentsRepository.updateComment(
            'comment_1',
            'Updated comment!',
          ),
        ).thenAnswer((_) async {});

        final success = await operations.editComment(
          commentId: 'comment_1',
          newContent: 'Updated comment!',
          currentUserId: 'user_456',
        );

        expect(success, isTrue);
        verify(
          () => mockCommentsRepository.updateComment(
            'comment_1',
            'Updated comment!',
          ),
        ).called(1);
      });

      test(
        'should not validate author (current implementation limitation)',
        () async {
          when(
            () => mockCommentsRepository.updateComment(
              'comment_1',
              'Updated comment!',
            ),
          ).thenAnswer((_) async {});

          final success = await operations.editComment(
            commentId: 'comment_1',
            newContent: 'Updated comment!',
            currentUserId: 'user_789', // Not the author — still succeeds
          );

          expect(success, isTrue);
          verify(
            () => mockCommentsRepository.updateComment(
              'comment_1',
              'Updated comment!',
            ),
          ).called(1);
        },
      );

      test('should fail with empty content', () async {
        final success = await operations.editComment(
          commentId: 'comment_1',
          newContent: '  ',
          currentUserId: 'user_456',
        );

        expect(success, isFalse);
        verifyNever(
          () => mockCommentsRepository.updateComment(
            any(),
            any(),
          ),
        );
      });
    });

    // ---- Deletion ----

    group('Comment Deletion', () {
      test('should delete comment successfully', () async {
        when(
          () => mockCommentsRepository.deleteComment('comment_1'),
        ).thenAnswer((_) async {});

        final success = await operations.deleteComment(
          commentId: 'comment_1',
          currentUserId: 'user_456',
          canDeleteValidator: (commentId) => true,
        );

        expect(success, isTrue);
        verify(
          () => mockCommentsRepository.deleteComment('comment_1'),
        ).called(1);
      });

      test(
        'should not validate permission (current implementation limitation)',
        () async {
          when(
            () => mockCommentsRepository.deleteComment('comment_1'),
          ).thenAnswer((_) async {});

          final success = await operations.deleteComment(
            commentId: 'comment_1',
            currentUserId: 'user_789',
            canDeleteValidator: (commentId) => false, // Validator is ignored
          );

          expect(success, isTrue);
          verify(
            () => mockCommentsRepository.deleteComment('comment_1'),
          ).called(1);
        },
      );
    });

    // ---- Queries ----

    group('Comment Queries', () {
      test('should return comment for getCommentById when found', () async {
        when(
          () => mockCommentsRepository.read('comment_1'),
        ).thenAnswer((_) async => testComment);

        final comment = await operations.getCommentById(commentId: 'comment_1');

        expect(comment, isNotNull);
        expect(comment?.id, equals('comment_1'));
      });

      test('should return null for getCommentById when not found', () async {
        when(
          () => mockCommentsRepository.read('unknown'),
        ).thenAnswer((_) async => null);

        final comment = await operations.getCommentById(commentId: 'unknown');

        expect(comment, isNull);
      });

      test(
        'should return true for commentExists when comment exists',
        () async {
          when(
            () => mockCommentsRepository.read('comment_1'),
          ).thenAnswer((_) async => testComment);

          final exists = await operations.commentExists(commentId: 'comment_1');

          expect(exists, isTrue);
        },
      );

      test('should return false for commentExists when not found', () async {
        when(
          () => mockCommentsRepository.read('unknown'),
        ).thenAnswer((_) async => null);

        final exists = await operations.commentExists(commentId: 'unknown');

        expect(exists, isFalse);
      });

      test('should get comment count', () async {
        when(
          () => mockCommentsRepository.getCommentsForRecipe('recipe_1'),
        ).thenAnswer((_) async => [testComment]);

        final count = await operations.getCommentCount(recipeId: 'recipe_1');

        expect(count, equals(1));
      });
    });
    group('injected collaborators (BUT-1508)', () {
      test('the first-comment milestone reads joinedAt from the injected '
          'profile service', () async {
        final joined = DateTime(2025, 3, 4);
        when(() => mockUserService.currentUserProfile).thenReturn(
          UserProfile(
            uid: 'user_456',
            displayName: 'Test User',
            email: 'test@example.com',
            joinedAt: joined,
            lastActiveAt: joined,
          ),
        );
        when(
          () => mockCommentsRepository.addComment(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            parentCommentId: any(named: 'parentCommentId'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).thenAnswer((_) async => testComment);

        await operations.createComment(
          recipeId: 'recipe_1',
          content: 'Great recipe!',
          authorId: 'user_456',
          authorDisplayName: 'Test User',
        );

        verify(
          () => mockSocialTracker.logFirstCommentIfMilestone(
            userId: 'user_456',
            joinedAt: joined,
          ),
        ).called(1);
      });

      test(
        'getComments drops authors blocked by the injected filter',
        () async {
          final filtered = CommentCrudOperations(
            commentsRepository: mockCommentsRepository,
            analyticsService: mockAnalyticsService,
            userService: mockUserService,
            blockedFilter: _StubBlockedUserFilter(const {'blocked_author'}),
          );
          final blockedComment = RecipeComment(
            id: 'comment_2',
            recipeId: 'recipe_1',
            authorId: 'blocked_author',
            authorDisplayName: 'Blocked',
            text: 'Hidden',
            createdAt: DateTime.now(),
          );
          when(
            () => mockCommentsRepository.getCommentsForRecipe('recipe_1'),
          ).thenAnswer((_) async => [testComment, blockedComment]);

          final result = await filtered.getComments(recipeId: 'recipe_1');

          expect(result.map((c) => c.id), ['comment_1']);
        },
      );
    });
  });
}
