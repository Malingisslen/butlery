// lib/services/shopping/menu_shopping_generation_result.dart

/// Outcome of a week→shopping-list generation, for the snackbar/UI.
///
/// A null return from `MenuShoppingListGenerator.generateForWeek` means
/// FAILURE (swallowed by the service error path) — the no-recipes case is
/// the explicit [MenuShoppingGenerationResult.nothingToGenerate], so the
/// view can show the right message for each.
class MenuShoppingGenerationResult {
  final String listId;
  final String listName;
  final int itemCount;
  final int recipeCount;

  /// Recipe ids on the plan whose Recipe could not be resolved (deleted or
  /// not yet cached). Logged; carried for observability.
  final int unresolvedRecipes;

  /// BUT-1613: how many planned meals had their quantities scaled to who's
  /// home (present count differs from the recipe's serving count). Surfaced so
  /// the UI can explain why amounts changed instead of the shrink reading as a
  /// bug. 0 = nothing was scaled (list matches authored amounts).
  final int scaledMeals;

  const MenuShoppingGenerationResult({
    required this.listId,
    required this.listName,
    required this.itemCount,
    required this.recipeCount,
    required this.unresolvedRecipes,
    this.scaledMeals = 0,
  });

  static const nothingToGenerate = MenuShoppingGenerationResult(
    listId: '',
    listName: '',
    itemCount: 0,
    recipeCount: 0,
    unresolvedRecipes: 0,
  );

  bool get isEmptyPlan => listId.isEmpty;
}
