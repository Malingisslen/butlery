// lib/viewmodels/file_import_viewmodel.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Owns the CSV/Excel file-import flow's state and business logic, lifting it
/// out of [FileImportView] (MVVM). The view keeps the one thing the VM can't:
/// presenting the batch-preview screen and reading the user's selection back.
class FileImportViewModel extends BaseViewModel {
  FileImportViewModel({
    ImportManager? importManager,
    UnifiedRecipeService? recipeService,
    PersonalTagService? tagService,
  }) : _importManager = importManager ?? ServiceLocator.get<ImportManager>(),
       _injectedRecipeService = recipeService,
       _injectedTagService = tagService;

  final ImportManager _importManager;
  final UnifiedRecipeService? _injectedRecipeService;
  final PersonalTagService? _injectedTagService;

  UnifiedRecipeService? get _recipeService =>
      _injectedRecipeService ?? ServiceLocator.tryGet<UnifiedRecipeService>();

  /// Each saved recipe is one write, so one file saves at most this many.
  static const maxRecipesPerFile = 500;

  String? _statusMessage;
  int _importedCount = 0;
  int _failedCount = 0;
  int _skippedDuplicates = 0;
  int _skippedOverCap = 0;

  String? get statusMessage => _statusMessage;
  int get importedCount => _importedCount;
  int get failedCount => _failedCount;
  bool get allSucceeded => _failedCount == 0;

  /// Resets back to idle (used when the user cancels the preview).
  void reset() {
    _statusMessage = null;
    _importedCount = 0;
    _failedCount = 0;
    _skippedDuplicates = 0;
    _skippedOverCap = 0;
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
      final result = await _importManager.importFile();
      final denied = result.rateLimitDenied;
      if (denied != null) {
        _statusMessage = denied.swedishMessage;
        setLoading(false);
        return const [];
      }
      final capped = result.recipes.take(maxRecipesPerFile).toList();
      _skippedOverCap = result.recipes.length - capped.length;
      final fresh = _withoutDuplicates(capped);
      _skippedDuplicates = capped.length - fresh.length;
      if (fresh.isEmpty) {
        _statusMessage = _skippedDuplicates > 0
            ? AppLocale.current.importAllAlreadyHeld
            : AppLocale.current.importNoFileOrNoRecipes;
        setLoading(false);
        return const [];
      }
      setLoading(false);
      return fresh;
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

    final tagIds = await _resolveTagNames(
      selected.expand((r) => r.personalTagIds ?? const <String>[]),
    );
    final recipeService = _recipeService!;
    for (final recipe in selected) {
      try {
        // The whole parsed recipe goes through, so the section headings the
        // parser kept in its structured ingredients reach the saved recipe.
        await recipeService.createRecipeFrom(
          recipe.copyWith(
            personalTagIds: (recipe.personalTagIds ?? const <String>[])
                .map((name) => tagIds[_tagKey(name)])
                .nonNulls
                .toSet()
                .toList(),
            // A file's tags are names; the ids above replace them.
            personalTags: null,
          ),
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
    final l = AppLocale.current;
    _statusMessage = [
      l.importComplete(_importedCount, _failedCount),
      if (_skippedDuplicates > 0) l.importSkippedDuplicates(_skippedDuplicates),
      if (_skippedOverCap > 0)
        l.importSkippedOverLimit(_skippedOverCap, maxRecipesPerFile),
    ].join('\n');
    setLoading(false);
  }

  /// Leaves out a recipe the user already has word for word (same title and
  /// ingredients), and a row repeated in the file. Compares against the recipes
  /// already in memory, so it costs no read; before they have loaded nothing
  /// is counted as held.
  List<Recipe> _withoutDuplicates(List<Recipe> parsed) {
    final service = _recipeService;
    final seen = {
      if (service != null && service.isInitialized)
        for (final r in service.recipes) _duplicateKey(r),
    };
    return [
      for (final r in parsed)
        if (seen.add(_duplicateKey(r))) r,
    ];
  }

  static String _normalized(String text) =>
      SwedishCharacterNormalizer.normalize(
        text.trim().replaceAll(RegExp(r'\s+'), ' '),
      );

  static String _duplicateKey(Recipe r) =>
      [r.title, ...r.ingredients].map(_normalized).join('\n');

  static String _tagKey(String name) => name.trim().toLowerCase();

  /// The file names tags in words; a recipe stores tag ids. Each name maps to
  /// the user's tag of that name, ignoring case, and a new name becomes a new
  /// tag. The tag list is read once; a name that cannot be a tag (too long,
  /// reserved) is left off rather than failing the recipe.
  Future<Map<String, String>> _resolveTagNames(Iterable<String> names) async {
    final wanted = {for (final n in names) _tagKey(n): n.trim()}..remove('');
    if (wanted.isEmpty) return const {};
    final tagService =
        _injectedTagService ?? ServiceLocator.tryGet<PersonalTagService>();
    if (tagService == null) return const {};
    try {
      final existing = await tagService.getAllTags();
      final ids = {for (final t in existing) _tagKey(t.name): t.id};
      var sortOrder = existing.fold(
        -1,
        (m, t) => t.sortOrder > m ? t.sortOrder : m,
      );
      for (final MapEntry(:key, value: name) in wanted.entries) {
        if (ids.containsKey(key) || PersonalTag.validateName(name) != null) {
          continue;
        }
        try {
          final created = await tagService.createTag(
            PersonalTag.create(name: name, sortOrder: ++sortOrder),
          );
          if (created != null) ids[key] = created.id;
        } catch (e) {
          AppLogger.warning('File import: a tag was not created: $e');
        }
      }
      return ids;
    } catch (e) {
      AppLogger.error('File import: tags could not be read', e);
      return const {};
    }
  }
}
