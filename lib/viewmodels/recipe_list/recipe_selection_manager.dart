// lib/viewmodels/recipe_list/recipe_selection_manager.dart

import 'package:flutter/foundation.dart';

/// Manages multi-select state for recipe list bulk operations.
class RecipeSelectionManager extends ChangeNotifier {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;

  void enterSelectionMode(String firstId) {
    _isSelectionMode = true;
    _selectedIds.add(firstId);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(Iterable<String> visibleIds) {
    _selectedIds.addAll(visibleIds);
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
