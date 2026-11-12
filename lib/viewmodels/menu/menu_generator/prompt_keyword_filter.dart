import 'package:clock/clock.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';

abstract final class PromptKeywordFilter {
  static const _minFilteredPoolSize = 3;

  /// Filters or boosts recipes based on prompt keywords.
  ///
  /// Returns filtered pool if large enough (>= 3), otherwise returns
  /// full pool so generation can still proceed.
  static List<Recipe> apply(String prompt, List<Recipe> recipes) {
    final lower = prompt.toLowerCase();

    final wantsFavorites =
        lower.contains('favoriter') || lower.contains('favourites');
    final wantsRecent = lower.contains('senaste') || lower.contains('recent');

    if (!wantsFavorites && !wantsRecent) return recipes;

    final now = clock.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    List<Recipe> filtered;
    if (wantsFavorites) {
      filtered = recipes.where((r) => r.isFavorite).toList();
    } else {
      filtered = recipes
          .where(
            (r) =>
                r.lastCookedAt != null &&
                r.lastCookedAt!.isAfter(thirtyDaysAgo),
          )
          .toList();
    }

    if (filtered.length >= _minFilteredPoolSize) return filtered;

    // Pool too small — fall back to full pool
    AppLogger.info(
      'Filtered pool too small (${filtered.length}), using full pool',
    );
    return recipes;
  }
}
