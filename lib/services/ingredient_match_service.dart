import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// Result of matching a recipe against a set of selected ingredients.
class IngredientMatchResult {
  final Recipe recipe;

  /// Fraction of the recipe's normalized ingredients present in the search set.
  final double matchPercent;

  /// How many of the recipe's ingredients were in the search set.
  final int matchedCount;

  /// Total normalized ingredients on this recipe.
  final int totalCount;

  /// Taxonomy IDs of ingredients the recipe needs but the user didn't select.
  final List<String> missingIngredientIds;

  const IngredientMatchResult({
    required this.recipe,
    required this.matchPercent,
    required this.matchedCount,
    required this.totalCount,
    required this.missingIngredientIds,
  });
}

/// Scores recipes by ingredient overlap with a user-supplied ingredient set.
///
/// Extracted from PantryService.getMatchingRecipes to allow ad-hoc ingredient
/// search without requiring pantry items. PantryService delegates here.
class IngredientMatchService extends BaseService {
  final IngredientLookupService _lookupService;
  final IngredientRepository _ingredientRepository;

  /// Session cache: recipe ID and rows → registry ingredient IDs.
  final Map<String, Set<String>> _normalizationCache = {};

  IngredientMatchService({
    required IngredientLookupService lookupService,
    required IngredientRepository ingredientRepository,
  }) : _lookupService = lookupService,
       _ingredientRepository = ingredientRepository;

  @override
  String get serviceName => 'IngredientMatchService';

  /// Scores [recipes] by the share of their ingredients in
  /// [selectedIngredientIds]. Returns results sorted by match% descending
  /// (zero-overlap excluded).
  ///
  /// The ids come from looking the raw ingredient rows up in the registry.
  /// `ingredientsNormalized` holds cleaned Swedish names ("potatis"), not
  /// registry ids ("potato"), so it can never intersect the selection.
  Future<List<IngredientMatchResult>> matchRecipes({
    required Set<String> selectedIngredientIds,
    required List<Recipe> recipes,
  }) => _matchWithResolver(
    selectedIngredientIds: selectedIngredientIds,
    recipes: recipes,
    resolveNormalized: _lookupIds,
    operationName: 'matchRecipes',
  );

  /// The ingredient search: like [matchRecipes], but a selected ingredient
  /// also matches its specific forms ([expandToSpecificForms]), so "kyckling"
  /// finds a recipe with "kycklingfilé". The pantry keeps [matchRecipes],
  /// where having one is not having the other.
  Future<List<IngredientMatchResult>> matchRecipesWithNormalization({
    required Set<String> selectedIngredientIds,
    required List<Recipe> recipes,
  }) async => _matchWithResolver(
    selectedIngredientIds: await expandToSpecificForms(selectedIngredientIds),
    recipes: recipes,
    resolveNormalized: _lookupIds,
    operationName: 'matchRecipesWithNormalization',
  );

  /// [ids] plus every registry entry that is a specific form of one of them:
  /// same group, and a word of its Swedish name starts with the selected
  /// one's ("kycklingfilé", "hel kyckling" for "kyckling"). The group keeps
  /// "kycklingbuljong" out of "kyckling", and the word start keeps
  /// "sötpotatis" out of "potatis". If the registry cannot be read, [ids]
  /// is returned as it is.
  Future<Set<String>> expandToSpecificForms(Set<String> ids) async {
    if (ids.isEmpty) return ids;
    final List<IngredientData> all;
    try {
      all = await _ingredientRepository.getAll();
    } catch (e) {
      AppLogger.warning('Ingredient registry unavailable for expansion: $e');
      return ids;
    }
    final selected = all.where((i) => ids.contains(i.id)).toList();
    final expanded = {...ids};
    for (final base in selected) {
      final name = base.swedish.trim().toLowerCase();
      if (name.isEmpty) continue;
      for (final other in all) {
        if (other.group != base.group) continue;
        final otherName = other.swedish.trim().toLowerCase();
        if (otherName.startsWith(name) || otherName.contains(' $name')) {
          expanded.add(other.id);
        }
      }
    }
    return expanded;
  }

