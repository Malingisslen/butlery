/// Facade/Coordinator for specialized shared content ViewModels.
/// Orchestrates SharedRecipeViewModel, SharedMenuViewModel, SharedShoppingViewModel,
/// SharedContentSearchViewModel, and SocialSharingViewModel providing unified interface.
/// Transformed from 1,965-line monolithic ViewModel to clean coordinator pattern.

// lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_search_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/social_sharing_viewmodel.dart';
// Removed unused model imports - content accessed through ViewModels
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Enumeration for content tabs
enum ContentTab {
  recipes,
  menus,
  shoppingLists,
}

/// Orchestrator ViewModel that coordinates all shared content ViewModels
class SharedContentCoordinatorViewModel extends ChangeNotifier {
  
  // ===== SPECIALIZED VIEWMODELS =====
  
  late final SharedRecipeViewModel _recipeViewModel;
  late final SharedMenuViewModel _menuViewModel;
  late final SharedShoppingViewModel _shoppingViewModel;
  late final SharedContentSearchViewModel _searchViewModel;
  late final SocialSharingViewModel _socialSharingViewModel;

  // ===== STATE VARIABLES =====
  
  /// Current active tab
  ContentTab _currentTab = ContentTab.recipes;
  
  /// Global loading state (when multiple ViewModels are loading)
  bool _isGloballyLoading = false;
  
  /// Global error state
  String? _globalError;
  
  /// Initialization state
  bool _isInitialized = false;
  
  /// Initialization in progress
  bool _isInitializing = false;

  // ===== CONSTRUCTOR =====
  
  SharedContentCoordinatorViewModel({
    SharedRecipeViewModel? recipeViewModel,
    SharedMenuViewModel? menuViewModel,
    SharedShoppingViewModel? shoppingViewModel,
    SharedContentSearchViewModel? searchViewModel,
    SocialSharingViewModel? socialSharingViewModel,
  }) {
    AppLogger.info('🎯 SharedContentCoordinatorViewModel: Starting initialization of orchestration layer');
    _initializeViewModels(
      recipeViewModel: recipeViewModel,
      menuViewModel: menuViewModel,
      shoppingViewModel: shoppingViewModel,
      searchViewModel: searchViewModel,
      socialSharingViewModel: socialSharingViewModel,
    );
    AppLogger.success('✅ SharedContentCoordinatorViewModel: Orchestration layer initialized');
  }

  // ===== GETTERS - VIEWMODEL ACCESS =====
  
  /// Access to recipe ViewModel
  SharedRecipeViewModel get recipeViewModel => _recipeViewModel;
  
  /// Access to menu ViewModel
  SharedMenuViewModel get menuViewModel => _menuViewModel;
  
  /// Access to shopping list ViewModel
  SharedShoppingViewModel get shoppingViewModel => _shoppingViewModel;
  
  /// Access to search ViewModel
  SharedContentSearchViewModel get searchViewModel => _searchViewModel;
  
  /// Access to social sharing ViewModel
  SocialSharingViewModel get socialSharingViewModel => _socialSharingViewModel;

  // ===== GETTERS - COORDINATOR STATE =====
  
  /// Current active tab
  ContentTab get currentTab => _currentTab;
  
  /// Global loading state
  bool get isGloballyLoading => _isGloballyLoading;
  
  /// Global error state
  String? get globalError => _globalError;
  
  /// Has global error
  bool get hasGlobalError => _globalError != null;
  
  /// Initialization state
  bool get isInitialized => _isInitialized;
  
  /// Initialization in progress
  bool get isInitializing => _isInitializing;
  
  /// Any ViewModel is loading
  bool get isAnyViewModelLoading => 
      _recipeViewModel.isLoading || 
      _menuViewModel.isLoading || 
      _shoppingViewModel.isLoading ||
      _searchViewModel.isSearching ||
      _socialSharingViewModel.isSharing;
  
  /// Any ViewModel is operating
  bool get isAnyViewModelOperating =>
      _recipeViewModel.isOperating ||
      _menuViewModel.isOperating ||
      _shoppingViewModel.isOperating ||
      _socialSharingViewModel.isBusy;

