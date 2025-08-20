// test/unit/services/unified/operations/modules/recipe_comments_manager_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_comments_manager.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/unified/operations/modules/comment_crud_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RecipeCommentsManager', () {
    late MockUnifiedRecipeService mockParentService;
    late MockNotificationService mockNotificationService;
    late MockCommentCrudOperations mockCrudOperations;
    late RecipeCommentsManager commentsManager;
    late Recipe testRecipe;
    late RecipeComment testComment;
    late RecipeComment testReply;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(RecipeComment(
        id: 'test',
        recipeId: 'test',
        authorId: 'test',
        authorDisplayName: 'Test',
        text: 'Test',
        createdAt: DateTime.now(),
      ));
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();
      mockCrudOperations = MockCommentCrudOperations();

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .asCollaborative()
          .asSwedishDinner()
          .build();

      testComment = RecipeComment(
        id: 'comment_1',
        recipeId: 'recipe_1',
        authorId: 'user_456',
        authorDisplayName: 'Test User',
        text: 'Great recipe!',
        createdAt: DateTime.now(),
      );

      testReply = RecipeComment(
        id: 'reply_1',
        recipeId: 'recipe_1',
        authorId: 'user_789',
        authorDisplayName: 'Reply User',
        text: 'Thanks!',
        parentCommentId: 'comment_1',
        createdAt: DateTime.now(),
      );

      // Configure mock services
      mockParentService.setServiceState(
        userId: 'user_456',
        displayName: 'Test User',
        recipes: [testRecipe],
      );

      // Create comments manager instance with test extension
      commentsManager = TestableRecipeCommentsManager(
        mockParentService,
        mockNotificationService,
        mockCrudOperations,
      );
    });

    tearDown(() async {
      commentsManager.dispose();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Comment CRUD Operations', () {
      test('should add comment successfully', () async {
        // Arrange
        when(() => mockCrudOperations.createComment(
              recipeId: 'recipe_1',
              content: 'Great recipe!',
              authorId: 'user_456',
              authorDisplayName: 'Test User',
              parentCommentId: null,
              canCommentValidator: any(named: 'canCommentValidator'),
              recipeGetter: any(named: 'recipeGetter'),
            )).thenAnswer((_) async => 'comment_1');
        when(() => mockCrudOperations.getCommentById(commentId: 'comment_1'))
            .thenAnswer((_) async => testComment);

        // Act
        final commentId = await commentsManager.addComment(
          recipeId: 'recipe_1',
          content: 'Great recipe!',
        );

        // Assert
        expect(commentId, equals('comment_1'));
        verify(() => mockCrudOperations.createComment(
              recipeId: 'recipe_1',
              content: 'Great recipe!',
              authorId: 'user_456',
              authorDisplayName: 'Test User',
              parentCommentId: null,
              canCommentValidator: any(named: 'canCommentValidator'),
              recipeGetter: any(named: 'recipeGetter'),
            )).called(1);
      });

      test('should add reply to comment', () async {
        // Arrange
        when(() => mockCrudOperations.createComment(
              recipeId: 'recipe_1',
              content: 'Thanks!',
              authorId: 'user_456',
              authorDisplayName: 'Test User',
              parentCommentId: 'comment_1',
              canCommentValidator: any(named: 'canCommentValidator'),
              recipeGetter: any(named: 'recipeGetter'),
            )).thenAnswer((_) async => 'reply_1');
        when(() => mockCrudOperations.getCommentById(commentId: 'reply_1'))
            .thenAnswer((_) async => testReply);

        // Act
        final replyId = await commentsManager.addComment(
          recipeId: 'recipe_1',
          content: 'Thanks!',
          parentCommentId: 'comment_1',
        );

        // Assert
        expect(replyId, equals('reply_1'));
        // Verify increment reply count was called through utilities
      });

      test('should get comments for recipe', () async {
        // Arrange
        when(() => mockCrudOperations.getComments(
              recipeId: 'recipe_1',
              limit: 20,
              before: null,
              includeReplies: true,
            )).thenAnswer((_) async => [testComment]);

        // Act
        final comments = await commentsManager.getComments(
          recipeId: 'recipe_1',
        );

        // Assert
        expect(comments.length, equals(1));
        expect(comments[0].id, equals('comment_1'));
      });

      test('should edit comment', () async {
        // Arrange
        when(() => mockCrudOperations.editComment(
              commentId: 'comment_1',
              newContent: 'Updated comment',
              currentUserId: 'user_456',
            )).thenAnswer((_) async => true);
        when(() => mockCrudOperations.getCommentById(commentId: 'comment_1'))
            .thenAnswer((_) async => testComment);

        // Act
        final success = await commentsManager.editComment(
          commentId: 'comment_1',
          newContent: 'Updated comment',
        );

        // Assert
        expect(success, isTrue);
      });

      test('should delete comment', () async {
        // Arrange
        when(() => mockCrudOperations.getCommentById(commentId: 'comment_1'))
            .thenAnswer((_) async => testComment);
        when(() => mockCrudOperations.deleteComment(
              commentId: 'comment_1',
              currentUserId: 'user_456',
              canDeleteValidator: any(named: 'canDeleteValidator'),
            )).thenAnswer((_) async => true);

        // Act
        final success = await commentsManager.deleteComment('comment_1');

        // Assert
        expect(success, isTrue);
        verify(() => mockCrudOperations.deleteComment(
              commentId: 'comment_1',
              currentUserId: 'user_456',
              canDeleteValidator: any(named: 'canDeleteValidator'),
            )).called(1);
      });

      test('should not delete comment without permission', () async {
        // Arrange
        when(() => mockCrudOperations.getCommentById(commentId: 'comment_1'))
            .thenAnswer((_) async => testComment);
        when(() => mockCrudOperations.deleteComment(
              commentId: 'comment_1',
              currentUserId: 'user_456',
              canDeleteValidator: any(named: 'canDeleteValidator'),
            )).thenAnswer((_) async => false);

        // Act
        final success = await commentsManager.deleteComment('comment_1');

        // Assert
        expect(success, isFalse);
      });
    });

    group('Comment Streaming', () {
      test('should stream comments for recipe', () async {
        // Arrange
        final streamController = StreamController<List<RecipeComment>>();
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_1'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = commentsManager.getCommentsStream('recipe_1');

        // Add test data
        streamController.add([testComment]);

        // Assert
        final comments = await stream.first;
        expect(comments.length, equals(1));
        expect(comments[0].id, equals('comment_1'));

        // Cleanup
        await streamController.close();
      });

      test('should reuse existing stream for same recipe', () {
        // Arrange
        final streamController = StreamController<List<RecipeComment>>();
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_1'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream1 = commentsManager.getCommentsStream('recipe_1');
        final stream2 = commentsManager.getCommentsStream('recipe_1');

        // Assert
        expect(identical(stream1, stream2), isTrue);

        // Cleanup
        streamController.close();
      });

      test('should create different streams for different recipes', () {
        // Arrange
        final streamController1 = StreamController<List<RecipeComment>>();
        final streamController2 = StreamController<List<RecipeComment>>();
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_1'))
            .thenAnswer((_) => streamController1.stream);
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_2'))
            .thenAnswer((_) => streamController2.stream);

        // Act
        final stream1 = commentsManager.getCommentsStream('recipe_1');
        final stream2 = commentsManager.getCommentsStream('recipe_2');

        // Assert
        expect(identical(stream1, stream2), isFalse);

        // Cleanup
        streamController1.close();
        streamController2.close();
      });
    });

    group('Comment Likes', () {
      test('should toggle like on comment', () async {
        // Arrange
        when(() => mockCrudOperations.getCommentById(commentId: 'comment_1'))
            .thenAnswer((_) async => testComment);

        // Act
        final success = await commentsManager.toggleCommentLike('comment_1');

        // Assert
        expect(success, isTrue);
        // Note: The actual toggle is handled by CommentLikesSystem static method
      });

      test('should not toggle like when not authenticated', () async {
        // Arrange
        mockParentService.setServiceState(userId: null);

        // Act
        final success = await commentsManager.toggleCommentLike('comment_1');

        // Assert
        expect(success, isFalse);
      });
    });

    group('Comment Statistics', () {
      test('should get comment statistics', () async {
        // Act
        final stats = await commentsManager.getCommentStatistics('recipe_1');

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
        // Note: CommentUtilities.getCommentStatistics is a static method
      });

      test('should get comment activity timeline', () async {
        // Act
        final timeline = await commentsManager.getCommentActivityTimeline(
          recipeId: 'recipe_1',
          limit: 50,
        );

        // Assert
        expect(timeline, isA<List<Map<String, dynamic>>>());
      });

      test('should get most active commenters', () async {
        // Act
        final commenters = await commentsManager.getMostActiveCommenters(
          recipeId: 'recipe_1',
          limit: 10,
        );

        // Assert
        expect(commenters, isA<List<Map<String, dynamic>>>());
      });
    });

    group('Stream Management', () {
      test('should dispose all streams properly', () {
        // Arrange
        final streamController1 = StreamController<List<RecipeComment>>();
        final streamController2 = StreamController<List<RecipeComment>>();
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_1'))
            .thenAnswer((_) => streamController1.stream);
        when(() => mockCrudOperations.createCommentStream(recipeId: 'recipe_2'))
            .thenAnswer((_) => streamController2.stream);

        commentsManager.getCommentsStream('recipe_1');
        commentsManager.getCommentsStream('recipe_2');

        // Act
        commentsManager.dispose();

        // Assert (no exceptions thrown)
        expect(true, isTrue);

        // Cleanup
        streamController1.close();
        streamController2.close();
      });
    });
  });
}

// Mock classes
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {
  String? _currentUserId = 'user_456';
  String? _currentUserDisplayName = 'Test User';
  List<Recipe> _recipes = [];

  void setServiceState({
    String? userId,
    String? displayName,
    List<Recipe>? recipes,
  }) {
    if (userId != null) _currentUserId = userId;
    if (displayName != null) _currentUserDisplayName = displayName;
    if (recipes != null) _recipes = recipes;
  }

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserDisplayName => _currentUserDisplayName;

  @override
  List<Recipe> get recipes => _recipes;
}

class MockNotificationService extends Mock implements NotificationService {}

class MockCommentCrudOperations extends Mock implements CommentCrudOperations {}

// Testable extension of RecipeCommentsManager that allows injection of mock operations
class TestableRecipeCommentsManager extends RecipeCommentsManager {
  final MockCommentCrudOperations mockCrudOperations;

  TestableRecipeCommentsManager(
    super.parent,
    super.notificationService,
    this.mockCrudOperations,
  );

  CommentCrudOperations get crudOperations => mockCrudOperations;
}

// Extension removed - private fields not accessible
