/// Direct unit tests for [TagPhase2Derived] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Phase 2 derives tags purely from Phase 1's tags + the recipe (no Phase 3-5
/// chain), so calculate() is directly testable: base→dish-type derivation, the
/// few-ingredients threshold, and the meal-context tags (dessert/fika/frukost/
/// dryck) from Phase-1 tags. The coverage-gated spicy/mild tags need a populated
/// IngredientLookupResult and are left to the tagging integration tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

Phase1Result p1({Set<String> tags = const {}}) => Phase1Result(
  tags: tags,
  allergenStatus: const {},
  dietaryStatus: const {},
  lookup: IngredientLookupResult.empty(),
);

void main() {
  final phase2 = TagPhase2Derived();

  // A recipe with >6 ingredients + a neutral title, so "få-ingredienser" and
  // the title-keyword rules don't fire unless a test wants them to.
  Recipe plainRecipe() => RecipeFactory.build(
    title: 'Vardagsmat',
    ingredients: List.generate(8, (i) => 'ingrediens $i'),
  );

  group('base → dish-type derivation', () {
    final cases = {
      'pastabaserad': 'pasta-dish',
      'risbaserad': 'rice-dish',
      'nudelbaserad': 'noodle-dish',
      'potatisbaserad': 'potato-dish',
      'brödbaserad': 'bread-dish',
    };
    cases.forEach((baseTag, dishTag) {
      test('$baseTag → $dishTag', () {
        final r = phase2.calculate(p1(tags: {baseTag}), plainRecipe());
        expect(r.tags, contains(dishTag));
      });
    });
  });

  group('få-ingredienser threshold', () {
    test('added for 6 or fewer ingredients', () {
      final recipe = RecipeFactory.build(
        title: 'Vardagsmat',
        ingredients: ['a', 'b', 'c'],
      );
      expect(
        phase2.calculate(p1(), recipe).tags,
        contains('få-ingredienser'),
      );
    });

    test('not added above 6 ingredients', () {
      expect(
        phase2.calculate(p1(), plainRecipe()).tags,
        isNot(contains('få-ingredienser')),
      );
    });
  });

  group('meal-context tags from Phase-1 tags', () {
    test('kaka yields both dessert and fika', () {
      final r = phase2.calculate(p1(tags: {'kaka'}), plainRecipe());
      expect(r.tags, containsAll(<String>['dessert', 'fika']));
    });

    test('smoothie yields dryck', () {
      final r = phase2.calculate(p1(tags: {'smoothie'}), plainRecipe());
      expect(r.tags, contains('dryck'));
    });

    test('pannkaka yields frukost', () {
      final r = phase2.calculate(p1(tags: {'pannkaka'}), plainRecipe());
      expect(r.tags, contains('frukost'));
    });

    test('a title keyword (drink) also yields dryck', () {
      final recipe = RecipeFactory.build(
        title: 'Grön drink',
        ingredients: List.generate(8, (i) => 'i$i'),
      );
      expect(phase2.calculate(p1(), recipe).tags, contains('dryck'));
    });
  });

  group('Phase2Result', () {
    test('hasTag covers both phase-2 and phase-1 tags; allTags merges', () {
      final r = phase2.calculate(p1(tags: {'pastabaserad'}), plainRecipe());
      expect(r.hasTag('pasta-dish'), isTrue); // derived in phase 2
      expect(r.hasTag('pastabaserad'), isTrue); // inherited from phase 1
      expect(r.allTags, containsAll(<String>['pastabaserad', 'pasta-dish']));
    });
  });
}
