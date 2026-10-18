// test/unit/services/unified/operations/modules/comment_notifications_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/comment_notifications.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/recipe_activity_strategies.dart';
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

    group('Nameless author', () {
      test(
        'names the commenter per language slot, nothing persisted',
        () async {
          when(
            () => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              variablesByLocale: any(named: 'variablesByLocale'),
              additionalData: any(named: 'additionalData'),
            ),
          ).thenAnswer((_) async {});

          await CommentNotifications.sendCommentNotifications(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            comment: RecipeComment(
              id: 'comment_1',
              recipeId: 'recipe_1',
              authorId: 'user_456',
              authorDisplayName: '',
              text: 'Hej',
              createdAt: DateTime.now(),
            ),
          );

          final captured = verify(
            () => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: captureAny(named: 'variables'),
              variablesByLocale: captureAny(named: 'variablesByLocale'),
              additionalData: any(named: 'additionalData'),
            ),
          ).captured;
          final variables = captured[0] as Map<String, String>;
          final byLocale = captured[1] as Map<String, Map<String, String>>;
          expect(variables['commenterName'], '');
          expect(byLocale['sv']!['commenterName'], 'Okänd användare');
          expect(byLocale['en']!['commenterName'], 'Unknown user');
        },
      );

      Future<List<dynamic>> captureSend(
        Future<void> Function() act,
      ) async {
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});
        await act();
        return verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: captureAny(named: 'variables'),
            variablesByLocale: captureAny(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).captured;
      }

      RecipeComment authored(String name, {String? parent}) => RecipeComment(
        id: 'c_nameless',
        recipeId: 'recipe_1',
        parentCommentId: parent,
        authorId: 'user_789',
        authorDisplayName: name,
        text: 'Hej',
        createdAt: DateTime.now(),
      );

      test('names the replier per language slot', () async {
        final captured = await captureSend(
          () => CommentNotifications.sendReplyNotifications(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            reply: authored('', parent: 'comment_1'),
            parentComment: testComment,
          ),
        );
        final byLocale = captured[1] as Map<String, Map<String, String>>;
        expect((captured[0] as Map)['replierName'], '');
        expect(byLocale['sv']!['replierName'], 'Okänd användare');
        expect(byLocale['en']!['replierName'], 'Unknown user');
      });

      test('names the mentioner per language slot', () async {
        final captured = await captureSend(
          () => CommentNotifications.sendMentionNotifications(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            comment: authored(''),
            mentionedUserIds: ['user_111'],
          ),
        );
        final byLocale = captured[1] as Map<String, Map<String, String>>;
        expect((captured[0] as Map)['mentionerName'], '');
        expect(byLocale['sv']!['mentionerName'], 'Okänd användare');
        expect(byLocale['en']!['mentionerName'], 'Unknown user');
      });

      test(
        'a stored legacy label is not sent as the sender-language name',
        () async {
          final captured = await captureSend(
            () => CommentNotifications.sendCommentNotifications(
              notificationService: mockNotificationService,
              recipe: testRecipe,
              comment: authored('Okänd användare'),
            ),
          );
          final byLocale = captured[1] as Map<String, Map<String, String>>;
          expect((captured[0] as Map)['commenterName'], '');
          expect(byLocale['en']!['commenterName'], 'Unknown user');
        },
      );
    });

    group('Comment Notifications', () {
      test('should send notifications to recipe members', () async {
        // Arrange
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
        );

        // Assert
        verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: [
              'user_123',
              'user_789',
              'user_999',
            ], // All members except commenter
            strategy: NotificationStrategy.recipeComment,
            variables: {
              'commenterName': 'Test Commenter',
              'recipeName': 'Test Recipe',
              'commentPreview': 'Great recipe! @user_999 you should try this.',
            },
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: {
              'recipeId': 'recipe_1',
              'commentId': 'comment_1',
              'action': 'comment_added',
              'commenterId': 'user_456',
            },
          ),
        ).called(1);
      });

      test('should include mentioned users in notifications', () async {
        // Arrange
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
          mentions: ['user_external'], // User not in recipe members
        );

        // Assert
        verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(
              named: 'targetUserIds',
              that: containsAll([
                'user_123',
                'user_789',
                'user_999',
                'user_external',
              ]),
            ),
            strategy: NotificationStrategy.recipeComment,
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).called(1);
      });

      test('should not send notifications when no service available', () async {
        // Act
        await CommentNotifications.sendCommentNotifications(
          notificationService: null,
          recipe: testRecipe,
          comment: testComment,
        );

        // Assert
        verifyNever(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        );
      });

      test('should handle notification errors gracefully', () async {
        // Arrange
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenThrow(Exception('Notification error'));

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
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await CommentNotifications.sendReplyNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          reply: testReply,
          parentComment: testComment,
        );

        // Assert
        verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: ['user_456'], // Parent comment author
            strategy: RecipeActivityStrategies.commentReply,
            variables: {
              'replierName': 'Reply User',
              'recipeName': 'Test Recipe',
              'replyPreview': 'I agree with you!',
            },
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: {
              'recipeId': 'recipe_1',
              'commentId': 'reply_1',
              'parentCommentId': 'comment_1',
              'action': 'comment_reply',
              'replierId': 'user_789',
            },
          ),
        ).called(1);
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
        verifyNever(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        );
      });
    });

    group('Mention Notifications', () {
      test('should send notifications for mentions', () async {
        // Arrange
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final mentions = ['user_111', 'user_222'];

        // Act
        await CommentNotifications.sendMentionNotifications(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          comment: testComment,
          mentionedUserIds: mentions,
        );

        // Assert — mocktail any() can't be nested inside a Map literal; match
        // the variables map by predicate instead (asserts the static fields,
        // tolerates whatever the implementation generates for commentPreview).
        verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: mentions,
            strategy: RecipeActivityStrategies.commentMention,
            variables: any(
              named: 'variables',
              that: predicate<Map<String, dynamic>>(
                (v) =>
                    v['mentionerName'] == 'Test Commenter' &&
                    v['recipeName'] == 'Test Recipe' &&
                    v.containsKey('commentPreview'),
              ),
            ),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: {
              'recipeId': 'recipe_1',
              'commentId': 'comment_1',
              'action': 'comment_mention',
              'mentionerId': 'user_456',
            },
          ),
        ).called(1);
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
        verifyNever(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        );
      });
    });

    group('Notification Batching', () {
      test('should batch multiple comment notifications', () async {
        // Arrange
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final comments = List.generate(
          3,
          (i) => RecipeComment(
            id: 'comment_$i',
            recipeId: 'recipe_1',
            authorId: 'user_${456 + i}',
            authorDisplayName: 'User $i',
            text: 'Comment $i',
            createdAt: DateTime.now().add(Duration(minutes: i)),
          ),
        );

        // Act
        for (final comment in comments) {
          await CommentNotifications.sendCommentNotifications(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            comment: comment,
          );
        }

        // Assert
        verify(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: NotificationStrategy.recipeComment,
            variables: any(named: 'variables'),
            variablesByLocale: any(named: 'variablesByLocale'),
            additionalData: any(named: 'additionalData'),
          ),
        ).called(3);
      });
    });
  });
}
