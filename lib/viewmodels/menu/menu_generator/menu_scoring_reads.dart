import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';
import 'package:butlery/services/user_service.dart';

/// The optional personalisation reads that feed a generation's scoring
/// context. Both fail open.
abstract final class MenuScoringReads {
  /// Reads pantry ingredient overlap for the candidate [pool] (BUT-1321), keyed
  /// by recipeId. Fail-open: an unregistered [PantryService] or a read failure
  /// yields an empty map and generation proceeds without the pantry boost.
  static Future<Map<String, double>> buildPantryMatch(
    UserService userService,
    List<Recipe> pool,
  ) async {
    final pantryMatch = <String, double>{};
    final pantryService = ServiceLocator.tryGet<PantryService>();
    final userId = userService.currentUserId;
    if (pantryService != null && userId != null && pool.isNotEmpty) {
      try {
        final matches = await pantryService.getMatchingRecipes(userId, pool);
        for (final match in matches) {
          pantryMatch[match.recipe.id] = match.matchPercent;
        }
      } catch (e) {
        // Never let a pantry read block menu generation — fall through with
        // no pantry boost.
        AppLogger.warning('Pantry-aware menu scoring skipped: $e');
      }
    }
    return pantryMatch;
  }

  /// Reads pooled "Butlery-betyget" community stats for the candidate [pool]
  /// (BUT-1516), keyed by recipeId, so the scorer can apply the shrinkage boost.
  /// Gated on the `enable_pooled_ratings` flag, so it issues ZERO Firestore
  /// reads while the feature is dark. Fail-open: any error (or an unregistered
  /// repository) yields an empty map and generation proceeds unweighted, exactly
  /// like the pantry read.
  static Future<Map<String, PooledStats>> buildPooledStats(
    List<Recipe> pool,
  ) async {
    final pooledOn =
        ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enablePooledRatings,
        ) ??
        false;
    if (!pooledOn || pool.isEmpty) return const {};

    final ratingsRepo = ServiceLocator.tryGet<RatingsRepository>();
    if (ratingsRepo == null) return const {};

    try {
      // Derive each candidate's poolKey — a current-version hint, else compute it
      // (older recipes saved before the flag went live carry no hint). Both may
      // be null for a generic/no-anchor dish; those simply get no pooled signal.
      final poolKeyByRecipeId = <String, String>{};
      for (final recipe in pool) {
        final hint = recipe.core.ratingPoolKey;
        final key = CanonicalPoolKey.isCurrent(hint)
            ? hint
            : CanonicalPoolKey.compute(
                title: recipe.core.title,
                ingredients: recipe.core.ingredients,
              );
        if (key != null && key.isNotEmpty) {
          poolKeyByRecipeId[recipe.id] = key;
        }
      }
      if (poolKeyByRecipeId.isEmpty) return const {};

      // getBulkPooledStats de-dupes + drops empties internally, so pass the
      // per-recipe keys directly (duplicate dishes collapse to one query).
      final statsByKey = await ratingsRepo.getBulkPooledStats(
        poolKeyByRecipeId.values.toList(),
      );
      final byRecipeId = <String, PooledStats>{};
      poolKeyByRecipeId.forEach((recipeId, key) {
        final stats = statsByKey[key];
        if (stats != null) byRecipeId[recipeId] = stats;
      });
      return byRecipeId;
    } catch (e) {
      // Never let a pooled-ratings read block menu generation.
      AppLogger.warning('Pooled-rating menu scoring skipped: $e');
      return const {};
    }
  }
}
