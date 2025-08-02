import 'dart:async';
import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Repository interface for recipe data operations.
abstract class RecipeRepository extends Repository<Recipe> with StreamManagementMixin {
  /// Stream of recipes for the specified user.
  Stream<List<Recipe>> watchRecipes(String userId);

  /// Subscribe to recipe changes for real-time collaboration.
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
  });

  /// Search recipes by query text.
  Future<List<Recipe>> searchRecipes(String query);

  /// Batch add multiple recipes.
  Future<void> addRecipes(List<Recipe> recipes);

  /// Fetch all public archive recipes.
  Future<List<Recipe>> fetchArchiveRecipes();

  /// Fetch specific archive recipe by ID.
  Future<Recipe> fetchArchiveRecipe(String id);

  /// Fetch all recipes for a specific user.
  Future<List<Recipe>> fetchUserRecipes(String userId);
}
