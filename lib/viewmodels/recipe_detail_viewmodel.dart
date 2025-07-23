// lib/viewmodels/recipe_detail_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe_unified.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/analytics_service.dart';
import '../core/injection.dart';

/// ViewModel för RecipeDetailView
/// Hanterar visning och borttagning av recept
/// UPPDATERAD för flera bilder
class RecipeDetailViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final AnalyticsService _analyticsService;

  Recipe _recipe;
  bool _isDeleting = false;
  String? _error;

  RecipeDetailViewModel({
    required Recipe recipe,
    UnifiedRecipeService? recipeService,
    AnalyticsService? analyticsService,
  }) : _recipe = recipe,
       _recipeService = recipeService ?? sl<UnifiedRecipeService>(),
       _analyticsService = analyticsService ?? sl<AnalyticsService>() {
    // Lyssna på UnifiedRecipeService för uppdateringar
    _recipeService.addListener(_onRecipeServiceUpdate);
  }

  @override
  void dispose() {
    _recipeService.removeListener(_onRecipeServiceUpdate);
    super.dispose();
  }

  void _onRecipeServiceUpdate() {
    // Uppdatera vårt recept om det har ändrats i service
    final updatedRecipe = _recipeService.getRecipeById(_recipe.id);
    if (updatedRecipe != null && updatedRecipe.updatedAt != _recipe.updatedAt) {
      _recipe = updatedRecipe;
      notifyListeners();
    }
  }

  // Getters
  Recipe get recipe => _recipe;
  bool get isDeleting => _isDeleting;
  String? get error => _error;
  bool get hasError => _error != null;

  // Convenience getters för UI
  bool get hasImages => _recipe.hasImages; // NY!
  bool get hasMultipleImages => _recipe.imageUrls.length > 1; // NY!
  String get portionsDisplay => _recipe.portions?.toString() ?? '–';
  String get timeDisplay => _recipe.timeMinutes?.toString() ?? '–';
  bool get hasRating => _recipe.rating != null;
  String get ratingDisplay => _recipe.rating?.toStringAsFixed(1) ?? '–';
  bool get hasTags => _recipe.tags != null && _recipe.tags!.isNotEmpty;

  /// Ta bort receptet
  Future<bool> deleteRecipe() async {
    _setDeleting(true);
    _error = null;

    try {
      final success = await _recipeService.deleteRecipe(_recipe.id);

      if (success) {
        // Logga analytics för recipe deletion
        await _analyticsService.logRecipeDeleted(
          recipeId: _recipe.id,
          recipeTitle: _recipe.title,
          mealType: _recipe.mealType,
          isPersonal: _recipe.isPersonal,
          createdAt: _recipe.createdAt,
        );

        return true;
      } else {
        _error = _recipeService.error ?? 'Kunde inte ta bort recept';
        return false;
      }
    } catch (e) {
      _error = 'Kunde inte ta bort recept: ${e.toString()}';
      return false;
    } finally {
      _setDeleting(false);
    }
  }

  /// Markera receptet som tillagat
  Future<bool> markAsCooked() async {
    try {
      // Uppdatera receptet med ny lastCookedAt
      final updatedRecipe = _recipe.copyWith(lastCookedAt: DateTime.now());

      final success = await _recipeService.updateRecipe(updatedRecipe);

      if (success) {
        _recipe = updatedRecipe;
        notifyListeners();

        // Logga analytics med rätt metod
        await _analyticsService.logRecipeCooked(
          recipeId: _recipe.id,
          recipeTitle: _recipe.title,
          mealType: _recipe.mealType,
          isFirstTime: _recipe.lastCookedAt == null,
        );

        return true;
      } else {
        _error = 'Kunde inte uppdatera recept';
        return false;
      }
    } catch (e) {
      _error = 'Kunde inte uppdatera recept: ${e.toString()}';
      return false;
    }
  }

  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
