// The one allergen answer every screen shares. Each case differs from its
// neighbour in a single variable so a regression names the rule it broke.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/allergen_verdict.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

import '../../../infrastructure/factories/recipe_factory.dart';

TagResult _tags(
  Map<String, TriState> allergen, {
  double coverage = 1.0,
  String version = kTagGeneratorVersion,
}) => TagResult(
  tags: const {},
  allergenStatus: allergen,
  dietaryStatus: const {},
  coverage: coverage,
  generatedAt: DateTime(2026),
  generatorVersion: version,
);

Recipe _recipe({TagResult? tags, TagOverrides? overrides}) =>
    RecipeFactory.build(
      id: 'r1',
      title: 'r1',
    ).copyWith(tagResult: tags, tagOverrides: overrides);

void main() {
  group('AllergenVerdict.forAllergen', () {
    test('an untagged recipe is unsettled, not free', () {
      final verdict = AllergenVerdict.forAllergen(_recipe(), 'gluten');

      expect(verdict.effective, TriState.unknown);
      expect(verdict.overridden, isFalse);
    });

    test('a fresh FREE stays free', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(tags: _tags({'gluten': TriState.free})),
        'gluten',
      );

      expect(verdict.effective, TriState.free);
    });

    test('FREE from old tagging is not trusted', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(tags: _tags({'gluten': TriState.free}, version: '1.0.0')),
        'gluten',
      );

      expect(verdict.effective, TriState.unknown);
      expect(verdict.auto, TriState.free);
    });

    test('FREE below full coverage is not trusted', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(tags: _tags({'gluten': TriState.free}, coverage: 0.9)),
        'gluten',
      );

      expect(verdict.effective, TriState.unknown);
    });

    test('CONTAINS from old tagging stays CONTAINS', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(tags: _tags({'gluten': TriState.contains}, version: '1.0.0')),
        'gluten',
      );

      expect(verdict.effective, TriState.contains);
    });

    test('an override wins over both the tagger and the staleness rule', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(
          tags: _tags({'gluten': TriState.free}, version: '1.0.0'),
          overrides: const TagOverrides(
            allergenOverrides: {'gluten': TriState.contains},
          ),
        ),
        'gluten',
      );

      expect(verdict.effective, TriState.contains);
      expect(verdict.overridden, isTrue);
    });
  });

  group('AllergenVerdict.trusted', () {
    test('ignores an override but keeps the staleness downgrade', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(
          tags: _tags({'gluten': TriState.free}, coverage: 0.5),
          overrides: const TagOverrides(
            allergenOverrides: {'gluten': TriState.contains},
          ),
        ),
        'gluten',
      );

      expect(verdict.effective, TriState.contains);
      expect(verdict.trusted, TriState.unknown);
    });

    test('a CONTAINS is trusted as found', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(
          tags: _tags({'gluten': TriState.contains}, coverage: 0.5),
          overrides: const TagOverrides(
            allergenOverrides: {'gluten': TriState.free},
          ),
        ),
        'gluten',
      );

      expect(verdict.trusted, TriState.contains);
    });
  });

  group('AllergenVerdict.overrideHidesContains', () {
    test('true when the user marked ok what the tagger found', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(
          tags: _tags({'gluten': TriState.contains}),
          overrides: const TagOverrides(
            allergenOverrides: {'gluten': TriState.free},
          ),
        ),
        'gluten',
      );

      expect(verdict.effective, TriState.free);
      expect(verdict.overrideHidesContains, isTrue);
    });

    test('false when the override only adds a warning', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(
          tags: _tags({'gluten': TriState.free}),
          overrides: const TagOverrides(
            allergenOverrides: {'gluten': TriState.contains},
          ),
        ),
        'gluten',
      );

      expect(verdict.overrideHidesContains, isFalse);
    });

    test('false without an override', () {
      final verdict = AllergenVerdict.forAllergen(
        _recipe(tags: _tags({'gluten': TriState.contains})),
        'gluten',
      );

      expect(verdict.overrideHidesContains, isFalse);
    });
  });
}
