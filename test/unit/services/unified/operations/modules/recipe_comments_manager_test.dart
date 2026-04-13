/// Unit tests for RecipeCommentsManager and CommentCrudOperations
///
/// RecipeCommentsManager creates CommentCrudOperations() in its constructor,
/// which calls `ServiceLocator.get<CommentsRepository>()` and
/// `ServiceLocator.get<AnalyticsService>()`. We test:
/// 1. CommentCrudOperations — directly with injected mocks
/// 2. RecipeCommentsManager auth guards — via production ServiceLocator bridge
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/modules/comment_crud_operations.dart';
import 'package:butlery/services/unified/operations/modules/recipe_comments_manager.dart';

import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/core/di/di_container.dart';

void main() {
  // -----------------------------------------------------------------------
  // Part 1: CommentCrudOperations — inject mocks directly
  // -----------------------------------------------------------------------
  group('CommentCrudOperations', () {
    late CommentCrudOperations crud;
    late MockCommentsRepository mockCommentsRepo;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockCommentsRepo = MockCommentsRepository();
      mockAnalytics = MockAnalyticsService();

      crud = CommentCrudOperations(
        commentsRepository: mockCommentsRepo,
        analyticsService: mockAnalytics,
      );
    });

    group('createComment', () {
      test('creates comment and returns ID', () async {
        final comment = RecipeComment(
          id: 'c1',
          recipeId: 'r1',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          text: 'Great recipe!',
        );

        when(() => mockCommentsRepo.addComment(
              recipeId: any(named: 'recipeId'),
              userId: any(named: 'userId'),
              content: any(named: 'content'),
              parentCommentId: any(named: 'parentCommentId'),
            )).thenAnswer((_) async => comment);

        when(() => mockAnalytics.logCommentCreated(
              recipeId: any(named: 'recipeId'),
              commentLength: any(named: 'commentLength'),
            )).thenAnswer((_) async {});

        final result = await crud.createComment(
          recipeId: 'r1',
          content: 'Great recipe!',
          authorId: 'u1',
          authorDisplayName: 'Anna',
        );

        expect(result, 'c1');
        verify(() => mockCommentsRepo.addComment(
              recipeId: 'r1',
              userId: 'u1',
              content: 'Great recipe!',
              parentCommentId: null,
            )).called(1);
      });

      test('trims content before saving', () async {
        final comment = RecipeComment(
          id: 'c2',
          recipeId: 'r1',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          text: 'Trimmed',
        );

        when(() => mockCommentsRepo.addComment(
              recipeId: any(named: 'recipeId'),
              userId: any(named: 'userId'),
              content: any(named: 'content'),
              parentCommentId: any(named: 'parentCommentId'),
            )).thenAnswer((_) async => comment);

        when(() => mockAnalytics.logCommentCreated(
              recipeId: any(named: 'recipeId'),
              commentLength: any(named: 'commentLength'),
            )).thenAnswer((_) async {});

        await crud.createComment(
          recipeId: 'r1',
          content: '  Trimmed  ',
          authorId: 'u1',
          authorDisplayName: 'Anna',
        );

        verify(() => mockCommentsRepo.addComment(
              recipeId: 'r1',
              userId: 'u1',
              content: 'Trimmed',
              parentCommentId: null,
            )).called(1);
      });

      test('throws on empty content', () async {
        expect(
          () => crud.createComment(
            recipeId: 'r1',
            content: '   ',
            authorId: 'u1',
            authorDisplayName: 'Anna',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('passes parentCommentId for replies', () async {
        final reply = RecipeComment(
          id: 'reply-1',
          recipeId: 'r1',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          text: 'Nice!',
          parentCommentId: 'parent-1',
        );

        when(() => mockCommentsRepo.addComment(
              recipeId: any(named: 'recipeId'),
              userId: any(named: 'userId'),
              content: any(named: 'content'),
              parentCommentId: any(named: 'parentCommentId'),
            )).thenAnswer((_) async => reply);

        when(() => mockAnalytics.logCommentCreated(
              recipeId: any(named: 'recipeId'),
              commentLength: any(named: 'commentLength'),
            )).thenAnswer((_) async {});

        final result = await crud.createComment(
          recipeId: 'r1',
          content: 'Nice!',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          parentCommentId: 'parent-1',
        );

        expect(result, 'reply-1');
      });
    });

    group('getComments', () {
      test('returns comments sorted with replies after parents', () async {
        final parent = RecipeComment(
          id: 'p1',
          recipeId: 'r1',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          text: 'Parent',
          createdAt: DateTime(2024, 1, 1),
        );
        final reply = RecipeComment(
          id: 'reply1',
          recipeId: 'r1',
          authorId: 'u2',
          authorDisplayName: 'Erik',
          text: 'Reply',
          parentCommentId: 'p1',
          createdAt: DateTime(2024, 1, 2),
        );

        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenAnswer((_) async => [reply, parent]);

        final comments = await crud.getComments(recipeId: 'r1');

        // Parent should come before reply
        expect(comments.length, 2);
        expect(comments[0].id, 'p1');
        expect(comments[1].id, 'reply1');
      });

      test('respects limit parameter', () async {
        final comments = List.generate(
          10,
          (i) => RecipeComment(
            id: 'c$i',
            recipeId: 'r1',
            authorId: 'u1',
            authorDisplayName: 'Anna',
            text: 'Comment $i',
            createdAt: DateTime(2024, 1, i + 1),
          ),
        );

        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenAnswer((_) async => comments);

        final result = await crud.getComments(recipeId: 'r1', limit: 5);
        expect(result.length, 5);
      });

      test('filters by before date', () async {
        final comments = [
          RecipeComment(
            id: 'old',
            recipeId: 'r1',
            authorId: 'u1',
            authorDisplayName: 'Anna',
            text: 'Old',
            createdAt: DateTime(2024, 1, 1),
          ),
          RecipeComment(
            id: 'new',
            recipeId: 'r1',
            authorId: 'u1',
            authorDisplayName: 'Anna',
            text: 'New',
            createdAt: DateTime(2024, 6, 1),
          ),
        ];

        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenAnswer((_) async => comments);

        final result = await crud.getComments(
          recipeId: 'r1',
          before: DateTime(2024, 3, 1),
        );

        expect(result.length, 1);
        expect(result.first.id, 'old');
      });

      test('returns empty list on error', () async {
        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenThrow(Exception('DB error'));

        final result = await crud.getComments(recipeId: 'r1');
        expect(result, isEmpty);
      });
    });

    group('editComment', () {
      test('edits comment successfully', () async {
        when(() => mockCommentsRepo.updateComment(any(), any()))
            .thenAnswer((_) async {});

        final result = await crud.editComment(
          commentId: 'c1',
          newContent: 'Updated text',
          currentUserId: 'u1',
        );

        expect(result, isTrue);
        verify(() => mockCommentsRepo.updateComment('c1', 'Updated text'))
            .called(1);
      });

      test('trims content before editing', () async {
        when(() => mockCommentsRepo.updateComment(any(), any()))
            .thenAnswer((_) async {});

        await crud.editComment(
          commentId: 'c1',
          newContent: '  Trimmed  ',
          currentUserId: 'u1',
        );

        verify(() => mockCommentsRepo.updateComment('c1', 'Trimmed')).called(1);
      });

      test('returns false on empty content', () async {
        final result = await crud.editComment(
          commentId: 'c1',
          newContent: '   ',
          currentUserId: 'u1',
        );

        expect(result, isFalse);
        verifyNever(() => mockCommentsRepo.updateComment(any(), any()));
      });

      test('returns false on error', () async {
        when(() => mockCommentsRepo.updateComment(any(), any()))
            .thenThrow(Exception('DB error'));

        final result = await crud.editComment(
          commentId: 'c1',
          newContent: 'text',
          currentUserId: 'u1',
        );

        expect(result, isFalse);
      });
    });

    group('deleteComment', () {
      test('deletes comment successfully', () async {
        when(() => mockCommentsRepo.deleteComment(any()))
            .thenAnswer((_) async {});

        final result = await crud.deleteComment(
          commentId: 'c1',
          currentUserId: 'u1',
          canDeleteValidator: (_) => true,
        );

        expect(result, isTrue);
        verify(() => mockCommentsRepo.deleteComment('c1')).called(1);
      });

      test('returns false on error', () async {
        when(() => mockCommentsRepo.deleteComment(any()))
            .thenThrow(Exception('DB error'));

        final result = await crud.deleteComment(
          commentId: 'c1',
          currentUserId: 'u1',
          canDeleteValidator: (_) => true,
        );

        expect(result, isFalse);
      });
    });

    group('getCommentById', () {
      test('returns comment when found', () async {
        final comment = RecipeComment(
          id: 'c1',
          recipeId: 'r1',
          authorId: 'u1',
          authorDisplayName: 'Anna',
          text: 'Hello',
        );

        when(() => mockCommentsRepo.read('c1'))
            .thenAnswer((_) async => comment);

        final result = await crud.getCommentById(commentId: 'c1');
        expect(result, isNotNull);
        expect(result!.id, 'c1');
      });

      test('returns null when not found', () async {
        when(() => mockCommentsRepo.read('missing'))
            .thenAnswer((_) async => null);

        final result = await crud.getCommentById(commentId: 'missing');
        expect(result, isNull);
      });

      test('returns null on error', () async {
        when(() => mockCommentsRepo.read('c1'))
            .thenThrow(Exception('DB error'));

        final result = await crud.getCommentById(commentId: 'c1');
        expect(result, isNull);
      });
    });

    group('getCommentCount', () {
      test('returns count of comments for recipe', () async {
        final comments = [
          RecipeComment(
            id: 'c1',
            recipeId: 'r1',
            authorId: 'u1',
            authorDisplayName: 'A',
            text: '1',
          ),
          RecipeComment(
            id: 'c2',
            recipeId: 'r1',
            authorId: 'u2',
            authorDisplayName: 'B',
            text: '2',
          ),
        ];

        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenAnswer((_) async => comments);

        final count = await crud.getCommentCount(recipeId: 'r1');
        expect(count, 2);
      });

      test('returns 0 on error', () async {
        when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
            .thenThrow(Exception('DB error'));

        final count = await crud.getCommentCount(recipeId: 'r1');
        expect(count, 0);
      });
    });

    group('createCommentStream', () {
      test('streams sorted comments', () async {
        final comments = [
          RecipeComment(
            id: 'reply',
            recipeId: 'r1',
            authorId: 'u2',
            authorDisplayName: 'Erik',
            text: 'Reply',
            parentCommentId: 'parent',
            createdAt: DateTime(2024, 1, 2),
          ),
          RecipeComment(
            id: 'parent',
            recipeId: 'r1',
            authorId: 'u1',
            authorDisplayName: 'Anna',
            text: 'Parent',
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(() => mockCommentsRepo.getCommentsStream('r1'))
            .thenAnswer((_) => Stream.value(comments));

        final stream = crud.createCommentStream(recipeId: 'r1');
        final result = await stream.first;

        // Parent should be first
        expect(result[0].id, 'parent');
        expect(result[1].id, 'reply');
      });
    });
  });

  // -----------------------------------------------------------------------
  // Part 2: RecipeCommentsManager auth guards — needs ServiceLocator bridge
  // -----------------------------------------------------------------------
  group('RecipeCommentsManager auth guards', () {
    late RecipeCommentsManager manager;
    late MockCommentsRepository mockCommentsRepo;
    late MockAnalyticsService mockAnalytics;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to test GetIt
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      mockCommentsRepo = MockCommentsRepository();
      mockAnalytics = MockAnalyticsService();

      // Register mocks into shared GetIt so production ServiceLocator finds them
      TestServiceLocator.registerMock<CommentsRepository>(mockCommentsRepo);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalytics);

      manager = RecipeCommentsManager(
        getCurrentUserId: () => null, // unauthenticated by default
        getCurrentUserDisplayName: () => null,
        getRecipes: () => [],
        notificationService: null,
      );
    });

    tearDown(() async {
      manager.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('addComment returns null when not authenticated', () async {
      final result = await manager.addComment(
        recipeId: 'r1',
        content: 'Hello',
      );
      expect(result, isNull);
    });

    test('editComment returns false when not authenticated', () async {
      final result = await manager.editComment(
        commentId: 'c1',
        newContent: 'Updated',
      );
      expect(result, isFalse);
    });

    test('deleteComment returns false when not authenticated', () async {
      final result = await manager.deleteComment('c1');
      expect(result, isFalse);
    });

    test('toggleCommentLike returns false when not authenticated', () async {
      final result = await manager.toggleCommentLike('c1');
      expect(result, isFalse);
    });
  });

  group('RecipeCommentsManager authenticated', () {
    late RecipeCommentsManager manager;
    late MockCommentsRepository mockCommentsRepo;
    late MockAnalyticsService mockAnalytics;
    late List<Recipe> recipes;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      mockCommentsRepo = MockCommentsRepository();
      mockAnalytics = MockAnalyticsService();

      TestServiceLocator.registerMock<CommentsRepository>(mockCommentsRepo);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalytics);

      recipes = [];

      manager = RecipeCommentsManager(
        getCurrentUserId: () => 'user-1',
        getCurrentUserDisplayName: () => 'Anna',
        getRecipes: () => recipes,
        notificationService: null,
      );
    });

    tearDown(() async {
      manager.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('addComment creates comment when authenticated', () async {
      final comment = RecipeComment(
        id: 'new-c1',
        recipeId: 'r1',
        authorId: 'user-1',
        authorDisplayName: 'Anna',
        text: 'Test comment',
      );

      when(() => mockCommentsRepo.addComment(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => comment);

      when(() => mockAnalytics.logCommentCreated(
            recipeId: any(named: 'recipeId'),
            commentLength: any(named: 'commentLength'),
          )).thenAnswer((_) async {});

      // getCommentById is called after creation for notifications
      when(() => mockCommentsRepo.read(any())).thenAnswer((_) async => comment);

      final result = await manager.addComment(
        recipeId: 'r1',
        content: 'Test comment',
      );

      expect(result, 'new-c1');
    });

    test('getComments delegates to crud operations', () async {
      when(() => mockCommentsRepo.getCommentsForRecipe('r1'))
          .thenAnswer((_) async => []);

      final result = await manager.getComments(recipeId: 'r1');
      expect(result, isEmpty);
    });

    test('dispose cleans up streams', () {
      // Should not throw
      manager.dispose();
    });
  });
}
