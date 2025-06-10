// lib/viewmodels/menu_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/menu_service.dart';
import '../core/injection.dart';

/// ViewModel för VeckomenyView
/// Hanterar meny-generering och state management
class MenuViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final MenuService _menuService;

  // State
  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;
  String? _error;
  String _lastPrompt = '';

  MenuViewModel({RecipeService? recipeService, MenuService? menuService})
    : _recipeService = recipeService ?? sl<RecipeService>(),
      _menuService = menuService ?? sl<MenuService>() {
    // Lyssna på ändringar från RecipeService
    _recipeService.addListener(_onRecipesChanged);
  }

  // ===== GETTERS =====

  Map<String, List<Recipe>> get menu => Map.unmodifiable(_menu);
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasMenu => _menu.isNotEmpty;
  String get lastPrompt => _lastPrompt;

  int get totalRecipeCount =>
      _menu.values.fold(0, (sum, recipes) => sum + recipes.length);

  List<Recipe> get availableRecipes => _recipeService.recipes;
  bool get hasAvailableRecipes => availableRecipes.isNotEmpty;

  // ===== ACTIONS =====

  /// Generera meny från prompt
  Future<void> generateMenu(String prompt) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      _setError('Ange vad du vill ha för meny');
      return;
    }

    _setGenerating(true);
    _lastPrompt = trimmedPrompt;

    try {
      // Simulera lite latency för bättre UX
      await Future.delayed(const Duration(milliseconds: 300));

      if (availableRecipes.isEmpty) {
        throw Exception('Inga recept tillgängliga. Lägg till recept först.');
      }

      final generatedMenu = _menuService.generateMenuFromPrompt(
        trimmedPrompt,
        availableRecipes,
      );

      if (generatedMenu.isEmpty) {
        throw Exception(
          'Kunde inte generera meny från din begäran. Prova att vara mer specifik.',
        );
      }

      _menu = generatedMenu;
      _error = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setGenerating(false);
    }
  }

  /// Regenerera en specifik sektion
  Future<void> regenerateSection(String section) async {
    if (!hasMenu) return;

    _setGenerating(true);

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final currentCount = _menu[section]?.length ?? 1;

      // Generera nya recept för denna sektion
      final newRecipes = _menuService.generateMenuFromPrompt(
        '$currentCount $section',
        availableRecipes,
      );

      if (newRecipes.containsKey(section)) {
        _menu[section] = newRecipes[section]!;
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _setError('Kunde inte uppdatera $section: ${e.toString()}');
    } finally {
      _setGenerating(false);
    }
  }

  /// Rensa hela menyn
  void clearMenu() {
    _menu = {};
    _lastPrompt = '';
    _error = null;
    notifyListeners();
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Spara meny (för framtida persistence)
  Future<void> saveMenu() async {
    // TODO: Implementera med SharedPreferences
    // För nu är detta en placeholder
    debugPrint('Saving menu: $_menu');
  }

  /// Ladda sparad meny
  Future<void> loadSavedMenu() async {
    // TODO: Implementera med SharedPreferences
    // För nu är detta en placeholder
    debugPrint('Loading saved menu...');
  }

  // ===== PRIVATE METHODS =====

  void _setGenerating(bool value) {
    _isGenerating = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _onRecipesChanged() {
    // Om recept ändras och vi har en meny, kan vi behöva uppdatera
    if (hasMenu) {
      // Kontrollera om några recept i menyn har tagits bort
      final allRecipeIds = availableRecipes.map((r) => r.id).toSet();
      var menuChanged = false;

      _menu.forEach((category, recipes) {
        final validRecipes =
            recipes.where((r) => allRecipeIds.contains(r.id)).toList();
        if (validRecipes.length != recipes.length) {
          _menu[category] = validRecipes;
          menuChanged = true;
        }
      });

      if (menuChanged) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}
