import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

/// Type of change emitted from [subscribeToUserRecipes].
enum RecipeChangeType { added, modified, removed }

/// Model describing a recipe change event.
class RecipeChange {
  final Recipe recipe;
  final RecipeChangeType type;

  RecipeChange({required this.recipe, required this.type});
}

/// Repository responsible for communicating with Firestore for recipes.
class RecipeRepository {
  final FirebaseFirestore _firestore;

  RecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userRecipesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('recipes');
  }

  CollectionReference<Map<String, dynamic>> get _archiveRef =>
      _firestore.collection('butlery_archive');

  /// Listen to real-time updates for a user's recipes.
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function(dynamic)? onError,
  }) {
    return _userRecipesRef(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final changes = snapshot.docChanges.map((change) {
        final recipe = Recipe.fromFirestore(change.doc);
        final type = switch (change.type) {
          DocumentChangeType.added => RecipeChangeType.added,
          DocumentChangeType.modified => RecipeChangeType.modified,
          DocumentChangeType.removed => RecipeChangeType.removed,
        };
        return RecipeChange(recipe: recipe, type: type);
      }).toList();
      onData(changes);
    }, onError: onError);
  }

  Future<void> addRecipe(String userId, Recipe recipe) async {
    await _userRecipesRef(userId).doc(recipe.id).set(recipe.toFirestore());
  }

  Future<void> updateRecipe(String userId, Recipe recipe) async {
    await _userRecipesRef(userId).doc(recipe.id).update(recipe.toFirestore());
  }

  Future<void> deleteRecipe(String userId, String id) async {
    await _userRecipesRef(userId).doc(id).delete();
  }

  Future<List<Recipe>> fetchUserRecipes(String userId) async {
    final snapshot =
        await _userRecipesRef(userId).orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }

  Future<List<Recipe>> fetchArchiveRecipes() async {
    final snapshot = await _archiveRef.orderBy('title').get();
    return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }

  Future<Recipe> fetchArchiveRecipe(String id) async {
    final doc = await _archiveRef.doc(id).get();
    if (!doc.exists) {
      throw Exception('Recipe not found');
    }
    return Recipe.fromFirestore(doc);
  }
}
