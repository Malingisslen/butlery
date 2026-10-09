import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

/// Builds the recipe form for `Routes.manualEntry` from its route arguments.
///
/// Kept out of `AppRouter.generateRoute` so the argument decode can be tested
/// without the router's auth check, and so the import callers write the same
/// key the decode reads.
abstract final class ManualEntryRoute {
  static const importedWithoutIngredientsKey = 'importedWithoutIngredients';

  static bool hasNoIngredients(Recipe recipe) =>
      recipe.ingredients.every((i) => i.trim().isEmpty);

  static SkrivSjalvReceptView page(Object? arguments) {
    if (arguments is! Map<String, dynamic>) {
      return const SkrivSjalvReceptView();
    }
    return SkrivSjalvReceptView(
      initialRecipe: arguments['initialRecipe'],
      isTemplate: arguments['isTemplate'] as bool? ?? false,
      importedWithoutIngredients:
          arguments[importedWithoutIngredientsKey] as bool? ?? false,
      // Onboarding opens the form mid-wizard and passes false so save pops
      // back into its flow instead of flinging the user to a recipe detail.
      navigateToDetailOnSave:
          arguments['navigateToDetailOnSave'] as bool? ?? true,
    );
  }
}
