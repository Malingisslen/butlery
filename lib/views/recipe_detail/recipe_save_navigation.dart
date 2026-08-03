import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Where the user lands after a NEW recipe is saved from the create/import form.
///
/// BUT-900 follow-on: every recipe-creation path (manual "skriv själv", URL /
/// photo / social import, duplicate) funnels through the same form, which used to
/// just `pop` on save — dropping the user back on the add-recipe picker, never
/// seeing the recipe they made. Centralising the post-save navigation here means
/// one place decides it for all those paths.
class RecipeSaveNavigation {
  RecipeSaveNavigation._();

  /// Call on a successful save of a NEW recipe.
  ///
  /// [navigateToDetail] true (default for the form): replace the form with the
  /// new recipe's detail page so the user immediately sees what they created;
  /// "back" then returns to wherever they started, not into the used-up form.
  ///
  /// [navigateToDetail] false: pop the form, handing the saved recipe back to
  /// its opener. Used by onboarding, which must keep driving its own wizard flow
  /// rather than fling the user out to a recipe detail mid-onboarding.
  static void afterSuccessfulSave(
    BuildContext context,
    Recipe savedRecipe, {
    required bool navigateToDetail,
  }) {
    if (navigateToDetail) {
      // BUT-1779: the detail route decodes its argument as a Recipe (or a Map
      // carrying one) and falls through to the generic error screen otherwise —
      // a bare id landed every "skriv själv" save on "Sidan kunde inte hittas".
      Navigator.of(context).pushReplacementNamed(
        Routes.recipeDetail,
        arguments: savedRecipe,
      );
    } else {
      Navigator.of(context).pop(savedRecipe);
    }
  }
}
