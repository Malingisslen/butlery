// lib/viewmodels/menu/menu_generator.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/menu/menu_allergen_trust.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/menu/menu_quality_analyzer.dart';

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
/// hidden-recipe hint to "familjens allergier" only when the household or
/// present-diner union was actually in play — a solo user's own filter gets
/// neutral wording (BUT-1464 review M2, no over-attribution).
enum MenuPrefSource { present, household, singleUser }

/// Pool statistics from the last [MenuGenerator.getAvailableRecipesAsync]
/// run, so the menu UI can explain a shrunken pool instead of it looking
/// like a bug (BUT-1464, PM conditions 1-3).
class MenuPoolStats {
  /// Recipes removed by the allergen/dietary filter (household union when a
  /// household exists, otherwise the single user's own preferences).
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

/// Focused module for menu generation
/// This module handles ONLY menu generation:
/// - AI-powered menu generation from prompts
/// - Menu section regeneration
/// - Recipe availability validation
/// - Generation error handling
/// - Allergen-safe recipe filtering
/// ❌ DOES NOT CONTAIN: State management, persistence, social features
class MenuGenerator {
  final MenuService _menuService;
  final UnifiedRecipeService _recipeService;
  final UserService _userService;

  /// Whether to filter out recipes containing user's tracked allergens.
  bool filterByAllergens;

  /// Whether to filter out recipes that don't match user's dietary preferences.
  bool filterByDietary;

  /// Whether to use smart swap (cuisine/category/season scoring) vs random.
  bool useSmartSwap;

  /// Whether to use aggregated household allergens instead of single-user.
  ///
  /// Defaults to TRUE (safety-by-default, BUT-1464): once a household exists,
  /// one member's allergy keeps those recipes out of everyone's menus without
  /// any setup step. With no household this is a no-op (single-user filtering,
  /// unchanged).
  ///
  /// BUT-1465: now driven by the persisted per-user opt-out — read live from the
  /// profile (like [_userService.allergenPreferences]) so the settings toggle
  /// takes effect immediately. A missing/unreadable value reads as `true`
  /// (fail-safe: never silently stop filtering a household member's allergens).
  bool get useHouseholdAllergens =>
      _userService.currentUserProfile?.useHouseholdAllergens ?? true;

  /// Present-aware allergen filtering (family Phase 4, opt-in). When set, the
  /// async menu pool is filtered against the UNION of just these present
  /// diners' allergens (resolved from the family roster — accounts AND diner
  /// profiles, so a present child's allergens count), instead of the whole
  /// household. Null = the default whole-household union behaviour. The present
  /// set is supplied by the caller (e.g. the who's-eating pick); this is the
  /// generator-side capability the per-night UI will drive.
  List<String>? presentMemberIds;

  /// Optional source of recent weekly plans for cross-week dedup (BUT-1318).
  /// When null (e.g. group flow, tests without the service registered) the
  /// recent-use down-weighting is simply skipped — no Firestore read happens
  /// and generation behaves exactly as before.
  final WeeklyMenuPlanService? _weeklyMenuPlanService;

  MenuGenerator({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required UserService userService,
    WeeklyMenuPlanService? weeklyMenuPlanService,
    this.filterByAllergens = false,
    this.filterByDietary = false,
    this.useSmartSwap = true,
  }) : _menuService = menuService,
       _recipeService = recipeService,
       _userService = userService,
       _weeklyMenuPlanService = weeklyMenuPlanService;

  List<Recipe> get availableRecipes {
    if (!_recipeService.isInitialized) {
      return [];
    }
    var recipes = _recipeService.recipes;
    if (filterByAllergens) {
      recipes = _filterByAllergenPreferences(recipes);
    }
    if (filterByDietary) {
      recipes = _filterByDietaryPreferences(recipes);
    }
    return recipes;
  }

  /// Stats from the most recent [getAvailableRecipesAsync] run, so the UI
  /// can explain a shrunken pool (hint row) and mark UNKNOWN-soft recipes.
  MenuPoolStats? lastPoolStats;

