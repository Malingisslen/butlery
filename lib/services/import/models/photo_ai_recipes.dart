import 'package:butlery/models/recipe_unified.dart';

/// Every recipe the AI reading found on one photo, in reading order.
///
/// Carried beside the single `recipe` of the import result types the photo
/// AI route passes through; `recipes.first` is that `recipe`.
class PhotoAiRecipes {
  PhotoAiRecipes(
    List<Recipe> recipes, {
    this.firstContinuesFromPreviousPage = false,
    this.droppedRecipeCount = 0,
  }) : recipes = List.unmodifiable(recipes),
       assert(recipes.isNotEmpty, 'An AI reading that succeeded has a recipe');

  final List<Recipe> recipes;

  /// The photo starts mid-recipe: [recipes].first is the tail of the last
  /// recipe on the page before, and its title may be empty.
  final bool firstContinuesFromPreviousPage;

  /// Recipes on the photo the server read but could not use.
  final int droppedRecipeCount;
}
