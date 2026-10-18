// Megagenomgång A43: every recipe-activity notification is rendered from the
// variables its real caller sends, and no "{placeholder}" survives into the
// push text. The recipe-comment template used to ask for {count}, which no
// caller sends.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/notifications/modules/notification_content_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/operations/modules/comment_notifications.dart';
import 'package:butlery/services/unified/operations/modules/rating_notifications.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _Sent {
  _Sent(this.strategy, this.variables);
  final NotificationStrategy strategy;
  final Map<String, String> variables;
}

void main() {
  late MockNotificationService service;
  late List<_Sent> sent;
  late Recipe recipe;
  late RecipeComment comment;
  late RecipeComment reply;

  setUpAll(() {
    registerFallbackValue(NotificationStrategy.recipeComment);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<NotificationAction>[]);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = MockNotificationService();
    sent = [];

    void capture(Invocation i) {
      sent.add(
        _Sent(
          i.namedArguments[#strategy] as NotificationStrategy,
          i.namedArguments[#variables] as Map<String, String>,
        ),
      );
    }

    when(
      () => service.sendImmediateNotification(
        variablesByLocale: any(named: 'variablesByLocale'),
        targetUserIds: any(named: 'targetUserIds'),
        strategy: any(named: 'strategy'),
        variables: any(named: 'variables'),
        additionalData: any(named: 'additionalData'),
        actions: any(named: 'actions'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer((i) async => capture(i));
    when(
      () => service.sendBatchableNotification(
        targetUserIds: any(named: 'targetUserIds'),
        strategy: any(named: 'strategy'),
        variables: any(named: 'variables'),
        variablesByLocale: any(named: 'variablesByLocale'),
        additionalData: any(named: 'additionalData'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer((i) async => capture(i));

    recipe = Recipe(
      core: RecipeCore(
        id: 'recipe_1',
        title: 'Köttbullar',
        description: 'd',
        ingredients: const ['a'],
        instructions: const ['b'],
        mealType: 'Middag',
        createdBy: 'owner',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: 'owner',
        ownerDisplayName: 'Ägaren',
        memberPermissions: {
          'owner': ResourcePermission.owner,
          'friend': ResourcePermission.editor,
          'mentioned': ResourcePermission.viewer,
        },
      ),
    );
    comment = RecipeComment(
      id: 'c1',
      recipeId: 'recipe_1',
      authorId: 'friend',
      authorDisplayName: 'Kim',
      text: 'Gott!',
      createdAt: DateTime(2026, 10, 2),
    );
    reply = RecipeComment(
      id: 'r1',
      recipeId: 'recipe_1',
      parentCommentId: 'c1',
      authorId: 'mentioned',
      authorDisplayName: 'Sam',
      text: 'Håller med',
      createdAt: DateTime(2026, 10, 3),
    );
  });

  tearDown(BaseUnitTest.resetMocks);

  test('every sender fills its template and leaves no placeholder', () async {
    await CommentNotifications.sendCommentNotifications(
      notificationService: service,
      recipe: recipe,
      comment: comment,
    );
    await CommentNotifications.sendReplyNotifications(
      notificationService: service,
      recipe: recipe,
      reply: reply,
      parentComment: comment,
    );
    await CommentNotifications.sendMentionNotifications(
      notificationService: service,
      recipe: recipe,
      comment: comment,
      mentionedUserIds: const ['mentioned'],
    );
    await CommentNotifications.sendLikeNotifications(
      notificationService: service,
      recipe: recipe,
      comment: comment,
      likerUserId: 'mentioned',
      likerDisplayName: 'Sam',
    );
    await RatingNotifications.sendRatingNotification(
      notificationService: service,
      recipe: recipe,
      rating: 4,
      raterName: 'Kim',
    );
    await RatingNotifications.sendFirstRatingNotification(
      notificationService: service,
      recipe: recipe,
      rating: 5,
      raterName: 'Kim',
      review: 'Mycket gott',
    );
    await RatingNotifications.sendRatingMilestoneNotification(
      notificationService: service,
      recipe: recipe,
      totalRatings: 10,
      averageRating: 4.2,
    );
    await RatingNotifications.sendRatingSummaryNotification(
      notificationService: service,
      userId: 'owner',
      recipeRatingSummaries: const [
        {'recipeName': 'Köttbullar', 'newRatings': 3},
      ],
      period: 'weekly',
    );

    expect(sent, hasLength(8));
    final manager = NotificationContentManager(userId: 'owner');
    for (final s in sent) {
      final template = manager.createTemplate(
        strategy: s.strategy,
        variables: s.variables,
      );
      expect(template.title, isNot(contains('{')), reason: template.title);
      expect(template.body, isNot(contains('{')), reason: template.body);
      expect(template.body.trim(), isNotEmpty);
    }
  });
}
