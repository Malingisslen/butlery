import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/menu_scoring.dart';

/// Why a dish was among the week's suggestions, as far as the picker's own
/// signals can prove it (BUT-2523). A reason is only listed when the signal
/// that tilted the draw is present for that dish, so absence means "chance".
enum MenuPickReason { notRecent, seasonal, familyFavourite, pantry }

/// What the last generation knew, kept so the screen can explain a dish
/// without reading anything again.
class MenuPickSignals {
  const MenuPickSignals({
    required this.recentIds,
    required this.recentKnown,
    required this.context,
    required this.seasonTag,
  });

  final Set<String> recentIds;

  /// False when the earlier weeks could not be read: then "not on the menu
  /// lately" is unknown and must not be claimed.
  final bool recentKnown;
  final MenuScoringContext context;
  final String seasonTag;

  static MenuPickSignals now({
    required Set<String> recentIds,
    required bool recentKnown,
    required MenuScoringContext context,
  }) => MenuPickSignals(
    recentIds: recentIds,
    recentKnown: recentKnown,
    context: context,
    seasonTag: SeasonUtils.currentSeasonTag(),
  );
}

abstract final class MenuPickReasons {
  /// Pantry overlap at or above this share of the recipe counts as "you have
  /// it at home".
  static const double pantryThreshold = 0.5;

  /// Family average at or above this counts as a household favourite.
  static const double favouriteThreshold = 4.0;

  static List<MenuPickReason> forRecipe(
    Recipe recipe,
    MenuPickSignals signals,
  ) {
    final reasons = <MenuPickReason>[];
    if (signals.recentKnown && !signals.recentIds.contains(recipe.id)) {
      reasons.add(MenuPickReason.notRecent);
    }
    final tags = recipe.tagResult?.tags;
    if (tags != null && tags.contains(signals.seasonTag)) {
      reasons.add(MenuPickReason.seasonal);
    }
    final familyAvg = recipe.core.familyAverage;
    if (familyAvg != null &&
        (recipe.core.familyRatingCount ?? 0) > 0 &&
        familyAvg >= favouriteThreshold) {
      reasons.add(MenuPickReason.familyFavourite);
    }
    final overlap = signals.context.pantryMatchByRecipeId[recipe.id] ?? 0.0;
    if (overlap >= pantryThreshold) reasons.add(MenuPickReason.pantry);
    return reasons;
  }
}