  /// Async version of availableRecipes that supports household allergen aggregation.
  Future<List<Recipe>> getAvailableRecipesAsync() async {
    if (!_recipeService.isInitialized) return [];

    var recipes = _recipeService.recipes;

    if (!filterByAllergens && !filterByDietary) {
      lastPoolStats = MenuPoolStats.empty;
      return recipes;
    }

    final (prefs, prefSource) = await _resolveActivePrefs();
    final beforeCount = recipes.length;
    final unknownSoft = <String>{};
    if (filterByAllergens) {
      recipes = _filterByPrefs(
        recipes,
        prefs,
        allergens: true,
        unknownSoftCollector: unknownSoft,
      );
    }
    if (filterByDietary) {
      recipes = _filterByPrefs(recipes, prefs, allergens: false);
    }
    lastPoolStats = MenuPoolStats(
      hiddenByAllergenFilter: beforeCount - recipes.length,
      unknownSoftRecipeIds: unknownSoft,
      trackedAllergenCount: prefs.trackedAllergens.length,
      prefSource: prefSource,
    );
    return recipes;
  }

  /// Resolves which allergen/dietary preferences the async pool filters by.
  ///
  /// Priority: present-diner union (opt-in, NON-EMPTY set required — an empty
  /// "no one selected" list must NOT disable filtering) → whole-household
  /// union (when [useHouseholdAllergens] and a household exists) → the single
  /// user's own preferences. Every fall-through lands on a FILTERED pool,
  /// never an unfiltered one.
  Future<(UserAllergenPreferences, MenuPrefSource)>
  _resolveActivePrefs() async {
    final present = presentMemberIds;
    if (present != null && present.isNotEmpty) {
      final prefs = await _presentAllergenPrefs(present);
      if (prefs != null) return (prefs, MenuPrefSource.present);
    }
    if (useHouseholdAllergens) {
      final householdService = ServiceLocator.tryGet<HouseholdService>();
      if (householdService != null && householdService.hasHousehold) {
        return (
          await householdService.getAggregatedAllergenPreferences(),
          MenuPrefSource.household,
        );
      }
    }
    return (_userService.allergenPreferences, MenuPrefSource.singleUser);
  }

  /// Union of the present diners' allergens/dietary prefs, resolved from the
  /// family roster (accounts + diner profiles). Returns null when the roster
  /// can't be resolved (no household, services unavailable) so the caller can
  /// fall back to the existing filtering. Read-only: uses `getForUser` (never
  /// creates a household).
  Future<UserAllergenPreferences?> _presentAllergenPrefs(
    List<String> presentIds,
  ) async {
    final rosterService = ServiceLocator.tryGet<HouseholdRosterService>();
    final householdRepo = ServiceLocator.tryGet<HouseholdRepository>();
    final permission = ServiceLocator.tryGet<PermissionService>();
    if (rosterService == null || householdRepo == null || permission == null) {
      return null;
    }
    final uid = permission.currentUserId;
    if (uid == null) return null;

    final households = await householdRepo.getForUser(uid);
    if (households.isEmpty) return null;
    final roster = await rosterService.getRoster(households.first.id);

    final present = presentIds.toSet();
    final allergens = <String>{};
    final dietary = <String>{};
    // Safety-conservative: exclude untagged (UNKNOWN) recipes if ANY present
    // diner opts out of unknowns — one cautious diner makes the union cautious.
    var includeUnknown = true;
    for (final member in roster) {
      if (!present.contains(member.memberId)) continue;
      final prefs = member.allergenPreferences;
      if (prefs != null) {
        allergens.addAll(prefs.trackedAllergens);
        dietary.addAll(prefs.trackedDietary);
        if (!prefs.includeUnknownInMenu) includeUnknown = false;
      }
    }
    return UserAllergenPreferences(
      trackedAllergens: allergens,
      trackedDietary: dietary,
      includeUnknownInMenu: includeUnknown,
    );
  }

