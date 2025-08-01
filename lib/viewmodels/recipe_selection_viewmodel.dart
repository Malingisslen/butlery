/// Comprehensive recipe selection ViewModel providing advanced recipe sharing and selection management for Flutter applications.
///
/// This module implements sophisticated recipe selection functionality following Single Responsibility Principle,
/// specializing in recipe discovery, multi-selection coordination, sharing status tracking, and social recipe distribution.
/// It provides complete recipe selection infrastructure while maintaining clean separation from UI rendering,
/// recipe data persistence, and complex social sharing business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe selection presentation layer concerns:
/// - **Recipe Discovery Intelligence**: Advanced recipe search with filtering and discovery functionality
/// - **Multi-Selection Management**: Sophisticated recipe selection with state tracking and visual feedback
/// - **Sharing Status Coordination**: Comprehensive shared recipe tracking with availability management
/// - **Social Distribution System**: Recipe sharing operations with friend targeting and delivery confirmation
/// - **Swedish Localization Excellence**: Complete Swedish language support for selection operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by recipe selection views and presentation components)
/// - Recipe data persistence and storage (handled by UnifiedRecipeService and underlying data repositories)
/// - Complex social relationship business logic (handled by social recipe services and relationship infrastructure)
/// - Share delivery infrastructure (handled by social services and communication systems)
///
/// **Recipe Selection ViewModel Features:**
/// - **Advanced Recipe Search**: Intelligent recipe discovery with multi-criteria search and filtering capabilities
/// - **Smart Selection Management**: Multi-recipe selection with state tracking and shared recipe awareness
/// - **Sharing Status Intelligence**: Comprehensive tracking of already shared recipes with visual indicators
/// - **Social Recipe Distribution**: Friend-targeted sharing with delivery confirmation and status tracking
/// - **Swedish Localization**: Complete Swedish language support for selection operations and error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize recipe selection ViewModel with service and friend targeting
/// final recipeSelectionViewModel = RecipeSelectionViewModel(
///   recipeService: ServiceLocator.get<UnifiedRecipeService>(),
///   targetFriend: friendProfile,
/// );
/// 
/// // Load recipes and sharing status
/// await recipeSelectionViewModel.loadRecipes();
/// 
/// // Recipe search and filtering
/// recipeSelectionViewModel.updateSearchQuery('vegetarisk pasta');
/// final searchResults = recipeSelectionViewModel.filteredRecipes;
/// recipeSelectionViewModel.clearSearch(); // Clear search results
/// 
/// // Recipe selection and management  
/// recipeSelectionViewModel.toggleRecipeSelection('recipe_123'); // Select recipe
/// recipeSelectionViewModel.toggleRecipeSelection('recipe_456'); // Select another
/// recipeSelectionViewModel.clearSelection(); // Clear all selections
/// 
/// // Selection state monitoring
/// if (recipeSelectionViewModel.hasSelectedRecipes) {
///   final selectedCount = recipeSelectionViewModel.selectedCount;
///   final selectedRecipes = recipeSelectionViewModel.selectedRecipes;
///   final summary = recipeSelectionViewModel.getSelectionSummary();
/// }
/// 
/// // Shared recipe status checking
/// final isShared = recipeSelectionViewModel.isRecipeAlreadyShared('recipe_789');
/// final sharedRecipeIds = recipeSelectionViewModel.alreadySharedRecipeIds;
/// 
/// // Share selected recipes with comprehensive coordination
/// final shared = await recipeSelectionViewModel.shareSelectedRecipes();
/// if (shared) {
///   final shareMessage = recipeSelectionViewModel.getShareMessage();
///   // Show success message with share details
/// } else if (recipeSelectionViewModel.hasError) {
///   // Handle sharing error
/// }
/// 
/// // Monitor sharing progress
/// if (recipeSelectionViewModel.isSharing) {
///   // Show sharing progress indicator
/// }
/// 
/// // State monitoring and data access
/// if (recipeSelectionViewModel.isLoading) {
///   // Show loading indicator
/// } else if (recipeSelectionViewModel.hasError) {
///   // Display error message
/// } else if (recipeSelectionViewModel.hasRecipes) {
///   final totalCount = recipeSelectionViewModel.totalCount;
///   final filteredCount = recipeSelectionViewModel.filteredCount;
/// }
/// 
/// // Validation and capability checking
/// if (recipeSelectionViewModel.canShare) {
///   // Enable share button
/// }
/// 
/// // Refresh functionality for pull-to-refresh
/// await recipeSelectionViewModel.refresh();
/// ```

