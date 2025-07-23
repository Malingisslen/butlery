import 'dart:async';
import 'repository.dart';
import '../../models/recipe_unified.dart';
import '../../models/recipe_change.dart';

abstract class RecipeRepository extends Repository<Recipe> {
  /// Stream of all recipes belonging to a specific user
  Stream<List<Recipe>> watchRecipes(String userId);

  /// Subscribe to realtime updates for a user's recipes.
  ///
  /// [onData] will be invoked with a list of [RecipeChange] whenever one or
  /// more recipes are added, modified or removed. Returns the underlying
  /// [StreamSubscription] so the caller can cancel the subscription.
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
  });

  /// Search among a users recipes
  Future<List<Recipe>> searchRecipes(String query);

  /// Add multiple recipes at once
  Future<void> addRecipes(List<Recipe> recipes);

  /// Fetch all recipes from the public recipe archive.
  Future<List<Recipe>> fetchArchiveRecipes();

  /// Fetch a single recipe from the public archive by id.
  Future<Recipe> fetchArchiveRecipe(String id);

  /// Fetch all recipes belonging to [userId].
  Future<List<Recipe>> fetchUserRecipes(String userId);
}
