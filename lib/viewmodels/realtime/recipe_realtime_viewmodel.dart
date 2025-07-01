import 'package:flutter/foundation.dart';

import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../core/injection.dart';

import 'realtime_base_viewmodel.dart';

/// View model that exposes real time recipe updates.
class RecipeRealtimeViewModel extends RealtimeBaseViewModel<RecipeService> {
  RecipeRealtimeViewModel({RecipeService? recipeService})
      : super(recipeService ?? sl<RecipeService>());

  List<Recipe> get recipes => service.recipes;
  bool get isLoading => service.isLoading;
  bool get hasError => service.hasError;
  String? get error => service.lastError;

  Future<void> refresh() async => service.refresh();

  Future<RecipeOperationResult> addRecipe(Recipe recipe) =>
      service.addRecipe(recipe);

  Future<RecipeOperationResult> updateRecipe(Recipe recipe) =>
      service.updateRecipe(recipe);

  Future<RecipeOperationResult> deleteRecipe(String id) =>
      service.deleteRecipe(id);
}
