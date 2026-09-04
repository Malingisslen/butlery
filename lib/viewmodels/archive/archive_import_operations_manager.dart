/// Manager handling batch import operations for archived recipes.

// lib/viewmodels/archive/archive_import_operations_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

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
      _setError(AppLocale.current.errorNoRecipesSelected);
      return;
    }

    _setImporting(true);

    try {
      final toImport = archivedRecipes
          .where((r) => selectedRecipeIds.contains(r.id))
          .map((r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'))
          .toList();

      final result = await _recipeService.personal.addMultipleUnifiedRecipes(
        toImport,
      );

      if (result.isSuccess) {
        _error = null;
        onSuccess();
        notifyListeners();
      } else {
        _setError(result.message ?? AppLocale.current.errorImportFailed);
      }
    } catch (e) {
      _setError(AppLocale.current.errorImportFailed);
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
      final toImport =
          (filteredRecipes.isEmpty ? archivedRecipes : filteredRecipes)
              .map((r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'))
              .toList();

      final result = await _recipeService.personal.addMultipleUnifiedRecipes(
        toImport,
      );

      if (result.isSuccess) {
        _error = null;
        onSuccess();
        notifyListeners();
      } else {
        _setError(result.message ?? AppLocale.current.errorImportFailed);
      }
    } catch (e) {
      _setError(AppLocale.current.errorImportFailed);
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

  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  // BUT-1641: swallowed, not thrown — the caller reaching here is an async
  // continuation finishing after the screen closed. Why the parents' own
  // guards do not cover this is recorded in the ticket.
  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  /// Exists only to flip the flag above. This class holds no subscriptions and
  /// no timers, so there is nothing else to cancel — that half of BUT-1628's
  /// finding still holds.
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
