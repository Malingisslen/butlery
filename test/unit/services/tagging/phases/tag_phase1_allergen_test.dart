/// BUT-1401: direct unit tests for `Phase1AllergenCalculator` — the per-allergen
/// FREE / CONTAINS / UNKNOWN computation the allergen-safe-filtering guarantee
/// rests on, which previously had zero direct coverage.
///
/// These run against the STATIC allergen fallback (firebaseConfig = null), so
/// they pin the real shipped allergen keys (gluten / mjölk / ...). The tri-valued
/// math itself lives in IngredientLookupResult.getPropertyStatus:
///   - coverage < 1.0            → UNKNOWN (can't confirm — safety-critical)
///   - a matched ingredient with the trigger property → CONTAINS
///   - full coverage, no trigger → FREE
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_allergen.dart';

import '../../../../infrastructure/helpers/tagging_test_helper.dart';

void main() {
  group('Phase1AllergenCalculator (static fallback, firebaseConfig=null)', () {
    test(
      'CONTAINS: matched ingredient carries the trigger property at full coverage',
      () {
        // gluten → trigger property "contains-gluten" (static AllergenConfig).
        final lookup = IngredientLookupResult(
          matched: [
            TaggingTestHelper.ingredient('vetemjöl', 'grain', {
              'contains-gluten',
            }),
          ],
          unmatched: const [],
          coverage: 1.0,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, null);

        expect(result.status['gluten'], TriState.contains);
      },
    );

    test(
      'FREE: full coverage and no ingredient carries the trigger property',
      () {
        final lookup = IngredientLookupResult(
          matched: [TaggingTestHelper.ingredient('ris', 'grain', const {})],
          unmatched: const [],
          coverage: 1.0,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, null);

        expect(result.status['gluten'], TriState.free);
      },
    );

    test(
      'UNKNOWN: coverage < 1.0 cannot confirm, even if the trigger is present',
      () {
        // Safety-critical: a partial lookup must NOT report FREE/CONTAINS — an
        // unanalysed ingredient could carry the allergen.
        final lookup = IngredientLookupResult(
          matched: [
            TaggingTestHelper.ingredient('vetemjöl', 'grain', {
              'contains-gluten',
            }),
          ],
          unmatched: const ['okänd ingrediens'],
          coverage: 0.5,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, null);

        expect(result.status['gluten'], TriState.unknown);
      },
    );

    test('a CONTAINS decision records the triggering ingredient', () {
      // mjölk → trigger property "dairy".
      final lookup = IngredientLookupResult(
        matched: [
          TaggingTestHelper.ingredient('grädde', 'dairy', {'dairy'}),
        ],
        unmatched: const [],
        coverage: 1.0,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, null);

      expect(result.status['mjölk'], TriState.contains);
      final dairyDecision = result.decisions.firstWhere(
        (d) => d.key == 'mjölk',
      );
      expect(dairyDecision.result, TriState.contains);
      expect(dairyDecision.triggeringIngredients, contains('grädde'));
    });

    test('every computed allergen status has a matching decision', () {
      final lookup = IngredientLookupResult(
        matched: [TaggingTestHelper.ingredient('ris', 'grain', const {})],
        unmatched: const [],
        coverage: 1.0,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, null);

      // The static config defines the core allergens — they all appear.
      expect(result.status.containsKey('gluten'), isTrue);
      expect(result.status.containsKey('mjölk'), isTrue);
      expect(result.status.containsKey('ägg'), isTrue);
      expect(result.decisions, isNotEmpty);
      for (final key in result.status.keys) {
        expect(
          result.decisions.any((d) => d.key == key),
          isTrue,
          reason: 'allergen "$key" has a status but no decision',
        );
      }
    });

    test('combined allergen (OR logic): one matched trigger → CONTAINS', () {
      // nötter → "tree-nut OR peanut". A peanut match alone must flag it.
      final lookup = IngredientLookupResult(
        matched: [
          TaggingTestHelper.ingredient('jordnötter', 'nut', {'peanut'}),
        ],
        unmatched: const [],
        coverage: 1.0,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, null);

      expect(result.status['nötter'], TriState.contains);
    });

    test(
      'combined allergen: full coverage, neither trigger present → FREE',
      () {
        final lookup = IngredientLookupResult(
          matched: [TaggingTestHelper.ingredient('ris', 'grain', const {})],
          unmatched: const [],
          coverage: 1.0,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, null);

        expect(result.status['nötter'], TriState.free);
      },
    );
  });
}
