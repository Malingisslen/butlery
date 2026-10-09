// BUT-697 chunk-1: Semantics coverage for comment item widgets.
// Verifies that the long-press target, react chip, and like-count text
// each expose discoverable Semantics labels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_support/semantics_announcement.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  RecipeComment makeComment({
    Map<String, List<String>> reactions = const {},
    int likeCount = 0,
  }) {
    return RecipeComment(
      id: 'c1',
      recipeId: 'r1',
      authorId: 'u1',
      authorDisplayName: 'Test Author',
      text: 'Hej, jättegott!',
      createdAt: DateTime.now(),
      likesCount: likeCount,
      reactions: reactions,
    );
  }

  testWidgets(
    'comment_item_widgets — long-press target exposes reaction prompt label',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => CommentItemWidgets.buildCommentItem(
              context: context,
              comment: makeComment(),
              authorDisplayName: 'Test Author',
              authorAvatarUrl: null,
              formattedTime: '2m',
              onReply: () {},
              onToggleLike: () {},
              onShowLikes: () {},
              currentUserId: 'me',
              onReactionTap: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Kommentar, långtryck för att reagera')),
        findsWidgets,
      );
      handle.dispose();
    },
  );

  testWidgets('comment_item_widgets — react hint chip exposes label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => CommentItemWidgets.buildCommentItem(
            context: context,
            comment: makeComment(),
            authorDisplayName: 'Test Author',
            authorAvatarUrl: null,
            formattedTime: '2m',
            onReply: () {},
            onToggleLike: () {},
            onShowLikes: () {},
            currentUserId: 'me',
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    final react = find.bySemanticsLabel(RegExp(r'^Reagera på kommentar'));
    expect(react, findsWidgets);
    expectNothingAnnouncedTwice(tester, react.first);
    expectActivatable(tester, react.first);
    handle.dispose();
  });

  testWidgets('comment_item_widgets — like-count text exposes plural label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => CommentItemWidgets.buildCommentItem(
            context: context,
            comment: makeComment(likeCount: 3),
            authorDisplayName: 'Test Author',
            authorAvatarUrl: null,
            formattedTime: '2m',
            onReply: () {},
            onToggleLike: () {},
            onShowLikes: () {},
            currentUserId: 'me',
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^Visa vem som gillat')),
      findsOneWidget,
    );
    expectNothingAnnouncedTwice(
      tester,
      find.bySemanticsLabel(RegExp(r'^Visa vem som gillat')),
    );
    handle.dispose();
  });
}
