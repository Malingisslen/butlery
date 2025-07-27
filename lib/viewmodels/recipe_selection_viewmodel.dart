// lib/viewmodels/recipe_selection_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

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
  final Set<String> _alreadySharedRecipeIds = {}; // ✅ NY: För redan delade recept
  
  // Additional getters for dialog compatibility
  bool get hasSelectedRecipes => _selectedRecipeIds.isNotEmpty;
  int get selectedCount => _selectedRecipeIds.length;
  
  // Search and filtering compatibility methods
  void updateSearch(String query) => updateSearchQuery(query);
  bool get hasSearchResults => _filteredRecipes.isNotEmpty;
  void clearSearch() => updateSearchQuery('');
  int get filteredCount => _filteredRecipes.length;
  int get totalCount => _allRecipes.length;
  void clearSelections() => clearSelection();

  // Getters
  List<Recipe> get allRecipes => _allRecipes;
  List<Recipe> get filteredRecipes => _filteredRecipes;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSharing => _isSharing;
  bool get hasError => _error != null;
  bool get hasRecipes => _allRecipes.isNotEmpty;
  bool get hasFilteredRecipes => _filteredRecipes.isNotEmpty;
  bool get canShare => _selectedRecipeIds.isNotEmpty && !_isSharing;
  Set<String> get selectedRecipeIds => _selectedRecipeIds;
  Set<String> get alreadySharedRecipeIds => _alreadySharedRecipeIds; // ✅ NY: För UI

  /// Lista över valda recept (inklusive kompletta Recipe-objekt)
  List<Recipe> get selectedRecipes {
    return _allRecipes.where((recipe) => _selectedRecipeIds.contains(recipe.id)).toList();
  }

  /// Indikator om receptet redan är delat med vald vän
  bool isRecipeAlreadyShared(String recipeId) => _alreadySharedRecipeIds.contains(recipeId);

  /// Ladda alla recept
  Future<void> loadRecipes() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('📋 Laddar recept för delning...');

      final recipes = _recipeService.recipes;
      _allRecipes = recipes.toList();

      // Ladda redan delade recept
      await _loadSharedRecipes();

      _applyFilters();
      _setLoading(false);

      AppLogger.success('✅ ${_allRecipes.length} recept laddade');
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av recept', e);
      _setError('Kunde inte ladda recept');
      _setLoading(false);
    }
  }

  /// Sök i recept
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query;
    _applyFilters();
  }

  /// Välj eller avmarkera recept
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
      AppLogger.debug('➖ Avmarkerat recept: $recipeId');
    } else {
      _selectedRecipeIds.add(recipeId);
      AppLogger.debug('➕ Markerat recept: $recipeId');
    }
    notifyListeners();
  }

  /// Kontrollera om recept är valt
  bool isRecipeSelected(String recipeId) {
    return _selectedRecipeIds.contains(recipeId);
  }

  /// Rensa alla val
  void clearSelection() {
    if (_selectedRecipeIds.isNotEmpty) {
      _selectedRecipeIds.clear();
      notifyListeners();
      AppLogger.debug('🧹 Rensat receptval');
    }
  }

  /// Dela valda recept med vännen
  Future<bool> shareSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty || _isSharing) return false;

    _setSharing(true);
    _clearError();

    try {
      AppLogger.info('📤 Delar ${_selectedRecipeIds.length} recept med ${targetFriend.displayName}');

      final recipes = selectedRecipes;
      for (final recipe in recipes) {
        final success = await _recipeService.social.shareRecipe(
          recipeId: recipe.id,
          memberIds: [targetFriend.uid],
          memberDisplayNames: {targetFriend.uid: targetFriend.displayName},
        );
        
        final shareResult = success != null;

        if (!shareResult) {
          throw Exception('Kunde inte dela recept: ${recipe.title}');
        }
      }

      // Lägg till delade recept i redan-delat lista
      _alreadySharedRecipeIds.addAll(_selectedRecipeIds);
      clearSelection(); // Rensa valet efter lyckad delning

      _setSharing(false);
      AppLogger.success('✅ Recept delade med ${targetFriend.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Fel vid delning av recept', e);
      _setError('Kunde inte dela recept. Försök igen.');
      _setSharing(false);
      return false;
    }
  }

  /// Applicera filter och sortering
  void _applyFilters() {
    var filtered = _allRecipes;

    // Textfilter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((recipe) {
        return recipe.title.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(query));
      }).toList();
    }

    // Sortera: opådelat först, sedan alfabetiskt
    filtered.sort((a, b) {
      final aShared = _alreadySharedRecipeIds.contains(a.id);
      final bShared = _alreadySharedRecipeIds.contains(b.id);

      if (aShared && !bShared) return 1; // a efter b
      if (!aShared && bShared) return -1; // a före b
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    _filteredRecipes = filtered;
    notifyListeners();

    AppLogger.debug(
        '🔍 Filtrerade recept: ${_filteredRecipes.length}/${_allRecipes.length}');
  }


  /// Uppdatera recept från service
  Future<void> refresh() async {
    AppLogger.debug('🔄 Uppdaterar receptlista...');
    await loadRecipes();
  }

  /// Statusinformation för delning
  String getSelectionSummary() {
    if (_selectedRecipeIds.isEmpty) return 'Inga recept valda';
    if (_selectedRecipeIds.length == 1) return '1 recept valt';
    return '${_selectedRecipeIds.length} recept valda';
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

  /// Load recipes that are already shared with target friend
  Future<void> _loadSharedRecipes() async {
    try {
      // Get all collaborative recipes that the current user owns or participates in
      final collaborativeRecipes = await _recipeService.social.getSharedByMe();
      final sharedWithMeRecipes = await _recipeService.social.getSharedWithMe();
      
      final sharedRecipeIds = <String>{};
      
      // Check recipes shared by me
      for (final recipe in collaborativeRecipes) {
        if (recipe.socialData?.memberPermissions != null) {
          final memberIds = recipe.socialData!.memberPermissions!.keys.toSet();
          // If target friend is a member of this recipe, mark as shared
          if (memberIds.contains(targetFriend.uid)) {
            sharedRecipeIds.add(recipe.id);
          }
        }
      }
      
      // Check recipes shared with me (in case friend shared with us)
      for (final recipe in sharedWithMeRecipes) {
        if (recipe.socialData?.memberPermissions != null) {
          final memberIds = recipe.socialData!.memberPermissions!.keys.toSet();
          if (memberIds.contains(targetFriend.uid)) {
            sharedRecipeIds.add(recipe.id);
          }
        }
      }
      
      _alreadySharedRecipeIds.clear();
      _alreadySharedRecipeIds.addAll(sharedRecipeIds);
      
      AppLogger.debug('Found ${sharedRecipeIds.length} recipes already shared with ${targetFriend.displayName}');
    } catch (e) {
      AppLogger.error('Error loading shared recipes', e);
      _alreadySharedRecipeIds.clear();
    }
  }
}