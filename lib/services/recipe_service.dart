// lib/services/recipe_service.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../core/error/failures.dart';
import '../core/error/error_handler.dart';
import '../core/extensions/future_extensions.dart';

/// Resultat av en RecipeService operation
class RecipeOperationResult {
  final bool isSuccess;
  final String message;
  final List<String>? warnings;

  const RecipeOperationResult({
    required this.isSuccess,
    required this.message,
    this.warnings,
  });

  factory RecipeOperationResult.success(
    String message, {
    List<String>? warnings,
  }) {
    return RecipeOperationResult(
      isSuccess: true,
      message: message,
      warnings: warnings,
    );
  }

  factory RecipeOperationResult.error(String message) {
    return RecipeOperationResult(isSuccess: false, message: message);
  }
}

/// Singleton service för att hantera recept
/// Använder ChangeNotifier för reaktiv UI
class RecipeService extends ChangeNotifier {
  static RecipeService? _instance;

  // Private constructor för singleton
  RecipeService._internal();

  // Factory constructor som returnerar samma instans
  factory RecipeService() {
    _instance ??= RecipeService._internal();
    return _instance!;
  }

  // ===== STATE MANAGEMENT =====

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _lastError;
  bool _isInitialized = false;

  // ===== GETTERS =====

  /// Alla recept (read-only kopia)
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  /// Om service laddar just nu
  bool get isLoading => _isLoading;

  /// Senaste fel (null om inget fel)
  String? get lastError => _lastError;

  /// Om service har ett aktivt fel
  bool get hasError => _lastError != null;

  /// Om service är initialiserad
  bool get isInitialized => _isInitialized;

  // ===== INITIALIZATION =====

  /// Initialisera service - ladda data från storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    clearError();

    try {
      // Simulera loading från database/storage med timeout
      await Future.delayed(
        const Duration(milliseconds: 300),
      ).withShortTimeout();

      // ✅ ANVÄND DUMMY_RECIPES SOM STANDARDRECEPT
      _recipes = List.from(dummyRecipesNotifier.value);

      _isInitialized = true;
      debugPrint(
        '✅ RecipeService: Initialiserad med ${_recipes.length} standardrecept',
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      debugPrint('❌ RecipeService: Initialiseringsfel: ${failure.message}');
    } finally {
      _setLoading(false);
    }
  }

  // ===== CRUD OPERATIONS =====

  /// Lägg till ett nytt recept
  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    _setLoading(true);
    clearError();

    try {
      // Kontrollera att receptet inte redan finns
      if (_recipes.any((r) => r.id == recipe.id)) {
        return RecipeOperationResult.error(
          'Recept med ID ${recipe.id} finns redan',
        );
      }

      // Simulera async operation (Firebase senare) med timeout
      await Future.delayed(
        const Duration(milliseconds: 200),
      ).withShortTimeout();

      _recipes.add(recipe);
      notifyListeners();

      debugPrint('✅ RecipeService: Lade till recept "${recipe.title}"');
      return RecipeOperationResult.success('Recept "${recipe.title}" sparat');
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Lägg till flera recept samtidigt (för arkiv-import)
  Future<RecipeOperationResult> addMultipleRecipes(List<Recipe> recipes) async {
    _setLoading(true);
    clearError();

    try {
      // Längre timeout för bulk operations
      await Future.delayed(
        const Duration(milliseconds: 500),
      ).withTimeout(duration: const Duration(seconds: 10));

      final warnings = <String>[];
      int addedCount = 0;

      for (final recipe in recipes) {
        if (_recipes.any((r) => r.id == recipe.id)) {
          warnings.add('Recept "${recipe.title}" finns redan');
          continue;
        }

        _recipes.add(recipe);
        addedCount++;
      }

      notifyListeners();

      final message =
          addedCount == recipes.length
              ? 'Alla $addedCount recept importerade från arkiv'
              : '$addedCount av ${recipes.length} recept importerade från arkiv';

      debugPrint('✅ RecipeService: $message');
      return RecipeOperationResult.success(
        message,
        warnings: warnings.isNotEmpty ? warnings : null,
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Uppdatera ett befintligt recept
  Future<RecipeOperationResult> updateRecipe(Recipe updatedRecipe) async {
    _setLoading(true);
    clearError();

    try {
      final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
      if (index == -1) {
        throw ValidationFailure(
          message: 'Recept med ID ${updatedRecipe.id} hittades inte',
        );
      }

      await Future.delayed(
        const Duration(milliseconds: 200),
      ).withShortTimeout();

      _recipes[index] = updatedRecipe;
      notifyListeners();

      debugPrint(
        '✅ RecipeService: Uppdaterade recept "${updatedRecipe.title}"',
      );
      return RecipeOperationResult.success(
        'Recept "${updatedRecipe.title}" uppdaterat',
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Ta bort ett recept
  Future<RecipeOperationResult> deleteRecipe(String recipeId) async {
    _setLoading(true);
    clearError();

    try {
      final recipe = _recipes.firstWhere(
        (r) => r.id == recipeId,
        orElse:
            () =>
                throw ValidationFailure(
                  message: 'Recept med ID $recipeId hittades inte',
                ),
      );

      await Future.delayed(
        const Duration(milliseconds: 200),
      ).withShortTimeout();

      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      debugPrint('✅ RecipeService: Tog bort recept "${recipe.title}"');
      return RecipeOperationResult.success(
        'Recept "${recipe.title}" borttaget',
      );
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      return RecipeOperationResult.error(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  /// Hämta recept by ID
  Recipe? getRecipeById(String id) {
    try {
      return _recipes.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Sök recept
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return recipes;

    final lowerQuery = query.toLowerCase();
    return _recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
          recipe.description.toLowerCase().contains(lowerQuery) ||
          recipe.ingredients.any(
            (ing) => ing.toLowerCase().contains(lowerQuery),
          ) ||
          (recipe.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ??
              false);
    }).toList();
  }

  // ===== ERROR HANDLING =====

  /// Rensa fel
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Sätt fel
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  /// Sätt loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  /// Återställ service (för testing)
  void reset() {
    _recipes.clear();
    _isLoading = false;
    _lastError = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Refresh data (för pull-to-refresh)
  Future<void> refresh() async {
    _setLoading(true);
    clearError();

    try {
      // Simulera refresh från server med timeout
      await Future.delayed(
        const Duration(milliseconds: 500),
      ).withShortTimeout();

      // I framtiden: ladda om från Firebase
      notifyListeners();
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    // Cleanup om behövs
    super.dispose();
  }
}
