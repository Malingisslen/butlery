/// Widget tests for [CommentFormWidget]'s draft-persistence cycle (BUT-1058,
/// follow-up to BUT-917). The widget persists in-flight comment text per recipe
/// under `comment_draft_v1_<recipeId>` SharedPreferences keys: load on mount,
/// save on every keystroke, clear on successful post, isolated per recipe.
///
/// These assert data/persistence behaviour (TextField content + prefs values),
/// NOT visual appearance, so they need no human visual verification.
///
/// The viewmodel is faked via mocktail — the widget only reads a handful of
/// getters and records two calls (`updateNewCommentText`, `postComment`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';

class _FakeSocialRecipeViewModel extends Mock
    implements SocialRecipeViewModel {}

const _kDraftPrefix = 'comment_draft_v1_';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

void main() {
  late _FakeSocialRecipeViewModel vm;

  setUp(() {
    vm = _FakeSocialRecipeViewModel();
    // Default getter stubs — the widget reads these in build(). Overridden
    // per-test where the case needs a specific value (e.g. non-empty text to
    // enable the send button).
    when(() => vm.isReplying).thenReturn(false);
    when(() => vm.isPostingComment).thenReturn(false);
    when(() => vm.newCommentText).thenReturn('');
    when(() => vm.currentUser).thenReturn(null);
    when(() => vm.updateNewCommentText(any())).thenReturn(null);
  });

  CommentFormWidget buildWidget(String recipeId) => CommentFormWidget(
        socialViewModel: vm,
        recipeId: recipeId,
        onShowMessage: (_, {bool isError = false}) {},
      );

  testWidgets('load on mount: seeds TextField from prefs and syncs VM',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'${_kDraftPrefix}r1': 'half-written'});

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    // _loadDraft is async (SharedPreferences.getInstance) — let it settle.
    await tester.pumpAndSettle();

    expect(find.text('half-written'), findsOneWidget,
        reason: 'mounted draft must populate the TextField');
    verify(() => vm.updateNewCommentText('half-written')).called(1);
  });

  testWidgets('save on edit: each keystroke persists to prefs', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${_kDraftPrefix}r1'), 'fresh',
        reason: 'onChanged must persist the draft under the recipe key');
  });

  testWidgets('clear on post-success: draft key is removed', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'${_kDraftPrefix}r1': 'about to send'});
    // Send button is enabled only when newCommentText is non-empty + not posting.
    when(() => vm.newCommentText).thenReturn('about to send');
    when(() => vm.postComment('r1')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    verify(() => vm.postComment('r1')).called(1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${_kDraftPrefix}r1'), isNull,
        reason: 'successful post must clear the persisted draft');
  });

  testWidgets('per-recipe isolation: r2 ignores r1 draft and leaves it intact',
      (tester) async {
    SharedPreferences.setMockInitialValues({'${_kDraftPrefix}r1': 'r1 only'});

    await tester.pumpWidget(_wrap(buildWidget('r2')));
    await tester.pumpAndSettle();

    // r2's field stays empty — it must not read r1's draft.
    expect(find.text('r1 only'), findsNothing,
        reason: 'a different recipe must not load another recipe\'s draft');
    verifyNever(() => vm.updateNewCommentText('r1 only'));

    // r1's draft is untouched by mounting r2.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${_kDraftPrefix}r1'), 'r1 only',
        reason: 'mounting r2 must not disturb r1\'s persisted draft');
  });
}
