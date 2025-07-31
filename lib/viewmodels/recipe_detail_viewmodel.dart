// lib/viewmodels/recipe_detail_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// ViewModel för RecipeDetailView
/// Hanterar visning och borttagning av recept
/// UPPDATERAD för flera bilder
class RecipeDetailViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final AnalyticsService _analyticsService;

  Recipe _recipe;
  bool _isDeleting = false;

  RecipeDetailViewModel({
    required Recipe recipe,
    UnifiedRecipeService? recipeService,
    AnalyticsService? analyticsService,
  }) : _recipe = recipe,
       _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
       _analyticsService = analyticsService ?? ServiceLocator.get<AnalyticsService>() {
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
  String? get error => null; // No error state needed for now
  bool get hasError => false; // No error state needed for now

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
    
    try {
      final result = await safeExecute(
        () async {
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
            final errorMessage = _recipeService.error ?? 'Kunde inte ta bort recept';
            throw Exception(errorMessage);
          }
        },
        operationName: 'Delete recipe',
      );
      
      return result ?? false;
    } finally {
      _setDeleting(false);
    }
  }

  /// Markera receptet som tillagat
  Future<bool> markAsCooked() async {
    return await safeExecute(
      () async {
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
          throw Exception('Kunde inte uppdatera recept');
        }
      },
      operationName: 'Mark as cooked',
    ) ?? false;
  }

  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }

  void clearError() {
    // Clear any error state if needed
    notifyListeners();
  }
}
