/// Recipe selection ViewModel for multi-selection, search, sharing status tracking, and social distribution.
/// ```dart
/// final vm = RecipeSelectionViewModel(recipeService: ServiceLocator.get<UnifiedRecipeService>());
/// await vm.loadRecipes();
/// vm.toggleRecipeSelection(id);
/// if (vm.hasSelectedRecipes) { final summary = vm.getSelectionSummary(); }
/// // Share selected recipes with comprehensive coordination
/// final shared = await recipeSelectionViewModel.shareSelectedRecipes();
/// if (shared) {
///   final shareMessage = recipeSelectionViewModel.getShareMessage();
///   // Show success message with share details
/// } else if (recipeSelectionViewModel.hasError) {
///   // Handle sharing error
/// }
/// // Monitor sharing progress
/// if (recipeSelectionViewModel.isSharing) {
///   // Show sharing progress indicator
/// }
/// // State monitoring and data access
/// if (recipeSelectionViewModel.isLoading) {
///   // Show loading indicator
/// } else if (recipeSelectionViewModel.hasError) {
///   // Display error message
/// } else if (recipeSelectionViewModel.hasRecipes) {
///   final totalCount = recipeSelectionViewModel.totalCount;
///   final filteredCount = recipeSelectionViewModel.filteredCount;
/// }
/// // Validation and capability checking
/// if (recipeSelectionViewModel.canShare) {
///   // Enable share button
/// }
/// // Refresh functionality for pull-to-refresh
/// await recipeSelectionViewModel.refresh();
/// ```

