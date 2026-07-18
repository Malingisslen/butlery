import 'package:butlery/viewmodels/base_viewmodel.dart';

/// BUT-948: multi-select state for shopping-list bulk operations. Mirrors
/// `pantry_selection_manager.dart` / `recipe_selection_manager.dart`
/// (long-press to enter, tap to toggle, auto-exit on last deselect).
class ShoppingSelectionManager extends BaseViewModel {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool isSelected(String id) => _selectedIds.contains(id);

  void enterSelectionMode(String firstId) {
    _isSelectionMode = true;
    _selectedIds.add(firstId);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(Iterable<String> visibleIds) {
    _selectedIds.addAll(visibleIds);
    if (_selectedIds.isNotEmpty) _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
