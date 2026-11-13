// lib/viewmodels/menu/menu_generator.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/viewmodels/menu/menu_generation_run.dart';
import 'package:butlery/viewmodels/menu/menu_quality_analyzer.dart';
import 'package:butlery/viewmodels/menu/menu_generator/menu_pool_models.dart';
import 'package:butlery/viewmodels/menu/menu_generator/menu_pool_prefs.dart';
import 'package:butlery/viewmodels/menu/menu_generator/menu_scoring_reads.dart';
import 'package:butlery/viewmodels/menu/menu_generator/prompt_keyword_filter.dart';
import 'package:butlery/viewmodels/menu/menu_generator/recent_plan_reader.dart';
import 'package:butlery/viewmodels/menu/menu_generator/swap_candidates.dart';

export 'package:butlery/viewmodels/menu/menu_generator/menu_pool_models.dart';

/// Focused module for menu generation
/// This module handles ONLY menu generation:
/// - AI-powered menu generation from prompts
/// - Menu section regeneration
/// - Generation error handling
/// - Allergen-safe recipe filtering
/// ❌ DOES NOT CONTAIN: State management, persistence, social features
class MenuGenerator {
  final MenuService _menuService;
  final UnifiedRecipeService _recipeService;
  final OwnProfileReader _userService;

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
  /// any setup step. With no household this is a no-op.
  ///
  /// BUT-1465: now driven by the persisted per-user opt-out — read live from the
  /// profile so the settings toggle takes effect immediately. A missing/unreadable value reads as `true`
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

  /// BUT-1625: asked once per generation, re-roll and swap, AFTER the
  /// allergen-safe pool exists, for the ids in that pool that no meal this
  /// week could take without someone at home disliking them. Those are
  /// down-weighted or tried last; the pool itself never changes. Null, or a
  /// call that throws, means no dislikes.
  Future<Set<String>> Function(List<Recipe> pool)? unplaceableIds;

  Future<Set<String>> _unplaceableIn(List<Recipe> pool) async {
    final provider = unplaceableIds;
    if (provider == null || pool.isEmpty) return const {};
    try {
      return await provider(pool);
    } catch (e) {
      AppLogger.warning('Menu dislikes skipped (${e.runtimeType})');
      return const {};
    }
  }

  /// BUT-2362: asked on every generation, re-roll and swap with the dishes
  /// the household allergen filter removed, for the ids among them some
  /// lunch or middag this week can still take because the person who reacts
  /// is away. Those stay in the pool; placement then puts them only on such
  /// a meal. Null, or a call that throws, adds nothing.
  Future<Set<String>> Function(List<Recipe> removed)? mealScopedIds;

  Future<Set<String>> _mealScopedIn(List<Recipe> removed) async {
    final provider = mealScopedIds;
    if (provider == null || removed.isEmpty) return const {};
    try {
      return await provider(removed);
    } catch (e) {
      AppLogger.warning('Meal allergen scope skipped (${e.runtimeType})');
      return const {};
    }
  }

  /// Optional source of recent weekly plans for cross-week dedup (BUT-1318).
  /// When null (e.g. group flow, tests without the service registered) the
  /// recent-use down-weighting is simply skipped — no Firestore read happens
  /// and generation behaves exactly as before.
  final WeeklyMenuPlanService? _weeklyMenuPlanService;

  MenuGenerator({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required OwnProfileReader userService,
    WeeklyMenuPlanService? weeklyMenuPlanService,
    this.filterByAllergens = false,
    this.filterByDietary = false,
    this.useSmartSwap = true,
  }) : _menuService = menuService,
       _recipeService = recipeService,
       _userService = userService,
       _weeklyMenuPlanService = weeklyMenuPlanService;

