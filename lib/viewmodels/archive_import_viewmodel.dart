/// ViewModel managing archive recipe import with filtering, search, selection, and batch operations.

// lib/viewmodels/archive_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/viewmodels/archive/archive_search_manager.dart';
import 'package:butlery/viewmodels/archive/archive_selection_manager.dart';
import 'package:butlery/viewmodels/archive/archive_import_operations_manager.dart';

export 'package:butlery/viewmodels/archive/archive_search_manager.dart'
    show TimeFilter;

/// Archive import ViewModel managing filtering, search, selection, and batch import of archived recipes.
class ArchiveImportViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StreamManagementMixin {
  late final ArchiveSearchManager _searchManager;
  late final ArchiveSelectionManager _selectionManager;
  late final ArchiveImportOperationsManager _importManager;

  ArchiveImportViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
  }) {
    final recipeServiceInstance =
        recipeService ?? ServiceLocator.get<UnifiedRecipeService>();
    final searchServiceInstance =
        searchService ?? ServiceLocator.get<SearchService>();

    _searchManager = ArchiveSearchManager(searchServiceInstance);
    _selectionManager = ArchiveSelectionManager();
    _importManager = ArchiveImportOperationsManager(recipeServiceInstance);

    // Listen to manager changes
    _searchManager.addListener(_onManagersChanged);
    _selectionManager.addListener(_onManagersChanged);
    _importManager.addListener(_onManagersChanged);
  }

  void _onManagersChanged() {
    notifyListeners();
  }

  // ===== STATE ACCESSORS =====
  List<Recipe> get archivedRecipes => _searchManager.archivedRecipes;
  List<Recipe> get filteredRecipes => _searchManager.filteredRecipes;
  Set<String> get selectedTags => _searchManager.selectedTags;
  Set<String> get selectedRecipeIds => _selectionManager.selectedRecipeIds;
  TimeFilter get timeFilter => _searchManager.timeFilter;
  String get searchQuery => _searchManager.searchQuery;
  bool get isImporting => _importManager.isImporting;
  String? get error => _importManager.error;
  bool get hasError => _importManager.hasError;
  int get selectedCount => _selectionManager.selectedCount;
  bool get hasSelection => _selectionManager.hasSelection;
  bool get allSelected => _selectionManager.isAllSelected(filteredRecipes);
  Set<String> get availableTags => _searchManager.availableTags;

  // ===== FILTERING OPERATIONS =====

  void updateSearch(String query) {
    _searchManager.updateSearch(query);
    _selectionManager.updateSelection(filteredRecipes);
  }

  void toggleTag(String tag) {
    _searchManager.toggleTag(tag);
    _selectionManager.updateSelection(filteredRecipes);
  }

  void setTimeFilter(TimeFilter filter) {
    _searchManager.setTimeFilter(filter);
    _selectionManager.updateSelection(filteredRecipes);
  }

  // ===== SELECTION OPERATIONS =====

  void toggleRecipeSelection(String recipeId) {
    _selectionManager.toggleRecipeSelection(recipeId);
  }

  void toggleSelectAll() {
    _selectionManager.toggleSelectAll(filteredRecipes);
  }

  // ===== IMPORT OPERATIONS =====

  Future<void> importSelectedRecipes() async {
    await _importManager.importSelectedRecipes(
      archivedRecipes,
      selectedRecipeIds,
      () => _selectionManager.clearSelection(),
    );
  }

  Future<void> importAllRecipes() async {
    await _importManager.importAllRecipes(
      filteredRecipes,
      archivedRecipes,
      () => _selectionManager.clearSelection(),
    );
  }

  void clearError() {
    _importManager.clearError();
  }

  void clearFilters() {
    _searchManager.clearFilters();
    _selectionManager.clearSelection();
  }

  @override
  void dispose() {
    _searchManager.removeListener(_onManagersChanged);
    _selectionManager.removeListener(_onManagersChanged);
    _importManager.removeListener(_onManagersChanged);
    _searchManager.dispose();
    _selectionManager.dispose();
    _importManager.dispose();
    disposeStreamResources();
    super.dispose();
  }
}
