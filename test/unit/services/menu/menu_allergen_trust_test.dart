// test/unit/services/menu/menu_allergen_trust_test.dart
//
// BUT-1464: the asymmetric trust matrix for menu allergen/dietary filtering.
// Pure-compute helper, so these are direct unit tests (the wiring into the
// generation entry points is pinned in menu_household_allergen_test.dart).

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu/menu_allergen_trust.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TagResult tag({
    Map<String, TriState> allergen = const {},
    Map<String, TriState> dietary = const {},
    String version = kTagGeneratorVersion,
    double coverage = 1.0,
  }) => TagResult(
    tags: const {},
    allergenStatus: allergen,
    dietaryStatus: dietary,
    coverage: coverage,
    generatedAt: DateTime(2026),
    generatorVersion: version,
  );

  Recipe recipeWith({TagResult? t, TagOverrides? overrides}) {
    final base = RecipeFactory.build(id: 'r1', title: 'r1');
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    ).copyWith(tagOverrides: overrides);
  }

  group('allergen asymmetric matrix', () {
    test('fresh FREE stays FREE', () {
      final r = recipeWith(t: tag(allergen: {'gluten': TriState.free}));
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.free,
      );
    });

    test('stale FREE (needsRetagging) is downgraded to UNKNOWN', () {
      final r = recipeWith(
        t: tag(allergen: {'gluten': TriState.free}, version: '1.0.0'),
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.unknown,
      );
    });

    test('stale CONTAINS is NEVER downgraded', () {
      final r = recipeWith(
        t: tag(allergen: {'gluten': TriState.contains}, version: '1.0.0'),
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.contains,
      );
    });

    test('missing key and null tagResult are UNKNOWN', () {
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(recipeWith(t: tag()), 'soja'),
        TriState.unknown,
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(recipeWith(), 'soja'),
        TriState.unknown,
      );
    });

    test('manual CONTAINS override beats a fresh auto FREE', () {
      final r = recipeWith(
        t: tag(allergen: {'gluten': TriState.free}),
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.contains},
        ),
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.contains,
      );
    });

    test('manual FREE override beats the stale-FREE downgrade (human wins '
        'over staleness)', () {
      final r = recipeWith(
        t: tag(allergen: {'gluten': TriState.free}, version: '1.0.0'),
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.free},
        ),
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.free,
      );
    });

    test('manual override applies even with NO tagResult', () {
      final r = recipeWith(
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.contains},
        ),
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
        TriState.contains,
      );
    });

    test(
      'FREE at partial coverage is downgraded to UNKNOWN, CONTAINS is not '
      '(defense-in-depth, review L1)',
      () {
        final partial = recipeWith(
          t: tag(
            allergen: {
              'gluten': TriState.free,
              'mjölk': TriState.contains,
            },
            coverage: 0.8,
          ),
        );
        expect(
          MenuAllergenTrust.effectiveAllergenStatus(partial, 'gluten'),
          TriState.unknown,
          reason: 'unmatched ingredients cannot prove absence',
        );
        expect(
          MenuAllergenTrust.effectiveAllergenStatus(partial, 'mjölk'),
          TriState.contains,
          reason: 'a positive match stays trustworthy at any coverage',
        );
        expect(
          MenuAllergenTrust.effectiveDietaryStatus(
            recipeWith(
              t: tag(dietary: {'vegetarisk': TriState.free}, coverage: 0.8),
            ),
            'vegetarisk',
          ),
          TriState.unknown,
        );
      },
    );
  });

  group('dietary mirrors the allergen semantics', () {
    test('stale FREE downgraded, stale CONTAINS kept', () {
      final stale = recipeWith(
        t: tag(
          dietary: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.contains,
          },
          version: '1.0.0',
        ),
      );
      expect(
        MenuAllergenTrust.effectiveDietaryStatus(stale, 'vegetarisk'),
        TriState.unknown,
      );
      expect(
        MenuAllergenTrust.effectiveDietaryStatus(stale, 'vegansk'),
        TriState.contains,
      );
    });

    test('dietary override wins over the auto verdict', () {
      final r = recipeWith(
        t: tag(dietary: {'vegetarisk': TriState.contains}),
        overrides: const TagOverrides(
          dietaryOverrides: {'vegetarisk': TriState.free},
        ),
      );
      expect(
        MenuAllergenTrust.effectiveDietaryStatus(r, 'vegetarisk'),
        TriState.free,
      );
    });
  });
}
