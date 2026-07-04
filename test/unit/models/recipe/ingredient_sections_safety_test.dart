/// Ingredient sections (PR #211) — the allergen-safety invariants.
///
/// The feature's whole safety hinge: component headings ("Deg", "Fyllning")
/// live ONLY in `RecipeIngredient.section`, never as their own entry in the
/// flat `Recipe.ingredients` list that allergen tagging reads. These pin the
/// binding acceptance criteria 1–3:
///   1. a sectioned recipe's flat list == its unsectioned twin's, so tagging
///      produces the identical result (tagging is a pure function of the flat
///      ingredient strings — identical input ⇒ identical output).
///   2. no structuredIngredients entry is ever a heading line (the alignment
///      invariant entry.raw == ingredients[i] holds with sections present).
///   3. section label text never appears in the flat list, so it can never
///      reach CONTAINS/FREE verdict logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';

Recipe kanelbullar({required bool withSections}) => Recipe(
  core: RecipeCore(
    id: 'r',
    title: 'Kanelbullar',
    description: '',
    ingredients: const ['5 dl vetemjöl', '75 g smör', '2 msk kanel'],
    structuredIngredients: [
      RecipeIngredient(
        amount: 5,
        unit: 'dl',
        name: 'vetemjöl',
        raw: '5 dl vetemjöl',
        section: withSections ? 'Deg' : null,
      ),
      RecipeIngredient(
        amount: 75,
        unit: 'g',
        name: 'smör',
        raw: '75 g smör',
        section: withSections ? 'Fyllning' : null,
      ),
      RecipeIngredient(
        amount: 2,
        unit: 'msk',
        name: 'kanel',
        raw: '2 msk kanel',
        section: withSections ? 'Fyllning' : null,
      ),
    ],
    instructions: const ['Baka'],
    mealType: 'Fika',
  ),
  type: RecipeType.personal,
);

void main() {
  group('allergen-safety invariants (criteria 1–3)', () {
    test('criterion 1: the flat ingredient list is byte-identical with and '
        'without sections — so tagging input, hence output, is unchanged', () {
      final sectioned = kanelbullar(withSections: true);
      final flatTwin = kanelbullar(withSections: false);

      expect(sectioned.ingredients, flatTwin.ingredients);
      expect(sectioned.ingredients, [
        '5 dl vetemjöl',
        '75 g smör',
        '2 msk kanel',
      ]);
    });

    test('criterion 3: no section label text leaks into the flat list', () {
      final r = kanelbullar(withSections: true);
      for (final label in ['Deg', 'Fyllning', 'deg', 'fyllning']) {
        expect(
          r.ingredients,
          isNot(contains(label)),
          reason: 'heading "$label" must never be an ingredient line',
        );
        expect(
          r.ingredients.any((i) => i.trim() == label),
          isFalse,
        );
      }
    });

    test('criterion 2: every structured entry aligns with a flat line '
        '(entry.raw == ingredients[i]); none is a heading', () {
      final r = kanelbullar(withSections: true);
      final structured = r.structuredIngredients;
      expect(structured.length, r.ingredients.length);
      for (var i = 0; i < structured.length; i++) {
        expect(structured[i].raw, r.ingredients[i]);
      }
    });

    test('sections survive Firestore + JSON round-trips but never migrate '
        'into the flat list', () {
      final r = kanelbullar(withSections: true);

      final viaJson = RecipeCore.fromJson(r.core.toJson());
      expect(viaJson.ingredients, r.ingredients);
      expect(
        viaJson.structuredIngredients?.map((e) => e.section),
        ['Deg', 'Fyllning', 'Fyllning'],
      );

      final map = r.core.toJson()
        ..remove('createdAt')
        ..remove('updatedAt');
      final viaMap = RecipeCore.fromMap('r', map);
      expect(viaMap.ingredients, r.ingredients);
      expect(
        viaMap.structuredIngredients?.map((e) => e.section),
        ['Deg', 'Fyllning', 'Fyllning'],
      );
    });
  });
}
