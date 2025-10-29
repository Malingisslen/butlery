/// Manager handling archive recipe selection operations.

// lib/viewmodels/archive/archive_selection_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Manages recipe selection state for batch import operations.
class ArchiveSelectionManager extends ChangeNotifier {
  final Set<String> _selectedRecipeIds = {};

  Set<String> get selectedRecipeIds => Set.unmodifiable(_selectedRecipeIds);
  int get selectedCount => _selectedRecipeIds.length;
  bool get hasSelection => _selectedRecipeIds.isNotEmpty;

  /// Checks if all filtered recipes are selected.
  bool isAllSelected(List<Recipe> filteredRecipes) {
    return _selectedRecipeIds.length == filteredRecipes.length &&
        filteredRecipes.every((r) => _selectedRecipeIds.contains(r.id));
  }

  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
    } else {
      _selectedRecipeIds.add(recipeId);
    }
    notifyListeners();
  }

  void toggleSelectAll(List<Recipe> filteredRecipes) {
    if (isAllSelected(filteredRecipes)) {
      _selectedRecipeIds.clear();
    } else {
      _selectedRecipeIds.clear();
      _selectedRecipeIds.addAll(filteredRecipes.map((r) => r.id));
    }
    notifyListeners();
  }

  /// Removes selections for recipes no longer in the filtered list.
  void updateSelection(List<Recipe> filteredRecipes) {
    final currentRecipeIds = filteredRecipes.map((r) => r.id).toSet();
    final sizeBefore = _selectedRecipeIds.length;
    _selectedRecipeIds.removeWhere((id) => !currentRecipeIds.contains(id));
    if (_selectedRecipeIds.length != sizeBefore) {
      notifyListeners();
    }
  }

  void clearSelection() {
    if (_selectedRecipeIds.isNotEmpty) {
      _selectedRecipeIds.clear();
      notifyListeners();
    }
  }
}
