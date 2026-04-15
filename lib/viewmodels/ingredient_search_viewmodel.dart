import 'dart:async';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for ingredient-set search ("Sök med ingredienser").
///
/// Users select ingredients via autocomplete, then get recipes ranked
/// by how many of those ingredients each recipe uses.
class IngredientSearchViewModel extends BaseViewModel {
  final IngredientMatchService _matchService;
  final IngredientRepository _ingredientRepository;
  final UnifiedRecipeService _recipeService;

  IngredientSearchViewModel({
    required IngredientMatchService matchService,
    required IngredientRepository ingredientRepository,
    required UnifiedRecipeService recipeService,
  })  : _matchService = matchService,
        _ingredientRepository = ingredientRepository,
        _recipeService = recipeService;

  // -- Selected ingredients (chips) --

  final List<IngredientData> _selectedIngredients = [];
  List<IngredientData> get selectedIngredients =>
      List.unmodifiable(_selectedIngredients);

  void addIngredient(IngredientData ingredient) {
    if (_selectedIngredients.any((i) => i.id == ingredient.id)) return;
    _selectedIngredients.add(ingredient);
    _autocompleteResults = [];
    _lastSearchQuery = null;
    notifyListeners();
  }

  void removeIngredient(String ingredientId) {
    _selectedIngredients.removeWhere((i) => i.id == ingredientId);
    notifyListeners();
  }

  void clearIngredients() {
    _selectedIngredients.clear();
    _matchResults = [];
    _hasSearched = false;
    _resolvedNames.clear();
    notifyListeners();
  }

  // -- Autocomplete --

  List<IngredientData> _autocompleteResults = [];
  List<IngredientData> get autocompleteResults => _autocompleteResults;

  Timer? _searchDebouncer;
  String? _lastSearchQuery;

  void searchIngredient(String query) {
    final trimmed = query.trim();
    if (trimmed == _lastSearchQuery) return;
    _lastSearchQuery = trimmed;

    _searchDebouncer?.cancel();
    if (trimmed.isEmpty) {
      _autocompleteResults = [];
      if (!isDisposed) notifyListeners();
      return;
    }
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results =
            await _ingredientRepository.searchIngredients(trimmed, limit: 10);
        if (isDisposed) return;
        // Filter out already-selected ingredients
        final selectedIds = _selectedIngredients.map((i) => i.id).toSet();
        _autocompleteResults =
            results.where((r) => !selectedIds.contains(r.id)).toList();
        notifyListeners();
      } catch (e) {
        // Autocomplete failures are non-fatal but logged for debugging
        if (!isDisposed) {
          _autocompleteResults = [];
          notifyListeners();
        }
      }
    });
  }

  // -- Match results --

  List<IngredientMatchResult> _matchResults = [];
  List<IngredientMatchResult> get matchResults => _matchResults;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  /// Cached display names for missing ingredient IDs.
  final Map<String, String> _resolvedNames = {};
  Map<String, String> get resolvedNames => _resolvedNames;

  /// Returns display name for an ingredient ID, or the ID as fallback.
  String ingredientName(String id) => _resolvedNames[id] ?? id;

  // -- Collaborative recipe cache --

  List<Recipe>? _cachedCollaborativeRecipes;

  /// Merges personal + collaborative recipes, deduplicating by ID.
  /// On collaborative fetch failure, returns personal-only (next search retries).
  Future<List<Recipe>> _getAllSearchableRecipes() async {
    final personal = _recipeService.recipes;
    final personalIds = personal.map((r) => r.id).toSet();

    if (_cachedCollaborativeRecipes == null) {
      try {
        _cachedCollaborativeRecipes =
            await _recipeService.social.getCollaborativeRecipes();
      } catch (_) {
        // Transient failure — return personal-only, next search retries
        return personal;
      }
    }

    final collaborative = _cachedCollaborativeRecipes!
        .where((r) => !personalIds.contains(r.id))
        .toList();

    return [...personal, ...collaborative];
  }

  /// Force re-fetch collaborative recipes on next search.
  void refreshCollaborative() {
    _cachedCollaborativeRecipes = null;
  }

  Future<void> performSearch() async {
    if (_selectedIngredients.isEmpty) return;

    await executeAsyncVoid(
      () async {
        final selectedIds = _selectedIngredients.map((i) => i.id).toSet();
        final allRecipes = await _getAllSearchableRecipes();

        _matchResults = await _matchService.matchRecipesWithNormalization(
          selectedIngredientIds: selectedIds,
          recipes: allRecipes,
        );
        _hasSearched = true;

        // Resolve display names for missing ingredients across all results
        final allMissingIds = <String>{};
        for (final r in _matchResults) {
          allMissingIds.addAll(r.missingIngredientIds);
        }
        // Only resolve IDs we haven't cached yet
        final idsToResolve =
            allMissingIds.where((id) => !_resolvedNames.containsKey(id));
        if (idsToResolve.isNotEmpty) {
          final names =
              await _matchService.resolveIngredientNames(idsToResolve.toList());
          _resolvedNames.addAll(names);
        }
      },
      errorPrefix: 'Kunde inte söka recept',
    );
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    super.dispose();
  }
}
