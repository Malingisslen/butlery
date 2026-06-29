// lib/viewmodels/menu/menu_generator.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
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
  bool useHouseholdAllergens = false;

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

  /// Async version of availableRecipes that supports household allergen aggregation.
  Future<List<Recipe>> getAvailableRecipesAsync() async {
    if (!_recipeService.isInitialized) return [];

    var recipes = _recipeService.recipes;

    // Present-aware filtering takes precedence over the whole-household union
    // when a NON-EMPTY present set is supplied (opt-in). An empty list ("no one
    // selected") must NOT disable filtering — it falls through to the
    // whole-household union, never an unfiltered (unsafe) pool. Also falls
    // through if the roster/household can't be resolved.
    final present = presentMemberIds;
    if (present != null &&
        present.isNotEmpty &&
        (filterByAllergens || filterByDietary)) {
      final prefs = await _presentAllergenPrefs(present);
      if (prefs != null) {
        if (filterByAllergens) {
          recipes = _filterByPrefs(recipes, prefs, allergens: true);
        }
        if (filterByDietary) {
          recipes = _filterByPrefs(recipes, prefs, allergens: false);
        }
        return recipes;
      }
    }

    if (useHouseholdAllergens) {
      final householdService = ServiceLocator.tryGet<HouseholdService>();
      if (householdService != null && householdService.hasHousehold) {
        final prefs = await householdService.getAggregatedAllergenPreferences();
        if (filterByAllergens) {
          recipes = _filterByPrefs(recipes, prefs, allergens: true);
        }
        if (filterByDietary) {
          recipes = _filterByPrefs(recipes, prefs, allergens: false);
        }
        return recipes;
      }
    }

    // Fall back to single-user filtering
    if (filterByAllergens) {
      recipes = _filterByAllergenPreferences(recipes);
    }
    if (filterByDietary) {
      recipes = _filterByDietaryPreferences(recipes);
    }
    return recipes;
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

  /// Filter recipes using explicit prefs (for household aggregation).
  List<Recipe> _filterByPrefs(
    List<Recipe> recipes,
    UserAllergenPreferences prefs, {
    required bool allergens,
  }) {
    if (allergens) {
      if (!prefs.hasTrackedAllergens) return recipes;
      final tracked = prefs.trackedAllergens;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        final tagResult = recipe.tagResult;
        if (tagResult == null) return includeUnknown;
        for (final allergen in tracked) {
          final status = tagResult.getAllergenStatus(allergen);
          if (status == TriState.contains) return false;
          if (!includeUnknown && status == TriState.unknown) return false;
        }
        return true;
      }).toList();
    } else {
      if (!prefs.hasTrackedDietary) return recipes;
      final tracked = prefs.trackedDietary;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        final tagResult = recipe.tagResult;
        if (tagResult == null) return includeUnknown;
        for (final dietary in tracked) {
          final status = tagResult.getDietaryStatus(dietary);
          if (status != TriState.free) {
            if (status == TriState.contains) return false;
            if (!includeUnknown && status == TriState.unknown) return false;
          }
        }
        return true;
      }).toList();
    }
  }

  /// Filters out recipes that CONTAIN any of the user's tracked allergens.
  /// When includeUnknownInMenu is false, also excludes UNKNOWN status recipes.
  List<Recipe> _filterByAllergenPreferences(List<Recipe> recipes) {
    final prefs = _userService.allergenPreferences;
    if (!prefs.hasTrackedAllergens) return recipes;

    final tracked = prefs.trackedAllergens;
    final includeUnknown = prefs.includeUnknownInMenu;
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      // BUT-1394: a null verdict is functionally UNKNOWN. Honour the
      // "include unknown in menu" opt-out here exactly as the async
      // household path (_filterByPrefs) does — otherwise a user who asked for
      // only-proven-safe recipes still gets fully-untagged ones in a
      // single-user menu (allergen-safety surface).
      if (tagResult == null) return includeUnknown;

      for (final allergen in tracked) {
        final status = tagResult.getAllergenStatus(allergen);
        if (status == TriState.contains) {
          return false;
        }
        if (!includeUnknown && status == TriState.unknown) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filters out recipes that don't match user's tracked dietary preferences.
  /// A recipe passes if it is FREE for ALL tracked dietary preferences.
  /// Respects includeUnknownInMenu setting for consistency with allergen filtering.
  List<Recipe> _filterByDietaryPreferences(List<Recipe> recipes) {
    final prefs = _userService.allergenPreferences;
    if (!prefs.hasTrackedDietary) return recipes;

    final tracked = prefs.trackedDietary;
    final includeUnknown = prefs.includeUnknownInMenu;
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      // BUT-1394: a null verdict is functionally UNKNOWN. Honour the
      // "include unknown in menu" opt-out here exactly as the async
      // household path (_filterByPrefs) does — otherwise a user who asked for
      // only-proven-safe recipes still gets fully-untagged ones in a
      // single-user menu (allergen-safety surface).
      if (tagResult == null) return includeUnknown;

      for (final diet in tracked) {
        final status = tagResult.getDietaryStatus(diet);
        if (status == TriState.contains) {
          return false;
        }
        if (!includeUnknown && status == TriState.unknown) {
          return false;
        }
      }
      return true;
    }).toList();
  }

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

    if (availableRecipes.isEmpty) {
      throw Exception(AppLocale.current.errorNoRecipesAvailable);
    }

    final pool = _applyPromptKeywordFilter(prompt, availableRecipes);

    final recentIds = await _recentlyUsedRecipeIds();

    final generatedMenu = await _menuService.generateMenuFromPrompt(
      prompt,
      pool,
      recentlyUsedRecipeIds: recentIds,
    );

    if (generatedMenu.isEmpty) {
      throw Exception(
        AppLocale.current.errorGeneric,
      );
    }

    return generatedMenu;
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

    final newRecipes = await _menuService.generateMenuFromPrompt(
      prompt,
      availableRecipes,
      recentlyUsedRecipeIds: recentIds,
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
  SwapResult swapSingleRecipe(
    Recipe currentRecipe,
    String category,
    Map<String, List<Recipe>> currentMenu,
  ) {
    final currentMenuRecipeIds = <String>{};
    for (final recipes in currentMenu.values) {
      for (final recipe in recipes) {
        currentMenuRecipeIds.add(recipe.id);
      }
    }

    final eligibleRecipes = _filterEligibleForSwap(
      availableRecipes,
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
