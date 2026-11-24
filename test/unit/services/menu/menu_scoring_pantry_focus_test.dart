// BUT-2498: "Använd det jag har hemma" lets pantry overlap decide the draw
// instead of nudging it, and never removes a recipe from it.

import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  final covered = RecipeFactory.build(id: 'covered', title: 'Covered');
  final half = RecipeFactory.build(id: 'half', title: 'Half');
  final none = RecipeFactory.build(id: 'none', title: 'None');

  const focus = MenuScoringContext(
    pantryFocus: true,
    pantryMatchByRecipeId: {'covered': 1.0, 'half': 0.5},
  );

  test('a fully covered recipe outweighs a half covered one, which '
      'outweighs one the pantry does not touch', () {
    expect(
      focus.multiplierFor(covered),
      closeTo(MenuScoringContext.pantryFocusBoost, 1e-9),
    );
    expect(
      focus.multiplierFor(covered),
      greaterThan(focus.multiplierFor(half)),
    );
    expect(focus.multiplierFor(half), greaterThan(focus.multiplierFor(none)));
  });

  test('a recipe the pantry does not touch stays selectable at weight 1', () {
    expect(focus.multiplierFor(none), 1.0);
  });

  test('the focus is not held down by the gentle combined cap', () {
    expect(
      focus.multiplierFor(covered),
      greaterThan(MenuScoringContext.maxCombinedBoost),
    );
  });

  test('a disliked recipe still weighs 0.05x under the focus', () {
    const disliked = MenuScoringContext(
      pantryFocus: true,
      pantryMatchByRecipeId: {'covered': 1.0},
      dislikedRecipeIds: {'covered'},
    );
    expect(
      disliked.multiplierFor(covered),
      closeTo(MenuScoringContext.pantryFocusBoost * 0.05, 1e-9),
    );
  });

  test('without the focus the old nudge is unchanged', () {
    const nudge = MenuScoringContext(pantryMatchByRecipeId: {'covered': 1.0});
    expect(nudge.multiplierFor(covered), closeTo(1.3, 1e-9));
  });
}
