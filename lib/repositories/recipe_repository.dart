import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

abstract class RecipeRepository {
  FirebaseFirestore get firestore;

  Future<void> addRecipe(Recipe recipe);
  Future<void> updateRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<List<Recipe>> getAllRecipes();
}

class FirebaseRecipeRepository implements RecipeRepository {
  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<void> addRecipe(Recipe recipe) {
    // TODO
    throw UnimplementedError();
  }

  @override
  Future<void> updateRecipe(Recipe recipe) {
    // TODO
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecipe(String id) {
    // TODO
    throw UnimplementedError();
  }

  @override
  Future<List<Recipe>> getAllRecipes() {
    // TODO
    throw UnimplementedError();
  }
}