  /// Match keys for ingredients the user named without picking a registry
  /// entry (a pantry row typed by hand). They go through the same lookup as
  /// a recipe's rows, so "lök" here meets "1 hackad lök" there, and a name
  /// the registry lacks still meets the same unmatched name in a recipe.
  Future<Set<String>> keysForNames(List<String> names) async {
    if (names.isEmpty) return const {};
    try {
      final lookupResult = await _lookupService.lookupFromRaw(names);
      return {
        ...lookupResult.matched.map((m) => m.id),
        ...lookupResult.unmatched,
      };
    } catch (e) {
      AppLogger.warning('Failed to look up ingredient names: $e');
      return const {};
    }
  }

  Future<List<IngredientMatchResult>> _matchWithResolver({
    required Set<String> selectedIngredientIds,
    required List<Recipe> recipes,
    required Future<Set<String>?> Function(Recipe) resolveNormalized,
    required String operationName,
  }) async {
    final result = await executeServiceOperation<List<IngredientMatchResult>>(
      () async {
        if (selectedIngredientIds.isEmpty) return const [];

        final matches = <IngredientMatchResult>[];
        for (final recipe in recipes) {
          final normalizedSet = await resolveNormalized(recipe);
          if (normalizedSet == null || normalizedSet.isEmpty) continue;

          final overlap = normalizedSet
              .intersection(selectedIngredientIds)
              .length;
          if (overlap == 0) continue;

          matches.add(
            IngredientMatchResult(
              recipe: recipe,
              matchPercent: overlap / normalizedSet.length,
              matchedCount: overlap,
              totalCount: normalizedSet.length,
              missingIngredientIds: normalizedSet
                  .difference(selectedIngredientIds)
                  .toList(growable: false),
            ),
          );
        }

        matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
        return matches;
      },
      operationName: operationName,
      defaultValue: const [],
    );
    return result ?? const [];
  }

  /// Resolves Swedish display names for ingredient taxonomy IDs.
  /// Falls back through: getById → findByName(en) → findByName(sv) → raw ID.
  /// All repository calls are in-memory cache lookups (no Firestore round-trips).
  Future<Map<String, String>> resolveIngredientNames(
    List<String> ingredientIds,
  ) async {
    final names = <String, String>{};
    for (final id in ingredientIds) {
      final data = await _ingredientRepository.getById(id);
      if (data != null) {
        names[id] = data.swedish;
        continue;
      }
      // ID might be an English name (from legacy normalization) — try lookup
      final byEnglish = await _ingredientRepository.findByName(
        id,
        language: 'en',
      );
      if (byEnglish != null) {
        names[id] = byEnglish.swedish;
        continue;
      }
      final bySwedish = await _ingredientRepository.findByName(id);
      if (bySwedish != null) {
        names[id] = bySwedish.swedish;
        continue;
      }
      // Last resort: clean up the raw ID for display
      names[id] = id.replaceAll('-', ' ');
    }
    return names;
  }

  /// Looks a recipe's raw ingredients up in the registry and caches the
  /// result. Returns null if the recipe has no raw ingredients.
  /// Includes both taxonomy-matched IDs and unmatched normalized strings
  /// so that match % reflects the full ingredient list.
  Future<Set<String>?> _lookupIds(Recipe recipe) async {
    final rawIngredients = recipe.core.ingredients;
    if (rawIngredients.isEmpty) return null;

    // Keyed on the rows too, so an edited recipe is looked up again.
    final cacheKey = '${recipe.id}\x00${Object.hashAll(rawIngredients)}';
    final cached = _normalizationCache[cacheKey];
    if (cached != null) return cached;

    try {
      final lookupResult = await _lookupService.lookupFromRaw(rawIngredients);
      final ids = <String>{
        ...lookupResult.matched.map((m) => m.id),
        // Include unmatched normalized strings so match % is accurate
        ...lookupResult.unmatched,
      };
      if (ids.isNotEmpty) {
        _normalizationCache[cacheKey] = ids;
      }
      return ids.isEmpty ? null : ids;
    } catch (e) {
      AppLogger.warning(
        'Failed to normalize ingredients for recipe ${recipe.id}: $e',
      );
      return null;
    }
  }

  @override
  Future<void> onDispose() async {
    _normalizationCache.clear();
  }
}
