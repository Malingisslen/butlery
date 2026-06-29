/// Menu generation service using Swedish natural language parsing.
///
/// Parses requests like "3 middagar, 2 luncher" and randomly selects
/// matching recipes from the user's collection. NOT AI/LLM-based.
/// Supports weighted selection (recency, season boost, cuisine diversity).
library;

import 'package:clock/clock.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

/// Generates menus by parsing Swedish meal requests and randomly selecting recipes.
///
/// Example: "tre frukoster och två middagar" → 3 breakfast + 2 dinner recipes
class MenuService extends BaseService {
  MenuService({LexiconProvider? lexiconProvider, Random? random})
    : _lexiconProvider = lexiconProvider,
      _random = random ?? Random();

  final LexiconProvider? _lexiconProvider;
  Lexicon? _cachedLexicon;

  /// RNG for weighted recipe selection. Injectable + seedable so tests can make
  /// the probabilistic weighting deterministic instead of asserting on flaky
  /// statistical thresholds: the season-boost test flaked at n=1000 because the
  /// boost vs no-boost distributions overlap at ~4σ (got 549 vs a >550 floor) —
  /// a fixed seed removes the flake without weakening the check.
  final Random _random;

  @override
  String get serviceName => 'MenuService';

  Future<Lexicon?> _loadLexicon() async {
    if (_cachedLexicon != null) return _cachedLexicon;
    if (_lexiconProvider == null) return null;
    _cachedLexicon = await _lexiconProvider.load();
    return _cachedLexicon;
  }