// lib/viewmodels/recipe_selection_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive recipe selection ViewModel providing advanced recipe sharing through service integration.
/// Manages recipe selection state enabling social recipe sharing with multi-recipe selection, sharing status tracking,
/// search functionality, and friend-targeted distribution while maintaining clean MVVM architecture separation between
/// recipe selection business logic and UI presentation concerns through comprehensive state management.
/// **Core Responsibilities:**
/// - Advanced recipe discovery with search functionality and intelligent filtering capabilities (loading managed by AsyncOperationMixin)
/// - Comprehensive multi-selection management with state tracking and shared recipe awareness
/// - Sharing status coordination with already shared recipe tracking and visual feedback
/// - Social recipe distribution with friend targeting and delivery confirmation
/// - Swedish localized error messages and user feedback coordination throughout selection operations
class RecipeSelectionViewModel extends ChangeNotifier
    with StreamManagementMixin, StateNotifierMixin, AsyncOperationMixin {
  final UnifiedRecipeService _recipeService;

  /// Target friend for recipe sharing and social distribution coordination.
  /// Stores the friend profile for targeted sharing enabling friend-specific
  /// functionality and social recipe distribution management.
  final UserProfile targetFriend;

  /// Initializes recipe selection ViewModel with comprehensive service integration and friend targeting.
  /// [recipeService] UnifiedRecipeService instance for recipe operations and social sharing coordination
  /// [targetFriend] UserProfile instance for friend targeting and social distribution management
  /// Establishes recipe selection infrastructure with service integration and friend targeting, enabling comprehensive
  /// social recipe sharing functionality with multi-selection management, sharing status tracking,
  /// and search capabilities through unified state management and reactive coordination.
  /// **Service Integration:**
  /// - UnifiedRecipeService integration for recipe operations and social sharing functionality
  /// - Friend targeting setup for personalized sharing and social distribution coordination
  /// - State management preparation for selection tracking and sharing status coordination
  /// - Swedish localized error handling preparation for comprehensive user feedback
  RecipeSelectionViewModel({
    required UnifiedRecipeService recipeService,
    required this.targetFriend,
  }) : _recipeService = recipeService;

  /// Complete recipe collection for selection and sharing coordination.
  /// Stores all available recipes enabling recipe discovery, selection functionality,
  /// and comprehensive recipe management throughout selection operations.
  List<Recipe> _allRecipes = [];

  /// Filtered recipe collection based on search criteria for display coordination.
  /// Stores search-filtered recipe results enabling responsive search functionality
  /// and recipe discovery throughout selection interface operations.
  List<Recipe> _filteredRecipes = [];

  /// Current search query for recipe filtering and discovery functionality.
  /// Stores user search input enabling recipe search functionality
  /// and content discovery throughout recipe selection operations.
  String _searchQuery = '';

  /// isLoading, error, hasError provided by StateNotifierMixin

  /// Selected recipe IDs for sharing coordination and selection management.
  /// Stores selected recipes for sharing enabling multi-recipe selection,
  /// sharing coordination, and selection state tracking.
  final Set<String> _selectedRecipeIds = {};

  /// Sharing operation state for UI progress indication during sharing operations.
  /// Operation-specific state maintained separately from general loading (isLoading)
  /// because sharing requires distinct visual treatment from recipe loading.
  /// Indicates active sharing operation for loading indicators and interaction
  /// control during recipe sharing and delivery processes.
  bool _isSharing = false;

  /// Already shared recipe IDs for sharing status tracking and visual feedback.
  /// Stores recipes already shared with target friend enabling sharing status display,
  /// duplicate prevention, and comprehensive sharing state management.
  final Set<String> _alreadySharedRecipeIds = {};

  // Additional getters for dialog compatibility
  bool get hasSelectedRecipes => _selectedRecipeIds.isNotEmpty;
  int get selectedCount => _selectedRecipeIds.length;

  // Search and filtering compatibility methods
  void updateSearch(String query) => updateSearchQuery(query);
  bool get hasSearchResults => _filteredRecipes.isNotEmpty;
  void clearSearch() => updateSearchQuery('');
  int get filteredCount => _filteredRecipes.length;
  int get totalCount => _allRecipes.length;
  void clearSelections() => clearSelection();

  // Getters
  List<Recipe> get allRecipes => _allRecipes;
  List<Recipe> get filteredRecipes => _filteredRecipes;
  String get searchQuery => _searchQuery;

  /// isLoading, error, hasError provided by StateNotifierMixin
  bool get isSharing => _isSharing; // Operation-specific state for sharing
  bool get hasRecipes => _allRecipes.isNotEmpty;
  bool get hasFilteredRecipes => _filteredRecipes.isNotEmpty;
  bool get canShare => _selectedRecipeIds.isNotEmpty && !_isSharing;
  Set<String> get selectedRecipeIds => _selectedRecipeIds;
  Set<String> get alreadySharedRecipeIds => _alreadySharedRecipeIds; // For UI

  /// List of selected recipes (including complete Recipe objects)
  List<Recipe> get selectedRecipes {
    return _allRecipes
        .where((recipe) => _selectedRecipeIds.contains(recipe.id))
        .toList();
  }

  /// Indicator whether the recipe is already shared with selected friend
  bool isRecipeAlreadyShared(String recipeId) =>
      _alreadySharedRecipeIds.contains(recipeId);

  /// Ladda alla recept
  Future<void> loadRecipes() async {
    try {
      await executeNamedOperation('loadRecipes', () async {
        AppLogger.info('📋 Laddar recept för delning...');

        final recipes = _recipeService.recipes;
        _allRecipes = recipes.toList();

        // Ladda redan delade recept
        await _loadSharedRecipes();

        _applyFilters();

        AppLogger.success('✅ ${_allRecipes.length} recept laddade');
      });
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av recept', e);
      setError(AppLocale.current.errorCouldNotLoad('recept'));
    }
  }

  /// Search recipes
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query;
    _applyFilters();
  }

  /// Advanced recipe selection toggling with state management and visual feedback coordination.
  /// [recipeId] Recipe identifier for selection management and state tracking
  /// Toggles recipe selection state enabling multi-recipe selection functionality,
  /// selection state tracking, and comprehensive selection management with visual feedback
  /// and UI coordination through reactive selection state management.
  /// **Selection Features:**
  /// - Multi-recipe selection with state tracking and visual feedback coordination
  /// - Selection state persistence with comprehensive tracking and management
  /// - Visual feedback integration with UI selection indicators and responsive design
  /// - Performance optimized selection with efficient state management and coordination
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
      AppLogger.debug('➖ Avmarkerat recept: $recipeId');
    } else {
      _selectedRecipeIds.add(recipeId);
      AppLogger.debug('➕ Markerat recept: $recipeId');
    }
    notifyListeners();
  }

  /// Recipe selection status checking for UI state management and selection coordination.
  /// [recipeId] Recipe identifier for selection status validation and UI state management
  /// Returns selection status enabling UI selection indicators, checkbox state management,
  /// and comprehensive selection tracking throughout recipe selection interface operations.
  /// **Status Features:**
  /// - Selection state validation with comprehensive tracking and UI coordination
  /// - UI selection indicators with checkbox state management and visual feedback
  /// - Selection tracking with persistent state management and responsive coordination
  bool isRecipeSelected(String recipeId) {
    return _selectedRecipeIds.contains(recipeId);
  }

  /// Comprehensive selection clearing with state management and UI coordination.
  /// Clears all recipe selections enabling selection reset functionality,
  /// UI state management, and comprehensive selection coordination with
  /// visual feedback and responsive state management through reactive clearing.
  /// **Clearing Features:**
  /// - Complete selection reset with state management and visual feedback coordination
  /// - UI state synchronization with selection indicators and responsive design
  /// - Performance optimized clearing with efficient state management and coordination
  void clearSelection() {
    if (_selectedRecipeIds.isNotEmpty) {
      _selectedRecipeIds.clear();
      notifyListeners();
      AppLogger.debug('🧹 Rensat receptval');
    }
  }

  /// Share selected recipes with the friend
  Future<bool> shareSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty || _isSharing) return false;

    _setSharing(true);
    clearError();

    try {
      AppLogger.info(
          '📤 Delar ${_selectedRecipeIds.length} recept med ${targetFriend.displayName}');

      final recipes = selectedRecipes;
      for (final recipe in recipes) {
        final success = await _recipeService.social.shareRecipe(
          recipeId: recipe.id,
          memberIds: [targetFriend.uid],
          memberDisplayNames: {targetFriend.uid: targetFriend.displayName},
        );

        final shareResult = success != null;

        if (!shareResult) {
          throw Exception(AppLocale.current.errorCouldNotUpdate('recept'));
        }
      }

      // Add shared recipes to already-shared list
      _alreadySharedRecipeIds.addAll(_selectedRecipeIds);
      clearSelection(); // Rensa valet efter lyckad delning

      _setSharing(false);
      AppLogger.success(
          '✅ Recept delade med ${targetFriend.displayName.maskedName}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Fel vid delning av recept', e);
      setError(AppLocale.current.errorCouldNotUpdate('recept'));
      _setSharing(false);
      return false;
    }
  }

  /// Advanced filtering and sorting coordination with search criteria and sharing status prioritization.
  /// Applies comprehensive filtering logic combining search criteria with intelligent sorting,
  /// prioritizing unshared recipes and maintaining alphabetical organization for optimal
  /// user experience and efficient recipe discovery through responsive filtering operations.
  /// **Filtering Features:**
  /// - Multi-criteria search across recipe titles, descriptions, and ingredients with comprehensive matching
  /// - Case-insensitive search with performance optimized filtering and responsive results
  /// - Sharing status prioritization with unshared recipes displayed first for optimal user experience
  /// - Alphabetical sorting with consistent recipe organization and predictable interface behavior
  /// - Real-time filtering with immediate results and responsive user interface coordination
  void _applyFilters() {
    var filtered = _allRecipes;

    // Apply text-based search filtering
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((recipe) {
        return recipe.title.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query) ||
            recipe.ingredients
                .any((ingredient) => ingredient.toLowerCase().contains(query));
      }).toList();
    }

    // Apply intelligent sorting: unshared recipes first, then alphabetical
    filtered.sort((a, b) {
      final aShared = _alreadySharedRecipeIds.contains(a.id);
      final bShared = _alreadySharedRecipeIds.contains(b.id);

      if (aShared && !bShared) return 1; // Place shared after unshared
      if (!aShared && bShared) return -1; // Place unshared before shared
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    _filteredRecipes = filtered;
    notifyListeners();

    AppLogger.debug(
        '🔍 Filtrerade recept: ${_filteredRecipes.length}/${_allRecipes.length}');
  }

  /// Update recipes from service
  Future<void> refresh() async {
    AppLogger.debug('🔄 Uppdaterar receptlista...');
    await loadRecipes();
  }

  /// Status information for sharing
  String getSelectionSummary() {
    if (_selectedRecipeIds.isEmpty) {
      return AppLocale.current.selectionNoRecipesSelected;
    }
    return AppLocale.current
        .selectionRecipesSelected(_selectedRecipeIds.length);
  }

  /// Get share message for selected recipes
  String getShareMessage() {
    if (_selectedRecipeIds.isEmpty) return '';

    if (_selectedRecipeIds.length == 1) {
      final recipe = selectedRecipes.first;
      return '${recipe.title} delat med ${targetFriend.displayName}! 🍽️';
    } else {
      return '${_selectedRecipeIds.length} recept delade med ${targetFriend.displayName}! 🍽️';
    }
  }

  /// setLoading, setError, clearError provided by StateNotifierMixin

  /// Sharing operation state management with UI notification coordination.
  /// [sharing] Sharing state for operation-specific progress indication
  /// Updates sharing operation state enabling UI sharing progress indicators,
  /// interaction control, and comprehensive sharing state management throughout
  /// recipe sharing operations with reactive UI coordination.
  void _setSharing(bool sharing) {
    _isSharing = sharing;
    notifyListeners();
  }

  /// Comprehensive shared recipe loading with friend-specific sharing status coordination.
  /// Loads all recipes already shared with target friend enabling sharing status tracking,
  /// duplicate prevention, and comprehensive sharing history management with collaborative
  /// recipe analysis and social data coordination through unified sharing status operations.
  /// **Shared Recipe Loading Features:**
  /// - Comprehensive collaborative recipe analysis with bidirectional sharing detection
  /// - Friend-specific sharing status with targeted relationship validation and tracking
  /// - Social data coordination with member permission analysis and comprehensive validation
  /// - Duplicate prevention with already shared recipe identification and status management
  /// - Error handling with graceful fallback and comprehensive error recovery coordination
  Future<void> _loadSharedRecipes() async {
    try {
      // Get all collaborative recipes in parallel for better performance
      final results = await Future.wait([
        _recipeService.social.getSharedByMe(),
        _recipeService.social.getSharedWithMe(),
      ]);
      final collaborativeRecipes = results[0];
      final sharedWithMeRecipes = results[1];

      final sharedRecipeIds = <String>{};

      // Check recipes shared by current user with target friend
      for (final recipe in collaborativeRecipes) {
        if (recipe.socialData?.memberPermissions != null) {
          final memberIds = recipe.socialData!.memberPermissions!.keys.toSet();
          // If target friend is a member of this recipe, mark as shared
          if (memberIds.contains(targetFriend.uid)) {
            sharedRecipeIds.add(recipe.id);
          }
        }
      }

      // Check recipes shared with current user (bidirectional sharing detection)
      for (final recipe in sharedWithMeRecipes) {
        if (recipe.socialData?.memberPermissions != null) {
          final memberIds = recipe.socialData!.memberPermissions!.keys.toSet();
          if (memberIds.contains(targetFriend.uid)) {
            sharedRecipeIds.add(recipe.id);
          }
        }
      }

      _alreadySharedRecipeIds.clear();
      _alreadySharedRecipeIds.addAll(sharedRecipeIds);

      AppLogger.debug(
          'Found ${sharedRecipeIds.length} recipes already shared with ${targetFriend.displayName}');
    } catch (e) {
      AppLogger.error('Error loading shared recipes', e);
      _alreadySharedRecipeIds.clear();
    }
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
