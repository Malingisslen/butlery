import 'repository.dart';
import '../../models/recipe.dart';

abstract class RecipeRepository extends Repository<Recipe> {
  /// Stream of all recipes belonging to a specific user
  Stream<List<Recipe>> watchRecipes(String userId);

  /// Search among a users recipes
  Future<List<Recipe>> searchRecipes(String query);

  /// Add multiple recipes at once
  Future<void> addRecipes(List<Recipe> recipes);
}
