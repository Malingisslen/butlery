/// BUT-2107: a recipe whose `socialData.ownerId` is '' and whose `createdBy`
/// is a real uid belongs to that uid.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid: comment notifications went to the uid '' and never reached the
/// creator.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/operations/modules/comment_notifications.dart';

import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../test_support/base_unit_test.dart';

const _creator = 'user_creator';
const _commenter = 'user_commenter';

Recipe _recipe({
  String? createdBy = _creator,
  String ownerId = '',
  RecipeType type = RecipeType.collaborative,
}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Gryta',
    description: 'd',
    ingredients: const ['i'],
    instructions: const ['s'],
    mealType: 'Middag',
    createdBy: createdBy,
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  ),
  type: type,
  socialData: RecipeSocialData(
    ownerId: ownerId,
    memberPermissions: {_commenter: ResourcePermission.editor},
  ),
);

void main() {
  late MockNotificationService service;

  setUpAll(() async {
    registerFallbackValue(NotificationStrategy.recipeComment);
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    service = MockNotificationService();
    when(
      () => service.sendBatchableNotification(
        targetUserIds: any(named: 'targetUserIds'),
        strategy: any(named: 'strategy'),
        variables: any(named: 'variables'),
        variablesByLocale: any(named: 'variablesByLocale'),
        additionalData: any(named: 'additionalData'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<List<String>?> recipients(
    Recipe recipe, {
    String authorId = _commenter,
  }) async {
    await CommentNotifications.sendCommentNotifications(
      notificationService: service,
      recipe: recipe,
      comment: RecipeComment(
        id: 'c1',
        recipeId: 'r1',
        authorId: authorId,
        authorDisplayName: 'A',
        text: 'Hej',
        createdAt: DateTime(2026, 10, 8),
      ),
    );
    final calls = verify(
      () => service.sendBatchableNotification(
        targetUserIds: captureAny(named: 'targetUserIds'),
        strategy: any(named: 'strategy'),
        variables: any(named: 'variables'),
        variablesByLocale: any(named: 'variablesByLocale'),
        additionalData: any(named: 'additionalData'),
      ),
    ).captured;
    return calls.isEmpty ? null : (calls.single as List).cast<String>();
  }

  group('sendCommentNotifications', () {
    test('the creator is notified and the uid "" never is', () async {
      final to = await recipients(_recipe());

      expect(to, contains(_creator));
      expect(to, isNot(contains('')));
    });

    test('closing: both fields empty leaves only the other member', () async {
      final to = await recipients(
        _recipe(createdBy: '', ownerId: ''),
        authorId: 'someone',
      );

      expect(to, [_commenter]);
    });

    test('closing: the creator commenting on their own recipe notifies '
        'nobody extra', () async {
      final to = await recipients(_recipe(), authorId: _creator);

      expect(to, [_commenter]);
    });
  });

  group('shouldReceiveCommentNotifications', () {
    test('collaborative: the creator receives them when ownerId is empty', () {
      expect(
        CommentNotifications.shouldReceiveCommentNotifications(
          recipe: _recipe(),
          userId: _creator,
        ),
        isTrue,
      );
    });

    test('personal: the creator receives them when ownerId is empty', () {
      expect(
        CommentNotifications.shouldReceiveCommentNotifications(
          recipe: _recipe(type: RecipeType.personal),
          userId: _creator,
        ),
        isTrue,
      );
    });

    test('closing: someone else created it (both types)', () {
      for (final type in [RecipeType.personal, RecipeType.collaborative]) {
        expect(
          CommentNotifications.shouldReceiveCommentNotifications(
            recipe: _recipe(createdBy: 'other', type: type),
            userId: _creator,
          ),
          isFalse,
        );
      }
    });

    test('closing: both fields are empty (both types)', () {
      for (final type in [RecipeType.personal, RecipeType.collaborative]) {
        expect(
          CommentNotifications.shouldReceiveCommentNotifications(
            recipe: _recipe(createdBy: '', type: type),
            userId: _creator,
          ),
          isFalse,
        );
      }
    });
  });
}
