/// Comprehensive archive import ViewModel providing advanced batch processing and recipe restoration for Flutter applications.
///
/// This module implements sophisticated archive-based recipe importing following Single Responsibility Principle,
/// specializing in bulk recipe restoration from Butlery's archived recipe collection with advanced filtering,
/// search capabilities, and batch import operations. It provides complete archive import infrastructure
/// while maintaining clean separation from UI rendering, data persistence, and other import types.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles archive import presentation layer concerns:
/// - **Archive Processing Excellence**: Advanced archived recipe filtering, search, and selection with intelligent caching
/// - **Batch Import Intelligence**: Sophisticated bulk import operations with validation and comprehensive error handling
/// - **Recipe Restoration Management**: Complete archived recipe restoration with metadata preservation and source attribution
/// - **Advanced Filtering System**: Multi-criteria filtering including tags, time, search, and selection management
/// - **Import State Coordination**: Complete import workflow state management with progress tracking and error handling
///
/// **What This Module Does NOT Handle:**
/// - Direct recipe data persistence (handled by UnifiedRecipeService and personal recipe operations)
/// - UI rendering and widget creation (handled by archive import views and presentation components)
/// - Complex business logic implementation (handled by recipe services and underlying business layer)
/// - Archive data management and storage (handled by archived recipes data layer and storage systems)
///
/// **Archive Import ViewModel Features:**
/// - **Multi-Criteria Filtering**: Advanced recipe filtering with tags, time constraints, and full-text search
/// - **Batch Import Operations**: Sophisticated bulk import with validation and comprehensive error handling
/// - **Selection Management**: Complete recipe selection system with individual and bulk selection coordination
/// - **Performance Optimization**: Intelligent caching and filtering optimization for large archive collections
/// - **Swedish Localization**: Complete Swedish language support for filters, errors, and user feedback
///
/// **Usage Examples:**
/// ```dart
/// // Initialize archive import ViewModel with service dependencies
/// final archiveImportViewModel = ArchiveImportViewModel(
///   recipeService: ServiceLocator.get<UnifiedRecipeService>(),
///   searchService: ServiceLocator.get<SearchService>(),
/// );
/// 
/// // Archive filtering and search operations
/// archiveImportViewModel.updateSearch('pannkakor');
/// archiveImportViewModel.toggleTag('vegetarisk');
/// archiveImportViewModel.setTimeFilter(TimeFilter.under30);
/// final filteredRecipes = archiveImportViewModel.filteredRecipes;
/// 
/// // Recipe selection management
/// archiveImportViewModel.toggleRecipeSelection('recipe_123');
/// archiveImportViewModel.toggleSelectAll();
/// final selectedCount = archiveImportViewModel.selectedCount;
/// 
/// // Batch import operations
/// await archiveImportViewModel.importSelectedRecipes();
/// if (archiveImportViewModel.hasError) {
///   final error = archiveImportViewModel.error;
/// }
/// 
/// // Bulk import all filtered recipes
/// await archiveImportViewModel.importAllRecipes();
/// 
/// // Filter and state management
/// final availableTags = archiveImportViewModel.availableTags;
/// final hasSelection = archiveImportViewModel.hasSelection;
/// archiveImportViewModel.clearFilters();
/// 
/// // Import status monitoring
/// if (archiveImportViewModel.isImporting) {
///   // Show import progress indicator
/// } else if (archiveImportViewModel.selectedCount > 0) {
///   // Enable import buttons
/// }
/// ```

// lib/viewmodels/archive_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/data/archived_recipes.dart' as archive;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Time-based filtering criteria for archived recipe filtering and search optimization.
/// 
/// Provides structured time filtering options enabling efficient recipe discovery
/// based on cooking time constraints with user-friendly filtering categories.
enum TimeFilter { 
  /// No time filtering - show all recipes regardless of cooking time
  all, 
  /// Recipes taking less than 15 minutes to prepare and cook
  under15, 
  /// Recipes taking less than 30 minutes to prepare and cook
  under30, 
  /// Recipes taking less than 60 minutes to prepare and cook
  under60 
}

