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

  testWidgets('comment_item_widgets — reply and like are single buttons '
      'named by their tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    var replied = 0;
    var toggled = 0;
    Future<void> pump({required bool liked}) => tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => CommentItemWidgets.buildCommentItem(
            context: context,
            comment: makeComment(),
            authorDisplayName: 'Test Author',
            authorAvatarUrl: null,
            formattedTime: '2m',
            isLiked: liked,
            onReply: () => replied++,
            onToggleLike: () => toggled++,
            onShowLikes: () {},
            currentUserId: 'me',
            onReactionTap: (_) {},
          ),
        ),
      ),
    );
    Finder button(String name) => find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == name,
    );

    await pump(liked: false);
    for (final name in ['Svara på kommentar', 'Gilla kommentar']) {
      expect(button(name), findsOneWidget);
      expect(announcedLines(tester, button(name)), [name]);
      expectActivatable(tester, button(name));
      expect(find.bySemanticsLabel(RegExp('^$name')), findsNothing);
    }
    await tester.tap(button('Svara på kommentar'));
    await tester.tap(button('Gilla kommentar'));
    expect([replied, toggled], [1, 1]);

    await pump(liked: true);
    expect(announcedLines(tester, button('Ta bort gilla-markering')), [
      'Ta bort gilla-markering',
    ]);
    expect(button('Gilla kommentar'), findsNothing);
    handle.dispose();
  });

  Finder tooltipButton(String name) => find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == name,
  );

  testWidgets('comment_item_widgets — own comment edit and delete are '
      'named buttons that reach their callbacks', (tester) async {
    final handle = tester.ensureSemantics();
    var edited = 0;
    var deleted = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => CommentItemWidgets.buildCommentItem(
            context: context,
            comment: makeComment(),
            authorDisplayName: 'Test Author',
            authorAvatarUrl: null,
            formattedTime: '2m',
            isOwnComment: true,
            onReply: () {},
            onToggleLike: () {},
            onShowLikes: () {},
            onEdit: () => edited++,
            onDelete: () => deleted++,
            currentUserId: 'u1',
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    for (final name in ['Redigera kommentar', 'Ta bort kommentar']) {
      expect(tooltipButton(name), findsOneWidget);
      expect(announcedLines(tester, tooltipButton(name)), [name]);
      expectActivatable(tester, tooltipButton(name));
    }
    expect(tooltipButton('Anmäl kommentar'), findsNothing);
    await tester.tap(tooltipButton('Redigera kommentar'));
    await tester.tap(tooltipButton('Ta bort kommentar'));
    expect([edited, deleted], [1, 1]);
    handle.dispose();
  });

  testWidgets('comment_item_widgets — other users comment report is a '
      'named button', (tester) async {
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

    final report = tooltipButton('Anmäl kommentar');
    expect(report, findsOneWidget);
    expect(announcedLines(tester, report), ['Anmäl kommentar']);
    expectActivatable(tester, report);
    expect(tooltipButton('Redigera kommentar'), findsNothing);
    expect(tooltipButton('Ta bort kommentar'), findsNothing);
    handle.dispose();
  });

  testWidgets('comment_item_widgets — like-count text exposes plural label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var shown = 0;
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
            onShowLikes: () => shown++,
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
    expectActivatable(
      tester,
      find.bySemanticsLabel(RegExp(r'^Visa vem som gillat')),
    );
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Visa vem som gillat')));
    expect(shown, 1);
    handle.dispose();
  });
}
