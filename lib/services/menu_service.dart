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
import 'package:butlery/services/menu/menu_allergen_trust.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/protein_category.dart';
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
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) async {
    final lexicon = await _loadLexicon();
    if (lexicon == null) return {};
    final parsed = MenuConstraintParser.parse(input, lexicon);
    if (parsed.isEmpty) return {};
    return generateMenuFromParsedRequest(
      parsed,
      allRecipes,
      recentlyUsedRecipeIds: recentlyUsedRecipeIds,
      scoringContext: scoringContext,
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

  /// Test-only view of the rating ceiling, so the personalisation-signal
  /// ceilings can be asserted to stay below it (rating stays the strongest
  /// nudge; personalisation is a tiebreaker, not a filter).
  @visibleForTesting
  static double get debugMaxRatingBoost => _maxRatingBoost;

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
    MenuScoringContext context = MenuScoringContext.empty,
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

    // Personalisation nudges (BUT-1320 pantry/cuisine/skill). Gentle,
    // multiplicative, never zero — identity (1.0) when no context is supplied,
    // so the pre-personalisation behaviour is byte-for-byte preserved.
    weight *= context.multiplierFor(recipe);

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
    MenuScoringContext context = MenuScoringContext.empty,
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
              context: context,
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
    MenuScoringContext context = MenuScoringContext.empty,
  }) => _recipeWeight(
    recipe,
    seasonTag: seasonTag,
    recentlyUsedIds: recentlyUsedIds,
    context: context,
  );

  static String? _cuisineOf(Recipe recipe) =>
      CuisineConfig.extractCuisineTag(recipe);

  /// Most recipes of one category allowed in a single generated week, per
  /// dimension (cuisine, protein). Extras are swapped out for a diverse
  /// alternative.
  static const int _maxPerCategory = 2;

  /// The classification dimensions the weekly-menu balance enforces, each
  /// mapping a recipe to its category within that dimension (or `null` = no
  /// signal, left unconstrained). Cuisine (BUT-359) and protein category
  /// (BUT-1324) are enforced TOGETHER by [_enforceMenuDiversity] — see the note
  /// there on why a single combined pass is used instead of two sequential ones.
  static final List<String? Function(Recipe)> _diversityDimensions = [
    _cuisineOf,
    ProteinCategory.categoryOf,
  ];

  /// Rebalances the selected recipes so that, within a single generated week, no
  /// cuisine AND no protein category appears more than [_maxPerCategory] times
  /// (BUT-359 cuisine + BUT-1324 protein). Extras are swapped for the
  /// best-weighted non-duplicate alternative from the full pool; recipes with no
  /// cuisine/protein signal are never constrained and never dropped for lacking
  /// one.
  ///
  /// This is a single COMBINED pass over both dimensions, and that is
  /// deliberate. A cuisine-only pass and a protein-only pass run back-to-back
  /// can undo each other: a cuisine swap that breaks up an Italian cluster can
  /// pull in a chicken dish that recreates a poultry cluster, and the protein
  /// pass fixing that can reintroduce the cuisine cluster. By checking every
  /// dimension on each swap — a selected recipe is a replacement candidate if it
  /// sits in an over-full category in ANY dimension, and a replacement is
  /// accepted only if it creates no new cluster in ANY dimension — the pass
  /// converges on a selection that satisfies both constraints at once.
  ///
  /// Termination: every accepted swap removes one recipe from an over-full
  /// category and adds a replacement that creates no new cluster, so the total
  /// count of over-full slots strictly decreases; the loop therefore converges.
  /// The iteration cap is a belt-and-suspenders guard. If the pool cannot
  /// satisfy both constraints, no swap is forced — the best achievable selection
  /// is kept rather than dropping any recipe, and neither dimension is privileged
  /// over the other (a residual violation can remain in either).
  List<Recipe> _enforceMenuDiversity(
    List<Recipe> selected,
    List<Recipe> fullPool,
    Random rand, {
    required Set<String> usedIds,
    required String seasonTag,
    Set<String> recentlyUsedIds = const {},
    MenuScoringContext context = MenuScoringContext.empty,
  }) {
    if (selected.length <= _maxPerCategory) return selected;

    final dimensions = _diversityDimensions;
    final result = List<Recipe>.from(selected);
    final resultIds = {for (final r in result) r.id, ...usedIds};

    // Per-dimension category counts of the current result (recount after swaps).
    List<Map<String, int>> countCategories() {
      final counts = List.generate(dimensions.length, (_) => <String, int>{});
      for (final recipe in result) {
        for (var d = 0; d < dimensions.length; d++) {
          final key = dimensions[d](recipe);
          if (key != null) {
            counts[d][key] = (counts[d][key] ?? 0) + 1;
          }
        }
      }
      return counts;
    }

    var changed = true;
    var iterations = 0;
    final maxIterations = result.length * dimensions.length * 2;
    while (changed && iterations < maxIterations) {
      iterations++;
      changed = false;
      final counts = countCategories();

      final hasViolation = counts.any(
        (m) => m.values.any((c) => c > _maxPerCategory),
      );
      if (!hasViolation) break;

      for (var i = 0; i < result.length; i++) {
        // Only touch recipes sitting in an over-full category in some dimension.
        var overfull = false;
        for (var d = 0; d < dimensions.length; d++) {
          final key = dimensions[d](result[i]);
          if (key != null && (counts[d][key] ?? 0) > _maxPerCategory) {
            overfull = true;
            break;
          }
        }
        if (!overfull) continue;

        final replacement = _findBalancedReplacement(
          fullPool,
          result[i],
          resultIds,
          dimensions,
          counts,
          seasonTag,
          recentlyUsedIds,
          context,
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

  /// Finds the highest-weighted recipe not already selected whose categories
  /// won't create a new cluster in ANY diversity dimension, evaluated as if
  /// [outgoing] (the recipe about to be swapped out) were already removed. A
  /// recipe with no signal in a dimension is unconstrained there.
  static Recipe? _findBalancedReplacement(
    List<Recipe> pool,
    Recipe outgoing,
    Set<String> usedIds,
    List<String? Function(Recipe)> dimensions,
    List<Map<String, int>> currentCounts,
    String seasonTag,
    Set<String> recentlyUsedIds,
    MenuScoringContext context,
  ) {
    // Swapping [outgoing] out frees a slot in each of its categories, so a
    // candidate that shares a now-freed category is a legal replacement.
    // Without this decrement the scan checks candidates against counts that
    // still include the outgoing recipe, wrongly rejecting valid diversifying
    // swaps and leaving a cluster the pool could have resolved (BUT-1457).
    final effectiveCounts = [
      for (final m in currentCounts) Map<String, int>.from(m),
    ];
    for (var d = 0; d < dimensions.length; d++) {
      final key = dimensions[d](outgoing);
      if (key != null) {
        final c = (effectiveCounts[d][key] ?? 0) - 1;
        if (c <= 0) {
          effectiveCounts[d].remove(key);
        } else {
          effectiveCounts[d][key] = c;
        }
      }
    }

    Recipe? best;
    double bestWeight = -1;

    for (final recipe in pool) {
      if (usedIds.contains(recipe.id)) continue;

      var wouldCluster = false;
      for (var d = 0; d < dimensions.length; d++) {
        final key = dimensions[d](recipe);
        if (key != null && (effectiveCounts[d][key] ?? 0) >= _maxPerCategory) {
          wouldCluster = true;
          break;
        }
      }
      if (wouldCluster) continue;

      final weight = _recipeWeight(
        recipe,
        seasonTag: seasonTag,
        recentlyUsedIds: recentlyUsedIds,
        context: context,
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
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) async {
    return await executeServiceOperation(
          () async => _generateFromParsedInternal(
            parsed,
            allRecipes,
            recentlyUsedRecipeIds,
            scoringContext,
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
    MenuScoringContext scoringContext,
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
        context: scoringContext,
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
          context: scoringContext,
        );
        // Soft constraints fall back to unconstrained pool when empty.
        if (selected.isEmpty && sub.isSoft) {
          selected = _weightedSelect(
            slotPool.where((r) => !usedIds.contains(r.id)).toList(),
            sub.count,
            rand,
            seasonTag: season,
            recentlyUsedIds: recentlyUsedRecipeIds,
            context: scoringContext,
          );
        }
        for (final r in selected) {
          usedIds.add(r.id);
        }
        picks.addAll(selected);
      }

      final diversified = _enforceMenuDiversity(
        picks,
        slotPool,
        rand,
        usedIds: usedIds,
        seasonTag: season,
        recentlyUsedIds: recentlyUsedRecipeIds,
        context: scoringContext,
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
      if (tr == null) {
        // No tag data = include (can't determine) — EXCEPT when a manual
        // override says CONTAINS: a human correction can exist on an
        // untagged recipe and must still exclude it (BUT-1464 review M1).
        final ov = r.tagOverrides;
        if (ov != null) {
          for (final a in p.globalAllergenAvoid) {
            if (ov.allergenOverrides[a] == TriState.contains) return false;
          }
          for (final d in p.globalDietaryRequire) {
            if (ov.dietaryOverrides[d] == TriState.contains) return false;
          }
        }
        return true;
      }
      // BUT-1464: trust-guarded reads — manual overrides win, stale FREE is
      // not trusted for an explicit "utan X" prompt constraint. Shared with
      // the per-slot filter via _allTrustedFree so the two never diverge.
      if (!_allTrustedFree(r, p.globalAllergenAvoid, p.globalDietaryRequire)) {
        return false;
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

  /// BUT-1466/1464: true iff every listed allergen/dietary key resolves to a
  /// TRUSTED FREE via [MenuAllergenTrust] — manual overrides win and a stale/
  /// low-coverage auto-FREE is downgraded to UNKNOWN. Works on untagged recipes
  /// too: a null tagResult reads as UNKNOWN unless a manual override says
  /// otherwise, so an untagged recipe qualifies only when a human marked it
  /// free. Shared by [_passesGlobals] and [_matchesConstraint] so the global
  /// and per-slot filters never disagree on what counts as safe.
  static bool _allTrustedFree(
    Recipe r,
    Iterable<String> allergenKeys,
    Iterable<String> dietaryKeys,
  ) {
    for (final a in allergenKeys) {
      if (MenuAllergenTrust.effectiveAllergenStatus(r, a) != TriState.free) {
        return false;
      }
    }
    for (final d in dietaryKeys) {
      if (MenuAllergenTrust.effectiveDietaryStatus(r, d) != TriState.free) {
        return false;
      }
    }
    return true;
  }

  static bool _matchesConstraint(Recipe r, RecipeConstraint c) {
    if (c.isUnconstrained) return true;
    final tr = r.tagResult;
    // BUT-1466: trust-guarded allergen/dietary reads via _allTrustedFree.
    // Do NOT early-return on tr == null — MenuAllergenTrust honours a manual
    // "utan X" override even on an untagged recipe, so a human-marked-free
    // untagged recipe must still qualify (it was previously wrongly excluded).
    // Untagged with no override reads UNKNOWN → not free → excluded (safe).
    if (!_allTrustedFree(r, c.allergenFree, c.dietaryFree)) return false;

    // The remaining checks read the auto tagResult; an untagged recipe can't
    // satisfy a positive tag/cuisine requirement, but a pure allergen/dietary/
    // time constraint it now can.
    if (c.requiredTags.isNotEmpty &&
        (tr == null || !tr.hasAllTags(c.requiredTags))) {
      return false;
    }
    // An untagged recipe can't be proven free of an excluded tag, so exclude
    // it from a "utan X" slot (conservative — a "no grytor" slot must not
    // surface a recipe that might be a gryta). Only allergen/dietary/time
    // constraints newly match untagged recipes (via a manual override); the
    // tag-based checks stay strict as they were before BUT-1466.
    if (c.excludedTags.isNotEmpty &&
        (tr == null || c.excludedTags.any(tr.tags.contains))) {
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
