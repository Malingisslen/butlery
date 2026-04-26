// BUT-697 chunk-1: Semantics coverage for the legacy threaded CommentItemWidget.
// Verifies the Like and Reply buttons each surface localized Semantics labels.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/recipe/comment_item_widget.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

class _FakeSocialRecipeViewModel extends Mock
    implements SocialRecipeViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  testWidgets(
      'comment_item_widget — like and reply buttons expose Semantics labels',
      (tester) async {
    final handle = tester.ensureSemantics();
    final vm = _FakeSocialRecipeViewModel();
    when(() => vm.getAuthorDisplayName(any())).thenReturn('Test Author');
    when(() => vm.getAuthorAvatarUrl(any())).thenReturn(null);
    when(() => vm.hasLikedComment(any())).thenReturn(false);
    when(() => vm.getReplies(any())).thenReturn(const <RecipeComment>[]);

    final comment = RecipeComment(
      id: 'c1',
      recipeId: 'r1',
      authorId: 'u1',
      authorDisplayName: 'Test Author',
      text: 'Trevligt!',
      createdAt: DateTime.now(),
      likesCount: 0,
    );

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: CommentItemWidget(
          socialViewModel: vm,
          comment: comment,
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp(r'Gilla kommentar')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'Svara på kommentar')), findsWidgets);
    handle.dispose();
  });
}
