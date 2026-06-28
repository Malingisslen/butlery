/// Direct unit tests for [TagPhase5Cuisine.calculateFromPhase1] +
/// [Phase5ResultPartial] (BUT-1149 coverage burndown — previously zero direct
/// coverage).
///
/// Phase 5 detects cuisine tags. The cleanly-testable surface (no Phase 2-4
/// chain) is the CRIT-7 Phase-1 fallback path: calculateFromPhase1 + the
/// Phase5ResultPartial merge. The schema.org-cuisine shortcut is exercised
/// against the REAL CuisineConfig (reading a live keyword→tag pair, so the test
/// survives config edits). The full calculate() (needs Phase4Result) is left to
/// tagging integration tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

Phase1Result phase1({Set<String> tags = const {}}) => Phase1Result(
  tags: tags,
  allergenStatus: const {},
  dietaryStatus: const {},
  lookup: IngredientLookupResult.empty(),
);

void main() {
  group('Phase5ResultPartial', () {
    test('allTags merges phase-1 tags with the cuisine tags', () {
      final partial = Phase5ResultPartial(
        tags: const {'italiensk'},
        phase1: phase1(tags: {'under-30-min'}),
      );
      expect(
        partial.allTags,
        containsAll(<String>['under-30-min', 'italiensk']),
      );
      expect(partial.hasTag('italiensk'), isTrue);
      expect(partial.hasTag('nope'), isFalse);
    });
  });

  group('calculateFromPhase1', () {
    test(
      'detects a cuisine from a title keyword via the live CuisineConfig',
      () {
        // Read a real keyword→tag pair from the shipped config so this stays
        // correct as the config evolves; matching by title hits the static path.
        final entry = CuisineConfig.cuisines.firstWhere(
          (c) => c.titleKeywords.isNotEmpty,
        );
        final keyword = entry.titleKeywords.first;

        final recipe = RecipeFactory.build(title: 'Min $keyword middag');
        final result = TagPhase5Cuisine().calculateFromPhase1(phase1(), recipe);

        expect(result.tags, contains(entry.tag));
      },
    );

    test('carries the phase-1 tags through into allTags', () {
      final recipe = RecipeFactory.build(title: 'Zzxqv plain dish');
      final result = TagPhase5Cuisine().calculateFromPhase1(
        phase1(tags: {'under-15-min'}),
        recipe,
      );
      expect(result.allTags, contains('under-15-min'));
      expect(result.phase1.tags, contains('under-15-min'));
    });
  });
}