/// Comprehensive archive import ViewModel providing advanced batch processing and recipe restoration through service coordination.
///
/// Manages archived recipe importing with sophisticated filtering, search, selection, and batch import capabilities.
/// Integrates with UnifiedRecipeService and SearchService to provide complete archive import functionality
/// while maintaining clean MVVM architecture separation between archive import business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Advanced archived recipe filtering with multi-criteria search and tag-based filtering
/// - Recipe selection management with individual and bulk selection coordination
/// - Batch import operations with validation and comprehensive error handling
/// - Performance optimization through intelligent caching and filtering strategies
/// - Swedish localized error messages and user feedback coordination
class ArchiveImportViewModel extends ChangeNotifier with ErrorHandlingMixin, StreamManagementMixin {
  final UnifiedRecipeService _recipeService;
  final SearchService _searchService;

  // ===== ARCHIVE IMPORT STATE =====

  /// Selected filtering tags for advanced recipe filtering and discovery.
  /// 
  /// Stores user-selected tags enabling multi-criteria filtering
  /// and advanced recipe discovery throughout archive import workflow.
  final Set<String> _selectedTags = {};
  
  /// Selected recipe IDs for batch import operations and selection management.
  /// 
  /// Tracks user-selected recipes enabling batch import coordination
  /// and selection state management throughout archive import functionality.
  final Set<String> _selectedRecipeIds = {};
  
  /// Current time-based filtering criteria for cooking time constraints.
  /// 
  /// Stores selected time filter enabling time-based recipe filtering
  /// and cooking duration discovery throughout archive import operations.
  TimeFilter _timeFilter = TimeFilter.all;
  
  /// Current search query for full-text recipe search and discovery.
  /// 
  /// Stores user search input enabling comprehensive recipe search
  /// and content discovery throughout archive import functionality.
  String _searchQuery = '';
  
  /// Import operation state for UI progress indication during batch operations.
  /// 
  /// Indicates active import processing for loading indicators and interaction
  /// control during archive import and batch recipe processing.
  bool _isImporting = false;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout archive import operations and batch processing.
  String? _error;

  // ===== PERFORMANCE CACHING =====

  /// Cached filtered recipes for performance optimization during repeated filtering operations.
  /// 
  /// Stores filtered recipe results enabling performance optimization
  /// and reducing computational overhead during archive browsing.
  List<Recipe>? _cachedFilteredRecipes;
  
  /// Last search query for cache validation and optimization coordination.
  /// 
  /// Tracks previous search state enabling cache invalidation
  /// and performance optimization throughout filtering operations.
  String? _lastSearchQuery;
  
  /// Last time filter for cache validation and optimization coordination.
  /// 
  /// Tracks previous time filter state enabling cache invalidation
  /// and performance optimization throughout filtering operations.
  TimeFilter? _lastTimeFilter;
  
  /// Last selected tags for cache validation and optimization coordination.
  /// 
  /// Tracks previous tag selection state enabling cache invalidation
  /// and performance optimization throughout filtering operations.
  Set<String>? _lastSelectedTags;

