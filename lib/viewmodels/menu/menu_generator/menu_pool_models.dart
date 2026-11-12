import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Result of a recipe swap operation, including alternatives info.
class SwapResult {
  final Recipe? recipe;
  final int alternativesRemaining;
  final String? exhaustedMessage;

  const SwapResult({
    this.recipe,
    required this.alternativesRemaining,
    this.exhaustedMessage,
  });
}

/// Whose preferences filtered the last menu pool. The UI attributes the
/// hidden-recipe hint to "hushållets allergier" only when the household or
/// present-diner union was actually in play — a solo user's own filter gets
/// neutral wording (BUT-1464 review M2, no over-attribution).
/// [householdIncomplete] is the household union built while at least one
/// member's profile could not be read (BUT-1663): the pool was filtered by a
/// widened, safety-floored set rather than the household's real preferences,
/// so telemetry must not report it as a plain [household] run.
/// [presentIncomplete] is the same situation for the who's-eating-today union
/// (BUT-2076).
enum MenuPrefSource {
  present,
  presentIncomplete,
  household,
  householdIncomplete,
  singleUser
  ;

  /// The pool was filtered by a widened safety floor because someone eating
  /// could not be read — the menu must say so rather than claim precision.
  bool get isRosterIncomplete =>
      this == presentIncomplete || this == householdIncomplete;
}

/// Pool statistics from the last [MenuGenerator.getAvailableRecipesAsync]
/// run, so the menu UI can explain a shrunken pool instead of it looking
/// like a bug (BUT-1464, PM conditions 1-3).
class MenuPoolStats {
  /// Recipes removed by the allergen/dietary filter (household union when a
  /// household exists).
  final int hiddenByAllergenFilter;

  /// Recipes that stayed in the pool despite an UNKNOWN effective status for
  /// a tracked allergen — the `includeUnknownInMenu` soft path. The UI marks
  /// these with an "allergener okända" chip.
  final Set<String> unknownSoftRecipeIds;

  /// How many allergens were tracked by the preferences used for filtering
  /// (analytics context for the hidden count).
  final int trackedAllergenCount;

  /// Which preference set did the filtering — drives the hint wording.
  final MenuPrefSource prefSource;

  const MenuPoolStats({
    required this.hiddenByAllergenFilter,
    required this.unknownSoftRecipeIds,
    required this.trackedAllergenCount,
    required this.prefSource,
  });

  static const empty = MenuPoolStats(
    hiddenByAllergenFilter: 0,
    unknownSoftRecipeIds: {},
    trackedAllergenCount: 0,
    prefSource: MenuPrefSource.singleUser,
  );
}

/// P6-U01: the library has no recipe the generation may use. Its own
/// message (errorNoRecipesAvailable), kept apart from "Inga recept matchar",
/// which is a library with recipes where none matched.
class MenuNoRecipesException implements Exception {
  const MenuNoRecipesException();

  @override
  String toString() => AppLocale.current.errorNoRecipesAvailable;
}
