/// Manager handling batch import operations for archived recipes.

// lib/viewmodels/archive/archive_import_operations_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/disposal_guard_mixin.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:uuid/uuid.dart';

/// Manages batch import operations with error handling and state management.
class ArchiveImportOperationsManager extends ChangeNotifier
    with DisposalGuardMixin {
  final UnifiedRecipeService _recipeService;

  bool _isImporting = false;
  String? _error;

  ArchiveImportOperationsManager(this._recipeService);

  bool get isImporting => _isImporting;

  // The archive's ids live for the whole app session and a create keeps its
  // draft's id, so without a fresh one a second import of the same recipe
  // would overwrite the user's first copy.
  static Recipe _asNewCopy(Recipe r) => RecipeFactory.newPersonalFrom(
    r.copyWith(sourceUrl: 'Från Butlerys arkiv'),
    ownerId: r.createdBy.orEmpty(),
    id: const Uuid().v4(),
  );
  String? get error => _error;
  bool get hasError => _error != null;

  // BUT-2303: a new account is seeded with the archive's own recipes, so
  // "Importera alla" would hand them over a second time. Only copies Butlery
  // itself provided count as already held; the user's own recipe with the
  // same title is not a match.
  static const _butleryProvided = {
    'Butlerys startrecept',
    'Från Butlerys arkiv',
  };

  List<Recipe> _notYetHeld(List<Recipe> candidates) {
    final held = {
      for (final r in _recipeService.recipes)
        if (_butleryProvided.contains(r.sourceUrl))
          SwedishCharacterNormalizer.normalize(r.title),
    };
    return candidates
        .where(
          (r) => !held.contains(SwedishCharacterNormalizer.normalize(r.title)),
        )
        .toList();
  }

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
          .map(_asNewCopy)
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
      final toImport = _notYetHeld(
        filteredRecipes.isEmpty ? archivedRecipes : filteredRecipes,
      ).map(_asNewCopy).toList();
      if (toImport.isEmpty) {
        _error = null;
        onSuccess();
        notifyListeners();
        return;
      }

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
}
