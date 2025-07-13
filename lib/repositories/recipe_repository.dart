import "../models/recipe.dart";
abstract class RecipeRepository {
  Future<void> addRecipe(Recipe recipe);
  Future<void> updateRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<List<Recipe>> getAllRecipes();
}
