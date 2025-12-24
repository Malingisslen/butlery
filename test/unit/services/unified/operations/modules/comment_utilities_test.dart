// test/unit/services/unified/operations/modules/comment_utilities_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/services/unified/operations/modules/comment_utilities.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
// RecipeSocialData is part of recipe_unified.dart, already imported
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  late MockCommentsRepository mockCommentsRepository;

  // Register the mock BEFORE any test groups to ensure it's available when CommentUtilities loads
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

    // Initialize base test infrastructure
    await BaseUnitTest.setupUnit();

    // Create and register mock repository before CommentUtilities class loads
    mockCommentsRepository = MockCommentsRepository();
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<CommentsRepository>(mockCommentsRepository);
  });

  tearDownAll(() async {
    // Clean up after all tests
    await GetIt.instance.reset();
  });

  group('CommentUtilities', () {
    late Recipe testPersonalRecipe;
    late Recipe testCollaborativeRecipe;
    late RecipeComment testComment;
    late RecipeComment testReply;

    setUp(() async {
      // Create test data
      testPersonalRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_recipe_1',
          title: 'Test Personal Recipe',
          description: 'A test personal recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        ),
      );

      testCollaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab_recipe_1',
          title: 'Test Collaborative Recipe',
          description: 'A test collaborative recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'user_123': ResourcePermission.owner,
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
            'user_admin': ResourcePermission.admin,
          },
        ),
      );

      testComment = RecipeComment(
        id: 'comment_1',
        recipeId: 'collab_recipe_1',
        authorId: 'user_456',
        authorDisplayName: 'Test Commenter',
        text: 'Great recipe!',
        createdAt: DateTime.now(),
        likedByUserIds: ['user_789', 'user_admin'],
        replyCount: 2,
        isDeleted: false,
      );

      testReply = RecipeComment(
        id: 'reply_1',
        recipeId: 'collab_recipe_1',
        parentCommentId: 'comment_1',
        authorId: 'user_789',
        authorDisplayName: 'Reply User',
        text: 'I agree!',
        createdAt: DateTime.now(),
        likedByUserIds: [],
        replyCount: 0,
        isDeleted: false,
      );
    });

    tearDown(() async {
      // Reset mocks after each test
      BaseUnitTest.resetMocks();
    });

    group('Permission Checking', () {
      test('should allow owner to comment on personal recipe', () {
        // Act
        final canComment = CommentUtilities.canCommentOnRecipe(
          recipe: testPersonalRecipe,
          currentUserId: 'user_123',
        );

        // Assert
        expect(canComment, isTrue);
      });

      test('should not allow others to comment on personal recipe', () {
        // Act
        final canComment = CommentUtilities.canCommentOnRecipe(
          recipe: testPersonalRecipe,
          currentUserId: 'user_456',
        );

        // Assert
        expect(canComment, isFalse);
      });

      test('should allow members to comment on collaborative recipe', () {
        // Act
        final canComment = CommentUtilities.canCommentOnRecipe(
          recipe: testCollaborativeRecipe,
          currentUserId: 'user_456',
        );

        // Assert
        expect(canComment, isTrue);
      });

      test('should identify recipe owner correctly', () {
        // Act
        final isOwner = CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: testCollaborativeRecipe,
          currentUserId: 'user_123',
        );

        // Assert
        expect(isOwner, isTrue);
      });

      test('should identify admin correctly', () {
        // Act
        final isAdmin = CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: testCollaborativeRecipe,
          currentUserId: 'user_admin',
        );

        // Assert
        expect(isAdmin, isTrue);
      });

      test('should allow comment author to delete their comment', () {
        // Act
        final canDelete = CommentUtilities.canDeleteComment(
          comment: testComment,
          currentUserId: 'user_456',
          recipe: testCollaborativeRecipe,
        );

        // Assert
        expect(canDelete, isTrue);
      });

      test('should allow recipe owner to delete any comment', () {
        // Act
        final canDelete = CommentUtilities.canDeleteComment(
          comment: testComment,
          currentUserId: 'user_123',
          recipe: testCollaborativeRecipe,
        );

        // Assert
        expect(canDelete, isTrue);
      });

      test('should only allow author to edit comment', () {
        // Act
        final canEdit = CommentUtilities.canEditComment(
          comment: testComment,
          currentUserId: 'user_456',
        );
        final cannotEdit = CommentUtilities.canEditComment(
          comment: testComment,
          currentUserId: 'user_789',
        );

        // Assert
        expect(canEdit, isTrue);
        expect(cannotEdit, isFalse);
      });
    });

    group('Reply Count Management', () {
      test('should increment reply count', () async {
        // Arrange
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => testComment);
        when(() => mockCommentsRepository.update(any()))
            .thenAnswer((_) async => true);

        // Act
        await CommentUtilities.incrementReplyCount(
          parentCommentId: 'comment_1',
        );

        // Assert
        verify(() => mockCommentsRepository.read('comment_1')).called(1);
        verify(() => mockCommentsRepository.update(any())).called(1);
      });

      test('should decrement reply count', () async {
        // Arrange
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => testComment);
        when(() => mockCommentsRepository.update(any()))
            .thenAnswer((_) async => true);

        // Act
        await CommentUtilities.decrementReplyCount(
          parentCommentId: 'comment_1',
        );

        // Assert
        verify(() => mockCommentsRepository.read('comment_1')).called(1);
        verify(() => mockCommentsRepository.update(any())).called(1);
      });

      test('should not decrement below zero', () async {
        // Arrange
        final zeroReplyComment = testComment.copyWith(replyCount: 0);
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => zeroReplyComment);
        when(() => mockCommentsRepository.update(any()))
            .thenAnswer((_) async => true);

        // Act
        await CommentUtilities.decrementReplyCount(
          parentCommentId: 'comment_1',
        );

        // Assert
        final capturedComment =
            verify(() => mockCommentsRepository.update(captureAny()))
                .captured
                .first as RecipeComment;
        expect(capturedComment.replyCount, equals(0));
      });

      test('should get reply count', () async {
        // Arrange
        when(() => mockCommentsRepository.read('comment_1'))
            .thenAnswer((_) async => testComment);

        // Act
        final count = await CommentUtilities.getReplyCount(
          commentId: 'comment_1',
        );

        // Assert
        expect(count, equals(2));
      });
    });

    group('Comment Statistics', () {
      test('should calculate comprehensive statistics', () async {
        // Arrange
        final comments = [
          testComment,
          testReply,
          RecipeComment(
            id: 'comment_2',
            recipeId: 'collab_recipe_1',
            authorId: 'user_456',
            authorDisplayName: 'Test Commenter',
            text: 'Great recipe!',
            createdAt: DateTime.now(),
            isDeleted: true,
            likedByUserIds: ['user_123'],
          ),
          RecipeComment(
            id: 'comment_3',
            recipeId: 'collab_recipe_1',
            authorId: 'user_456',
            authorDisplayName: 'Test Commenter',
            text: 'Great recipe!',
            createdAt: DateTime.now(),
            editedAt: DateTime.now(),
            likedByUserIds: [],
          ),
        ];
        when(() =>
                mockCommentsRepository.getCommentsForRecipe('collab_recipe_1'))
            .thenAnswer((_) async => comments);

        // Act
        final stats = await CommentUtilities.getCommentStatistics(
          recipeId: 'collab_recipe_1',
        );

        // Assert
        expect(stats['total_comments'], equals(4));
        expect(stats['top_level_comments'], equals(3));
        expect(stats['replies'], equals(1));
        expect(stats['total_likes'], equals(3));
        expect(stats['unique_commenters'], equals(2));
        expect(stats['deleted_comments'], equals(1));
        expect(stats['edited_comments'], equals(1));
      });

      test('should get comment activity timeline', () async {
        // Arrange
        final now = DateTime.now();
        final comments = [
          RecipeComment(
            id: testComment.id,
            recipeId: testComment.recipeId,
            authorId: testComment.authorId,
            authorDisplayName: testComment.authorDisplayName,
            text: testComment.text,
            createdAt: now.subtract(Duration(hours: 2)),
            likedByUserIds: testComment.likedByUserIds,
            replyCount: testComment.replyCount,
            isDeleted: testComment.isDeleted,
          ),
          RecipeComment(
            id: testReply.id,
            recipeId: testReply.recipeId,
            authorId: testReply.authorId,
            authorDisplayName: testReply.authorDisplayName,
            text: testReply.text,
            createdAt: now.subtract(Duration(hours: 1)),
            parentCommentId: testReply.parentCommentId,
            likedByUserIds: testReply.likedByUserIds,
            replyCount: testReply.replyCount,
            isDeleted: testReply.isDeleted,
          ),
        ];
        when(() =>
                mockCommentsRepository.getCommentsForRecipe('collab_recipe_1'))
            .thenAnswer((_) async => comments);

        // Act
        final timeline = await CommentUtilities.getCommentActivityTimeline(
          recipeId: 'collab_recipe_1',
        );

        // Assert
        expect(timeline.length, equals(2));
        expect(timeline.first['type'], equals('comment_created'));
        expect(timeline.first['isReply'], isTrue);
      });

      test('should get most active commenters', () async {
        // Arrange
        final comments = [
          testComment,
          RecipeComment(
            id: 'comment_2',
            recipeId: testComment.recipeId,
            authorId: testComment.authorId,
            authorDisplayName: testComment.authorDisplayName,
            text: testComment.text,
            createdAt: testComment.createdAt,
            likedByUserIds: testComment.likedByUserIds,
            replyCount: testComment.replyCount,
            isDeleted: testComment.isDeleted,
          ),
          RecipeComment(
            id: 'comment_3',
            recipeId: testComment.recipeId,
            authorId: testComment.authorId,
            authorDisplayName: testComment.authorDisplayName,
            text: testComment.text,
            createdAt: testComment.createdAt,
            likedByUserIds: testComment.likedByUserIds,
            replyCount: testComment.replyCount,
            isDeleted: testComment.isDeleted,
          ),
          testReply,
        ];
        when(() =>
                mockCommentsRepository.getCommentsForRecipe('collab_recipe_1'))
            .thenAnswer((_) async => comments);

        // Act
        final activeCommenters = await CommentUtilities.getMostActiveCommenters(
          recipeId: 'collab_recipe_1',
        );

        // Assert
        expect(activeCommenters.length, equals(2));
        expect(activeCommenters.first['authorId'], equals('user_456'));
        expect(activeCommenters.first['commentCount'], equals(3));
      });
    });

    group('Stream Management', () {
      test('should create broadcast stream controller', () {
        // Act
        final controller = CommentUtilities.createCommentStreamController();

        // Assert
        expect(controller, isA<StreamController<List<RecipeComment>>>());
        expect(controller.stream.isBroadcast, isTrue);

        // Cleanup
        controller.close();
      });

      test('should dispose stream controller safely', () {
        // Arrange
        final controller = StreamController<List<RecipeComment>>.broadcast();

        // Act & Assert - should not throw
        expect(
          () => CommentUtilities.disposeCommentStream(controller),
          returnsNormally,
        );
        expect(controller.isClosed, isTrue);
      });

      test('should cleanup multiple streams', () {
        // Arrange
        final streams = {
          'stream1': StreamController<List<RecipeComment>>.broadcast(),
          'stream2': StreamController<List<RecipeComment>>.broadcast(),
          'stream3': StreamController<List<RecipeComment>>.broadcast(),
        };

        // Act
        CommentUtilities.cleanupCommentStreams(streams);

        // Assert
        expect(streams, isEmpty);
      });
    });

    group('Content Validation', () {
      test('should validate comment content', () {
        // Act & Assert
        expect(CommentUtilities.isValidCommentContent('Valid comment'), isTrue);
        expect(CommentUtilities.isValidCommentContent(''), isFalse);
        expect(CommentUtilities.isValidCommentContent('   '), isFalse);
        expect(CommentUtilities.isValidCommentContent('a' * 1001), isFalse);
      });

      test('should sanitize comment content', () {
        // Act
        final sanitized = CommentUtilities.sanitizeCommentContent(
          '  Multiple   spaces   <script>alert("xss")</script>  ',
        );

        // Assert
        expect(sanitized, equals('Multiple spaces alert("xss")'));
      });

      test('should extract mentions', () {
        // Act
        final mentions = CommentUtilities.extractMentions(
          'Hey @user123 and @john_doe, check this out!',
        );

        // Assert
        expect(mentions, equals(['user123', 'john_doe']));
      });

      test('should detect spam patterns', () {
        // Act & Assert
        expect(CommentUtilities.isLikelySpam('Normal comment'), isFalse);
        expect(CommentUtilities.isLikelySpam('aaaaaaaaaaaaaaa'), isTrue);
        expect(CommentUtilities.isLikelySpam('CLICK HERE NOW!!!'), isTrue);
        expect(CommentUtilities.isLikelySpam('Buy now limited time'), isTrue);
      });
    });

    group('Helper Utilities', () {
      test('should format comment age correctly', () {
        // Arrange
        final now = DateTime.now();

        // Act & Assert
        expect(
          CommentUtilities.getCommentAge(now.subtract(Duration(seconds: 30))),
          equals('nu'),
        );
        expect(
          CommentUtilities.getCommentAge(now.subtract(Duration(minutes: 5))),
          equals('5m'),
        );
        expect(
          CommentUtilities.getCommentAge(now.subtract(Duration(hours: 3))),
          equals('3h'),
        );
        expect(
          CommentUtilities.getCommentAge(now.subtract(Duration(days: 2))),
          equals('2d'),
        );
        expect(
          CommentUtilities.getCommentAge(now.subtract(Duration(days: 45))),
          equals('1mån'),
        );
      });

      test('should generate comment permalink', () {
        // Act
        final permalink = CommentUtilities.generateCommentPermalink(
          recipeId: 'recipe_123',
          commentId: 'comment_456',
        );

        // Assert
        expect(permalink, equals('/recipe/recipe_123#comment-comment_456'));
      });

      test('should check thread depth', () {
        // Act & Assert
        expect(CommentUtilities.isThreadTooDeep(2), isFalse);
        expect(CommentUtilities.isThreadTooDeep(3), isFalse);
        expect(CommentUtilities.isThreadTooDeep(4), isTrue);
        expect(CommentUtilities.isThreadTooDeep(2, maxDepth: 1), isTrue);
      });
    });
  });
}
