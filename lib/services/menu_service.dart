/// Menu generation service using Swedish natural language parsing.
///
/// Parses requests like "3 middagar, 2 luncher" and randomly selects
/// matching recipes from the user's collection. NOT AI/LLM-based.
/// Supports weighted selection (recency, season boost, cuisine diversity).
library;

import 'dart:math';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

/// Generates menus by parsing Swedish meal requests and randomly selecting recipes.
///
/// Example: "tre frukoster och två middagar" → 3 breakfast + 2 dinner recipes
class MenuService extends BaseService {
  MenuService();

  @override
  String get serviceName => 'MenuService';

  /// Parses Swedish meal request and returns randomly selected recipes.
  ///
  /// Supports: "3 middagar", "tre frukoster och två luncher", etc.
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes,
  ) async {
    return await executeServiceOperation(
          () async {
            return _generateMenuFromPromptInternal(input, allRecipes);
          },
          operationName: 'Generate menu from prompt',
          defaultValue: <String, List<Recipe>>{},
          requiresAuth: false,
        ) ??
        <String, List<Recipe>>{};
  }

  Map<String, List<Recipe>> _generateMenuFromPromptInternal(
    String input,
    List<Recipe> allRecipes,
  ) {
    if (input.trim().isEmpty) return {};

    final types = <String>{for (var r in allRecipes) r.mealType};

    // Swedish number words
    final word2num = <String, int>{
      'en': 1,
      'ett': 1,
      'två': 2,
      'tre': 3,
      'fyra': 4,
      'fem': 5,
      'sex': 6,
      'sju': 7,
      'åtta': 8,
      'nio': 9,
      'tio': 10,
    };

    int? parseNumber(String s) => int.tryParse(s) ?? word2num[s];

    final counts = <String, int>{};
    final lowerInput = input.toLowerCase();

    // Split on explicit separators: comma, 'och', '&', semicolon
    final explicitParts = lowerInput.split(RegExp(r'[,&;]| och | & '));

    if (explicitParts.length > 1) {
      for (var part in explicitParts) {
        part = part.trim();
        if (part.isEmpty) continue;
        _parseMealPart(part, counts, types, parseNumber);
      }
    } else {
      final singlePart = explicitParts[0].trim();
      if (singlePart.isNotEmpty) {
        final patterns = _extractMealPatterns(singlePart);
        if (patterns.length > 1) {
          for (final pattern in patterns) {
            _parseMealPart(pattern, counts, types, parseNumber);
          }
        } else {
          _parseMealPart(singlePart, counts, types, parseNumber);
        }
      }
    }

    if (counts.isEmpty) return {};

    final rand = Random();
    final result = <String, List<Recipe>>{};
    final usedIds = <String>{};
    final seasonTag = SeasonUtils.currentSeasonTag();

    counts.forEach((mealType, count) {
      final bucket = allRecipes
          .where((r) =>
              r.mealType.toLowerCase() == mealType.toLowerCase() &&
              !usedIds.contains(r.id))
          .toList();

      final selected = _weightedSelect(
        bucket,
        count,
        rand,
        seasonTag: seasonTag,
      );

      // Enforce cuisine diversity: max 2 recipes per cuisine
      final diversified = _enforceCuisineDiversity(selected, bucket, rand,
          usedIds: usedIds, seasonTag: seasonTag);

      for (final recipe in diversified) {
        usedIds.add(recipe.id);
      }
      result[mealType] = diversified;
    });

    return result;
  }

  /// Extracts quantity and meal type from a single part (e.g., "3 middagar").
  void _parseMealPart(
    String part,
    Map<String, int> counts,
    Set<String> types,
    int? Function(String) parseNumber,
  ) {
    part = part.trim();
    if (part.isEmpty) return;

    final match = RegExp(r'^(\d+|[a-zåäö]+)').firstMatch(part);
    if (match == null) return;

    final raw = match.group(1)!;
    final num = parseNumber(raw) ?? 0;
    if (num <= 0) return;

    final keyword = part.substring(match.end).trim();
    if (keyword.isEmpty) return;

    final type = _detectType(keyword, types);
    if (type != null) {
      counts[type] = (counts[type] ?? 0) + num;
    }
  }

  /// Finds "quantity + meal type" patterns in space-separated text.
  List<String> _extractMealPatterns(String input) {
    final patterns = <String>[];
    final words = input.split(RegExp(r'\s+'));

    for (int i = 0; i < words.length - 1; i++) {
      final currentWord = words[i];
      final nextWord = words[i + 1];

      final isNumber = RegExp(
        r'^(\d+|en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio)$',
      ).hasMatch(currentWord);

      final isMealType = RegExp(
        r'^(frukost|lunch|middag|dessert|mellanmål|fika)',
        caseSensitive: false,
      ).hasMatch(nextWord);

      if (isNumber && isMealType) {
        patterns.add('$currentWord $nextWord');
      }
    }

    return patterns;
  }

  // Delegate to CuisineConfig.allTags for cuisine tag lookup

  /// Calculates recipe weight based on recency, with optional season boost.
  ///
  /// Weight = daysSinceLastCooked (capped at 90). Never-cooked recipes get 90.
  /// Season boost: 1.5x for recipes tagged with the current season.
  static double _recipeWeight(Recipe recipe, {required String seasonTag}) {
    const maxDays = 90;
    final lastCooked = recipe.lastCookedAt;
    final daysSince = lastCooked == null
        ? maxDays
        : DateTime.now().difference(lastCooked).inDays.clamp(0, maxDays);

    double weight = daysSince.toDouble();
    if (weight < 1) weight = 1; // Minimum weight to participate

    // Season boost: 1.5x for seasonal recipes
    final tags = recipe.tagResult?.tags;
    if (tags != null && tags.contains(seasonTag)) {
      weight *= 1.5;
    }

    return weight;
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
  }) {
    if (pool.isEmpty) return [];
    final available = List<Recipe>.from(pool);
    final selected = <Recipe>[];

    for (var i = 0; i < min(count, pool.length); i++) {
      if (available.isEmpty) break;

      final weights =
          available.map((r) => _recipeWeight(r, seasonTag: seasonTag)).toList();
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

      final weight = _recipeWeight(recipe, seasonTag: seasonTag);
      if (weight > bestWeight) {
        bestWeight = weight;
        best = recipe;
      }
    }

    return best;
  }

  /// Normalizes plural forms and matches against available meal types.
  String? _detectType(String input, Set<String> available) {
    // Explicit Swedish plural-to-singular map (avoids over-stripping with regex)
    const pluralMap = {
      'middagar': 'middag',
      'luncher': 'lunch',
      'frukostar': 'frukost',
      'frukoster': 'frukost',
      'desserter': 'dessert',
      'efterrätter': 'efterrätt',
      'mellanmål': 'mellanmål',
      'fikor': 'fika',
    };

    final norm = input.replaceAll(RegExp(r'\d+'), '').trim();
    final singular = pluralMap[norm] ?? norm;

    for (var type in available) {
      final low = type.toLowerCase();
      if (low == singular || low.startsWith(singular)) return type;
    }
    return null;
  }
}