// lib/viewmodels/recipe_selection_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive recipe selection ViewModel providing advanced recipe sharing through service integration.
///
/// Manages recipe selection state enabling social recipe sharing with multi-recipe selection, sharing status tracking,
/// search functionality, and friend-targeted distribution while maintaining clean MVVM architecture separation between
/// recipe selection business logic and UI presentation concerns through comprehensive state management.
///
/// **Core Responsibilities:**
/// - Advanced recipe discovery with search functionality and intelligent filtering capabilities
/// - Comprehensive multi-selection management with state tracking and shared recipe awareness
/// - Sharing status coordination with already shared recipe tracking and visual feedback
/// - Social recipe distribution with friend targeting and delivery confirmation
/// - Swedish localized error messages and user feedback coordination throughout selection operations
class RecipeSelectionViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  
  /// Target friend for recipe sharing and social distribution coordination.
  /// 
  /// Stores the friend profile for targeted sharing enabling friend-specific
  /// functionality and social recipe distribution management.
  final UserProfile targetFriend;

  /// Initializes recipe selection ViewModel with comprehensive service integration and friend targeting.
  /// 
  /// [recipeService] UnifiedRecipeService instance for recipe operations and social sharing coordination
  /// [targetFriend] UserProfile instance for friend targeting and social distribution management
  /// 
  /// Establishes recipe selection infrastructure with service integration and friend targeting, enabling comprehensive
  /// social recipe sharing functionality with multi-selection management, sharing status tracking,
  /// and search capabilities through unified state management and reactive coordination.
  /// 
  /// **Service Integration:**
  /// - UnifiedRecipeService integration for recipe operations and social sharing functionality
  /// - Friend targeting setup for personalized sharing and social distribution coordination
  /// - State management preparation for selection tracking and sharing status coordination
  /// - Swedish localized error handling preparation for comprehensive user feedback
  RecipeSelectionViewModel({
    required UnifiedRecipeService recipeService,
    required this.targetFriend,
  })  : _recipeService = recipeService;

  // ===== RECIPE COLLECTION STATE =====

  /// Complete recipe collection for selection and sharing coordination.
  /// 
  /// Stores all available recipes enabling recipe discovery, selection functionality,
  /// and comprehensive recipe management throughout selection operations.
  List<Recipe> _allRecipes = [];
  
  /// Filtered recipe collection based on search criteria for display coordination.
  /// 
  /// Stores search-filtered recipe results enabling responsive search functionality
  /// and recipe discovery throughout selection interface operations.
  List<Recipe> _filteredRecipes = [];
  
  /// Current search query for recipe filtering and discovery functionality.
  /// 
  /// Stores user search input enabling recipe search functionality
  /// and content discovery throughout recipe selection operations.
  String _searchQuery = '';

  // ===== OPERATION STATE MANAGEMENT =====

  /// Loading state for UI progress indication during data operations.
  /// 
  /// Indicates active data loading for loading indicators and interaction
  /// control during recipe loading and initialization processes.
  bool _isLoading = false;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout recipe selection operations and sharing functionality.
  String? _error;
  
  /// Selected recipe IDs for sharing coordination and selection management.
  /// 
  /// Stores selected recipes for sharing enabling multi-recipe selection,
  /// sharing coordination, and selection state tracking.
  final Set<String> _selectedRecipeIds = {};
  
  /// Sharing operation state for UI progress indication during sharing operations.
  /// 
  /// Indicates active sharing operation for loading indicators and interaction
  /// control during recipe sharing and delivery processes.
  bool _isSharing = false;
  
  /// Already shared recipe IDs for sharing status tracking and visual feedback.
  /// 
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
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSharing => _isSharing;
  bool get hasError => _error != null;
  bool get hasRecipes => _allRecipes.isNotEmpty;
  bool get hasFilteredRecipes => _filteredRecipes.isNotEmpty;
  bool get canShare => _selectedRecipeIds.isNotEmpty && !_isSharing;
  Set<String> get selectedRecipeIds => _selectedRecipeIds;
  Set<String> get alreadySharedRecipeIds => _alreadySharedRecipeIds; // ✅ NY: För UI

  /// Lista över valda recept (inklusive kompletta Recipe-objekt)
  List<Recipe> get selectedRecipes {
    return _allRecipes.where((recipe) => _selectedRecipeIds.contains(recipe.id)).toList();
  }

  /// Indikator om receptet redan är delat med vald vän
  bool isRecipeAlreadyShared(String recipeId) => _alreadySharedRecipeIds.contains(recipeId);

  /// Ladda alla recept
  Future<void> loadRecipes() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('📋 Laddar recept för delning...');

      final recipes = _recipeService.recipes;
      _allRecipes = recipes.toList();

      // Ladda redan delade recept
      await _loadSharedRecipes();

      _applyFilters();
      _setLoading(false);

      AppLogger.success('✅ ${_allRecipes.length} recept laddade');
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av recept', e);
      _setError('Kunde inte ladda recept');
      _setLoading(false);
    }
  }

  /// Sök i recept
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query;
    _applyFilters();
  }

  // ===== RECIPE SELECTION OPERATIONS =====

  /// Advanced recipe selection toggling with state management and visual feedback coordination.
  /// 
  /// [recipeId] Recipe identifier for selection management and state tracking
  /// 
  /// Toggles recipe selection state enabling multi-recipe selection functionality,
  /// selection state tracking, and comprehensive selection management with visual feedback
  /// and UI coordination through reactive selection state management.
  /// 
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
  /// 
  /// [recipeId] Recipe identifier for selection status validation and UI state management
  /// 
  /// Returns selection status enabling UI selection indicators, checkbox state management,
  /// and comprehensive selection tracking throughout recipe selection interface operations.
  /// 
  /// **Status Features:**
  /// - Selection state validation with comprehensive tracking and UI coordination
  /// - UI selection indicators with checkbox state management and visual feedback
  /// - Selection tracking with persistent state management and responsive coordination
  bool isRecipeSelected(String recipeId) {
    return _selectedRecipeIds.contains(recipeId);
  }

  /// Comprehensive selection clearing with state management and UI coordination.
  /// 
  /// Clears all recipe selections enabling selection reset functionality,
  /// UI state management, and comprehensive selection coordination with
  /// visual feedback and responsive state management through reactive clearing.
  /// 
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

  /// Dela valda recept med vännen
  Future<bool> shareSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty || _isSharing) return false;

    _setSharing(true);
    _clearError();

    try {
      AppLogger.info('📤 Delar ${_selectedRecipeIds.length} recept med ${targetFriend.displayName}');

      final recipes = selectedRecipes;
      for (final recipe in recipes) {
        final success = await _recipeService.social.shareRecipe(
          recipeId: recipe.id,
          memberIds: [targetFriend.uid],
          memberDisplayNames: {targetFriend.uid: targetFriend.displayName},
        );
        
        final shareResult = success != null;

        if (!shareResult) {
          throw Exception('Kunde inte dela recept: ${recipe.title}');
        }
      }

      // Lägg till delade recept i redan-delat lista
      _alreadySharedRecipeIds.addAll(_selectedRecipeIds);
      clearSelection(); // Rensa valet efter lyckad delning

      _setSharing(false);
      AppLogger.success('✅ Recept delade med ${targetFriend.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Fel vid delning av recept', e);
      _setError('Kunde inte dela recept. Försök igen.');
      _setSharing(false);
      return false;
    }
  }

  // ===== PRIVATE FILTERING AND SORTING OPERATIONS =====

  /// Advanced filtering and sorting coordination with search criteria and sharing status prioritization.
  /// 
  /// Applies comprehensive filtering logic combining search criteria with intelligent sorting,
  /// prioritizing unshared recipes and maintaining alphabetical organization for optimal
  /// user experience and efficient recipe discovery through responsive filtering operations.
  /// 
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
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(query));
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


  /// Uppdatera recept från service
  Future<void> refresh() async {
    AppLogger.debug('🔄 Uppdaterar receptlista...');
    await loadRecipes();
  }

  /// Statusinformation för delning
  String getSelectionSummary() {
    if (_selectedRecipeIds.isEmpty) return 'Inga recept valda';
    if (_selectedRecipeIds.length == 1) return '1 recept valt';
    return '${_selectedRecipeIds.length} recept valda';
  }

  /// Få delningsmeddelande för valda recept
  String getShareMessage() {
    if (_selectedRecipeIds.isEmpty) return '';

    if (_selectedRecipeIds.length == 1) {
      final recipe = selectedRecipes.first;
      return '${recipe.title} delat med ${targetFriend.displayName}! 🍽️';
    } else {
      return '${_selectedRecipeIds.length} recept delade med ${targetFriend.displayName}! 🍽️';
    }
  }

  // ===== PRIVATE STATE MANAGEMENT OPERATIONS =====

  /// Loading state management with UI notification coordination.
  /// 
  /// [loading] Loading state for operation progress indication and interaction control
  /// 
  /// Updates loading state enabling UI progress indicators, interaction control,
  /// and comprehensive loading state management throughout recipe operations
  /// with reactive UI coordination and responsive state management.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Sharing operation state management with UI notification coordination.
  /// 
  /// [sharing] Sharing state for operation progress indication and interaction control
  /// 
  /// Updates sharing operation state enabling UI sharing progress indicators,
  /// interaction control, and comprehensive sharing state management throughout
  /// recipe sharing operations with reactive UI coordination.
  void _setSharing(bool sharing) {
    _isSharing = sharing;
    notifyListeners();
  }

  /// Error state management with Swedish localized message coordination.
  /// 
  /// [message] Swedish localized error message for user feedback and error display
  /// 
  /// Updates error state enabling UI error display, user feedback coordination,
  /// and comprehensive error management throughout recipe selection operations
  /// with Swedish localized error messages and responsive error handling.
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  /// Error state clearing with state reset coordination.
  /// 
  /// Clears current error state enabling error recovery, state reset functionality,
  /// and comprehensive error management with UI error display clearing
  /// and responsive error state coordination.
  void _clearError() {
    _error = null;
  }

  /// Comprehensive shared recipe loading with friend-specific sharing status coordination.
  /// 
  /// Loads all recipes already shared with target friend enabling sharing status tracking,
  /// duplicate prevention, and comprehensive sharing history management with collaborative
  /// recipe analysis and social data coordination through unified sharing status operations.
  /// 
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
      
      AppLogger.debug('Found ${sharedRecipeIds.length} recipes already shared with ${targetFriend.displayName}');
    } catch (e) {
      AppLogger.error('Error loading shared recipes', e);
      _alreadySharedRecipeIds.clear();
    }
  }
}