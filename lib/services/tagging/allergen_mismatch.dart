// lib/services/tagging/allergen_mismatch.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// BUT-1198: pure check for allergens a recipe CONTAINS that the user has not
/// configured to track. Reuses the deterministic Phase-1 allergen tags
/// `ImportManager` already attaches during import (`generatePhase1Preview`) —
/// no LLM or network call. Used by the import-flow allergen-setup banner.
///
/// `TriState.contains` is the only status that warrants the prompt:
/// `free`/`unknown` either pose no risk or carry no actionable signal.
class AllergenMismatch {
  const AllergenMismatch._();

  static Set<String> unconfiguredContainedAllergens(
    Recipe recipe,
    UserAllergenPreferences prefs,
  ) {
    final status = recipe.tagResult?.allergenStatus;
    if (status == null || status.isEmpty) return const {};
    return {
      for (final entry in status.entries)
        if (entry.value == TriState.contains &&
            !prefs.trackedAllergens.contains(entry.key))
          entry.key,
    };
  }
}
