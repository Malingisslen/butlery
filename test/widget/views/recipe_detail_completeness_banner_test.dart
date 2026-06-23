// test/widget/views/recipe_detail_completeness_banner_test.dart
//
// BUT-1230: the completeness ("improve") banner overflowed its title Row at
// narrow widths — the title Text had no Flexible, so a RenderFlex overflow
// fired for any recipe below the completeness threshold on a <=420px surface.
// These tests pump the banner alone (the overflow is internal to it; the full
// RecipeDetailView shell isn't needed) at phone widths and rely on
// flutter_test's default behavior of failing on RenderFlex overflow.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  /// A recipe below the completeness threshold (one ingredient, no
  /// instructions, no portions/time/image) — every banner row renders.
  Recipe incompleteRecipe() => Recipe(
    core: RecipeCore(
      id: 'r-incomplete',
      title: 'Pannkakor',
      description: '',
      ingredients: ['mjöl'],
      instructions: const [],
      mealType: 'Middag',
    ),
    type: RecipeType.personal,
  );

  Future<void> pumpBannerAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) =>
              RecipeDetailSharedWidgets.buildCompletenessBanner(
                context,
                incompleteRecipe(),
              ),
        ),
      ),
    );
  }

  testWidgets('completeness banner renders without overflow at 375px', (
    tester,
  ) async {
    await pumpBannerAt(tester, 375);
    expect(
      tester.takeException(),
      isNull,
      reason: 'RenderFlex overflow at phone width is the BUT-1230 bug',
    );
    expect(find.byIcon(Icons.tips_and_updates_outlined), findsOneWidget);
  });

  testWidgets('completeness banner renders without overflow at 320px '
      '(smallest supported phone)', (tester) async {
    await pumpBannerAt(tester, 320);
    expect(tester.takeException(), isNull);
  });
}
