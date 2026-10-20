/// Megagenomgång A19, A20: an own comment is deleted when the undo window
/// closes even if the page was left meanwhile (no confirm dialog), and a reply
/// to a reply is shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/observers/snackbar_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/base_unit_test.dart';

RecipeComment _comment(String id, String text, {String? parent}) =>
    RecipeComment(
      id: id,
      recipeId: 'r1',
      authorId: 'me',
      authorDisplayName: 'Jag',
      text: text,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      parentCommentId: parent,
    );

Recipe _recipe() => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Pannkakor',
    description: '',
    ingredients: const ['mjöl'],
    instructions: const ['Vispa'],
    mealType: 'Middag',
    timeMinutes: 20,
    portions: 4,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    createdBy: 'me',
  ),
  type: RecipeType.personal,
);

MockSocialRecipeViewModel _stubbedVm(
  List<RecipeComment> topLevel, {
  List<RecipeComment> Function(String id)? repliesOf,
}) {
  final vm = MockSocialRecipeViewModel();
  when(() => vm.initialize()).thenAnswer((_) async {});
  when(() => vm.refreshComments(any())).thenAnswer((_) async {});
  when(() => vm.startWatchingComments(any())).thenAnswer((_) async {});
  when(() => vm.stopWatchingComments()).thenReturn(null);
  when(() => vm.deleteComment(any(), any())).thenAnswer((_) async {});
  when(() => vm.topLevelComments).thenReturn(topLevel);
  when(() => vm.comments).thenReturn(topLevel);
  when(
    () => vm.getReplies(any()),
  ).thenAnswer(
    (i) =>
        repliesOf?.call(i.positionalArguments.first as String) ??
        const <RecipeComment>[],
  );
  when(() => vm.commentsError).thenReturn(null);
  when(() => vm.isReplying).thenReturn(false);
  when(() => vm.isPostingComment).thenReturn(false);
  when(() => vm.newCommentText).thenReturn('');
  when(() => vm.friends).thenReturn(const []);
  when(
    () => vm.currentUser,
  ).thenReturn(MockFactory.createUserProfile(userId: 'me'));
  when(() => vm.getAuthorDisplayName(any())).thenReturn('Jag');
  when(() => vm.getAuthorAvatarUrl(any())).thenReturn(null);
  when(() => vm.hasLikedComment(any())).thenReturn(false);
  return vm;
}

Widget _commentsApp(MockSocialRecipeViewModel vm) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: ChangeNotifierProvider<SocialRecipeViewModel>.value(
        value: vm,
        child: RecipeDetailComments(recipe: _recipe()),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets('a reply to a reply is shown, also below the indent limit', (
    tester,
  ) async {
    final comments = [
      _comment('a', 'rot'),
      _comment('b', 'svar', parent: 'a'),
      _comment('c', 'svar på svar', parent: 'b'),
      _comment('d', 'svar på svar på svar', parent: 'c'),
      _comment('e', 'svar fem', parent: 'd'),
    ];
    List<RecipeComment> repliesOf(String id) =>
        comments.where((c) => c.parentCommentId == id).toList();

    late Widget thread;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            thread = CommentItemWidgets.buildCommentWithReplies(
              context: context,
              comment: comments.first,
              replies: repliesOf('a'),
              repliesFor: repliesOf,
              commentBuilder: (c, depth) => Text(c.text),
            );
            return Scaffold(body: SingleChildScrollView(child: thread));
          },
        ),
      ),
    );

    for (final c in comments) {
      expect(find.text(c.text), findsOneWidget, reason: c.id);
    }
  });

  setUp(() async {
    // CommentFormWidget resolves its pickers from the production locator.
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  testWidgets('own comment: no dialog, and the delete is committed when the '
      'page is left inside the undo window', (tester) async {
    final comments = [_comment('a', 'min kommentar')];
    final vm = _stubbedVm(comments);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightTheme,
        navigatorObservers: [SnackbarRouteObserver()],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: SingleChildScrollView(
                      child:
                          ChangeNotifierProvider<SocialRecipeViewModel>.value(
                            value: vm,
                            child: RecipeDetailComments(recipe: _recipe()),
                          ),
                    ),
                  ),
                ),
              ),
              child: const Text('öppna'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kommentarer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Radera kommentaren'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing, reason: 'no confirm dialog');
    expect(find.byType(SnackBar), findsOneWidget);
    verifyNever(() => vm.deleteComment(any(), any()));

    // Leave the page inside the undo window.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    verify(() => vm.deleteComment('r1', 'a')).called(1);
  });

  testWidgets('view threads a reply to a reply through the VM getReplies', (
    tester,
  ) async {
    final a = _comment('a', 'rot');
    final b = _comment('b', 'svar', parent: 'a');
    final c = _comment('c', 'svar på svar', parent: 'b');
    final vm = _stubbedVm(
      [a],
      repliesOf: (id) => switch (id) {
        'a' => [b],
        'b' => [c],
        _ => const <RecipeComment>[],
      },
    );

    await tester.pumpWidget(_commentsApp(vm));
    await tester.tap(find.text('Kommentarer'));
    await tester.pumpAndSettle();

    expect(find.text('rot'), findsOneWidget);
    expect(find.text('svar'), findsOneWidget);
    expect(find.text('svar på svar'), findsOneWidget);
  });

  testWidgets('the comment form is given the recipe\'s name, which a comment '
      'that has to wait on the device is listed under', (tester) async {
    final vm = _stubbedVm([_comment('a', 'rot')]);

    await tester.pumpWidget(_commentsApp(vm));
    await tester.tap(find.text('Kommentarer'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CommentFormWidget>(find.byType(CommentFormWidget))
          .recipeName,
      'Pannkakor',
    );
  });
}
