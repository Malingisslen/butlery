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

  /// "Välj" in the top bar: selection mode with nothing selected yet
  /// (B-46; produktregler.md:870). The actions that need a selection stay
  /// off, their names readable, until something is ticked
  /// (produktregler.md:876).
  void startSelection() {
    _isSelectionMode = true;
    notifyListeners();
  }

  /// The "Markera alla" toggle's second half: untick everything and stay in
  /// selection mode (produktregler.md:877). Only the user leaves the mode
  /// (produktregler.md:878); this is not the last tick being taken off a
  /// row.
  void deselectAll() {
    _selectedIds.clear();
    notifyListeners();
  }
}
