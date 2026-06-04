/// BUT-1198: unit tests for [AllergenMismatch] — the pure check behind the
/// import-flow allergen-setup banner. The contract that matters for safety: a
/// recipe only prompts for an allergen it *CONTAINS* and the user does *not*
/// already track; FREE and UNKNOWN never prompt (UNKNOWN carries no actionable
/// signal, FREE poses no risk).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

TagResult _tags(Map<String, TriState> allergens) => TagResult(
      tags: const {},
      allergenStatus: allergens,
      dietaryStatus: const {},
      coverage: 1.0,
      generatedAt: DateTime(2026, 6, 4),
    );

Recipe _recipe(Map<String, TriState>? allergens) {
  final base = RecipeFactory.build();
  if (allergens == null) return base.copyWith(tagResult: null);
  return base.copyWith(tagResult: _tags(allergens));
}

UserAllergenPreferences _prefs(Set<String> tracked) =>
    UserAllergenPreferences.defaults.copyWith(trackedAllergens: tracked);

void main() {
  group('AllergenMismatch.unconfiguredContainedAllergens', () {
    test('flags a CONTAINS allergen the user does not track', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe({'gluten': TriState.contains}),
        _prefs(const {}),
      );

      expect(result, {'gluten'});
    });

    test('does not flag an allergen the user already tracks', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe({'gluten': TriState.contains}),
        _prefs(const {'gluten'}),
      );

      expect(result, isEmpty);
    });

    test('ignores FREE status, flags only the untracked CONTAINS', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe({'gluten': TriState.free, 'mjolk': TriState.contains}),
        _prefs(const {}),
      );

      expect(result, {'mjolk'});
    });

    test('ignores UNKNOWN status (no actionable signal)', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe({'gluten': TriState.unknown}),
        _prefs(const {}),
      );

      expect(result, isEmpty);
    });

    test('returns empty when the recipe carries no tag result', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe(null),
        _prefs(const {}),
      );

      expect(result, isEmpty);
    });

    test('returns every untracked CONTAINS allergen', () {
      final result = AllergenMismatch.unconfiguredContainedAllergens(
        _recipe({
          'gluten': TriState.contains,
          'mjolk': TriState.contains,
          'agg': TriState.contains,
        }),
        _prefs(const {'mjolk'}),
      );

      expect(result, {'gluten', 'agg'});
    });
  });

  // BUT-1200: the batch trigger for the photo-import multi-recipe save path —
  // one banner covers the whole saved selection rather than firing per recipe.
  group('AllergenMismatch.anyUnconfigured', () {
    test('true when at least one recipe in the batch has an untracked CONTAINS',
        () {
      final batch = [
        _recipe({'gluten': TriState.free}),
        _recipe({'mjolk': TriState.contains}),
      ];

      expect(AllergenMismatch.anyUnconfigured(batch, _prefs(const {})), isTrue);
    });

    test('false when every contained allergen in the batch is already tracked',
        () {
      final batch = [
        _recipe({'gluten': TriState.contains}),
        _recipe({'mjolk': TriState.contains}),
      ];

      expect(
        AllergenMismatch.anyUnconfigured(
            batch, _prefs(const {'gluten', 'mjolk'})),
        isFalse,
      );
    });

    test('false for an empty batch', () {
      expect(
        AllergenMismatch.anyUnconfigured(const <Recipe>[], _prefs(const {})),
        isFalse,
      );
    });

    test('false when no recipe in the batch carries a tag result', () {
      expect(
        AllergenMismatch.anyUnconfigured(
          [_recipe(null), _recipe(null)],
          _prefs(const {}),
        ),
        isFalse,
      );
    });
  });
}
