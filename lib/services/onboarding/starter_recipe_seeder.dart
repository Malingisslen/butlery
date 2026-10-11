import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';

/// Butlery's starter recipes, written into a new account so it does not open
/// on an empty library. Onboarding and the guest start both seed through
/// here.
///
/// Deliberately not a `BaseService`: it holds no state and no Firebase handle
/// of its own; the writes go through [UnifiedRecipeService].
class StarterRecipeSeeder {
  StarterRecipeSeeder({
    required UnifiedRecipeService recipeService,
    AnalyticsService? analytics,
  }) : _recipeService = recipeService,
       _analytics = analytics;

  final UnifiedRecipeService _recipeService;
  final AnalyticsService? _analytics;

  static String _seededKey(String uid) => 'starter_recipes_seeded_$uid';

  /// Seeds the starter recipes for [uid] unless this device already seeded
  /// them for it, so a retried onboarding or guest start does not add a
  /// second set.
  ///
  /// Returns the stored ids of the recipes that seeded, in seed order (the
  /// service mints a fresh id; the seed's own id is not the stored one).
  /// Per-recipe failures are tolerated and counted; nothing here throws, and
  /// an already-seeded uid returns an empty list.
  Future<List<String>> seed({required String? uid}) async {
    try {
      final prefs = uid == null
          ? null
          : await tryGetSharedPreferences(logTag: 'StarterRecipeSeeder');
      if (uid != null && prefs?.getBool(_seededKey(uid)) == true) {
        AppLogger.info('Starter recipes already seeded for this account');
        return const [];
      }

      final seeds = RecipeSeeds.allRecipes;
      final seededIds = <String>[];
      for (final seed in seeds) {
        try {
          final id = await _recipeService.createPersonalRecipe(
            title: seed.core.title,
            description: seed.core.description,
            ingredients: seed.core.ingredients,
            instructions: seed.core.instructions,
            mealType: seed.core.mealType,
            portions: seed.core.portions,
            timeMinutes: seed.core.timeMinutes,
            sourceUrl: 'Butlerys startrecept',
          );
          if (id != null) seededIds.add(id);
        } catch (e) {
          AppLogger.warning('Failed to seed recipe "${seed.core.title}": $e');
        }
      }

      if (uid != null && seededIds.isNotEmpty) {
        await prefs?.setBool(_seededKey(uid), true);
      }

      final seeded = seededIds.length;
      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingRecipesSeeded,
        parameters: {'count': seeded, 'attempted': seeds.length},
      );
      final failed = seeds.length - seeded;
      if (failed > 0) {
        _analytics?.logEvent(
          name: AnalyticsEvents.onboardingRecipesSeedFailed,
          parameters: {'failed': failed, 'attempted': seeds.length},
        );
      }
      AppLogger.info('Seeded $seeded/${seeds.length} starter recipes');

      // BUT-618: stamp `first_recipe_source = 'seed'` if this is the user's
      // first recipe surface. Dedupe is handled inside the helper.
      await FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: _analytics,
        userId: uid,
        source: 'seed',
      );
      return seededIds;
    } catch (e) {
      AppLogger.warning('Failed to seed starter recipes: $e');
      return const [];
    }
  }
}