  /// Parses Swedish meal request and returns randomly selected recipes.
  ///
  /// The prompt goes through the deterministic constraint parser (BUT-359).
  /// Returns empty map if no lexicon is available or the parser finds nothing.
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
  }) async {
    final lexicon = await _loadLexicon();
    if (lexicon == null) return {};
    final parsed = MenuConstraintParser.parse(input, lexicon);
    if (parsed.isEmpty) return {};
    return generateMenuFromParsedRequest(
      parsed,
      allRecipes,
      recentlyUsedRecipeIds: recentlyUsedRecipeIds,
    );
  }

  /// Returns the last parsed request for the given prompt, or null if no
  /// lexicon is available. Used by the ViewModel to expose the extraction
  /// trace to the chip strip UI.
  Future<ParsedMenuRequest?> parsePrompt(String input) async {
    final lexicon = await _loadLexicon();
    if (lexicon == null) return null;
    return MenuConstraintParser.parse(input, lexicon);
  }

  /// Modest rating boost ceiling. A 5★ recipe gets at most this multiplier;
  /// unrated recipes get 1.0 (no penalty). Kept gentle so ratings nudge but
  /// never dominate recency — the spread (1.0 → 1.4) is smaller than the
  /// season boost (1.5) on purpose.
  static const double _maxRatingBoost = 1.4;

  /// Down-weight applied to a recipe that appears in a recent weekly plan
  /// (BUT-1318). A decay rather than a hard exclude so the recipe can still
  /// be picked if the rest of the pool is too thin to fill the menu — this
  /// mirrors the `_minFilteredPoolSize` fallback philosophy without needing a
  /// pool-size branch here.
  static const double _recentUseDecay = 0.15;

  /// Calculates recipe weight based on recency, with optional season, rating,
  /// and recent-use adjustments.
  ///
  /// Weight = daysSinceLastCooked (capped at 90). Never-cooked recipes get 90.
  /// - Season boost: 1.5x for recipes tagged with the current season.
  /// - Rating boost (BUT-1319 + family Phase 4): up to 1.4x for a 5★ recipe,
  ///   scaled by the family verdict if the household has rated it, else the
  ///   public/personal rating. Unrated recipes get 1.0 — never penalized.
  /// - Recent-use decay (BUT-1318): 0.15x for recipes used in a recent plan,
  ///   so they rotate out but keep a non-zero chance of being picked.
  static double _recipeWeight(
    Recipe recipe, {
    required String seasonTag,
    Set<String> recentlyUsedIds = const {},
  }) {
    const maxDays = 90;
    final lastCooked = recipe.lastCookedAt;
    final daysSince = lastCooked == null
        ? maxDays
        : clock.now().difference(lastCooked).inDays.clamp(0, maxDays);

    double weight = daysSince.toDouble();
    if (weight < 1) weight = 1; // Minimum weight to participate

    // Season boost: 1.5x for seasonal recipes
    final tags = recipe.tagResult?.tags;
    if (tags != null && tags.contains(seasonTag)) {
      weight *= 1.5;
    }

    weight *= _ratingMultiplier(recipe);

    // Recent-use decay: strongly down-weight (not exclude) recently used
    // recipes so they keep a small, non-zero probability.
    if (recentlyUsedIds.contains(recipe.id)) {
      weight *= _recentUseDecay;
    }

    return weight;
  }

  /// Gentle rating boost in [1.0, _maxRatingBoost]. Linear in the average
  /// rating: 1★ → 1.0, 5★ → 1.4. Unrated recipes (count 0/null or rating null)
  /// return 1.0, so they are never penalized relative to a 1★ recipe — they
  /// just don't get the boost.
  ///
  /// Family-rating influence (Phase 4 item 13): the household's own
  /// `familyAverage` is the truest "did the people who eat this like it" signal,
  /// so it takes precedence over the public/personal `rating` when present. This
  /// is the soft v1 — a crowd-pleaser floats up, a household flop sinks but is
  /// never excluded (veto-strength is a later, configurable step). A
  /// present-diner subset average (vs the whole-household average) waits on the
  /// deferred WeeklyMenuPlanEntry attendees.
  static double _ratingMultiplier(Recipe recipe) {
    final familyAvg = recipe.core.familyAverage;
    final familyCount = recipe.core.familyRatingCount ?? 0;

    final double? rating;
    final int count;
    if (familyAvg != null && familyCount > 0) {
      rating = familyAvg;
      count = familyCount;
    } else {
      rating = recipe.core.rating;
      count = recipe.core.ratingCount ?? 0;
    }

    if (rating == null || count <= 0) return 1.0;
    final clamped = rating.clamp(1.0, 5.0);
    final fraction = (clamped - 1.0) / 4.0; // 0.0 at 1★, 1.0 at 5★
    return 1.0 + fraction * (_maxRatingBoost - 1.0);
  }

  /// Selects [count] recipes using cumulative-weight random selection.
  ///
  /// Higher-weighted recipes (not recently cooked, seasonal) are more likely
  /// to be picked but all recipes participate.
  List<Recipe> _weightedSelect(
    List<Recipe> pool,
    int count,
    Random rand, {
    required String seasonTag,
    Set<String> recentlyUsedIds = const {},
  }) {
    if (pool.isEmpty) return [];
    final available = List<Recipe>.from(pool);
    final selected = <Recipe>[];

    for (var i = 0; i < min(count, pool.length); i++) {
      if (available.isEmpty) break;

      final weights = available
          .map(
            (r) => _recipeWeight(
              r,
              seasonTag: seasonTag,
              recentlyUsedIds: recentlyUsedIds,
            ),
          )
          .toList();
      final totalWeight = weights.fold(0.0, (sum, w) => sum + w);

      if (totalWeight <= 0) {
        // Fallback: pick random
        selected.add(available.removeAt(rand.nextInt(available.length)));
        continue;
      }

      var pick = rand.nextDouble() * totalWeight;
      var chosenIndex = 0;
      for (var j = 0; j < weights.length; j++) {
        pick -= weights[j];
        if (pick <= 0) {
          chosenIndex = j;
          break;
        }
      }

      selected.add(available.removeAt(chosenIndex));
    }

    return selected;
  }

  /// Test-only access to the deterministic weight function, so the rating
  /// boost (BUT-1319) and recent-use decay (BUT-1318) can be asserted on the
  /// weight math directly instead of through the random draw.
  @visibleForTesting
  static double debugRecipeWeight(
    Recipe recipe, {
    required String seasonTag,
    Set<String> recentlyUsedIds = const {},
  }) => _recipeWeight(
    recipe,
    seasonTag: seasonTag,
    recentlyUsedIds: recentlyUsedIds,
  );

  static String? _cuisineOf(Recipe recipe) =>
      CuisineConfig.extractCuisineTag(recipe);

  /// Replaces excess same-cuisine recipes with next-highest-weighted alternatives.
  ///
  /// If more than 2 recipes share a cuisine, extras are swapped out for the
  /// best non-duplicate alternative from the full pool. Replacements are chosen
  /// so they don't create new clustering (checks current cuisine counts).
  List<Recipe> _enforceCuisineDiversity(
    List<Recipe> selected,
    List<Recipe> fullPool,
    Random rand, {
    required Set<String> usedIds,
    required String seasonTag,
    Set<String> recentlyUsedIds = const {},
  }) {
    if (selected.length <= 2) return selected;

    final result = List<Recipe>.from(selected);
    final resultIds = {for (final r in result) r.id, ...usedIds};

    // Recount cuisines from the current result (we'll update after each swap)
    Map<String, int> countCuisines() {
      final counts = <String, int>{};
      for (final recipe in result) {
        final cuisine = _cuisineOf(recipe);
        if (cuisine != null) {
          counts[cuisine] = (counts[cuisine] ?? 0) + 1;
        }
      }
      return counts;
    }

    // Iterate until no cuisine exceeds 2, or no more replacements possible.
    // Safety bound prevents infinite loop if replacements keep causing new clusters.
    var changed = true;
    var iterations = 0;
    final maxIterations = result.length * 2;
    while (changed && iterations < maxIterations) {
      iterations++;
      changed = false;
      final counts = countCuisines();
      if (counts.values.every((c) => c <= 2)) break;

      for (var i = 0; i < result.length; i++) {
        final cuisine = _cuisineOf(result[i]);
        if (cuisine == null || (counts[cuisine] ?? 0) <= 2) continue;

        // Find replacement: not already used, and whose cuisine has < 2 in result
        final replacement = _findDiverseReplacement(
          fullPool,
          resultIds,
          counts,
          seasonTag,
          recentlyUsedIds,
        );
        if (replacement == null) continue;

        resultIds.remove(result[i].id);
        result[i] = replacement;
        resultIds.add(replacement.id);
        changed = true;
        break; // Restart scan with updated counts
      }
    }

    return result;
  }

  /// Finds the highest-weighted recipe not already selected and whose cuisine
  /// won't create a new cluster (already has < 2 in current counts).
  static Recipe? _findDiverseReplacement(
    List<Recipe> pool,
    Set<String> usedIds,
    Map<String, int> currentCuisineCounts,
    String seasonTag,
    Set<String> recentlyUsedIds,
  ) {
    Recipe? best;
    double bestWeight = -1;

    for (final recipe in pool) {
      if (usedIds.contains(recipe.id)) continue;

      final cuisine = _cuisineOf(recipe);
      // Allow if no cuisine tag, or cuisine has room (< 2 in current menu)
      if (cuisine != null && (currentCuisineCounts[cuisine] ?? 0) >= 2) {
        continue;
      }

      final weight = _recipeWeight(
        recipe,
        seasonTag: seasonTag,
        recentlyUsedIds: recentlyUsedIds,
      );
      if (weight > bestWeight) {
        bestWeight = weight;
        best = recipe;
      }
    }

    return best;
  }

  /// Selects recipes from [allRecipes] matching the structured constraints
  /// in [parsed]. Return shape is the same `Map<mealType, List<Recipe>>` as
  /// [generateMenuFromPrompt] so the weekly-plan distribution layer is
  /// untouched.
  Future<Map<String, List<Recipe>>> generateMenuFromParsedRequest(
    ParsedMenuRequest parsed,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
  }) async {
    return await executeServiceOperation(
          () async => _generateFromParsedInternal(
            parsed,
            allRecipes,
            recentlyUsedRecipeIds,
          ),
          operationName: 'Generate menu from parsed request',
          defaultValue: <String, List<Recipe>>{},
          requiresAuth: false,
        ) ??
        <String, List<Recipe>>{};
  }

  Map<String, List<Recipe>> _generateFromParsedInternal(
    ParsedMenuRequest parsed,
    List<Recipe> allRecipes,
    Set<String> recentlyUsedRecipeIds,
  ) {
    final globallyOk = allRecipes
        .where((r) => _passesGlobals(r, parsed))
        .toList();

    if (globallyOk.length < allRecipes.length) {
      AppLogger.debug(
        'MenuService: ${allRecipes.length - globallyOk.length} recipes '
        'filtered by global constraints '
        '(${allRecipes.length} total → ${globallyOk.length} remaining)',
      );
    }

    final result = <String, List<Recipe>>{};
    final usedIds = <String>{};
    final rand = _random;
    final season = SeasonUtils.currentSeasonTag();

    // Day pins land first (so tacofredag wins over generic selection).
    for (final pin in parsed.dayPins) {
      final pool = globallyOk
          .where(
            (r) =>
                r.mealType.toLowerCase() == pin.mealType.toLowerCase() &&
                _matchesConstraint(r, pin.constraint) &&
                !usedIds.contains(r.id),
          )
          .toList();
      if (pool.isEmpty) continue;
      final pick = _weightedSelect(
        pool,
        1,
        rand,
        seasonTag: season,
        recentlyUsedIds: recentlyUsedRecipeIds,
      );
      for (final r in pick) {
        usedIds.add(r.id);
        (result[pin.mealType] ??= []).add(r);
      }
    }

    // Slot requests.
    for (final slot in parsed.slotRequests) {
      final slotPool = globallyOk
          .where(
            (r) =>
                r.mealType.toLowerCase() == slot.mealType.toLowerCase() &&
                !usedIds.contains(r.id),
          )
          .toList();

      if (slotPool.length < slot.totalCount) {
        // Build mealType distribution for diagnostics
        final mealDist = <String, int>{};
        for (final r in globallyOk) {
          final mt = r.mealType.toLowerCase();
          mealDist[mt] = (mealDist[mt] ?? 0) + 1;
        }
        AppLogger.warning(
          'MenuService: Only ${slotPool.length} recipes match '
          '"${slot.mealType}" but ${slot.totalCount} requested. '
          'Available mealTypes: $mealDist',
        );
      }

      final picks = <Recipe>[];
      for (final sub in slot.subRequests) {
        final subPool = slotPool
            .where((r) => _matchesConstraint(r, sub) && !usedIds.contains(r.id))
            .toList();
        var selected = _weightedSelect(
          subPool,
          sub.count,
          rand,
          seasonTag: season,
          recentlyUsedIds: recentlyUsedRecipeIds,
        );
        // Soft constraints fall back to unconstrained pool when empty.
        if (selected.isEmpty && sub.isSoft) {
          selected = _weightedSelect(
            slotPool.where((r) => !usedIds.contains(r.id)).toList(),
            sub.count,
            rand,
            seasonTag: season,
            recentlyUsedIds: recentlyUsedRecipeIds,
          );
        }
        for (final r in selected) {
          usedIds.add(r.id);
        }
        picks.addAll(selected);
      }

      final diversified = _enforceCuisineDiversity(
        picks,
        slotPool,
        rand,
        usedIds: usedIds,
        seasonTag: season,
        recentlyUsedIds: recentlyUsedRecipeIds,
      );
      for (final r in diversified) {
        usedIds.add(r.id);
      }
      (result[slot.mealType] ??= []).addAll(diversified);
    }

    return result;
  }

  static bool _passesGlobals(Recipe r, ParsedMenuRequest p) {
    if (p.globalAllergenAvoid.isEmpty &&
        p.globalDietaryRequire.isEmpty &&
        p.globalExcludedTags.isEmpty) {
      return true;
    }
    final tr = r.tagResult;
    // Allergen/dietary checks need tagResult
    if (p.globalAllergenAvoid.isNotEmpty || p.globalDietaryRequire.isNotEmpty) {
      if (tr == null) return true; // No tag data = include (can't determine)
      for (final a in p.globalAllergenAvoid) {
        if (tr.getAllergenStatus(a) != TriState.free) return false;
      }
      for (final d in p.globalDietaryRequire) {
        if (tr.getDietaryStatus(d) != TriState.free) return false;
      }
    }
    // Tag + ingredient exclusion (doesn't require tagResult)
    if (p.globalExcludedTags.isNotEmpty) {
      if (tr != null && p.globalExcludedTags.any(tr.tags.contains)) {
        return false;
      }
      final ings = r.core.ingredientsNormalized ?? r.core.ingredients;
      for (final word in p.globalExcludedTags) {
        if (ings.any((i) => i.toLowerCase().contains(word))) return false;
      }
    }
    return true;
  }

  static bool _matchesConstraint(Recipe r, RecipeConstraint c) {
    if (c.isUnconstrained) return true;
    final tr = r.tagResult;
    if (tr == null) return false;
    for (final d in c.dietaryFree) {
      if (tr.getDietaryStatus(d) != TriState.free) return false;
    }
    for (final a in c.allergenFree) {
      if (tr.getAllergenStatus(a) != TriState.free) return false;
    }
    if (c.requiredTags.isNotEmpty && !tr.hasAllTags(c.requiredTags)) {
      return false;
    }
    if (c.excludedTags.isNotEmpty && c.excludedTags.any(tr.tags.contains)) {
      return false;
    }
    if (c.requiredCuisines.isNotEmpty) {
      final cuisine = CuisineConfig.extractCuisineTag(r);
      if (cuisine == null || !c.requiredCuisines.contains(cuisine)) {
        return false;
      }
    }
    if (c.maxTimeMinutes != null) {
      final t = r.core.timeMinutes;
      if (t == null || t > c.maxTimeMinutes!) return false;
    }
    return true;
  }
}
