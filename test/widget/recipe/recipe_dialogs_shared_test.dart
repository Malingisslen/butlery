import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/recipe/collaboration_enable_dialog.dart';
import 'package:butlery/widgets/recipe/comment_audience_dialog.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';

import '../../helpers/user_profile_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late AppLocalizations l10n;

  Future<void> open(
    WidgetTester tester,
    void Function(BuildContext context) onOpen,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Center(
              child: ElevatedButton(
                onPressed: () => onOpen(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('comment audience dialog', () {
    testWidgets('lists every resolved name and counts the rest', (
      tester,
    ) async {
      await open(
        tester,
        (c) => showCommentAudienceDialog(
          c,
          resolved: ['Anna', 'Björn'],
          total: 5,
        ),
      );

      expect(find.text(l10n.recipeCommentAudienceTitle), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Björn'), findsOneWidget);
      expect(find.text(l10n.recipeCommentAudienceOthers(3)), findsOneWidget);
    });

    testWidgets('names nobody when no name resolved, but discloses the total', (
      tester,
    ) async {
      await open(
        tester,
        (c) => showCommentAudienceDialog(c, resolved: [], total: 4),
      );

      expect(find.text(l10n.recipeCommentVisiblePeople(4)), findsOneWidget);
      expect(find.text(l10n.recipeCommentAudienceOthers(4)), findsNothing);
    });
  });

  group('collaboration enable dialog', () {
    final friends = <UserProfile>[
      testUserProfile(uid: 'a', displayName: 'Anna'),
      testUserProfile(uid: 'b', displayName: 'Björn'),
    ];
    Set<String>? result;
    var done = false;

    Future<void> openPicker(WidgetTester tester) async {
      result = null;
      done = false;
      await open(tester, (c) async {
        result = await showCollaborationEnableDialog(c, friends: friends);
        done = true;
      });
    }

    testWidgets('Aktivera stays off until a friend is picked, then returns '
        'the picked uids', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.commonEnable));
      await tester.pumpAndSettle();
      expect(done, isFalse, reason: 'disabled button must not close it');

      await tester.tap(find.text('Björn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonEnable));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(result, {'b'});
    });

    testWidgets('cancelling returns null even after a pick', (tester) async {
      await openPicker(tester);
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(result, isNull);
    });
  });

  group('comment likes sheet', () {
    testWidgets('titles the count, lists each liker and offers a close', (
      tester,
    ) async {
      await open(
        tester,
        (c) => showButlerySheet<void>(
          context: c,
          builder: (_) => CommentItemWidgets.buildLikesDialog(
            context: c,
            likeCount: 2,
            likedByUserIds: ['a', 'b'],
            getDisplayName: (id) => id == 'a' ? 'Anna' : 'Björn',
            getAvatarUrl: (_) => null,
          ),
        ),
      );

      expect(find.text(l10n.socialLikesHeader(2)), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Björn'), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.commonClose), findsWidgets);
    });
  });
}
