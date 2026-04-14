import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
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

  /// Session cache: recipe ID → normalized ingredient IDs.
  /// Avoids re-normalizing the same legacy recipe across multiple searches.
  final Map<String, Set<String>> _normalizationCache = {};

  IngredientMatchService({
    required IngredientLookupService lookupService,
    required IngredientRepository ingredientRepository,
  })  : _lookupService = lookupService,
        _ingredientRepository = ingredientRepository;

  @override
  String get serviceName => 'IngredientMatchService';

  /// Core matching: intersect [selectedIngredientIds] with each recipe's
  /// `ingredientsNormalized`. Recipes without normalized data are skipped.
  /// Returns results sorted by match% descending (zero-overlap excluded).
  Future<List<IngredientMatchResult>> matchRecipes({
    required Set<String> selectedIngredientIds,
    required List<Recipe> recipes,
  }) =>
      _matchWithResolver(
        selectedIngredientIds: selectedIngredientIds,
        recipes: recipes,
        resolveNormalized: (recipe) async {
          final n = recipe.core.ingredientsNormalized;
          return (n != null && n.isNotEmpty) ? n.toSet() : null;
        },
        operationName: 'matchRecipes',
      );

  /// Like [matchRecipes] but handles legacy recipes (null ingredientsNormalized)
  /// by normalizing their raw ingredients in-memory via [IngredientLookupService].
  /// Results are cached per recipe ID for the session lifetime.
  Future<List<IngredientMatchResult>> matchRecipesWithNormalization({
    required Set<String> selectedIngredientIds,
    required List<Recipe> recipes,
  }) =>
      _matchWithResolver(
        selectedIngredientIds: selectedIngredientIds,
        recipes: recipes,
        resolveNormalized: (recipe) async {
          final n = recipe.core.ingredientsNormalized;
          if (n != null && n.isNotEmpty) return n.toSet();
          return _lazyNormalize(recipe);
        },
        operationName: 'matchRecipesWithNormalization',
      );

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

          final overlap =
              normalizedSet.intersection(selectedIngredientIds).length;
          if (overlap == 0) continue;

          matches.add(IngredientMatchResult(
            recipe: recipe,
            matchPercent: overlap / normalizedSet.length,
            matchedCount: overlap,
            totalCount: normalizedSet.length,
            missingIngredientIds: normalizedSet
                .difference(selectedIngredientIds)
                .toList(growable: false),
          ));
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
      List<String> ingredientIds) async {
    final names = <String, String>{};
    for (final id in ingredientIds) {
      final data = await _ingredientRepository.getById(id);
      if (data != null) {
        names[id] = data.swedish;
        continue;
      }
      // ID might be an English name (from legacy normalization) — try lookup
      final byEnglish =
          await _ingredientRepository.findByName(id, language: 'en');
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

  /// Normalizes a legacy recipe's raw ingredients in-memory and caches the
  /// result. Returns null if the recipe has no raw ingredients.
  /// Includes both taxonomy-matched IDs and unmatched normalized strings
  /// so that match % reflects the full ingredient list.
  Future<Set<String>?> _lazyNormalize(Recipe recipe) async {
    final cached = _normalizationCache[recipe.id];
    if (cached != null) return cached;

    final rawIngredients = recipe.core.ingredients;
    if (rawIngredients.isEmpty) return null;

    try {
      final lookupResult = await _lookupService.lookupFromRaw(rawIngredients);
      final ids = <String>{
        ...lookupResult.matched.map((m) => m.id),
        // Include unmatched normalized strings so match % is accurate
        ...lookupResult.unmatched,
      };
      if (ids.isNotEmpty) {
        _normalizationCache[recipe.id] = ids;
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
