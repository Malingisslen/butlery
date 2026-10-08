// lib/viewmodels/personal_tags/personal_tag_selection_manager.dart

import 'package:flutter/foundation.dart';

import 'package:butlery/models/tagging/personal_tag_bulk_delete_result.dart';

/// BUT-1185: multi-select state for personal-tag bulk operations
/// (merge / bulk-delete). Pure UI state — no Firestore. Mirrors
/// `recipe_selection_manager.dart`.
class PersonalTagSelectionManager extends ChangeNotifier {
  bool _isSelectionMode = false;
  final Set<String> _selectedTagIds = {};
  PersonalTagBulkDeleteResult? _partialDelete;

  /// The last bulk delete when only some tags went (P5-U33), or null.
  PersonalTagBulkDeleteResult? get partialDelete => _partialDelete;

  List<String> _partialDeletedNames = const [];

  /// The names of the tags [partialDelete] deleted, captured by tag id when
  /// the delete returned: the tag list no longer has them.
  List<String> get partialDeletedNames => _partialDeletedNames;

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
        // The outcome describes a selection that is gone now.
        _partialDelete = null;
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
    _partialDelete = null;
    _partialDeletedNames = const [];
    notifyListeners();
  }

  /// P5-U33: only some of the selected tags went. The ones that did not stay
  /// selected and the mode stays open, so the delete can be tried again
  /// (produktregler.md:908, :878). Identity is the tag id.
  void showPartialDelete(
    PersonalTagBulkDeleteResult result, {
    List<String> deletedNames = const [],
  }) {
    _isSelectionMode = true;
    _selectedTagIds
      ..clear()
      ..addAll(result.failedIds);
    _partialDelete = result;
    _partialDeletedNames = List.unmodifiable(deletedNames);
    notifyListeners();
  }

  /// Drops the partial outcome before a new attempt; the selection stays.
  void clearPartialDelete() {
    if (_partialDelete == null) return;
    _partialDelete = null;
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
    _selectedTagIds.clear();
    // Nothing the outcome described is selected any more.
    _partialDelete = null;
    notifyListeners();
  }
}
