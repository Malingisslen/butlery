// lib/viewmodels/recipe_selection_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe_unified.dart';
import '../models/user_profile.dart';
import '../services/unified/unified_recipe_service.dart';

/// ViewModel för receptval och delning med vänner
class RecipeSelectionViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final UserProfile targetFriend;

  RecipeSelectionViewModel({
    required UnifiedRecipeService recipeService,
    required this.targetFriend,
  })  : _recipeService = recipeService;

  // State
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  final Set<String> _selectedRecipeIds = {};
  bool _isSharing = false;
  Set<String> _alreadySharedRecipeIds = {}; // ✅ NY: För redan delade recept

  // Getters
  List<Recipe> get allRecipes => _allRecipes;
  List<Recipe> get filteredRecipes => _filteredRecipes;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasRecipes => _allRecipes.isNotEmpty;
  bool get hasSearchResults => _filteredRecipes.isNotEmpty;
  int get totalCount => _allRecipes.length;
  int get filteredCount => _filteredRecipes.length;
  Set<String> get selectedRecipeIds => _selectedRecipeIds;
  bool get hasSelectedRecipes => _selectedRecipeIds.isNotEmpty;
  int get selectedCount => _selectedRecipeIds.length;
  bool get isSharing => _isSharing;
  List<Recipe> get selectedRecipes => _allRecipes
      .where((recipe) => _selectedRecipeIds.contains(recipe.id))
      .toList();

  // ✅ NYA GETTERS för redan delade recept
  Set<String> get alreadySharedRecipeIds => _alreadySharedRecipeIds;

  /// Kontrollera om recept redan delats med vännen
  bool isRecipeAlreadyShared(String recipeId) {
    return _alreadySharedRecipeIds.contains(recipeId);
  }

  /// ✅ UPPDATERAD: Ladda användarens recept OCH kolla vilka som redan delats
  Future<void> loadRecipes() async {
    try {
      _setLoading(true);
      _clearError();

      // Ladda alla recept (unified format)
      _allRecipes = _recipeService.recipes;

      // ✅ NY: Kolla vilka som redan delats med denna vän
      // TODO: Implement getRecipesSharedWithFriend in social feature interface
      _alreadySharedRecipeIds = <String>{}; // For now, empty set

      _filteredRecipes = List.from(_allRecipes);

      // Applicera eventuell befintlig sökning
      if (_searchQuery.isNotEmpty) {
        _filterRecipes(_searchQuery);
      }
    } catch (e) {
      _setError('Kunde inte ladda recept: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Uppdatera sökquery och filtrera recept
  void updateSearch(String query) {
    _searchQuery = query;
    _filterRecipes(query);
    notifyListeners();
  }

  /// Rensa sökning
  void clearSearch() {
    _searchQuery = '';
    _filteredRecipes = List.from(_allRecipes);
    notifyListeners();
  }

  /// Toggla recept-selektion
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
    } else {
      _selectedRecipeIds.add(recipeId);
    }
    notifyListeners();
  }

  /// Kontrollera om recept är valt
  bool isRecipeSelected(String recipeId) {
    return _selectedRecipeIds.contains(recipeId);
  }

  /// Rensa alla selektioner
  void clearSelections() {
    _selectedRecipeIds.clear();
    notifyListeners();
  }

  /// Välj alla filtrerade recept
  void selectAllFiltered() {
    for (final recipe in _filteredRecipes) {
      _selectedRecipeIds.add(recipe.id);
    }
    notifyListeners();
  }

  /// Dela valda recept med SocialRecipeService
  Future<bool> shareSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty) return false;

    try {
      _setSharing(true);

      // Hämta de valda recepten
      final recipesToShare = selectedRecipes;

      // Dela varje recept individuellt med den specifika vännen
      // Vi använder shareRecipeToFriends men med bara en vän i listan
      bool allSuccessful = true;

      for (final recipe in recipesToShare) {
        final memberDisplayNames = {targetFriend.uid: targetFriend.displayName};
        
        final sharedRecipeId = await _recipeService.social.shareRecipe(
          recipeId: recipe.id,
          memberIds: [targetFriend.uid],
          memberDisplayNames: memberDisplayNames,
        );

        final success = sharedRecipeId != null;
        if (!success) {
          allSuccessful = false;
          // Vi fortsätter med nästa recept även om ett misslyckas
        } else {
          // ✅ NY: Lägg till i redan delade recept lokalt för direkta UI-uppdateringar
          _alreadySharedRecipeIds.add(recipe.id);
        }
      }

      // Rensa selektion efter lyckad delning
      if (allSuccessful) {
        clearSelections();
      }

      // ✅ Notifiera listeners för UI-uppdatering
      notifyListeners();

      return allSuccessful;
    } catch (e) {
      _setError('Kunde inte dela recept: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Privat metod för filtrering
  void _filterRecipes(String query) {
    if (query.isEmpty) {
      _filteredRecipes = List.from(_allRecipes);
    } else {
      final searchLower = query.toLowerCase();
      _filteredRecipes = _allRecipes.where((recipe) {
        return recipe.title.toLowerCase().contains(searchLower) ||
            recipe.mealType.toLowerCase().contains(searchLower) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(searchLower)) ||
            (recipe.tags
                    ?.any((tag) => tag.toLowerCase().contains(searchLower)) ??
                false);
      }).toList();
    }
  }

  /// Få delningsmeddelande för valda recept
  String getShareMessage() {
    if (_selectedRecipeIds.isEmpty) return '';

    if (_selectedRecipeIds.length == 1) {
      final recipe = selectedRecipes.first;
      return '${recipe.title} delat med ${targetFriend.displayName}! 🍽️';
    } else {
      return '${_selectedRecipeIds.length} recept delade med ${targetFriend.displayName}! 🍽️';
    }
  }

  // Private setters
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSharing(bool sharing) {
    _isSharing = sharing;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