  /// Filter recipes using explicit prefs — the ONE allergen/dietary filter
  /// for menu pools (household, present-diner, and single-user paths all
  /// land here so the trust guards can't diverge between them).
  ///
  /// Statuses go through [MenuAllergenTrust] (BUT-1464): manual overrides
  /// honoured, stale FREE downgraded to UNKNOWN, stale CONTAINS kept.
  /// A recipe with NO tagResult is functionally UNKNOWN (BUT-1394) and
  /// follows the same `includeUnknownInMenu` opt-out as tagged-but-unknown.
  ///
  /// [unknownSoftCollector], when supplied on the allergen pass, receives the
  /// ids of recipes that were INCLUDED despite an UNKNOWN effective status
  /// for a tracked allergen — the UI marks these (PM condition 2).
  List<Recipe> _filterByPrefs(
    List<Recipe> recipes,
    UserAllergenPreferences prefs, {
    required bool allergens,
    Set<String>? unknownSoftCollector,
  }) {
    if (allergens) {
      if (!prefs.hasTrackedAllergens) return recipes;
      final tracked = prefs.trackedAllergens;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        var sawUnknown = false;
        for (final allergen in tracked) {
          final status = MenuAllergenTrust.effectiveAllergenStatus(
            recipe,
            allergen,
          );
          if (status == TriState.contains) return false;
          if (status == TriState.unknown) {
            if (!includeUnknown) return false;
            sawUnknown = true;
          }
        }
        if (sawUnknown) unknownSoftCollector?.add(recipe.id);
        return true;
      }).toList();
    } else {
      if (!prefs.hasTrackedDietary) return recipes;
      final tracked = prefs.trackedDietary;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        for (final dietary in tracked) {
          final status = MenuAllergenTrust.effectiveDietaryStatus(
            recipe,
            dietary,
          );
          if (status == TriState.contains) return false;
          if (!includeUnknown && status == TriState.unknown) return false;
        }
        return true;
      }).toList();
    }
  }

  /// Single-user allergen filtering (sync pool only) — same trust-guarded
  /// filter as the async paths, fed by the user's own preferences.
  List<Recipe> _filterByAllergenPreferences(List<Recipe> recipes) =>
      _filterByPrefs(
        recipes,
        _userService.allergenPreferences,
        allergens: true,
      );

  /// Single-user dietary filtering (sync pool only) — see
  /// [_filterByAllergenPreferences].
  List<Recipe> _filterByDietaryPreferences(List<Recipe> recipes) =>
      _filterByPrefs(
        recipes,
        _userService.allergenPreferences,
        allergens: false,
      );

  bool get hasAvailableRecipes => availableRecipes.isNotEmpty;

  Future<void> ensureRecipeServiceInitialized() async {
    if (!_recipeService.isInitialized) {
      AppLogger.info('🔄 Initialiserar recept-service för meny-generering...');
      await _recipeService.initialize();
    }
  }

  /// Generate complete menu from prompt.
  ///
  /// Supports keyword filtering:
  /// - "favoriter" / "favourites" -> prefer favorites
  /// - "senaste" / "recent" -> prefer recently cooked (last 30 days)
  /// Falls back to full pool with boost if filtered pool is too small.
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String prompt,
  ) async {
    await ensureRecipeServiceInitialized();

    await Future.delayed(const Duration(milliseconds: 300));

    // BUT-1464: the async pool is THE allergen-safe pool (household union +
    // trust guards). Computed once — both the emptiness check and the
    // keyword filter must see the same filtered pool, never the sync
    // single-user one.
    final available = await getAvailableRecipesAsync();
    if (available.isEmpty) {
      throw Exception(AppLocale.current.errorNoRecipesAvailable);
    }

    final pool = _applyPromptKeywordFilter(prompt, available);

    final recentIds = await _recentlyUsedRecipeIds();
    final scoringContext = await _buildScoringContext(pool);

    final generatedMenu = await _menuService.generateMenuFromPrompt(
      prompt,
      pool,
      recentlyUsedRecipeIds: recentIds,
      scoringContext: scoringContext,
    );

    if (generatedMenu.isEmpty) {
      throw Exception(
        AppLocale.current.errorGeneric,
      );
    }

    _logHiddenByHouseholdEvent();

    return generatedMenu;
  }

  /// Fire-and-forget analytics for the pool shrink caused by allergen
  /// filtering (PM condition 3). [AnalyticsService.tryLog] (BUT-766) already
  /// guarantees this can never throw or delay generation.
  void _logHiddenByHouseholdEvent() {
    final stats = lastPoolStats;
    if (stats == null) return;
    AnalyticsService.tryLog(
      AnalyticsEvents.menuRecipesHiddenByHousehold,
      parameters: {
        'hidden_count': stats.hiddenByAllergenFilter,
        'tracked_allergen_count': stats.trackedAllergenCount,
        'pref_source': stats.prefSource.name,
      },
    );
  }

  /// Collects recipe IDs used in the last 1-2 weekly plans so generation can
  /// down-weight them (BUT-1318). Returns an empty set with no history (first
  /// menu ever) or when no plan service is wired — generation then uses the
  /// full pool unchanged. Errors are swallowed: a recent-plan read failure
  /// must never block menu generation.
  Future<Set<String>> _recentlyUsedRecipeIds() async {
    final service = _weeklyMenuPlanService;
    if (service == null) return const {};
    try {
      final now = clock.now();
      final thisWeek = IsoWeekUtils.weekStartOf(now);
      final lastWeek = thisWeek.subtract(const Duration(days: 7));
      // Read this week + last week only (1-2 plans) — bounded, cheap, and the
      // weeks the user is most likely repeating from.
      final plans = await Future.wait([
        service.getWeek(thisWeek),
        service.getWeek(lastWeek),
      ]);
      final ids = <String>{};
      for (final plan in plans) {
        for (final entry in plan.entries) {
          ids.add(entry.recipeId);
        }
      }
      return ids;
    } catch (e) {
      AppLogger.warning('Recent-plan dedup skipped: $e');
      return const {};
    }
  }

  /// Builds the per-generation personalisation context (BUT-1321): pantry
  /// overlap. The signal is optional — an unregistered [PantryService] or a
  /// pantry read failure simply yields an empty context, so generation degrades
  /// gracefully to the pre-personalisation behaviour.
  ///
  /// (Cuisine-affinity + cooking-skill nudges were removed in BUT-1594 — the
  /// menu is drawn from the user's own already-curated recipes, so weighting by
  /// them double-counted taste.)
  ///
  /// The pantry overlap is fetched ONCE here (a single batch call over the
  /// whole [pool]) and memoised into a map, so the per-candidate weight
  /// function never touches async work.
  Future<MenuScoringContext> _buildScoringContext(List<Recipe> pool) async {
    // The pantry and pooled reads are independent I/O — start both before
    // awaiting either so generation waits for the slower one, not their sum.
    final pantryFuture = _buildPantryMatch(pool);
    final pooledFuture = _buildPooledStats(pool);
    final pantryMatch = await pantryFuture;
    final pooledStats = await pooledFuture;

    return MenuScoringContext(
      pantryMatchByRecipeId: pantryMatch,
      pooledStatsByRecipeId: pooledStats,
    );
  }

  /// Reads pantry ingredient overlap for the candidate [pool] (BUT-1321), keyed
  /// by recipeId. Fail-open: an unregistered [PantryService] or a read failure
  /// yields an empty map and generation proceeds without the pantry boost.
  Future<Map<String, double>> _buildPantryMatch(List<Recipe> pool) async {
    final pantryMatch = <String, double>{};
    final pantryService = ServiceLocator.tryGet<PantryService>();
    final userId = _userService.currentUserId;
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
  Future<Map<String, PooledStats>> _buildPooledStats(List<Recipe> pool) async {
    final pooledOn =
        ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enablePooledRatings,
        ) ??
        false;
    if (!pooledOn || pool.isEmpty) return const {};

    final ratingsRepo = ServiceLocator.tryGet<RatingsRepository>();
    if (ratingsRepo == null) return const {};

    try {
      // Derive each candidate's poolKey — the pre-stamped hint, else compute it
      // (older recipes saved before the flag went live carry no hint). Both may
      // be null for a generic/no-anchor dish; those simply get no pooled signal.
      final poolKeyByRecipeId = <String, String>{};
      for (final recipe in pool) {
        final key =
            recipe.core.ratingPoolKey ??
            CanonicalPoolKey.compute(
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

  /// Filters or boosts recipes based on prompt keywords.
  ///
  /// Returns filtered pool if large enough (>= 3), otherwise returns
  /// full pool so generation can still proceed.
  static const _minFilteredPoolSize = 3;

  List<Recipe> _applyPromptKeywordFilter(String prompt, List<Recipe> recipes) {
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

  /// Regenerate specific menu section using the original prompt if available.
  Future<List<Recipe>?> regenerateMenuSection(
    String section,
    Map<String, List<Recipe>> currentMenu, {
    String? originalPrompt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final currentCount = currentMenu[section]?.length ?? 1;
    // Preserve original constraints (e.g. "utan linser") on refresh
    final prompt = originalPrompt ?? '$currentCount $section';

    // BUT-1329: a single-slot re-roll must get the same cross-week freshness
    // down-weighting as a full generation, so last-week recipes are deprioritised
    // here too. Empty set / no plan service → behaves exactly as before.
    final recentIds = await _recentlyUsedRecipeIds();
    // BUT-1464: re-rolls draw from the same allergen-safe async pool as full
    // generation — a refresh must not reintroduce a filtered-out recipe.
    final pool = await getAvailableRecipesAsync();
    // A re-roll rebuilds the scoring context from scratch so it scores against
    // the LIVE pantry + pooled stats (founder decision 2026-07-12, reverting the
    // BUT-1455 within-session cache): if the cook marked ingredients used since
    // generating, the swap reflects it.
    final scoringContext = await _buildScoringContext(pool);

    final newRecipes = await _menuService.generateMenuFromPrompt(
      prompt,
      pool,
      recentlyUsedRecipeIds: recentIds,
      scoringContext: scoringContext,
    );

    if (newRecipes.containsKey(section)) {
      return newRecipes[section];
    }

    return null;
  }

  /// Swap a single recipe with the best-scoring alternative.
  ///
  /// When [useSmartSwap] is true, candidates are scored:
  /// - +3 same cuisine tag as [currentRecipe]
  /// - +2 same category tag (mealType match)
  /// - +1 seasonal match
  /// Ties are broken randomly. Returns [SwapResult] with alternatives count.
  ///
  /// Async since BUT-1464: candidates come from the allergen-safe async pool
  /// so a manual swap can never return an allergen-unsafe replacement.
  Future<SwapResult> swapSingleRecipe(
    Recipe currentRecipe,
    String category,
    Map<String, List<Recipe>> currentMenu,
  ) async {
    final currentMenuRecipeIds = <String>{};
    for (final recipes in currentMenu.values) {
      for (final recipe in recipes) {
        currentMenuRecipeIds.add(recipe.id);
      }
    }

    final eligibleRecipes = _filterEligibleForSwap(
      await getAvailableRecipesAsync(),
      currentMenuRecipeIds,
      category,
    );

    if (eligibleRecipes.isEmpty) {
      AppLogger.warning(
        'No eligible recipes found for swap in category: $category',
      );
      return SwapResult(
        recipe: null,
        alternativesRemaining: 0,
        exhaustedMessage: AppLocale.current.menuSwapExhausted,
      );
    }

    final Recipe chosen;
    if (useSmartSwap) {
      chosen = _scoreAndPickBest(eligibleRecipes, currentRecipe);
    } else {
      eligibleRecipes.shuffle();
      chosen = eligibleRecipes.first;
    }

    // BUT-1474: a swap actually produced a replacement — this is the single
    // chokepoint for every user-initiated recipe swap (MenuViewModel.swapRecipe
    // is the only caller), so the swap-rate signal is emitted here. Fire-and-
    // forget via tryLog (BUT-766) so analytics can never throw or delay a swap.
    AnalyticsService.tryLog(
      AnalyticsEvents.menuRecipeSwapped,
      parameters: {'category': category},
    );

    return SwapResult(
      recipe: chosen,
      alternativesRemaining: eligibleRecipes.length - 1,
    );
  }

  /// Filters recipes eligible for swap: matches category, not in menu.
  List<Recipe> _filterEligibleForSwap(
    List<Recipe> pool,
    Set<String> excludeIds,
    String category,
  ) {
    return pool.where((recipe) {
      if (excludeIds.contains(recipe.id)) return false;

      final categoryLower = category.toLowerCase();
      final mealTypeLower = recipe.mealType.toLowerCase();

      if (categoryLower.contains('middag') ||
          categoryLower.contains('dinner')) {
        return mealTypeLower.contains('middag') ||
            mealTypeLower.contains('dinner') ||
            mealTypeLower.isEmpty;
      }
      if (categoryLower.contains('lunch')) {
        return mealTypeLower.contains('lunch') || mealTypeLower.isEmpty;
      }
      if (categoryLower.contains('frukost') ||
          categoryLower.contains('breakfast')) {
        return mealTypeLower.contains('frukost') ||
            mealTypeLower.contains('breakfast') ||
            mealTypeLower.isEmpty;
      }

      return mealTypeLower == categoryLower || mealTypeLower.isEmpty;
    }).toList();
  }

  /// Scores candidates and picks the highest. Ties are broken randomly.
  Recipe _scoreAndPickBest(List<Recipe> candidates, Recipe current) {
    final seasonTag = SeasonUtils.currentSeasonTag();
    final currentCuisine = _extractCuisine(current);
    final currentCategory = current.mealType.toLowerCase();

    var bestScore = -1;
    final bestCandidates = <Recipe>[];

    for (final candidate in candidates) {
      var score = 0;

      // +3 same cuisine
      if (currentCuisine != null) {
        final candidateCuisine = _extractCuisine(candidate);
        if (candidateCuisine == currentCuisine) score += 3;
      }

      // +2 same category
      if (candidate.mealType.toLowerCase() == currentCategory) score += 2;

      // +1 seasonal match
      final tags = candidate.tagResult?.tags;
      if (tags != null && tags.contains(seasonTag)) score += 1;

      if (score > bestScore) {
        bestScore = score;
        bestCandidates
          ..clear()
          ..add(candidate);
      } else if (score == bestScore) {
        bestCandidates.add(candidate);
      }
    }

    bestCandidates.shuffle();
    return bestCandidates.first;
  }

  static String? _extractCuisine(Recipe recipe) =>
      CuisineConfig.extractCuisineTag(recipe);

  /// Validate menu generation prerequisites.
  ///
  /// Facade over [MenuQualityAnalyzer.validatePromptNotEmpty]; the
  /// availability check stays here because it depends on generator state.
  void validateGenerationPrerequisites(String prompt) {
    MenuQualityAnalyzer.validatePromptNotEmpty(prompt);

    // Sync single-user pool is fine here: this emptiness PRE-check is not
    // safety-load-bearing — generation itself draws from the async
    // household-filtered pool and re-checks emptiness there (BUT-1464).
    if (availableRecipes.isEmpty) {
      throw Exception(AppLocale.current.errorNoRecipesAvailable);
    }
  }

  /// Analyze generated menu quality (delegates to [MenuQualityAnalyzer]).
  Map<String, dynamic> analyzeMenuQuality(Map<String, List<Recipe>> menu) =>
      MenuQualityAnalyzer.analyzeMenuQuality(menu);

  /// Get menu generation suggestions (delegates to [MenuQualityAnalyzer]).
  List<String> getGenerationSuggestions() =>
      MenuQualityAnalyzer.getGenerationSuggestions();

  /// Check if prompt is likely to generate good results
  /// (delegates to [MenuQualityAnalyzer]).
  bool isPromptOptimal(String prompt) =>
      MenuQualityAnalyzer.isPromptOptimal(prompt);
}
