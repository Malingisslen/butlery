// lib/services/recipe_service.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../core/error/failures.dart';
import '../core/error/error_handler.dart';
import '../core/extensions/future_extensions.dart';
import '../core/injection.dart';
import '../core/utils/logger.dart';
import 'persistence_service.dart';

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
/// Integrerar PersistenceService för permanent datalagring
class RecipeService extends ChangeNotifier {
  static RecipeService? _instance;

  // Reference till PersistenceService
  late final PersistenceService _persistenceService;

  // Private constructor för singleton
  RecipeService._internal() {
    // Hämta PersistenceService från dependency injection
    _persistenceService = sl<PersistenceService>();
    AppLogger.info('RecipeService initialiserad med PersistenceService');
  }

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
    if (_isInitialized) {
      AppLogger.debug('RecipeService redan initialiserad, skippar...');
      return;
    }

    _setLoading(true);
    clearError();

    try {
      // Försök ladda sparade recept från lokal storage
      final savedRecipes = await _loadRecipesFromStorage();

      if (savedRecipes.isNotEmpty) {
        // Vi har sparade recept! Använd dem
        _recipes = savedRecipes;
        AppLogger.info(
          'Laddade ${_recipes.length} sparade recept från lokal storage',
        );
      } else {
        // Ingen sparad data, använd dummy data som standard
        _recipes = List.from(dummyRecipesNotifier.value);
        AppLogger.info(
          'Ingen sparad data hittades, använder ${_recipes.length} standardrecept',
        );

        // Spara dummy data direkt så användaren har något nästa gång
        await _saveRecipesToStorage();
      }

      _isInitialized = true;
      AppLogger.success('RecipeService initialisering klar!');
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      ErrorHandler.logError(e, StackTrace.current);
      _setError(failure.message);
      AppLogger.error('RecipeService initialiseringsfel: ${failure.message}');

      // Fallback till dummy data om något går fel
      _recipes = List.from(dummyRecipesNotifier.value);
      _isInitialized = true;
    } finally {
      _setLoading(false);
    }
  }

  // ===== PERSISTENCE HELPERS =====

  /// Ladda recept från lokal storage
  Future<List<Recipe>> _loadRecipesFromStorage() async {
    try {
      // Använd loadRecipes() istället för getList()
      final recipes = await _persistenceService.loadRecipes();
      return recipes;
    } catch (e) {
      AppLogger.error('Fel vid laddning från storage: $e');
      return [];
    }
  }

  /// Spara alla recept till lokal storage
  Future<bool> _saveRecipesToStorage() async {
    try {
      // Använd saveRecipes() istället för saveList()
      final success = await _persistenceService.saveRecipes(_recipes);

      if (success) {
        AppLogger.debug('Sparade ${_recipes.length} recept till storage');
      } else {
        AppLogger.warning('Kunde inte spara recept till storage');
      }

      return success;
    } catch (e) {
      AppLogger.error('Fel vid sparning till storage: $e');
      return false;
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

      // Simulera async operation (Firebase senare)
      await Future.delayed(
        const Duration(milliseconds: 200),
      ).withShortTimeout();

      // Lägg till receptet
      _recipes.add(recipe);

      // Spara till persistent storage
      final saved = await _saveRecipesToStorage();

      notifyListeners();

      AppLogger.success('Lade till recept "${recipe.title}"');

      if (!saved) {
        // Receptet lades till men kunde inte sparas permanent
        return RecipeOperationResult.success(
          'Recept "${recipe.title}" tillagt (varning: kunde inte spara permanent)',
          warnings: ['Receptet kunde inte sparas permanent'],
        );
      }

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

      // Spara alla nya recept till storage
      final saved = await _saveRecipesToStorage();

      notifyListeners();

      final message =
          addedCount == recipes.length
              ? 'Alla $addedCount recept importerade från arkiv'
              : '$addedCount av ${recipes.length} recept importerade från arkiv';

      if (!saved) {
        warnings.add('Recepten kunde inte sparas permanent');
      }

      AppLogger.info(message);
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

      // Spara originalet för rollback om sparning misslyckas
      final originalRecipe = _recipes[index];

      // Uppdatera receptet
      _recipes[index] = updatedRecipe;

      // Försök spara till storage
      final saved = await _saveRecipesToStorage();

      if (!saved) {
        // Rollback om sparning misslyckades
        _recipes[index] = originalRecipe;
        AppLogger.error('Kunde inte spara uppdaterat recept, rollback utförd');
        return RecipeOperationResult.error(
          'Kunde inte spara uppdateringen permanent',
        );
      }

      notifyListeners();

      AppLogger.success('Uppdaterade recept "${updatedRecipe.title}"');
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
      final recipeIndex = _recipes.indexWhere((r) => r.id == recipeId);
      if (recipeIndex == -1) {
        throw ValidationFailure(
          message: 'Recept med ID $recipeId hittades inte',
        );
      }

      await Future.delayed(
        const Duration(milliseconds: 200),
      ).withShortTimeout();

      // Spara originalet för rollback
      final deletedRecipe = _recipes[recipeIndex];

      // Ta bort receptet
      _recipes.removeAt(recipeIndex);

      // Försök spara till storage
      final saved = await _saveRecipesToStorage();

      if (!saved) {
        // Rollback om sparning misslyckades
        _recipes.insert(recipeIndex, deletedRecipe);
        AppLogger.error('Kunde inte spara borttagning, rollback utförd');
        return RecipeOperationResult.error(
          'Kunde inte ta bort receptet permanent',
        );
      }

      notifyListeners();

      AppLogger.success('Tog bort recept "${deletedRecipe.title}"');
      return RecipeOperationResult.success(
        'Recept "${deletedRecipe.title}" borttaget',
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

    // Rensa även persistent storage
    _persistenceService.clearRecipes();
    AppLogger.debug('RecipeService återställd och storage rensad');
  }

  /// Refresh data (för pull-to-refresh)
  Future<void> refresh() async {
    _setLoading(true);
    clearError();

    try {
      // Simulera refresh från server
      await Future.delayed(
        const Duration(milliseconds: 500),
      ).withShortTimeout();

      // Ladda om från storage för att säkerställa synk
      final savedRecipes = await _loadRecipesFromStorage();
      if (savedRecipes.isNotEmpty) {
        _recipes = savedRecipes;
        AppLogger.debug('Refreshade ${_recipes.length} recept från storage');
      }

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
    // Spara en sista gång innan service stängs ner
    _saveRecipesToStorage();
    super.dispose();
  }
}