  /// Initializes archive import ViewModel with comprehensive service integration and caching preparation.
  /// 
  /// [recipeService] UnifiedRecipeService instance for recipe import operations (optional, uses service locator if not provided)
  /// [searchService] SearchService instance for advanced filtering and search operations (optional, uses service locator if not provided)
  /// 
  /// Establishes archive import infrastructure with service integration, enabling comprehensive
  /// archived recipe functionality with filtering, search, selection, and batch import capabilities.
  /// 
  /// **Initialization Process:**
  /// - UnifiedRecipeService integration for recipe import operations
  /// - SearchService integration for advanced filtering and search functionality
  /// - State initialization for filtering, selection, and caching systems
  /// - Performance optimization preparation with intelligent caching
  ArchiveImportViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
  }) : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
       _searchService = searchService ?? ServiceLocator.get<SearchService>();

  // ===== STATE ACCESSORS =====

  /// Complete archived recipes collection for filtering and import operations.
  /// 
  /// Provides access to full Butlery archived recipe collection enabling
  /// filtering, search, and import coordination throughout archive functionality.
  List<Recipe> get archivedRecipes => archive.archivedRecipes;
  
  /// Filtered recipes collection based on current search and filter criteria.
  /// 
  /// Provides dynamically filtered recipe results based on search query,
  /// selected tags, and time constraints with intelligent caching optimization.
  List<Recipe> get filteredRecipes => _getFilteredRecipes();
  
  /// Selected filtering tags for multi-criteria recipe discovery.
  /// 
  /// Provides immutable access to selected tags enabling filter display
  /// and tag-based recipe filtering coordination.
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);
  
  /// Selected recipe IDs for batch import operations and selection management.
  /// 
  /// Provides immutable access to selected recipes enabling batch operations
  /// and selection state management throughout import functionality.
  Set<String> get selectedRecipeIds => Set.unmodifiable(_selectedRecipeIds);
  
  /// Current time-based filtering criteria for cooking duration constraints.
  /// 
  /// Provides access to active time filter enabling time-based filtering
  /// and cooking duration discovery coordination.
  TimeFilter get timeFilter => _timeFilter;
  
  /// Current search query for full-text recipe search and content discovery.
  /// 
  /// Provides access to active search query enabling search-based filtering
  /// and content discovery coordination throughout archive functionality.
  String get searchQuery => _searchQuery;
  
  /// Import operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether batch import operation is in progress for loading indicators
  /// and user interaction management during archive import processing.
  bool get isImporting => _isImporting;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout archive import operations.
  String? get error => _error;
  
  /// Error state indicator for conditional UI rendering and error handling.
  /// 
  /// Indicates whether error state is active enabling conditional error
  /// display and error recovery functionality coordination.
  bool get hasError => _error != null;

  /// Selected recipes count for batch operations and selection status display.
  /// 
  /// Provides count of selected recipes enabling batch operation validation
  /// and selection status display throughout import functionality.
  int get selectedCount => _selectedRecipeIds.length;
  
  /// Selection availability indicator for conditional UI enabling and batch operations.
  /// 
  /// Indicates whether recipes are selected enabling batch operation buttons
  /// and selection-dependent functionality coordination.
  bool get hasSelection => _selectedRecipeIds.isNotEmpty;
  
  /// Complete selection status indicator for select-all functionality and UI coordination.
  /// 
  /// Indicates whether all filtered recipes are selected enabling select-all toggle
  /// and complete selection status display throughout archive functionality.
  bool get allSelected => _selectedRecipeIds.length == filteredRecipes.length;

  /// Available filtering tags extracted from archived recipe collection for advanced filtering.
  /// 
  /// Analyzes complete archived recipe collection to extract all unique tags
  /// enabling comprehensive tag-based filtering and recipe discovery functionality.
  /// 
  /// **Tag Extraction Process:**
  /// - Complete archive recipe analysis and tag collection
  /// - Unique tag identification and deduplication
  /// - Dynamic tag availability based on current archive content
  /// - Performance optimized tag extraction for large collections
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final tags = archiveImportViewModel.availableTags;
  /// // Display tags for user filtering selection
  /// ```
  Set<String> get availableTags {
    final tags = <String>{};
    for (final recipe in archivedRecipes) {
      if (recipe.tags != null) {
        tags.addAll(recipe.tags!);
      }
    }
    return tags;
  }

  // ===== FILTERING OPERATIONS =====

  /// Updates search query with comprehensive filtering coordination and cache management.
  /// 
  /// [query] New search query for full-text recipe search and content discovery
  /// 
  /// Performs search query update with cache invalidation, selection update,
  /// and UI notification ensuring responsive search functionality and optimal performance.
  /// 
  /// **Search Update Process:**
  /// - Search query state update with validation
  /// - Cache invalidation for performance optimization
  /// - Selection update based on new filtered results
  /// - UI notification and state coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.updateSearch('vegetarisk pasta');
  /// final results = archiveImportViewModel.filteredRecipes;
  /// ```
  void updateSearch(String query) {
    _searchQuery = query;
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  /// Toggles tag filter with comprehensive filtering coordination and cache management.
  /// 
  /// [tag] Tag identifier to toggle in filtering criteria
  /// 
  /// Performs tag filter toggle with cache invalidation, selection update,
  /// and UI notification enabling dynamic multi-criteria filtering functionality.
  /// 
  /// **Tag Toggle Process:**
  /// - Tag presence validation and toggle logic
  /// - Tag filter state update with deduplication
  /// - Cache invalidation for performance optimization
  /// - Selection update based on new filtered results
  /// - UI notification and state coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.toggleTag('vegetarisk');
  /// final activeTags = archiveImportViewModel.selectedTags;
  /// ```
  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  /// Updates time-based filter with comprehensive filtering coordination and cache management.
  /// 
  /// [filter] New time filter criteria for cooking duration constraints
  /// 
  /// Performs time filter update with cache invalidation, selection update,
  /// and UI notification enabling time-based recipe filtering and discovery.
  /// 
  /// **Time Filter Update Process:**
  /// - Time filter criteria validation and state update
  /// - Cache invalidation for performance optimization
  /// - Selection update based on new filtered results
  /// - UI notification and state coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.setTimeFilter(TimeFilter.under30);
  /// final quickRecipes = archiveImportViewModel.filteredRecipes;
  /// ```
  void setTimeFilter(TimeFilter filter) {
    _timeFilter = filter;
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  // ===== SELECTION OPERATIONS =====

  /// Toggles individual recipe selection with comprehensive selection management and state coordination.
  /// 
  /// [recipeId] Unique recipe identifier for selection toggle
  /// 
  /// Performs recipe selection toggle with immediate UI notification enabling
  /// individual recipe selection and batch operation preparation.
  /// 
  /// **Selection Toggle Process:**
  /// - Recipe ID presence validation and toggle logic
  /// - Selection state update with deduplication
  /// - Immediate UI notification and state coordination
  /// - Batch operation enablement based on selection state
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.toggleRecipeSelection('recipe_123');
  /// final isSelected = archiveImportViewModel.selectedRecipeIds.contains('recipe_123');
  /// ```
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
    } else {
      _selectedRecipeIds.add(recipeId);
    }
    notifyListeners();
  }

  /// Toggles complete selection with comprehensive batch selection management and state coordination.
  /// 
  /// Performs bulk selection toggle based on current selection state enabling
  /// efficient batch selection and deselection for import operations.
  /// 
  /// **Bulk Selection Process:**
  /// - Current selection state analysis (all selected vs partial selection)
  /// - Complete selection clearing or bulk selection based on state
  /// - Selection state update with all filtered recipe IDs
  /// - Immediate UI notification and batch operation enablement
  /// 
  /// **Selection Logic:**
  /// - If all filtered recipes selected: Clear all selections
  /// - If partial or no selection: Select all filtered recipes
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.toggleSelectAll();
  /// final allSelected = archiveImportViewModel.allSelected;
  /// ```
  void toggleSelectAll() {
    if (allSelected) {
      _selectedRecipeIds.clear();
    } else {
      _selectedRecipeIds.clear();
      _selectedRecipeIds.addAll(filteredRecipes.map((r) => r.id));
    }
    notifyListeners();
  }

  // ===== IMPORT OPERATIONS =====

  /// Imports selected recipes with comprehensive batch processing and validation.
  /// 
  /// Performs batch import of user-selected recipes with validation, source attribution,
  /// and comprehensive error handling ensuring successful archive recipe restoration.
  /// 
  /// **Selected Import Process:**
  /// 1. Selection validation ensuring recipes are selected
  /// 2. Recipe collection and source attribution preparation
  /// 3. Batch import through UnifiedRecipeService personal operations
  /// 4. Success handling with selection clearing and state update
  /// 5. Comprehensive error handling with Swedish localized messages
  /// 
  /// **Source Attribution**: All imported recipes marked with 'Från Butlerys arkiv'
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // Select recipes first
  /// archiveImportViewModel.toggleRecipeSelection('recipe_123');
  /// 
  /// // Import selected recipes
  /// await archiveImportViewModel.importSelectedRecipes();
  /// if (!archiveImportViewModel.hasError) {
  ///   // Import successful
  /// }
  /// ```
  Future<void> importSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty) {
      _setError('Inga recept valda');
      return;
    }

    _setImporting(true);

    try {
      final toImport =
          archivedRecipes
              .where((r) => _selectedRecipeIds.contains(r.id))
              .map(
                (r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'),
              )
              .toList();

      final result = await _recipeService.personal.addMultipleUnifiedRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        _selectedRecipeIds.clear();
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

  /// Imports all filtered recipes with comprehensive bulk processing and validation.
  /// 
  /// Performs bulk import of all filtered recipes (or complete archive if no filters)
  /// with validation, source attribution, and comprehensive error handling ensuring
  /// successful bulk archive recipe restoration.
  /// 
  /// **Bulk Import Process:**
  /// 1. Recipe collection based on current filters (filtered or complete archive)
  /// 2. Source attribution preparation for all recipes
  /// 3. Bulk import through UnifiedRecipeService personal operations
  /// 4. Success handling with selection clearing and state update
  /// 5. Comprehensive error handling with Swedish localized messages
  /// 
  /// **Import Logic:**
  /// - If filters active: Import only filtered recipes
  /// - If no filters: Import complete archived recipe collection
  /// 
  /// **Source Attribution**: All imported recipes marked with 'Från Butlerys arkiv'
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // Apply filters if needed
  /// archiveImportViewModel.updateSearch('vegetarisk');
  /// archiveImportViewModel.setTimeFilter(TimeFilter.under30);
  /// 
  /// // Import all filtered recipes
  /// await archiveImportViewModel.importAllRecipes();
  /// if (!archiveImportViewModel.hasError) {
  ///   // Bulk import successful
  /// }
  /// ```
  Future<void> importAllRecipes() async {
    _setImporting(true);

    try {
      final toImport =
          (filteredRecipes.isEmpty ? archivedRecipes : filteredRecipes)
              .map(
                (r) => r.copyWith(sourceUrl: 'Från Butlerys arkiv'),
              )
              .toList();
      final result = await _recipeService.personal.addMultipleUnifiedRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        _selectedRecipeIds.clear();
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

  /// Clears error state with comprehensive state cleanup and UI coordination.
  /// 
  /// Performs error state cleanup with immediate UI notification enabling
  /// proper error recovery and user interaction restoration throughout archive import operations.
  /// 
  /// **Error Clearing Process:**
  /// - Error message state reset and cleanup
  /// - Immediate UI notification for error display removal
  /// - Error recovery preparation for continued operations
  /// - State consistency maintenance throughout error handling
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (archiveImportViewModel.hasError) {
  ///   archiveImportViewModel.clearError();
  ///   // Error state cleared, UI updated
  /// }
  /// ```
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clears all filtering and selection state with comprehensive reset and UI coordination.
  /// 
  /// Performs complete filtering and selection state reset including search query,
  /// selected tags, time filter, recipe selection, and cache invalidation with
  /// immediate UI notification enabling fresh archive browsing experience.
  /// 
  /// **Complete Reset Process:**
  /// - Search query clearing and reset
  /// - Selected tags collection clearing
  /// - Time filter reset to 'all' state
  /// - Recipe selection clearing and deselection
  /// - Cache invalidation for performance optimization
  /// - Immediate UI notification and state coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// archiveImportViewModel.clearFilters();
  /// // All filters and selections cleared, showing complete archive
  /// ```
  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    _timeFilter = TimeFilter.all;
    _selectedRecipeIds.clear();
    _invalidateCache();
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  /// Generates filtered recipes collection with comprehensive caching optimization and multi-criteria filtering coordination.
  /// 
  /// Returns filtered recipe collection based on current search query, selected tags,
  /// and time constraints with intelligent caching optimization for performance enhancement.
  /// Performs multi-criteria filtering with SearchService integration ensuring optimal
  /// recipe discovery and browsing experience throughout archive import functionality.
  /// 
  /// **Filtering Process:**
  /// 1. Cache validation and optimization for repeated filtering operations
  /// 2. Base recipe collection preparation from archived recipes
  /// 3. Search query filtering through SearchService full-text search
  /// 4. Tag-based filtering with AND logic for precise recipe matching
  /// 5. Time-based filtering for cooking duration constraints
  /// 6. Result caching and optimization for performance enhancement
  /// 
  /// **Performance Optimization:**
  /// - Intelligent cache validation comparing filter state changes
  /// - Cache hit optimization for repeated filtering with same criteria
  /// - SearchService integration for optimized filtering operations
  /// - Result caching with state tracking for cache invalidation
  /// 
  /// **Filtering Logic:**
  /// - **Search**: Full-text search across recipe content through SearchService
  /// - **Tags**: AND logic - recipes must contain ALL selected tags
  /// - **Time**: Maximum cooking time constraints (under 15/30/60 minutes)
  /// - **Caching**: Results cached until filter criteria change
  List<Recipe> _getFilteredRecipes() {
    // Använd cache om möjligt
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastTimeFilter == _timeFilter &&
        _lastSelectedTags?.toString() == _selectedTags.toString()) {
      return _cachedFilteredRecipes!;
    }

    List<Recipe> results = List.from(archivedRecipes);

    // Sökfilter
    if (_searchQuery.isNotEmpty) {
      results = _searchService.searchRecipes(results, _searchQuery);
    }

    // Tagg-filter: AND-logik
    if (_selectedTags.isNotEmpty) {
      results = _searchService.filterByTags(results, _selectedTags.toList());
    }

    // Tids-filter
    switch (_timeFilter) {
      case TimeFilter.under15:
        results = _searchService.filterByMaxTime(results, 15);
        break;
      case TimeFilter.under30:
        results = _searchService.filterByMaxTime(results, 30);
        break;
      case TimeFilter.under60:
        results = _searchService.filterByMaxTime(results, 60);
        break;
      case TimeFilter.all:
        break;
    }

    // Cacha resultat
    _cachedFilteredRecipes = results;
    _lastSearchQuery = _searchQuery;
    _lastTimeFilter = _timeFilter;
    _lastSelectedTags = Set.from(_selectedTags);

    return results;
  }

  /// Updates recipe selection based on current filter results with comprehensive selection synchronization.
  /// 
  /// Performs selection state synchronization ensuring selected recipes remain valid
  /// after filtering operations by removing selections for recipes no longer matching
  /// current filter criteria, maintaining selection consistency throughout filtering workflow.
  /// 
  /// **Selection Update Process:**
  /// - Current filtered recipe IDs collection and analysis
  /// - Selection validation against current filter results
  /// - Invalid selection removal for recipes not matching filters
  /// - Selection state consistency maintenance throughout filtering operations
  /// 
  /// **Selection Synchronization Logic:**
  /// When filters change, previously selected recipes may no longer match current criteria.
  /// This method ensures selection state remains consistent by removing selections
  /// for recipes that are no longer visible in filtered results.
  void _updateSelection() {
    // Uppdatera selection baserat på nya filter
    final currentRecipeIds = filteredRecipes.map((r) => r.id).toSet();
    _selectedRecipeIds.removeWhere((id) => !currentRecipeIds.contains(id));
  }

  /// Invalidates cached filtered recipes for performance optimization and cache management.
  /// 
  /// Performs cache invalidation ensuring fresh filtering results when filter criteria change.
  /// Clears cached filtered recipes forcing recalculation on next filter operation
  /// enabling accurate filtering results and optimal performance throughout archive browsing.
  /// 
  /// **Cache Invalidation Process:**
  /// - Cached filtered recipes clearing and reset
  /// - Cache state preparation for fresh filtering operations
  /// - Performance optimization through intelligent cache management
  /// - Filter criteria change coordination and cache synchronization
  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }

  /// Sets import operation state with comprehensive UI notification and loading coordination.
  /// 
  /// [value] Import operation state for UI progress indication and interaction control
  /// 
  /// Updates import operation state with immediate UI notification enabling
  /// responsive import progress indication and user interaction management during
  /// batch import operations and archive recipe processing.
  /// 
  /// **Import State Management:**
  /// - Import operation state update and coordination
  /// - Immediate UI notification for loading indicators
  /// - User interaction control during import operations
  /// - Import progress indication and state management
  void _setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  /// Sets error state with comprehensive message coordination and UI notification.
  /// 
  /// [message] Error message for user display and error state management
  /// 
  /// Updates error state with Swedish localized error message and immediate UI notification
  /// enabling proper error display and user feedback throughout archive import operations
  /// and batch processing functionality.
  /// 
  /// **Error State Management:**
  /// - Error message state update with Swedish localization
  /// - Immediate UI notification for error display coordination
  /// - Error recovery preparation and state management
  /// - User feedback coordination throughout import operations
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
