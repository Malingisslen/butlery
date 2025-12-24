// test/unit/services/unified/operations/modules/comment_notifications_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/comment_notifications.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CommentNotifications', () {
    late MockNotificationService mockNotificationService;
    late Recipe testRecipe;
    late RecipeComment testComment;
    late RecipeComment testReply;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(NotificationStrategy.recipeComment);
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

      // Create mock notification service
      mockNotificationService = MockNotificationService();

      // Create test data
      testRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe_1',
          title: 'Test Recipe',
          description: 'A test recipe',
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
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_123': ResourcePermission.owner,
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
            'user_999': ResourcePermission.viewer,
          },
        ),
      );

      testComment = RecipeComment(
        id: 'comment_1',
        recipeId: 'recipe_1',
        authorId: 'user_456',
        authorDisplayName: 'Test Commenter',
        text: 'Great recipe! @user_999 you should try this.',
        createdAt: DateTime.now(),
      );

      testReply = RecipeComment(
        id: 'reply_1',
        recipeId: 'recipe_1',
        parentCommentId: 'comment_1',
        authorId: 'user_789',
        authorDisplayName: 'Reply User',
        text: 'I agree with you!',
        createdAt: DateTime.now(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Comment Notifications', () {
      test('should send notifications to recipe members', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
        );

        // Assert
        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: [
                'user_123',
                'user_789',
                'user_999'
              ], // All members except commenter
              strategy: NotificationStrategy.recipeComment,
              variables: {
                'commenterName': 'Test Commenter',
                'recipeName': 'Test Recipe',
                'commentPreview':
                    'Great recipe! @user_999 you should try this.',
              },
              additionalData: {
                'recipeId': 'recipe_1',
                'commentId': 'comment_1',
                'action': 'comment_added',
                'commenterId': 'user_456',
              },
            )).called(1);
      });

      test('should include mentioned users in notifications', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
          mentions: ['user_external'], // User not in recipe members
        );

        // Assert
        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(
                named: 'targetUserIds',
                that: containsAll(
                    ['user_123', 'user_789', 'user_999', 'user_external']),
              ),
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).called(1);
      });

      test('should not send notifications when no service available', () async {
        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: null,
          recipe: testRecipe,
          comment: testComment,
        );

        // Assert
        verifyNever(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            ));
      });

      test('should handle notification errors gracefully', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenThrow(Exception('Notification error'));

        // Act & Assert (should not throw)
        await CommentNotifications.sendCommentNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
        );
      });
    });

    group('Reply Notifications', () {
      test('should send notification to parent comment author', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendReplyNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          reply: testReply,
          parentComment: testComment,
        );

        // Assert
        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: ['user_456'], // Parent comment author
              strategy: NotificationStrategy.recipeComment,
              variables: {
                'replierName': 'Reply User',
                'recipeName': 'Test Recipe',
                'replyPreview': 'I agree with you!',
                'originalCommentPreview':
                    'Great recipe! @user_999 you should try this.',
              },
              additionalData: {
                'recipeId': 'recipe_1',
                'commentId': 'reply_1',
                'parentCommentId': 'comment_1',
                'action': 'comment_reply',
                'replierId': 'user_789',
              },
            )).called(1);
      });

      test('should not notify when replying to own comment', () async {
        // Arrange
        final selfReply = RecipeComment(
          id: 'self_reply',
          recipeId: 'recipe_1',
          parentCommentId: 'comment_1',
          authorId: 'user_456', // Same as parent comment author
          authorDisplayName: 'Test Commenter',
          text: 'Adding to my own comment',
          createdAt: DateTime.now(),
        );

        // Act
        await CommentNotifications.sendReplyNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          reply: selfReply,
          parentComment: testComment,
        );

        // Assert
        verifyNever(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            ));
      });
    });

    group('Mention Notifications', () {
      test('should send notifications for mentions', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        final mentions = ['user_111', 'user_222'];

        // Act
        await CommentNotifications.sendMentionNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
          mentionedUserIds: mentions,
        );

        // Assert
        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: mentions,
              strategy: NotificationStrategy.recipeComment,
              variables: {
                'mentionerName': 'Test Commenter',
                'recipeName': 'Test Recipe',
                'commentPreview': any(),
              },
              additionalData: {
                'recipeId': 'recipe_1',
                'commentId': 'comment_1',
                'action': 'comment_mention',
                'mentionerId': 'user_456',
              },
            )).called(1);
      });

      test('should not notify user who mentions themselves', () async {
        // Arrange
        final selfMentionComment = RecipeComment(
          id: 'self_mention',
          recipeId: 'recipe_1',
          authorId: 'user_456',
          authorDisplayName: 'Test User',
          text: 'Reminding @user_456 (myself) about this',
          createdAt: DateTime.now(),
        );

        // Act
        await CommentNotifications.sendMentionNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: selfMentionComment,
          mentionedUserIds: ['user_456'],
        );

        // Assert
        // No notification should be sent when list is empty
        verifyNever(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            ));
      });
    });

    group('Notification Batching', () {
      test('should batch multiple comment notifications', () async {
        // Arrange
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        final comments = List.generate(
            3,
            (i) => RecipeComment(
                  id: 'comment_$i',
                  recipeId: 'recipe_1',
                  authorId: 'user_${456 + i}',
                  authorDisplayName: 'User $i',
                  text: 'Comment $i',
                  createdAt: DateTime.now().add(Duration(minutes: i)),
                ));

        // Act
        for (final comment in comments) {
          await CommentNotifications.sendCommentNotifications(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            comment: comment,
          );
        }

        // Assert
        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).called(3);
      });
    });
  });
}
