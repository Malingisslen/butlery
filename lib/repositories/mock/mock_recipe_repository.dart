import 'dart:async';
import '../interfaces/recipe_repository.dart';
import '../../models/recipe.dart';
import '../../models/recipe_change.dart';
import 'in_memory_repository.dart';

/// In-memory implementation of [RecipeRepository] for tests.
class MockRecipeRepository extends InMemoryRepository<Recipe>
    implements RecipeRepository {
  MockRecipeRepository() : super((r) => r.id);

  final Map<String, StreamController<List<Recipe>>> _controllers = {};

  void _emit() {
    final recipes = items.values.toList();
    for (final controller in _controllers.values) {
      controller.add(recipes);
    }
  }

  @override
  Future<Recipe> create(Recipe entity) async {
    final result = await super.create(entity);
    _emit();
    return result;
  }

  @override
  Future<void> update(Recipe entity) async {
    await super.update(entity);
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    await super.delete(id);
    _emit();
  }

  @override
  Stream<List<Recipe>> watchRecipes(String userId) {
    return _controllers
        .putIfAbsent(userId, () => StreamController<List<Recipe>>.broadcast())
        .stream;
  }

  @override
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
  }) {
    return watchRecipes(userId).listen(
      (recipes) => onData(
        recipes
            .map((r) => RecipeChange(type: RecipeChangeType.added, recipe: r))
            .toList(),
      ),
      onError: onError,
    );
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    final lower = query.toLowerCase();
    return items.values
        .where((r) => r.title.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<void> addRecipes(List<Recipe> recipes) async {
    for (final recipe in recipes) {
      items[recipe.id] = recipe;
    }
    _emit();
  }

  @override
  Future<List<Recipe>> fetchArchiveRecipes() async => items.values.toList();

  @override
  Future<Recipe> fetchArchiveRecipe(String id) async {
    final recipe = items[id];
    if (recipe == null) {
      throw Exception('Recipe not found');
    }
    return recipe;
  }

  @override
  Future<List<Recipe>> fetchUserRecipes(String userId) async => items.values.toList();
}