  /// BUT-2345: the allergen-safe household pool for a caller with no
  /// generator of its own (the overflow-tray restore). Filters allergens and
  /// diet, as MenuViewModel's generator does.
  static Future<List<Recipe>> readHouseholdSafePool({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required OwnProfileReader userService,
  }) async {
    final generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
      filterByDietary: true,
    );
    await generator.ensureRecipeServiceInitialized();
    return generator.getAvailableRecipesAsync();
  }

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

  /// P6-U01: how many recipes the last [generateMenuFromPrompt] could choose
  /// from (the allergen-safe pool), so a result with no matches can say
  /// "bland dina 84 recept".
  int lastPoolSize = 0;

  /// True when the last generation, re-shuffle or swap could not read the
  /// earlier weeks, so it ran without the repeat down-weighting. A new
  /// generation replaces it; a re-shuffle or swap only ever raises it, since
  /// the menu on screen still came from the unread generation.
  bool lastRecencyReadFailed = false;

  /// Async version of availableRecipes that supports household allergen aggregation.
  ///
  /// A run cancelled while the preferences are read leaves [lastPoolStats]
  /// alone, since the screen has gone back to the suggestion they describe.
  Future<List<Recipe>> getAvailableRecipesAsync({
    bool Function()? isCancelled,
  }) async {
    if (!_recipeService.isInitialized) return [];

    var recipes = _recipeService.recipes;

    if (!filterByAllergens && !filterByDietary) {
      lastPoolStats = MenuPoolStats.empty;
      return recipes;
    }

    final (prefs, prefSource) = await MenuPoolPrefs.resolveActive(
      _userService,
      presentMemberIds,
    );
    final beforeCount = recipes.length;
    final unknownSoft = <String>{};
    if (filterByAllergens) {
      final safe = MenuPoolPrefs.filterByPrefs(
        recipes,
        prefs,
        allergens: true,
        unknownSoftCollector: unknownSoft,
      );
      final safeIds = {for (final r in safe) r.id};
      final scoped = await _mealScopedIn([
        for (final r in recipes)
          if (!safeIds.contains(r.id)) r,
      ]);
      recipes = scoped.isEmpty
          ? safe
          : [
              for (final r in recipes)
                if (safeIds.contains(r.id) || scoped.contains(r.id)) r,
            ];
    }
    if (filterByDietary) {
      recipes = MenuPoolPrefs.filterByPrefs(recipes, prefs, allergens: false);
    }
    if (isCancelled?.call() ?? false) return recipes;
    lastPoolStats = MenuPoolStats(
      hiddenByAllergenFilter: beforeCount - recipes.length,
      unknownSoftRecipeIds: unknownSoft,
      trackedAllergenCount: prefs.trackedAllergens.length,
      prefSource: prefSource,
    );
    return recipes;
  }

  /// Single-user allergen filtering (sync pool only) — same trust-guarded
  /// filter as the async paths, fed by the user's own preferences.
  List<Recipe> _filterByAllergenPreferences(List<Recipe> recipes) =>
      MenuPoolPrefs.filterByPrefs(recipes, _ownPrefs, allergens: true);

  /// Single-user dietary filtering (sync pool only) — see
  /// [_filterByAllergenPreferences].
  List<Recipe> _filterByDietaryPreferences(List<Recipe> recipes) =>
      MenuPoolPrefs.filterByPrefs(recipes, _ownPrefs, allergens: false);

  /// The signed-in user's own preferences as the MENU filters by them —
  /// see [HouseholdService.ownMenuPreferences] (BUT-2085, BUT-1694).
  UserAllergenPreferences get _ownPrefs =>
      HouseholdService.ownMenuPreferences(_userService.currentUserProfile);

  static const resolveHouseholdPrefs = MenuPoolPrefs.resolveHousehold;
  static const filterByPrefs = MenuPoolPrefs.filterByPrefs;

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
  ///
  /// Throws when the library is empty (errorNoRecipesAvailable). Returns an
  /// empty map when the library has recipes but none matched (P6-U01).
  ///
  /// BUT-2157: [isCancelled] is asked after each step; once it answers true
  /// no further read starts and [MenuGenerationCancelled] is thrown.
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String prompt, {
    bool Function()? isCancelled,
  }) async {
    await ensureRecipeServiceInitialized();
    _stopIfCancelled(isCancelled);

    // BUT-1464: the async pool is THE allergen-safe pool (household union +
    // trust guards). Computed once — both the emptiness check and the
    // keyword filter must see the same filtered pool, never the sync
    // single-user one.
    final available = await getAvailableRecipesAsync(isCancelled: isCancelled);
    _stopIfCancelled(isCancelled);
    lastPoolSize = available.length;
    if (available.isEmpty) {
      throw const MenuNoRecipesException();
    }

    final pool = PromptKeywordFilter.apply(prompt, available);

    final recent = await recentlyUsedRecipeIds(_weeklyMenuPlanService);
    _stopIfCancelled(isCancelled);
    lastRecencyReadFailed = recent.readFailed;
    final recentIds = recent.ids;
    final scoringContext = await _buildScoringContext(pool);
    _stopIfCancelled(isCancelled);

    final generatedMenu = await _menuService.generateMenuFromPrompt(
      prompt,
      pool,
      recentlyUsedRecipeIds: recentIds,
      scoringContext: scoringContext,
    );

    // P6-U01: nothing matched is an outcome, not an error.
    // An empty LIBRARY is still the error above.
    _logHiddenByHouseholdEvent();

    return generatedMenu;
  }

  static void _stopIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) throw const MenuGenerationCancelled();
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
    // The pantry, pooled and dislike reads are independent I/O — start all
    // before awaiting any so generation waits for the slowest, not the sum.
    final pantryFuture = MenuScoringReads.buildPantryMatch(_userService, pool);
    final pooledFuture = MenuScoringReads.buildPooledStats(pool);
    final dislikedFuture = _unplaceableIn(pool);
    final pantryMatch = await pantryFuture;
    final pooledStats = await pooledFuture;
    final disliked = await dislikedFuture;

    return MenuScoringContext(
      pantryMatchByRecipeId: pantryMatch,
      pooledStatsByRecipeId: pooledStats,
      dislikedRecipeIds: disliked,
    );
  }

  /// Regenerate specific menu section using the original prompt if available.
  Future<List<Recipe>?> regenerateMenuSection(
    String section,
    Map<String, List<Recipe>> currentMenu, {
    String? originalPrompt,
    bool Function()? isCancelled,
  }) async {
    _stopIfCancelled(isCancelled);

    final currentCount = currentMenu[section]?.length ?? 1;
    // Preserve original constraints (e.g. "utan linser") on refresh
    final prompt = originalPrompt ?? '$currentCount $section';

    // BUT-1329: a single-slot re-roll must get the same cross-week freshness
    // down-weighting as a full generation, so last-week recipes are deprioritised
    // here too. Empty set / no plan service → behaves exactly as before.
    final recent = await recentlyUsedRecipeIds(_weeklyMenuPlanService);
    _stopIfCancelled(isCancelled);
    if (recent.readFailed) lastRecencyReadFailed = true;
    final recentIds = recent.ids;
    // BUT-1464: re-rolls draw from the same allergen-safe async pool as full
    // generation — a refresh must not reintroduce a filtered-out recipe.
    final available = await getAvailableRecipesAsync(isCancelled: isCancelled);
    _stopIfCancelled(isCancelled);
    // The menu came from a "favoriter"/"senaste" prompt; a re-roll that left
    // the keyword out of the pool would bring back dishes the prompt excluded.
    final pool = PromptKeywordFilter.apply(prompt, available);
    // A re-roll rebuilds the scoring context from scratch so it scores against
    // the LIVE pantry + pooled stats (founder decision 2026-07-12, reverting the
    // BUT-1455 within-session cache): if the cook marked ingredients used since
    // generating, the swap reflects it.
    final scoringContext = await _buildScoringContext(pool);
    _stopIfCancelled(isCancelled);

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

    final allEligible = SwapCandidates.filterEligible(
      await getAvailableRecipesAsync(),
      currentMenuRecipeIds,
      category,
    );
    var eligibleRecipes = allEligible;
    // BUT-1625: a replacement nobody at home dislikes comes first; the rest
    // stay as the fallback so a dislike never exhausts the swap.
    final disliked = await _unplaceableIn(allEligible);
    if (disliked.isNotEmpty) {
      final liked = eligibleRecipes
          .where((r) => !disliked.contains(r.id))
          .toList();
      if (liked.isNotEmpty) eligibleRecipes = liked;
    }

    // Same intent as generation's repeat down-weighting: prefer a dish not
    // used in the last two weeks, but never run out of swaps because of it.
    final recent = await recentlyUsedRecipeIds(_weeklyMenuPlanService);
    if (recent.readFailed) lastRecencyReadFailed = true;
    if (recent.ids.isNotEmpty) {
      final fresh = eligibleRecipes
          .where((r) => !recent.ids.contains(r.id))
          .toList();
      if (fresh.isNotEmpty) eligibleRecipes = fresh;
    }

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
      chosen = SwapCandidates.scoreAndPickBest(eligibleRecipes, currentRecipe);
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
      alternativesRemaining: allEligible.length - 1,
    );
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
