import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';

/// Whether a recipe the user just created by hand goes on their profile
/// because of the setting "Nya recept är publika" (steg 10E).
///
/// Only the user's own writing: an import, a copy of another recipe and a
/// shared recipe start private whatever the setting says, and a minor never
/// publishes. The rules decide the rest (verified adult account) when the
/// flag is written.
bool showsNewRecipeOnProfile({
  required UserProfile? profile,
  required Recipe recipe,
  required bool fromTemplate,
}) {
  if (profile == null || !profile.newRecipesShowOnProfile) return false;
  if (profile.isMinor || fromTemplate) return false;
  if (recipe.type != RecipeType.personal) return false;
  if (recipe.core.sourceArtefact != null) return false;
  return recipe.sourceUrl.orEmpty().trim().isEmpty;
}
