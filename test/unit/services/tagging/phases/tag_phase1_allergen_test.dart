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
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_allergen.dart';

import '../../../../infrastructure/helpers/tagging_test_helper.dart';

/// Builds a [FirebaseTagConfig] whose allergen document carries [entries].
///
/// Only the allergen document is meaningful for these tests; the other four
/// config documents deserialize from empty maps (safe defaults). `displayOrder`
/// mirrors the entry keys because `enabledEntries` (and therefore
/// simple/combined classification) is driven off displayOrder.
FirebaseTagConfig _configWithAllergens(List<Map<String, dynamic>> entries) {
  return FirebaseTagConfig.fromDocuments(
    allergensData: {
      'schemaVersion': 1,
      'version': 1,
      'updatedBy': 'test',
      'displayOrder': entries.map((e) => e['key']).toList(),
      'entries': entries,
    },
    dietaryData: const {},
    cuisinesData: const {},
    propertiesData: const {},
    displayData: const {},
  );
}

Map<String, dynamic> _allergenEntry(
  String key,
  List<String> triggerProperties,
) => {
  'key': key,
  'triggerProperties': triggerProperties,
  'enabled': true,
};

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

  // The BUT-1401 coverage only exercised the static-fallback (firebaseConfig =
  // null) branch. These pin the admin-editable path: when a live Firebase config
  // IS present, the calculator derives allergen keys/trigger-properties from it
  // instead of the hardcoded static config. Uses arbitrary keys ('X-allergen')
  // to prove the keys come from the passed config, not the static fallback.
  group('Phase1AllergenCalculator (Firebase config provided)', () {
    test('simple allergen from config: CONTAINS at full coverage', () {
      final config = _configWithAllergens([
        _allergenEntry('X-allergen', ['prop-x']),
      ]);
      final lookup = IngredientLookupResult(
        matched: [
          TaggingTestHelper.ingredient('xfood', 'test', {'prop-x'}),
        ],
        unmatched: const [],
        coverage: 1.0,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, config);

      expect(result.status['X-allergen'], TriState.contains);
      final decision = result.decisions.firstWhere(
        (d) => d.key == 'X-allergen',
      );
      expect(decision.triggeringIngredients, contains('xfood'));
    });

    test('simple allergen from config: FREE at full coverage, no trigger', () {
      final config = _configWithAllergens([
        _allergenEntry('X-allergen', ['prop-x']),
      ]);
      final lookup = IngredientLookupResult(
        matched: [TaggingTestHelper.ingredient('ris', 'grain', const {})],
        unmatched: const [],
        coverage: 1.0,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, config);

      expect(result.status['X-allergen'], TriState.free);
    });

    test('simple allergen from config: coverage < 1.0 → UNKNOWN', () {
      final config = _configWithAllergens([
        _allergenEntry('X-allergen', ['prop-x']),
      ]);
      final lookup = IngredientLookupResult(
        matched: [
          TaggingTestHelper.ingredient('xfood', 'test', {'prop-x'}),
        ],
        unmatched: const ['okänd'],
        coverage: 0.5,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, config);

      expect(result.status['X-allergen'], TriState.unknown);
    });

    test(
      'simple allergen with EMPTY triggerProperties is skipped (CRIT-1), not '
      'emitted as FREE',
      () {
        // Safety-critical: a misconfigured allergen with no trigger property
        // must NOT silently resolve to FREE — it is dropped entirely so nothing
        // claims "fritt från" without evidence.
        final config = _configWithAllergens([
          _allergenEntry('broken', const []),
          _allergenEntry('X-allergen', ['prop-x']),
        ]);
        final lookup = IngredientLookupResult(
          matched: [TaggingTestHelper.ingredient('ris', 'grain', const {})],
          unmatched: const [],
          coverage: 1.0,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, config);

        expect(result.status.containsKey('broken'), isFalse);
        expect(result.status.containsKey('X-allergen'), isTrue);
      },
    );

    test(
      'combined allergen from config (OR logic): one trigger → CONTAINS',
      () {
        final config = _configWithAllergens([
          _allergenEntry('X-combined', ['prop-a', 'prop-b']),
        ]);
        final lookup = IngredientLookupResult(
          matched: [
            TaggingTestHelper.ingredient('bfood', 'test', {'prop-b'}),
          ],
          unmatched: const [],
          coverage: 1.0,
        );

        final result = Phase1AllergenCalculator.calculate(lookup, config);

        expect(result.status['X-combined'], TriState.contains);
      },
    );

    test('combined allergen from config: coverage < 1.0 → UNKNOWN', () {
      final config = _configWithAllergens([
        _allergenEntry('X-combined', ['prop-a', 'prop-b']),
      ]);
      final lookup = IngredientLookupResult(
        matched: [
          TaggingTestHelper.ingredient('bfood', 'test', {'prop-b'}),
        ],
        unmatched: const ['okänd'],
        coverage: 0.5,
      );

      final result = Phase1AllergenCalculator.calculate(lookup, config);

      expect(result.status['X-combined'], TriState.unknown);
    });
  });
}
