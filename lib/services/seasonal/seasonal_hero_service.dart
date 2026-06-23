import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';

/// Loads monthly seasonal-cooking data (BUT-409) and matches it against the
/// user's own recipes.
///
/// Data lives in `assets/seasonal/{year}.json` (currently only 2026).
/// Loading happens lazily on first use and the parsed map is cached for the
/// app's lifetime — the asset never changes at runtime.
///
/// Matching is substring-based against `Recipe.ingredients` so users with
/// "sparrissoppa" get matched for the April "sparris" ingredient. This is
/// good enough for V1; a taxonomy/normalisation pass can replace it later
/// without touching callers.
class SeasonalHeroService extends BaseService {
  SeasonalHeroService({String assetPath = _defaultAssetPath})
    : _assetPath = assetPath;

  static const String _defaultAssetPath = 'assets/seasonal/2026.json';

  final String _assetPath;
  Map<int, SeasonalMonth>? _monthsCache;
  bool _loadAttempted = false;

  @override
  String get serviceName => 'SeasonalHeroService';

  /// Returns the [SeasonalMonth] for the current (or provided) date, or
  /// `null` if the data couldn't be loaded or the month isn't curated.
  Future<SeasonalMonth?> getCurrentMonth({DateTime? now}) async {
    await _ensureLoaded();
    final month = (now ?? clock.now()).month;
    return _monthsCache?[month];
  }

  /// Returns the subset of [recipes] whose ingredients substring-match at
  /// least one of [month.ingredients]. Case-insensitive. Pure function —
  /// safe to call synchronously once the month is resolved.
  List<Recipe> matchUserRecipes(SeasonalMonth month, List<Recipe> recipes) {
    if (month.ingredients.isEmpty || recipes.isEmpty) return const [];
    final needles = month.ingredients; // already lowercase per fromJson
    return recipes
        .where((r) => recipeMatchesAnyNeedle(r, needles))
        .toList(growable: false);
  }

  /// Shared predicate used by both [matchUserRecipes] and
  /// `RecipeQueryViewModel.applySeasonalFilter` so the two paths can't drift.
  /// [lowercaseNeedles] must already be lowercased.
  static bool recipeMatchesAnyNeedle(
    Recipe recipe,
    List<String> lowercaseNeedles,
  ) {
    for (final ingredient in recipe.ingredients) {
      final haystack = ingredient.toLowerCase();
      for (final needle in lowercaseNeedles) {
        if (haystack.contains(needle)) return true;
      }
    }
    return false;
  }

  /// Convenience: returns `(month, matchingRecipes)` when at least two user
  /// recipes match, otherwise `null`. Mirrors the "hide when <2" UX rule so
  /// the view layer stays dumb.
  Future<SeasonalHeroResult?> resolveHero(
    List<Recipe> userRecipes, {
    DateTime? now,
    int minMatches = 2,
  }) async {
    final month = await getCurrentMonth(now: now);
    if (month == null) return null;
    final matches = matchUserRecipes(month, userRecipes);
    if (matches.length < minMatches) return null;
    return SeasonalHeroResult(month: month, matchingRecipes: matches);
  }

  Future<void> _ensureLoaded() async {
    if (_monthsCache != null || _loadAttempted) return;
    _loadAttempted = true;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Seasonal JSON: root must be an object');
      }
      final months = decoded['months'];
      if (months is! List) {
        throw const FormatException('Seasonal JSON: "months" must be a list');
      }
      final parsed = <int, SeasonalMonth>{};
      for (final entry in months) {
        if (entry is! Map<String, dynamic>) continue;
        final m = SeasonalMonth.fromJson(entry);
        parsed[m.monthIndex] = m;
      }
      _monthsCache = parsed;
    } catch (e, stack) {
      // Swallow — UI degrades to "no hero". Log so we notice regressions.
      AppLogger.warning(
        '[SeasonalHeroService] failed to load $_assetPath: $e\n$stack',
      );
      _monthsCache = const {};
    }
  }

  /// Test seam — lets widget/service tests inject canned data without
  /// hitting rootBundle.
  void debugInjectMonths(Map<int, SeasonalMonth> months) {
    _monthsCache = Map.unmodifiable(months);
    _loadAttempted = true;
  }
}

/// Resolved state for the seasonal header: the active month plus the user
/// recipes that match it.
class SeasonalHeroResult {
  const SeasonalHeroResult({
    required this.month,
    required this.matchingRecipes,
  });

  final SeasonalMonth month;
  final List<Recipe> matchingRecipes;

  int get matchCount => matchingRecipes.length;
}
