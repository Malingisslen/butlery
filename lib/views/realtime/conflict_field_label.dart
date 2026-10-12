import 'package:butlery/l10n/app_localizations.dart';

/// The name a person reads for a compared field, never the stored key.
/// A key without a name here (menus, lists) is shown as stored.
String conflictFieldLabel(AppLocalizations l, String key) => switch (key) {
  'title' => l.recipeTitle,
  'description' => l.recipeDescription,
  'ingredients' => l.recipeIngredients,
  'instructions' => l.recipeInstructions,
  'portions' => l.recipePortions,
  'timeMinutes' => l.recipeCookingTime,
  'mealType' => l.recipeMealType,
  _ => key,
};
