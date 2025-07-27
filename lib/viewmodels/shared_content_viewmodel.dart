// lib/viewmodels/shared_content_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';

// Focused modules
import 'package:butlery/viewmodels/shared_content/content_operations.dart';
import 'package:butlery/viewmodels/shared_content/social_content_features.dart';

/// Clean facade for shared content management using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - ContentOperations: Content management (loading, filtering, status)
/// - SocialContentFeatures: Social features (friends, sharing, social interactions)
///
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class SharedContentViewModel extends ChangeNotifier {
  final SocialRecipeService _socialRecipeService;
  final UnifiedFriendsService _friendsService;
  final UnifiedShoppingService _shoppingService;

  // ===== STATE MANAGEMENT =====

  // Search and filtering state
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // Loading and error state
  bool _isLoading = false;
  String? _error;
  bool _isImporting = false;

  // Content state (filtered based on dismiss status)
  List<SharedRecipe> _visibleSharedRecipes = [];
  List<SharedMenu> _visibleSharedMenus = [];

  // Social features state
  bool _isSharing = false;
  List<UserProfile> _availableFriends = [];
  final List<String> _selectedFriendIds = [];
  String _shareMessage = '';

  SharedContentViewModel({
    required SocialRecipeService socialRecipeService,
    required UnifiedFriendsService friendsService,
    required UnifiedShoppingService shoppingService,
  })  : _socialRecipeService = socialRecipeService,
        _friendsService = friendsService,
        _shoppingService = shoppingService {
    _initialize();
  }

  // ===== GETTERS =====

  // Basic state getters
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isImporting => _isImporting;

  // Content getters
  List<SharedRecipe> get visibleSharedRecipes => _visibleSharedRecipes;
  List<SharedMenu> get visibleSharedMenus => _visibleSharedMenus;

  // Content availability checks (delegate to ContentOperations)
  bool get hasSharedContent => ContentOperations.hasSharedContent(
      visibleSharedRecipes, visibleSharedMenus);

  bool get hasFilteredContent => ContentOperations.hasFilteredContent(
      filteredSharedRecipes, filteredSharedMenus);

  // Filtered content (delegate to ContentOperations)
  List<SharedRecipe> get filteredSharedRecipes => 
      ContentOperations.filterRecipes(visibleSharedRecipes, _searchQuery);

  List<SharedMenu> get filteredSharedMenus => 
      ContentOperations.filterMenus(visibleSharedMenus, _searchQuery);

  // Content counts
  int get totalSharedRecipes => visibleSharedRecipes.length;
  int get totalSharedMenus => visibleSharedMenus.length;

  int get unreadRecipesCount => 
      ContentOperations.getUnreadRecipesCount(visibleSharedRecipes);

  int get unreadMenusCount => 
      ContentOperations.getUnreadMenusCount(visibleSharedMenus);

  int get totalUnreadCount => unreadRecipesCount + unreadMenusCount;

  // Social features getters (delegate to SocialContentFeatures)
  bool get isSharing => _isSharing;
  List<UserProfile> get availableFriends => List.unmodifiable(_availableFriends);
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  String get shareMessage => _shareMessage;

  bool get hasFriends => SocialContentFeatures.hasFriends(_availableFriends);
  bool get hasSelectedFriends => SocialContentFeatures.hasSelectedFriends(_selectedFriendIds);
  int get selectedFriendsCount => SocialContentFeatures.getSelectedFriendsCount(_selectedFriendIds);
  bool get canShareShopping => SocialContentFeatures.canShareShopping(_selectedFriendIds, _isSharing);

  List<UserProfile> get selectedFriends => 
      SocialContentFeatures.getSelectedFriends(_availableFriends, _selectedFriendIds);

  // ===== INITIALIZATION =====

  Future<void> _initialize() async {
    await loadSharedContent();
    await _loadFriendsForSharing();

    // Listen to service changes
    _socialRecipeService.addListener(_onServiceDataChanged);
  }

  void _onServiceDataChanged() {
    _updateVisibleContent();
    notifyListeners();
  }

  void _updateVisibleContent() {
    ContentOperations.updateVisibleContent(
      _socialRecipeService,
      (recipes) => _visibleSharedRecipes = recipes,
      (menus) => _visibleSharedMenus = menus,
    );
  }

  // ===== CONTENT OPERATIONS (DELEGATE TO CONTENT_OPERATIONS) =====

  /// Load shared content
  Future<void> loadSharedContent() async {
    await ContentOperations.loadSharedContent(
      _socialRecipeService,
      _setLoading,
      _setError,
      _updateVisibleContent,
    );
  }

  /// Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    AppLogger.info('🔍 Search query updated: "$query"');
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
    AppLogger.info('🧹 Search cleared');
  }

  /// Set tab index
  void setTabIndex(int index) {
    if (index != _currentTabIndex) {
      _currentTabIndex = index;
      notifyListeners();
      AppLogger.info('📑 Tab changed to index: $index');
    }
  }

  // Read status management (delegate to ContentOperations)
  bool isRecipeRead(SharedRecipe sharedRecipe) => 
      ContentOperations.isRecipeRead(sharedRecipe);

  bool isMenuRead(SharedMenu sharedMenu) => 
      ContentOperations.isMenuRead(sharedMenu);

  Future<void> markRecipeAsRead(SharedRecipe sharedRecipe) async {
    await ContentOperations.markRecipeAsRead(
      sharedRecipe,
      _socialRecipeService,
      _visibleSharedRecipes,
      (recipes) => _visibleSharedRecipes = recipes,
      notifyListeners,
      _updateVisibleContent,
    );
  }

  Future<void> markMenuAsRead(SharedMenu sharedMenu) async {
    await ContentOperations.markMenuAsRead(
      sharedMenu,
      _socialRecipeService,
      _visibleSharedMenus,
      (menus) => _visibleSharedMenus = menus,
      notifyListeners,
      _updateVisibleContent,
    );
  }

  // Import status management (delegate to ContentOperations)
  bool isRecipeImported(SharedRecipe sharedRecipe) => 
      ContentOperations.isRecipeImported(sharedRecipe);

  bool isMenuImported(SharedMenu sharedMenu) => 
      ContentOperations.isMenuImported(sharedMenu);

  Future<bool> importSharedRecipe(SharedRecipe sharedRecipe) async {
    return await ContentOperations.importSharedRecipe(
      sharedRecipe,
      _socialRecipeService,
      _visibleSharedRecipes,
      (recipes) => _visibleSharedRecipes = recipes,
      _setImporting,
      _setError,
      notifyListeners,
    );
  }

  Future<bool> importSharedMenu(SharedMenu sharedMenu) async {
    return await ContentOperations.importSharedMenu(
      sharedMenu,
      _socialRecipeService,
      _visibleSharedMenus,
      (menus) => _visibleSharedMenus = menus,
      _setImporting,
      _setError,
      notifyListeners,
    );
  }

  // Dismiss functionality (delegate to ContentOperations)
  Future<bool> dismissSharedRecipe(SharedRecipe sharedRecipe) async {
    return await ContentOperations.dismissSharedRecipe(
      sharedRecipe,
      _socialRecipeService,
      _visibleSharedRecipes,
      (recipes) => _visibleSharedRecipes = recipes,
      _setError,
      notifyListeners,
      _updateVisibleContent,
    );
  }

  Future<bool> dismissSharedMenu(SharedMenu sharedMenu) async {
    return await ContentOperations.dismissSharedMenu(
      sharedMenu,
      _socialRecipeService,
      _visibleSharedMenus,
      (menus) => _visibleSharedMenus = menus,
      _setError,
      notifyListeners,
      _updateVisibleContent,
    );
  }

  Future<bool> undismissSharedRecipe(SharedRecipe sharedRecipe) async {
    return await ContentOperations.undismissSharedRecipe(
      sharedRecipe,
      _socialRecipeService,
      _updateVisibleContent,
      notifyListeners,
    );
  }

  Future<bool> undismissSharedMenu(SharedMenu sharedMenu) async {
    return await ContentOperations.undismissSharedMenu(
      sharedMenu,
      _socialRecipeService,
      _updateVisibleContent,
      notifyListeners,
    );
  }

  // ===== SOCIAL FEATURES (DELEGATE TO SOCIAL_CONTENT_FEATURES) =====

  /// Load friends for sharing functionality
  Future<void> _loadFriendsForSharing() async {
    _availableFriends = await SocialContentFeatures.loadFriendsForSharing(_friendsService);
  }

  /// Toggle friend selection for sharing
  void toggleFriendSelection(String friendId) {
    final updatedSelection = SocialContentFeatures.toggleFriendSelection(
      friendId, _selectedFriendIds);
    
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(updatedSelection);
    notifyListeners();
  }

  /// Select all friends
  void selectAllFriends() {
    final allSelected = SocialContentFeatures.selectAllFriends(_availableFriends);
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(allSelected);
    notifyListeners();
  }

  /// Clear all friend selections
  void clearAllSelections() {
    _selectedFriendIds.clear();
    notifyListeners();
    AppLogger.info('🧹 All friend selections cleared');
  }

  /// Update share message
  void updateShareMessage(String message) {
    _shareMessage = SocialContentFeatures.updateShareMessage(message);
    notifyListeners();
  }

  /// Share shopping list with selected friends
  Future<bool> shareShoppingList(UnifiedShoppingList shoppingList) async {
    final result = await SocialContentFeatures.shareShoppingList(
      shoppingList,
      _selectedFriendIds,
      _shareMessage,
      _shoppingService,
      _setSharing,
      _setError,
      _clearSharingForm,
    );
    
    if (result) {
      notifyListeners();
    }
    
    return result;
  }

  /// Get sharing summary for confirmation
  String getSharingSummary() {
    return SocialContentFeatures.getSharingSummary(_availableFriends, _selectedFriendIds);
  }

  /// Refresh friends list
  Future<void> refreshFriends() async {
    _availableFriends = await SocialContentFeatures.refreshFriends(_friendsService);
    notifyListeners();
  }

  /// Clear sharing form after successful share
  void _clearSharingForm() {
    final clearedForm = SocialContentFeatures.clearSharingForm();
    _shareMessage = clearedForm['shareMessage'] as String;
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(clearedForm['selectedFriendIds'] as List<String>);
  }

  // ===== REFRESH =====

  /// Refresh all content and friends
  Future<void> refresh() async {
    await loadSharedContent();
    await refreshFriends();
  }

  // ===== STATE MANAGEMENT HELPERS =====

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setImporting(bool importing) {
    _isImporting = importing;
    notifyListeners();
  }

  void _setSharing(bool sharing) {
    _isSharing = sharing;
    notifyListeners();
  }

  @override
  void dispose() {
    _socialRecipeService.removeListener(_onServiceDataChanged);
    super.dispose();
  }
}