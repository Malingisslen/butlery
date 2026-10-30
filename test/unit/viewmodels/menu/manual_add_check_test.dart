// A recipe placed in the menu by hand is checked against the household with
// the same verdict the generator uses. An unchecked allergen informs but does
// not stop the add.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/manual_add_check.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

const _glutenPrefs = UserAllergenPreferences(
  trackedAllergens: {'gluten'},
  trackedDietary: {},
);

Recipe _recipe(
  String id, {
  TriState? gluten,
  TagOverrides? overrides,
  List<String>? ingredients,
}) {
  final base = RecipeFactory.build(
    id: id,
    title: id,
    ingredients: ingredients,
  );
  return base.copyWith(
    tagResult: gluten == null
        ? null
        : TagResult(
            tags: const {},
            allergenStatus: {'gluten': gluten},
            dietaryStatus: const {},
            coverage: 1.0,
            generatedAt: DateTime(2026),
            generatorVersion: kTagGeneratorVersion,
          ),
    tagOverrides: overrides,
  );
}

List<ManualAddFinding> _check(
  List<Recipe> recipes, {
  MealDislikes? dislikes,
}) => ManualAddCheck.findingsFor(
  recipes,
  prefs: _glutenPrefs,
  dislikes: dislikes ?? MealDislikes.none,
);

void main() {
  test('a recipe that contains a tracked allergen needs confirmation', () {
    final findings = _check([_recipe('bread', gluten: TriState.contains)]);

    expect(findings, hasLength(1));
    expect(findings.single.containsAllergens, ['gluten']);
    expect(findings.single.needsConfirmation, isTrue);
  });

  test('a recipe proven free produces no finding', () {
    expect(_check([_recipe('salad', gluten: TriState.free)]), isEmpty);
  });

  test('an unchecked recipe is reported but does not need confirmation', () {
    final findings = _check([_recipe('new')]);

    expect(findings, hasLength(1));
    expect(findings.single.uncheckedAllergens, ['gluten']);
    expect(findings.single.needsConfirmation, isFalse);
  });

  test('an override marking the allergen ok clears the finding', () {
    final findings = _check([
      _recipe(
        'bread',
        gluten: TriState.contains,
        overrides: const TagOverrides(
          allergenOverrides: {'gluten': TriState.free},
        ),
      ),
    ]);

    expect(findings, isEmpty);
  });

  test('only the conflicting recipes are returned', () {
    final findings = _check([
      _recipe('bread', gluten: TriState.contains),
      _recipe('salad', gluten: TriState.free),
    ]);

    expect(findings.map((f) => f.recipe.id), ['bread']);
  });

  test('a disliked ingredient needs confirmation', () {
    final dislikes = MealDislikes(
      dislikesByMember: {
        'kid': {'lök'},
      },
      plan: null,
    );

    final findings = _check([
      _recipe('soup', gluten: TriState.free, ingredients: ['1 lök']),
    ], dislikes: dislikes);

    expect(findings.single.disliked, isTrue);
    expect(findings.single.needsConfirmation, isTrue);
  });

  group('check', () {
    test('a failed household read still checks the safety floor', () async {
      // The user tracks nothing of their own; gluten comes only from the floor.
      final check = ManualAddCheck(
        householdPrefs: () async => throw StateError('offline'),
        ownPrefs: () => UserAllergenPreferences.none,
        readDislikes: () async => const {},
      );

      final findings = await check.check([
        _recipe('bread', gluten: TriState.contains),
      ]);

      expect(findings.single.containsAllergens, ['gluten']);
      expect(findings.single.needsConfirmation, isTrue);
    });

    test('a failed dislikes read keeps the allergen findings', () async {
      final check = ManualAddCheck(
        householdPrefs: () async => _glutenPrefs,
        readDislikes: () async => throw StateError('offline'),
      );

      final findings = await check.check([
        _recipe('bread', gluten: TriState.contains),
      ]);

      expect(findings.single.containsAllergens, ['gluten']);
      expect(findings.single.disliked, isFalse);
    });

    test('uses the household preferences when they can be read', () async {
      final check = ManualAddCheck(
        householdPrefs: () async => UserAllergenPreferences.none,
        readDislikes: () async => const {},
      );

      final findings = await check.check([
        _recipe('bread', gluten: TriState.contains),
      ]);

      expect(findings, isEmpty);
    });
  });
}
