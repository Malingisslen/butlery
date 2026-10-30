import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/router/manual_entry_route.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';

/// Opens the recipe form holding [recipe].
///
/// [replace] drops the import screen from the back stack; the photo screen
/// keeps it, so going back from the form returns to the reading.
///
/// Shared by every import screen that ends in a single parsed recipe, so the
/// allergen prompt and the form arguments cannot drift apart between them.
void handOffRecipeToForm(
  BuildContext context,
  Recipe? recipe, {
  bool replace = true,
}) {
  // Non-blocking: the app-level ScaffoldMessenger survives the push, and the
  // tags come from the parse, so no extra LLM or network call is made.
  if (recipe != null) {
    final prefs = ServiceLocator.get<UserService>().allergenPreferences;
    if (AllergenMismatch.unconfiguredContainedAllergens(
      recipe,
      prefs,
    ).isNotEmpty) {
      AllergenSetupBanner.show(context);
    }
  }
  final arguments = {
    'initialRecipe': recipe,
    'isTemplate': true,
    ManualEntryRoute.importedWithoutIngredientsKey:
        recipe != null && ManualEntryRoute.hasNoIngredients(recipe),
  };
  // Replacing rather than pushing leaves no used-up import screen behind, so
  // saving lands on the new recipe with a clean back stack.
  if (replace) {
    Navigator.pushReplacementNamed(
      context,
      Routes.manualEntry,
      arguments: arguments,
    );
  } else {
    Navigator.pushNamed(context, Routes.manualEntry, arguments: arguments);
  }
}
