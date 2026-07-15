/// Register-audit fix (2026-07-02): generic 'seafood' ingredient property
/// must never prove a marine-related FREE verdict.
///
/// Before this fix, an ingredient carrying only 'seafood' (no fish/
/// crustacean/mollusc detail — e.g. the validated skaldjursfond row) fired
/// NO allergen rule, so a shellfish-stock recipe was marked skaldjursfri
/// and vegetarisk. Direction of error is deliberate: false CONTAINS is
/// acceptable, false FREE is not.
///
/// Both config branches are pinned (Data/ML panel condition): the static
/// fallback (firebaseConfig = null) AND the Firebase branch, constructed
/// from the exact JSON artifacts seeded to production tag_configs
/// (scripts/output/tagConfigs/*.json — regenerate via
/// `dart scripts/migrate_tag_configs.dart`, upload via seed-tag-configs).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_allergen.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_dietary.dart';

import '../../../../infrastructure/helpers/tagging_test_helper.dart';

/// A full-coverage lookup with one generic-marine ingredient — the exact
/// shape of the audit's dangerous rows (skaldjursfond pre-fix, jellyfish).
IngredientLookupResult _seafoodOnlyLookup() {
  return IngredientLookupResult(
    matched: [
      TaggingTestHelper.ingredient('skaldjursfond', 'protein/seafood', {
        'animal-product',
        'seafood',
      }),
    ],
    unmatched: const [],
    coverage: 1.0,
  );
}

IngredientLookupResult _dairyLookup() {
  return IngredientLookupResult(
    matched: [
      TaggingTestHelper.ingredient('grädde', 'dairy', {
        'animal-product',
        'dairy',
      }),
    ],
    unmatched: const [],
    coverage: 1.0,
  );
}

/// Builds the Firebase config from the seeded production artifacts, so the
/// test fails if the generated JSON ever loses the fix.
FirebaseTagConfig _seededConfig() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(
            File('scripts/output/tagConfigs/$name.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return FirebaseTagConfig.fromDocuments(
    allergensData: load('allergens'),
    dietaryData: load('dietary'),
    cuisinesData: load('cuisines'),
    propertiesData: load('properties'),
    displayData: load('display'),
  );
}

