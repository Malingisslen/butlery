import 'package:butlery/core/router/manual_entry_route.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:flutter_test/flutter_test.dart';

/// BUT-2285: the flag an import hands the recipe form when it found no
/// ingredient lines, and the route decode that carries it to the form.
void main() {
  Recipe recipe(List<String> ingredients) => Recipe(
    core: RecipeCore(
      id: '',
      title: 'Pannkakor',
      description: '',
      ingredients: ingredients,
      instructions: const [],
      mealType: 'Middag',
    ),
    type: RecipeType.personal,
  );

  group('hasNoIngredients', () {
    test('an empty list has no ingredients', () {
      expect(ManualEntryRoute.hasNoIngredients(recipe(const [])), isTrue);
    });

    test('blank lines count as no ingredients', () {
      expect(
        ManualEntryRoute.hasNoIngredients(recipe(const ['  ', ''])),
        isTrue,
      );
    });

    test('one real line among blanks is an ingredient', () {
      expect(
        ManualEntryRoute.hasNoIngredients(
          recipe(const ['', '6 dl mjölk']),
        ),
        isFalse,
      );
    });
  });

  group('page', () {
    test('passes the import flag the callers write to the form', () {
      final page = ManualEntryRoute.page(<String, dynamic>{
        'initialRecipe': recipe(const []),
        'isTemplate': true,
        ManualEntryRoute.importedWithoutIngredientsKey: true,
      });

      expect(page.importedWithoutIngredients, isTrue);
      expect(page.isTemplate, isTrue);
      expect(page.initialRecipe?.title, 'Pannkakor');
      expect(page.navigateToDetailOnSave, isTrue);
    });

    test('a caller that leaves the flag out gets no notice', () {
      final page = ManualEntryRoute.page(<String, dynamic>{
        'initialRecipe': recipe(const ['ägg']),
        'navigateToDetailOnSave': false,
      });

      expect(page.importedWithoutIngredients, isFalse);
      expect(page.isTemplate, isFalse);
      expect(page.navigateToDetailOnSave, isFalse);
    });

    test('no arguments open an empty form', () {
      final page = ManualEntryRoute.page(null);

      expect(page.initialRecipe, isNull);
      expect(page.importedWithoutIngredients, isFalse);
    });
  });
}
