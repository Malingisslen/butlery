import 'package:flutter/foundation.dart';

import '../../models/recipe.dart';
import '../../services/menu_service.dart';
import '../../services/recipe_service.dart';
import '../../core/injection.dart';

/// Simple view model for menu generation based on recipes.
class MenuRealtimeViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final MenuService _menuService;

  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;
  String? _error;

  MenuRealtimeViewModel({
    RecipeService? recipeService,
    MenuService? menuService,
  })  : _recipeService = recipeService ?? sl<RecipeService>(),
        _menuService = menuService ?? sl<MenuService>() {
    _recipeService.addListener(_onRecipesChanged);
  }

  Map<String, List<Recipe>> get menu => Map.unmodifiable(_menu);
  bool get isGenerating => _isGenerating;
  bool get hasMenu => _menu.isNotEmpty;
  String? get error => _error;
  bool get hasError => _error != null;

  List<Recipe> get availableRecipes => _recipeService.recipes;
  bool get hasAvailableRecipes => availableRecipes.isNotEmpty;

  Future<void> generateMenu(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      _setError('Ange vad du vill ha för meny');
      return;
    }

    _setGenerating(true);
    try {
      _menu = _menuService.generateMenuFromPrompt(trimmed, availableRecipes);
      _error = null;
    } catch (e) {
      _setError('$e');
    } finally {
      _setGenerating(false);
    }
    notifyListeners();
  }

  void clearMenu() {
    _menu.clear();
    notifyListeners();
  }

  void _onRecipesChanged() {
    notifyListeners();
  }

  void _setGenerating(bool value) {
    _isGenerating = value;
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
