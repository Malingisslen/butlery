// lib/viewmodels/personal_tags/personal_tag_selection_manager.dart

import 'package:flutter/foundation.dart';

/// BUT-1185: multi-select state for personal-tag bulk operations
/// (merge / bulk-delete). Pure UI state — no Firestore. Mirrors
/// `recipe_selection_manager.dart`.
class PersonalTagSelectionManager extends ChangeNotifier {
  bool _isSelectionMode = false;
  final Set<String> _selectedTagIds = {};

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedTagIds => Set.unmodifiable(_selectedTagIds);
  int get selectedCount => _selectedTagIds.length;

  bool isSelected(String id) => _selectedTagIds.contains(id);

  void enterSelection(String firstId) {
    _isSelectionMode = true;
    _selectedTagIds.add(firstId);
    notifyListeners();
  }

  void toggle(String id) {
    if (_selectedTagIds.contains(id)) {
      _selectedTagIds.remove(id);
      if (_selectedTagIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedTagIds.add(id);
    }
    notifyListeners();
  }

  void clear() => exitSelection();

  void exitSelection() {
    _selectedTagIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