  // ===== GETTERS - UNIFIED CONTENT ACCESS =====
  
  /// All shared content across all types
  Map<String, dynamic> get allSharedContent => {
    'recipes': _recipeViewModel.filteredContent,
    'menus': _menuViewModel.filteredContent,
    'shoppingLists': _shoppingViewModel.filteredContent,
  };
  
  /// Total unread count across all content types
  int get totalUnreadCount =>
      _recipeViewModel.unreadCount +
      _menuViewModel.unreadCount +
      _shoppingViewModel.unreadCount;
  
  /// Total content count across all types
  int get totalContentCount =>
      _recipeViewModel.totalCount +
      _menuViewModel.totalCount +
      _shoppingViewModel.totalCount;
  
  /// Has any content across all types
  bool get hasAnyContent =>
      _recipeViewModel.hasContent ||
      _menuViewModel.hasContent ||
      _shoppingViewModel.hasContent;
  
  /// Content counts by type
  Map<ContentTab, int> get contentCounts => {
    ContentTab.recipes: _recipeViewModel.totalCount,
    ContentTab.menus: _menuViewModel.totalCount,
    ContentTab.shoppingLists: _shoppingViewModel.totalCount,
  };
  
  /// Unread counts by type
  Map<ContentTab, int> get unreadCounts => {
    ContentTab.recipes: _recipeViewModel.unreadCount,
    ContentTab.menus: _menuViewModel.unreadCount,
    ContentTab.shoppingLists: _shoppingViewModel.unreadCount,
  };

  // ===== INITIALIZATION =====
  
  void _initializeViewModels({
    SharedRecipeViewModel? recipeViewModel,
    SharedMenuViewModel? menuViewModel,
    SharedShoppingViewModel? shoppingViewModel,
    SharedContentSearchViewModel? searchViewModel,
    SocialSharingViewModel? socialSharingViewModel,
  }) {
    // Initialize content ViewModels
    _recipeViewModel = recipeViewModel ?? SharedRecipeViewModel();
    _menuViewModel = menuViewModel ?? SharedMenuViewModel();
    _shoppingViewModel = shoppingViewModel ?? SharedShoppingViewModel();
    
    // Initialize search ViewModel with content ViewModels
    _searchViewModel = searchViewModel ?? SharedContentSearchViewModel(
      recipeViewModel: _recipeViewModel,
      menuViewModel: _menuViewModel,
      shoppingViewModel: _shoppingViewModel,
    );
    
    // Initialize social sharing ViewModel
    _socialSharingViewModel = socialSharingViewModel ?? SocialSharingViewModel(
      friendsService: ServiceLocator.get<UnifiedFriendsService>(),
      recipeCoordinator: ServiceLocator.get<SocialRecipeCoordinator>(),
      menuCoordinator: ServiceLocator.get<SocialMenuCoordinator>(),
      shoppingCoordinator: ServiceLocator.get<SocialShoppingCoordinator>(),
      menuService: ServiceLocator.get<UnifiedMenuService>(),
      shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
    );
    
    // Add listeners to specialized ViewModels
    _recipeViewModel.addListener(_onViewModelChanged);
    _menuViewModel.addListener(_onViewModelChanged);
    _shoppingViewModel.addListener(_onViewModelChanged);
    _searchViewModel.addListener(_onViewModelChanged);
    _socialSharingViewModel.addListener(_onViewModelChanged);
    
    AppLogger.info('✅ All specialized ViewModels initialized and connected');
  }
  
  /// Initialize all ViewModels and load initial data
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    
    _setInitializing(true);
    AppLogger.info('🔄 Initializing SharedContentCoordinatorViewModel...');
    
