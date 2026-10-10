// BUT-1625: a dish no meal this week could take without someone at home
// disliking it is down-weighted to 0.05x, never excluded.

import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  final disliked = RecipeFactory.build(id: 'disliked', title: 'Disliked');
  final other = RecipeFactory.build(id: 'other', title: 'Other');

  group('MenuScoringContext dislikedRecipeIds', () {
    test('a disliked recipe weighs 0.05x the same recipe without', () {
      const without = MenuScoringContext();
      const withDislike = MenuScoringContext(dislikedRecipeIds: {'disliked'});

      expect(without.multiplierFor(disliked), 1.0);
      expect(withDislike.multiplierFor(disliked), closeTo(0.05, 1e-9));
    });

    test('the 0.05 applies on top of an existing boost, not instead of it', () {
      // A fully pantry-matched recipe gets pantryMaxBoost (1.3x).
      const boosted = MenuScoringContext(
        pantryMatchByRecipeId: {'disliked': 1.0},
      );
      const boostedAndDisliked = MenuScoringContext(
        pantryMatchByRecipeId: {'disliked': 1.0},
        dislikedRecipeIds: {'disliked'},
      );

      expect(boosted.multiplierFor(disliked), closeTo(1.3, 1e-9));
      expect(
        boostedAndDisliked.multiplierFor(disliked),
        closeTo(boosted.multiplierFor(disliked) * 0.05, 1e-9),
      );
    });

    test('a recipe that is not disliked keeps its weight', () {
      const context = MenuScoringContext(
        pantryMatchByRecipeId: {'other': 1.0},
        dislikedRecipeIds: {'disliked'},
      );
      const same = MenuScoringContext(pantryMatchByRecipeId: {'other': 1.0});

      expect(context.multiplierFor(other), same.multiplierFor(other));
      expect(context.multiplierFor(other), closeTo(1.3, 1e-9));
    });

    test('a disliked recipe stays selectable: its weight is above zero', () {
      const context = MenuScoringContext(dislikedRecipeIds: {'disliked'});
      expect(context.multiplierFor(disliked), greaterThan(0));
    });

    test('the empty context is still the identity', () {
      expect(MenuScoringContext.empty.dislikedRecipeIds, isEmpty);
      expect(MenuScoringContext.empty.multiplierFor(disliked), 1.0);
    });
  });
}