void main() {
  group('seafood-only ingredient — allergen verdicts', () {
    for (final (branch, config) in [
      ('static fallback', null),
      ('firebase config (seeded artifact)', _seededConfig()),
    ]) {
      test('[$branch] skaldjur = CONTAINS, never FREE', () {
        final result = Phase1AllergenCalculator.calculate(
          _seafoodOnlyLookup(),
          config,
        );
        expect(result.status['skaldjur'], TriState.contains);
      });

      test(
        '[$branch] fisk stays FREE — generic marker must not override the '
        'specific-property win (PM panel condition)',
        () {
          final result = Phase1AllergenCalculator.calculate(
            _seafoodOnlyLookup(),
            config,
          );
          expect(result.status['fisk'], TriState.free);
        },
      );

      test('[$branch] non-marine recipe still proves skaldjursfri', () {
        final result = Phase1AllergenCalculator.calculate(
          _dairyLookup(),
          config,
        );
        expect(result.status['skaldjur'], TriState.free);
      });
    }
  });

  group('seafood-only ingredient — dietary verdicts', () {
    for (final (branch, config) in [
      ('static fallback', null),
      ('firebase config (seeded artifact)', _seededConfig()),
    ]) {
      test('[$branch] vegetarisk = CONTAINS (was the gelatin-class hole)', () {
        final result = Phase1DietaryCalculator.calculate(
          _seafoodOnlyLookup(),
          config,
        );
        expect(result.status['vegetarisk'], TriState.contains);
      });

      test('[$branch] vegansk = CONTAINS', () {
        final result = Phase1DietaryCalculator.calculate(
          _seafoodOnlyLookup(),
          config,
        );
        expect(result.status['vegansk'], TriState.contains);
      });

      test(
        '[$branch] kosheranpassad = CONTAINS (cannot prove non-shellfish)',
        () {
          final result = Phase1DietaryCalculator.calculate(
            _seafoodOnlyLookup(),
            config,
          );
          expect(result.status['kosheranpassad'], TriState.contains);
        },
      );

      test('[$branch] pescetarian unaffected — seafood is pescetarian-ok', () {
        final result = Phase1DietaryCalculator.calculate(
          _seafoodOnlyLookup(),
          config,
        );
        expect(result.status['pescetarian'], TriState.free);
      });

      test(
        '[$branch] dairy recipe stays vegetarisk FREE — the fix must not '
        'exclude animal-product wholesale (milk/egg are vegetarian)',
        () {
          final result = Phase1DietaryCalculator.calculate(
            _dairyLookup(),
            config,
          );
          expect(result.status['vegetarisk'], TriState.free);
          expect(result.status['vegansk'], TriState.contains);
        },
      );
    }
  });

  group('property-vocabulary lockstep (Security panel condition)', () {
    // Three hand-maintained copies exist, all pinned here: PROPERTIES.csv
    // (Sheet vocabulary), sync-ingredients.ts VALID_PROPERTIES (data gate),
    // and Dart PropertyRegistry.validProperties (config gate). Historical
    // drift is pinned exactly; ANY new divergence in any pair fails here. Reconciliation of the
    // historical set is a roadmap cleanup item — don't grow it.
    // BUT-1498 (2026-07-14) reconciled the shellfish/wheat pair: 'wheat' was a
    // phantom (removed from the registry) and 'shellfish' was added to the
    // registry to match the data gate. Only 'raw-safe' / 'processed' remain.
    const knownDartOnly = {'raw-safe'};
    const knownTsOnly = {'processed'};
    // The Sheet vocabulary (PROPERTIES.csv) tracks the TS data gate exactly:
    // it carries 'processed' and omits 'raw-safe', same split as TS-vs-Dart.
    const knownCsvOnly = {'processed'};

    Set<String> csvProperties() {
      // PROPERTIES.csv is the Sheet vocabulary export: column 0 is the
      // property id, row 0 is the `id,...` header. This is the third
      // hand-maintained copy — without reading it here a Sheet-side rename
      // (e.g. reviving a bare 'wheat') would drift silently, and an
      // ingredient could then carry a property the config gate never sees.
      final lines = File(
        'docs/tagging/data/Butlery_Ingredients_PROPERTIES.csv',
      ).readAsLinesSync();
      return lines
          .map((l) => l.split(',').first.trim())
          .where((id) => id.isNotEmpty && id != 'id')
          .toSet();
    }

    Set<String> tsValidProperties() {
      // BUT-1467 moved the definition from sync-ingredients.ts into the
      // pure logic module sync-ingredients-core.ts, typed the Set, and
      // split the allergen block into ALLERGEN_BLOCK_PROPERTIES which is
      // spread into VALID_PROPERTIES — this gate must union both literals
      // at the definition site.
      final src = File(
        'functions/src/admin/sync-ingredients-core.ts',
      ).readAsStringSync();
      final setBlock = RegExp(
        r'const VALID_PROPERTIES = new Set(?:<string>)?\(\[(.*?)\]\)',
        dotAll: true,
      ).firstMatch(src)!.group(1)!;
      final allergenBlock = RegExp(
        r'const ALLERGEN_BLOCK_PROPERTIES = \[(.*?)\]',
        dotAll: true,
      ).firstMatch(src)!.group(1)!;
      return RegExp(
        r'"([^"]+)"',
      ).allMatches('$setBlock $allergenBlock').map((m) => m.group(1)!).toSet();
    }

    test('TS sync gate and Dart registry differ only by the known set', () {
      final ts = tsValidProperties();
      final dart = PropertyRegistry.validProperties;
      expect(
        dart.difference(ts),
        knownDartOnly,
        reason:
            'new Dart-only property — add it to sync-ingredients.ts '
            'VALID_PROPERTIES or it will be rejected at data sync',
      );
      expect(
        ts.difference(dart),
        knownTsOnly,
        reason:
            'new TS-only property — add it to PropertyRegistry or '
            'config validation cannot see it',
      );
    });

    test(
      'Sheet CSV vocabulary and Dart registry differ only by the known set',
      () {
        final csv = csvProperties();
        final dart = PropertyRegistry.validProperties;
        expect(
          dart.difference(csv),
          knownDartOnly,
          reason:
              'new Dart-only property — add it to PROPERTIES.csv or the Sheet '
              'can never supply an ingredient that carries it',
        );
        expect(
          csv.difference(dart),
          knownCsvOnly,
          reason:
              'new Sheet-only property (e.g. a revived bare "wheat") — add it '
              'to PropertyRegistry or config validation cannot see it',
        );
      },
    );

    test('every allergen/dietary trigger property passes both gates', () {
      final ts = tsValidProperties();
      final dart = PropertyRegistry.validProperties;
      final seeded = _seededConfig();
      final used = <String>{
        for (final a in seeded.allergens.enabledEntries) ...a.triggerProperties,
        for (final d in seeded.dietary.enabledEntries) ...d.excludedProperties,
        // requiredProperties drive verdicts too (pescetarian requires
        // fish/crustacean/mollusc); production validateAllConfigs checks them.
        for (final d in seeded.dietary.enabledEntries) ...d.requiredProperties,
      };
      for (final prop in used) {
        expect(
          dart.contains(prop),
          isTrue,
          reason:
              "verdict-driving property '$prop' missing from "
              'PropertyRegistry — config validation would not cover it',
        );
        expect(
          ts.contains(prop),
          isTrue,
          reason:
              "verdict-driving property '$prop' missing from "
              'sync-ingredients.ts — the Sheet could never supply it',
        );
      }
    });
  });
}
