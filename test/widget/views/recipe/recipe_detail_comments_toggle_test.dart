// BUT-2349: the comments header says what a tap does, once, and carries its
// expanded state as a flag instead of in the label.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/semantics_announcement.dart';

void main() {
  testWidgets('the comments toggle reads "Visa eller dölj" once with its '
      'toggled state', (tester) async {
    final handle = tester.ensureSemantics();
    final vm = MockSocialRecipeViewModel();
    when(() => vm.initialize()).thenAnswer((_) async {});
    when(() => vm.refreshComments(any())).thenAnswer((_) async {});
    when(() => vm.startWatchingComments(any())).thenAnswer((_) async {});
    when(() => vm.stopWatchingComments()).thenReturn(null);
    when(() => vm.topLevelComments).thenReturn(const <RecipeComment>[]);
    final recipe = Recipe(
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
        createdBy: 'u1',
      ),
      type: RecipeType.personal,
    );

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<SocialRecipeViewModel>.value(
          value: vm,
          child: RecipeDetailComments(recipe: recipe),
        ),
      ),
    );
    await tester.pump();

    final toggle = find.bySemanticsLabel(RegExp('^Visa eller dölj'));
    expect(toggle, findsOneWidget);
    final lines = announcedLines(tester, toggle);
    expect(lines.where((l) => l == 'Visa eller dölj'), hasLength(1));
    expect(
      lines.where((l) => l == 'Kommentarer'),
      hasLength(1),
      reason: '$lines',
    );
    expectNothingAnnouncedTwice(tester, toggle);
    expectActivatable(tester, toggle);
    expect(
      tester.getSemantics(toggle).getSemanticsData().flagsCollection.isToggled,
      ui.Tristate.isFalse,
    );
    handle.dispose();
  });
}
