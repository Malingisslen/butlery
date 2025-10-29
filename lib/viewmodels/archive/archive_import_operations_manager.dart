/// Manager handling batch import operations for archived recipes.

// lib/viewmodels/archive/archive_import_operations_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// Manages batch import operations with error handling and state management.
class ArchiveImportOperationsManager extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;

  bool _isImporting = false;
  String? _error;

  ArchiveImportOperationsManager(this._recipeService);

  bool get isImporting => _isImporting;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Imports selected recipes with source attribution 'Från Butlerys arkiv'.
  Future<void> importSelectedRecipes(
    List<Recipe> archivedRecipes,
    Set<String> selectedRecipeIds,
    VoidCallback onSuccess,
  ) async {
    if (selectedRecipeIds.isEmpty) {
      _setError('Inga recept valda');
      return;
    }

    _setImporting(true);

    try {
      final toImport = archivedRecipes
          .where((r) => selectedRecipeIds.contains(r.id))
          .map((r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'))
          .toList();

      final result = await _recipeService.personal.addMultipleUnifiedRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        onSuccess();
        notifyListeners();
      } else {
        _setError(result.message ?? 'Import misslyckades');
      }
    } catch (e) {
      _setError('Import misslyckades: $e');
    } finally {
      _setImporting(false);
    }
  }

  /// Imports all filtered recipes (or all archived if no filters) with source attribution.
  Future<void> importAllRecipes(
    List<Recipe> filteredRecipes,
    List<Recipe> archivedRecipes,
    VoidCallback onSuccess,
  ) async {
    _setImporting(true);

    try {
      final toImport = (filteredRecipes.isEmpty ? archivedRecipes : filteredRecipes)
          .map((r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'))
          .toList();

      final result = await _recipeService.personal.addMultipleUnifiedRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        onSuccess();
        notifyListeners();
      } else {
        _setError(result.message ?? 'Import misslyckades');
      }
    } catch (e) {
      _setError('Import misslyckades: $e');
    } finally {
      _setImporting(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
