// lib/viewmodels/file_import_viewmodel.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Owns the CSV/Excel file-import flow's state and business logic, lifting it
/// out of [FileImportView] (MVVM). The view keeps the one thing the VM can't:
/// presenting the batch-preview screen and reading the user's selection back.
class FileImportViewModel extends BaseViewModel {
  FileImportViewModel({FileImportStrategy? strategy})
      : _strategy = strategy ?? FileImportStrategy();

  final FileImportStrategy _strategy;

  String? _statusMessage;
  int _importedCount = 0;
  int _failedCount = 0;

  String? get statusMessage => _statusMessage;
  int get importedCount => _importedCount;
  int get failedCount => _failedCount;
  bool get allSucceeded => _failedCount == 0;

  /// Resets back to idle (used when the user cancels the preview).
  void reset() {
    _statusMessage = null;
    _importedCount = 0;
    _failedCount = 0;
    setLoading(false); // notifies
  }

  /// Picks + parses the file. Returns the parsed recipes (empty when the user
  /// cancelled the picker or the file held none — [statusMessage] is set).
  Future<List<Recipe>> parseFile() async {
    _importedCount = 0;
    _failedCount = 0;
    _statusMessage = AppLocale.current.importSelectingFile;
    setLoading(true);
    try {
      final parsed = await _strategy.importMultiple();
      if (parsed.isEmpty) {
        _statusMessage = AppLocale.current.importNoFileOrNoRecipes;
        setLoading(false);
        return const [];
      }
      setLoading(false);
      return parsed;
    } catch (e) {
      AppLogger.error('File import (parse) failed', e);
      _statusMessage = AppLocale.current.errorGeneric;
      setLoading(false);
      return const [];
    }
  }

  /// Saves the user-selected recipes, continuing past individual failures and
  /// tracking imported/failed counts. Sets the final summary status.
  Future<void> importSelected(List<Recipe> selected) async {
    if (selected.isEmpty) {
      reset();
      return;
    }
    _importedCount = 0;
    _failedCount = 0;
    _statusMessage = AppLocale.current.importImportingRecipes(selected.length);
    setLoading(true);

    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    for (final recipe in selected) {
      try {
        await recipeService.createPersonalRecipe(
          title: recipe.title,
          description: recipe.description,
          ingredients: recipe.ingredients,
          instructions: recipe.instructions,
          mealType: recipe.mealType,
          portions: recipe.portions,
          timeMinutes: recipe.timeMinutes,
          personalTagIds: recipe.personalTagIds,
          rating: recipe.rating,
          sourceUrl: recipe.sourceUrl,
          imageUrls: recipe.imageUrls,
        );
        _importedCount++;
      } catch (e) {
        AppLogger.error('Failed to import recipe: ${recipe.id}', e);
        _failedCount++;
      }
      // The view may have been disposed mid-import (user navigated away). Keep
      // saving so their whole selection lands, but don't notify a dead VM.
      if (!isDisposed) notifyListeners();
    }

    if (isDisposed) return;
    _statusMessage =
        AppLocale.current.importComplete(_importedCount, _failedCount);
    setLoading(false);
  }
}