    try {
      // All ViewModels should auto-initialize their content
      // We just need to wait for them to complete
      await Future.wait([
        _waitForViewModelInitialization(_recipeViewModel),
        _waitForViewModelInitialization(_menuViewModel),
        _waitForViewModelInitialization(_shoppingViewModel),
      ]);
      
      _isInitialized = true;
      AppLogger.success('✅ SharedContentCoordinatorViewModel initialization completed');
      AppLogger.info('📊 Loaded content counts: ${contentCounts.toString()}');
    } catch (e) {
      _setGlobalError('Initialization failed: $e');
      AppLogger.error('❌ SharedContentCoordinatorViewModel initialization failed: $e');
    } finally {
      _setInitializing(false);
    }
  }
  
  /// Wait for a ViewModel to complete its initialization
  Future<void> _waitForViewModelInitialization(ChangeNotifier viewModel) async {
    // Simple approach: wait for loading state to become false
    // In a more sophisticated implementation, we could add initialization callbacks
    while ((viewModel as dynamic).isLoading == true) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // ===== TAB MANAGEMENT =====
  
  /// Set current active tab
  void setCurrentTab(ContentTab tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      AppLogger.info('📂 Tab changed to: $tab');
      notifyListeners();
    }
  }
  
  /// Get tab title for display
  String getTabTitle(ContentTab tab) {
    switch (tab) {
      case ContentTab.recipes:
        return 'Recept';
      case ContentTab.menus:
        return 'Menyer';
      case ContentTab.shoppingLists:
        return 'Handla';
    }
  }
  
  /// Get tab with unread indicator
  String getTabTitleWithUnreadCount(ContentTab tab) {
    final title = getTabTitle(tab);
    final unreadCount = unreadCounts[tab] ?? 0;
    
    if (unreadCount > 0) {
      return '$title ($unreadCount)';
    }
    
    return title;
  }

  // ===== UNIFIED OPERATIONS =====
  
  /// Refresh all content
  Future<void> refreshAllContent() async {
    AppLogger.info('🔄 Refreshing all shared content...');
    _setGlobalLoading(true);
    
    try {
      await Future.wait([
        _recipeViewModel.refreshContent(),
        _menuViewModel.refreshContent(),
        _shoppingViewModel.refreshContent(),
        _socialSharingViewModel.refreshFriends(),
      ]);
      
      AppLogger.success('✅ All content refreshed');
    } catch (e) {
      _setGlobalError('Failed to refresh content: $e');
      AppLogger.error('❌ Content refresh failed: $e');
    } finally {
      _setGlobalLoading(false);
    }
  }
  
  /// Mark all content as viewed
  Future<void> markAllAsViewed() async {
    AppLogger.info('👁️ Marking all content as viewed...');
    _setGlobalLoading(true);
    
    try {
      await Future.wait([
        _recipeViewModel.markAllAsViewed(),
        _menuViewModel.markAllAsViewed(),
        _shoppingViewModel.markAllAsViewed(),
      ]);
      
      AppLogger.success('✅ All content marked as viewed');
    } catch (e) {
      _setGlobalError('Failed to mark content as viewed: $e');
      AppLogger.error('❌ Mark all as viewed failed: $e');
    } finally {
      _setGlobalLoading(false);
    }
  }
  
  /// Perform unified search across all content types
  Future<void> performUnifiedSearch(String query) async {
    AppLogger.info('🔍 Performing unified search: "$query"');
    _searchViewModel.updateSearchQuery(query);
    
    // The search ViewModel will handle the actual search automatically
    // through its debounced search mechanism
  }
  
  /// Clear all search and filters
  void clearAllSearch() {
    _searchViewModel.clearSearch();
    _searchViewModel.clearFilters();
    AppLogger.info('🧹 Cleared all search and filters');
  }

  // ===== HIGH-LEVEL SHARING OPERATIONS =====

  /// Share recipe with friends
  Future<bool> shareRecipe(String recipeId, {List<String>? friendIds, String? message}) async =>
      _shareContent(recipeId, ShareableContentType.recipe, _getRecipeTitle(recipeId), friendIds, message);

  /// Share menu with friends
  Future<bool> shareMenu(String menuId, {List<String>? friendIds, String? message}) async =>
      _shareContent(menuId, ShareableContentType.menu, _getMenuTitle(menuId), friendIds, message);

  /// Share shopping list with friends
  Future<bool> shareShoppingList(String listId, {List<String>? friendIds, String? message}) async =>
      _shareContent(listId, ShareableContentType.shoppingList, _getShoppingListTitle(listId), friendIds, message);

  /// Generic content sharing helper
  Future<bool> _shareContent(String contentId, ShareableContentType contentType, String? contentTitle, List<String>? friendIds, String? message) async {
    _socialSharingViewModel.prepareForSharing(
      contentType: contentType,
      contentTitle: contentTitle,
      suggestedFriends: friendIds,
    );

    if (message != null) _socialSharingViewModel.updateShareMessage(message);

    final result = await _socialSharingViewModel.shareContent(
      contentId: contentId,
      contentType: contentType,
    );

    return result.success;
  }

  // ===== CONTENT TITLE HELPERS =====

  String? _getRecipeTitle(String recipeId) => _recipeViewModel.content
      .firstWhere((r) => r.id == recipeId, orElse: () => throw Exception())
      .recipeSnapshot.title;

  String? _getMenuTitle(String menuId) => _menuViewModel.content
      .firstWhere((m) => m.id == menuId, orElse: () => throw Exception())
      .menuTitle;

  String? _getShoppingListTitle(String listId) => _shoppingViewModel.content
      .firstWhere((l) => l.id == listId, orElse: () => throw Exception())
      .listName;

  // ===== ANALYTICS =====
  
  /// Get comprehensive analytics across all ViewModels
  Map<String, dynamic> getComprehensiveAnalytics() {
    return {
      'coordinator': {
        'currentTab': _currentTab.toString(),
        'totalUnreadCount': totalUnreadCount,
        'totalContentCount': totalContentCount,
        'hasAnyContent': hasAnyContent,
        'isInitialized': _isInitialized,
      },
      'recipes': _recipeViewModel.getEngagementStats(),
      'menus': _menuViewModel.getEngagementStats(),
      'shoppingLists': _shoppingViewModel.getEngagementStats(),
      'search': {
        'hasActiveQuery': _searchViewModel.hasSearchQuery,
        'resultCount': _searchViewModel.filteredResults.length,
        'hasActiveFilters': _searchViewModel.hasActiveFilters,
      },
      'socialSharing': _socialSharingViewModel.getSharingStats(),
    };
  }

  // ===== STATE MANAGEMENT =====
  
  /// Set global loading state
  void _setGlobalLoading(bool loading) {
    if (_isGloballyLoading != loading) {
      _isGloballyLoading = loading;
      notifyListeners();
    }
  }
  
  /// Set initializing state
  void _setInitializing(bool initializing) {
    if (_isInitializing != initializing) {
      _isInitializing = initializing;
      notifyListeners();
    }
  }
  
  /// Set global error state
  void _setGlobalError(String errorMessage) {
    _globalError = errorMessage;
    notifyListeners();
  }
  
  
  /// Handle changes from specialized ViewModels
  void _onViewModelChanged() {
    // Coordinate state changes from specialized ViewModels
    // This allows us to react to changes and coordinate across ViewModels
    notifyListeners();
  }

  // ===== CLEANUP =====
  
  @override
  void dispose() {
    // Remove listeners from specialized ViewModels
    _recipeViewModel.removeListener(_onViewModelChanged);
    _menuViewModel.removeListener(_onViewModelChanged);
    _shoppingViewModel.removeListener(_onViewModelChanged);
    _searchViewModel.removeListener(_onViewModelChanged);
    _socialSharingViewModel.removeListener(_onViewModelChanged);
    
    // Dispose specialized ViewModels
    _recipeViewModel.dispose();
    _menuViewModel.dispose();
    _shoppingViewModel.dispose();
    _searchViewModel.dispose();
    _socialSharingViewModel.dispose();
    
    AppLogger.info('SharedContentCoordinatorViewModel disposed with all specialized ViewModels');
    super.dispose();
  }
}