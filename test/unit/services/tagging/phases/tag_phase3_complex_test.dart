/// Direct unit tests for [TagPhase3Complex] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Phase 3 derives from Phase 1 + Phase 2 + the recipe. The deterministic,
/// lookup-independent rules are tested here: the difficulty tag (from ingredient
/// count + time + advanced-technique scan) and the storkok batch tag (portions
/// or title). The texture/nutrition helpers depend on a populated
/// IngredientLookupResult's ingredient groups and are left to integration.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

Phase1Result p1({Set<String> tags = const {}}) => Phase1Result(
  tags: tags,
  allergenStatus: const {},
  dietaryStatus: const {},
  lookup: IngredientLookupResult.empty(),
);

Phase2Result p2(Phase1Result base, {Set<String> tags = const {}}) =>
    Phase2Result(tags: tags, phase1: base);

Recipe recipe({
  int ingredientCount = 8,
  int timeMinutes = 45,
  int portions = 4,
  String title = 'Vardagsmat',
}) => RecipeFactory.build(
  title: title,
  portions: portions,
  timeMinutes: timeMinutes,
  ingredients: List.generate(ingredientCount, (i) => 'ingrediens $i'),
  instructions: const ['blanda allt', 'servera'],
);

void main() {
  final phase3 = TagPhase3Complex();

  Phase3Result run(Recipe r, {Set<String> p1Tags = const {}}) {
    final a = p1(tags: p1Tags);
    return phase3.calculate(a, p2(a), r);
  }

  group('difficulty', () {
    test('few ingredients + short time → enkel', () {
      final r = run(recipe(ingredientCount: 3, timeMinutes: 20));
      expect(r.tags, contains('enkel'));
    });

    test('many ingredients or long time → avancerad', () {
      final r = run(recipe(ingredientCount: 15, timeMinutes: 90));
      expect(r.tags, contains('avancerad'));
    });

    test('in-between → medel', () {
      final r = run(recipe(ingredientCount: 8, timeMinutes: 45));
      expect(r.tags, contains('medel'));
    });
  });

  group('storkok (batch cooking)', () {
    test('added for 6+ portions', () {
      expect(run(recipe(portions: 6)).tags, contains('storkok'));
    });

    test('added when the title says storkok', () {
      expect(
        run(recipe(portions: 4, title: 'Storkok köttgryta')).tags,
        contains('storkok'),
      );
    });

    test('not added for a normal small-batch recipe', () {
      expect(
        run(recipe(portions: 4, title: 'Vardagsmat')).tags,
        isNot(contains('storkok')),
      );
    });
  });

  group('Phase3Result', () {
    test('hasTag spans phase 1/2/3 and allTags merges them', () {
      final base = p1(tags: {'p1tag'});
      final result = phase3.calculate(
        base,
        p2(base, tags: {'p2tag'}),
        recipe(ingredientCount: 3, timeMinutes: 20),
      );
      expect(result.hasTag('enkel'), isTrue); // phase 3
      expect(result.hasTag('p2tag'), isTrue); // phase 2
      expect(result.hasTag('p1tag'), isTrue); // phase 1
      expect(
        result.allTags,
        containsAll(<String>['p1tag', 'p2tag', 'enkel']),
      );
    });
  });
}
