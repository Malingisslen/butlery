// lib/viewmodels/recipe_detail_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../core/injection.dart';

/// ViewModel för RecipeDetailView
class RecipeDetailViewModel extends ChangeNotifier {
  final RecipeService _recipeService;

  // State
  Recipe _recipe;
  bool _isDeleting = false;
  String? _error;

  RecipeDetailViewModel({required Recipe recipe, RecipeService? recipeService})
    : _recipe = recipe,
      _recipeService = recipeService ?? sl<RecipeService>() {
    // Lyssna på ändringar från RecipeService
    _recipeService.addListener(_onRecipesChanged);
  }

  // ===== GETTERS =====

  Recipe get recipe => _recipe;
  bool get isDeleting => _isDeleting;
  String? get error => _error;
  bool get hasError => _error != null;

  // Formaterade värden för visning
  String get portionsDisplay => _recipe.portions?.toString() ?? '?';
  String get timeDisplay => _recipe.timeMinutes?.toString() ?? '?';
  String get ratingDisplay => _recipe.rating?.toStringAsFixed(1) ?? '-';
  bool get hasRating => _recipe.rating != null;
  bool get hasImage => _recipe.imageUrl != null && _recipe.imageUrl!.isNotEmpty;
  bool get hasTags => _recipe.tags != null && _recipe.tags!.isNotEmpty;

  // ===== ACTIONS =====

  /// Ta bort recept
  Future<bool> deleteRecipe() async {
    _setDeleting(true);

    try {
      final result = await _recipeService.deleteRecipe(_recipe.id);

      if (result.isSuccess) {
        _error = null;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Kunde inte ta bort recept: ${e.toString()}');
      return false;
    } finally {
      _setDeleting(false);
    }
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  void _onRecipesChanged() {
    // Uppdatera lokalt recept om det har ändrats i service
    final updatedRecipe = _recipeService.recipes.firstWhere(
      (r) => r.id == _recipe.id,
      orElse: () => _recipe,
    );

    if (updatedRecipe != _recipe) {
      _recipe = updatedRecipe;
      notifyListeners();
    }
  }

  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}
