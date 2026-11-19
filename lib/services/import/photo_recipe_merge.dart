import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/models/photo_ai_recipes.dart';

/// Builds the recipe list for a set of AI-read pages, in page order.
///
/// A page that opens in the middle of a recipe is joined to the last recipe
/// of the page before it, and only then: a continuation anywhere else on the
/// page, or on the first page, has nothing to join and is a recipe of its
/// own to review. [untitled] names a recipe that has no title.
///
/// The pages' own recipes are not modified; the returned list holds new
/// instances where a join or a title replacement happened.
List<Recipe> mergePhotoRecipes(
  List<PhotoAiRecipes> pages, {
  required String untitled,
}) {
  final merged = <Recipe>[];
  for (final page in pages) {
    for (var i = 0; i < page.recipes.length; i++) {
      final recipe = page.recipes[i];
      final joinsPrevious =
          i == 0 && page.firstContinuesFromPreviousPage && merged.isNotEmpty;
      if (joinsPrevious) {
        merged[merged.length - 1] = _append(merged.last, recipe);
      } else {
        merged.add(
          recipe.title.trim().isEmpty
              ? recipe.copyWith(title: untitled)
              : recipe,
        );
      }
    }
  }
  return merged;
}

Recipe _append(Recipe head, Recipe tail) {
  final ingredients = _joinAtBreak(head.ingredients, tail.ingredients);
  final structured = [
    ...head.structuredIngredients,
    ...tail.structuredIngredients.skip(
      head.ingredients.length + tail.ingredients.length - ingredients.length,
    ),
  ];
  return head.copyWith(
    ingredients: ingredients,
    structuredIngredients: structured,
    instructions: _joinAtBreak(head.instructions, tail.instructions),
  );
}

/// [tail] after [head], without a first line that repeats [head]'s last: a
/// printed page break sometimes repeats the line it cut.
List<String> _joinAtBreak(List<String> head, List<String> tail) {
  final repeated =
      head.isNotEmpty &&
      tail.isNotEmpty &&
      head.last.trim().toLowerCase() == tail.first.trim().toLowerCase();
  return [...head, ...tail.skip(repeated ? 1 : 0)];
}
