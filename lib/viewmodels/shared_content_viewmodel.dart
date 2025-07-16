// lib/viewmodels/shared_content_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../services/social_recipe_service.dart';
import '../services/user_service.dart';
import '../services/unified/unified_friends_service.dart';
import '../services/unified/unified_shopping_service.dart';
import '../models/shared_recipe.dart';
import '../models/shared_menu.dart';
import '../models/unified/unified_shopping_list.dart'; // ✅ Lägg till för shopping
import '../models/user_profile.dart';
import '../core/utils/logger.dart';


class SharedContentViewModel extends ChangeNotifier {
  final SocialRecipeService _socialRecipeService;
  final UserService _userService;
  final UnifiedFriendsService _friendsService;
  final UnifiedShoppingService _shoppingService;

  // ==================== BEFINTLIG STATE ====================
  // Search and filtering state
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // Loading and error state
  bool _isLoading = false;
  String? _error;
  bool _isImporting = false;

  // Cached data (filtrerat baserat på dismiss status)
  List<SharedRecipe> _visibleSharedRecipes = [];
  List<SharedMenu> _visibleSharedMenus = [];

  // ==================== NYT: SHOPPING SHARE STATE ====================
  bool _isSharing = false;
  List<UserProfile> _availableFriends = [];
  final List<String> _selectedFriendIds = [];
  String _shareMessage = '';

  SharedContentViewModel({
    required SocialRecipeService socialRecipeService,
    required UserService userService,
    required UnifiedFriendsService friendsService,
    required UnifiedShoppingService shoppingService,
  })  : _socialRecipeService = socialRecipeService,
        _userService = userService,
        _friendsService = friendsService,
        _shoppingService = shoppingService {
    // ✅ Initiera
    _initialize();
  }

  // ==================== BEFINTLIGA GETTERS ====================
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isImporting => _isImporting;

  // Visible content (excluding dismissed items)
  List<SharedRecipe> get visibleSharedRecipes => _visibleSharedRecipes;
  List<SharedMenu> get visibleSharedMenus => _visibleSharedMenus;

  // Content availability checks
  bool get hasSharedContent =>
      visibleSharedRecipes.isNotEmpty || visibleSharedMenus.isNotEmpty;
  bool get hasFilteredContent =>
      filteredSharedRecipes.isNotEmpty || filteredSharedMenus.isNotEmpty;

  // Filtered content baserat på search query
  List<SharedRecipe> get filteredSharedRecipes {
    if (_searchQuery.isEmpty) return visibleSharedRecipes;

    final query = _searchQuery.toLowerCase();
    return visibleSharedRecipes.where((sharedRecipe) {
      final recipe = sharedRecipe.recipeSnapshot;
      return recipe.title.toLowerCase().contains(query) ||
          recipe.description.toLowerCase().contains(query) ||
          sharedRecipe.sharedByDisplayName.toLowerCase().contains(query) ||
          recipe.ingredients
              .any((ingredient) => ingredient.toLowerCase().contains(query)) ||
          (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
              false);
    }).toList();
  }

  List<SharedMenu> get filteredSharedMenus {
    if (_searchQuery.isEmpty) return visibleSharedMenus;

    final query = _searchQuery.toLowerCase();
    return visibleSharedMenus.where((sharedMenu) {
      return sharedMenu.menuTitle.toLowerCase().contains(query) ||
          sharedMenu.sharedByDisplayName.toLowerCase().contains(query) ||
          sharedMenu.menuSummary.toLowerCase().contains(query) ||
          sharedMenu.categories
              .any((category) => category.toLowerCase().contains(query)) ||
          sharedMenu.menuSnapshot.values.any((recipes) => recipes.any(
              (recipe) =>
                  recipe.title.toLowerCase().contains(query) ||
                  recipe.description.toLowerCase().contains(query)));
    }).toList();
  }

  // Counts för UI badges
  int get totalSharedRecipes => visibleSharedRecipes.length;
  int get totalSharedMenus => visibleSharedMenus.length;

  int get unreadRecipesCount {
    final currentUserId = _userService.currentUserProfile?.uid;
    if (currentUserId == null) return 0;

    return visibleSharedRecipes
        .where((recipe) => !recipe.isViewedBy(currentUserId))
        .length;
  }

  int get unreadMenusCount {
    final currentUserId = _userService.currentUserProfile?.uid;
    if (currentUserId == null) return 0;

    return visibleSharedMenus
        .where((menu) => !menu.isViewedBy(currentUserId))
        .length;
  }

  int get totalUnreadCount => unreadRecipesCount + unreadMenusCount;

  // ==================== NYA GETTERS FÖR SHOPPING SHARE ====================
  bool get isSharing => _isSharing;
  List<UserProfile> get availableFriends =>
      List.unmodifiable(_availableFriends);
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  String get shareMessage => _shareMessage;

  bool get hasFriends => _availableFriends.isNotEmpty;
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;
  int get selectedFriendsCount => _selectedFriendIds.length;
  bool get canShareShopping => hasSelectedFriends && !_isSharing;

  List<UserProfile> get selectedFriends {
    return _availableFriends
        .where((friend) => _selectedFriendIds.contains(friend.uid))
        .toList();
  }

  // ==================== BEFINTLIGA METODER (OFÖRÄNDRADE) ====================

  Future<void> _initialize() async {
    await loadSharedContent();
    await _loadFriendsForSharing(); // ✅ Ladda vänner för shopping share

    // Listen to service changes
    _socialRecipeService.addListener(_onServiceDataChanged);
  }

  void _onServiceDataChanged() {
    _updateVisibleContent();
    notifyListeners();
  }

  void _updateVisibleContent() {
    final currentUserId = _userService.currentUserProfile?.uid;
    if (currentUserId == null) {
      _visibleSharedRecipes = [];
      _visibleSharedMenus = [];
      return;
    }

    _visibleSharedRecipes =
        _socialRecipeService.getVisibleSharedRecipes(currentUserId);

    _visibleSharedMenus =
        _socialRecipeService.getVisibleSharedMenus(currentUserId);

    AppLogger.info(
        '👁️ Visible content updated: ${_visibleSharedRecipes.length} recept, ${_visibleSharedMenus.length} menyer');
  }

  Future<void> loadSharedContent() async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 Loading shared content...');

      await _socialRecipeService.refresh();
      _updateVisibleContent();

      AppLogger.success('✅ Shared content loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load shared content', e);
      _setError('Kunde inte ladda delat innehåll: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Search functionality
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    AppLogger.info('🔍 Search query updated: "$query"');
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
    AppLogger.info('🧹 Search cleared');
  }

  // Tab management
  void setTabIndex(int index) {
    if (index != _currentTabIndex) {
      _currentTabIndex = index;
      notifyListeners();
      AppLogger.info('📑 Tab changed to index: $index');
    }
  }

  // ==================== NYA METODER FÖR SHOPPING SHARE ====================

  /// ✅ Ladda vänner för shopping share functionality
  Future<void> _loadFriendsForSharing() async {
    try {
      _availableFriends = _friendsService.management.getAllFriends();
      AppLogger.info(
          '👥 Laddade ${_availableFriends.length} vänner för shopping share');
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänner för shopping share', e);
    }
  }

  /// ✅ Toggle friend selection för shopping share
  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
    AppLogger.info(
        '👤 Friend selection toggled: $friendId, selected: ${_selectedFriendIds.length}');
  }

  /// ✅ Select all friends
  void selectAllFriends() {
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(_availableFriends.map((f) => f.uid));
    notifyListeners();
    AppLogger.info('👥 All friends selected: ${_selectedFriendIds.length}');
  }

  /// ✅ Clear all selections
  void clearAllSelections() {
    _selectedFriendIds.clear();
    notifyListeners();
    AppLogger.info('🧹 All friend selections cleared');
  }

  /// ✅ Update share message
  void updateShareMessage(String message) {
    _shareMessage = message.trim();
    notifyListeners();
  }

  /// ✅ HUVUDMETOD: Share shopping list with selected friends
  Future<bool> shareShoppingList(UnifiedShoppingList shoppingList) async {
    if (!canShareShopping) {
      _setError('Kan inte dela - välj minst en vän');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      AppLogger.info(
          '🛒 Delar inköpslista "${shoppingList.name}" med ${_selectedFriendIds.length} vänner');

      // Konvertera UnifiedShoppingList till shareData format
      final shareData = {
        'type': 'shopping_list',
        'listId': shoppingList.id,
        'listName': shoppingList.name,
        'itemCount': shoppingList.totalItems,
        'items': shoppingList.items
            .map((item) => {
                  'name': item.name,
                  'amount': item.amount,
                  'unit': item.unit,
                  'category': item.category,
                  'bought': item.bought,
                })
            .toList(),
        'message': _shareMessage.isNotEmpty
            ? _shareMessage
            : 'Kolla in min inköpslista!',
        'sharedAt': DateTime.now().toIso8601String(),
      };
      
      AppLogger.debug('Share data prepared: ${shareData['itemCount']} items');

      // Dela med varje vald vän via UnifiedShoppingService
      bool allSuccessful = true;
      for (final friendId in _selectedFriendIds) {
        try {
          final success = await _shoppingService.sharing.shareListWithFriend(
            shoppingList.id,
            friendId,
          );
          if (success) {
            AppLogger.info('   ✅ Delad med vän: $friendId');
          } else {
            AppLogger.error('   ❌ Misslyckades med vän $friendId', 'Sharing failed');
            allSuccessful = false;
          }
        } catch (e) {
          AppLogger.error('   ❌ Misslyckades med vän $friendId', e);
          allSuccessful = false;
        }
      }

      if (allSuccessful) {
        // Rensa formulär efter lyckad delning
        _clearSharingForm();
        AppLogger.success('🎉 Shopping list delning slutförd framgångsrikt');
        return true;
      } else {
        _setError('Vissa delningar misslyckades');
        return false;
      }
    } catch (e) {
      _setError('Misslyckades med delning: $e');
      AppLogger.error('❌ Shopping list delning misslyckades', e);
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// ✅ Clear sharing form after successful share
  void _clearSharingForm() {
    _shareMessage = '';
    _selectedFriendIds.clear();
    // Don't notify here, calling method will notify
  }

  /// ✅ Refresh friends list
  Future<void> refreshFriends() async {
    AppLogger.info('🔄 Refreshing friends for shopping share');
    await _loadFriendsForSharing();
    notifyListeners();
  }

  /// ✅ Get sharing summary for confirmation
  String getSharingSummary() {
    final friendNames = selectedFriends.map((f) => f.displayName).join(', ');
    return 'Dela med: $friendNames';
  }

  // ==================== BEFINTLIGA METODER FÖR RECIPES/MENUS (OFÖRÄNDRADE) ====================

  // Read status management
  bool isRecipeRead(SharedRecipe sharedRecipe) {
    final currentUserId = _userService.currentUserProfile?.uid;
    return currentUserId != null && sharedRecipe.isViewedBy(currentUserId);
  }

  bool isMenuRead(SharedMenu sharedMenu) {
    final currentUserId = _userService.currentUserProfile?.uid;
    return currentUserId != null && sharedMenu.isViewedBy(currentUserId);
  }

  Future<void> markRecipeAsRead(SharedRecipe sharedRecipe) async {
    final currentUserId = _userService.currentUserProfile?.uid;
    if (currentUserId == null || sharedRecipe.isViewedBy(currentUserId)) {
      return;
    }

    try {
      final index =
          _visibleSharedRecipes.indexWhere((r) => r.id == sharedRecipe.id);
      if (index >= 0) {
        _visibleSharedRecipes[index] = sharedRecipe.markViewedBy(currentUserId);
        notifyListeners();
      }

      await _socialRecipeService.markSharedRecipeAsViewed(
          sharedRecipe.id, currentUserId);

      AppLogger.info(
          '✅ Recipe marked as read: ${sharedRecipe.recipeSnapshot.title}');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as read', e);
      _updateVisibleContent();
      notifyListeners();
    }
  }

  Future<void> markMenuAsRead(SharedMenu sharedMenu) async {
    final currentUserId = _userService.currentUserProfile?.uid;
    if (currentUserId == null || sharedMenu.isViewedBy(currentUserId)) {
      return;
    }

    try {
      final index =
          _visibleSharedMenus.indexWhere((m) => m.id == sharedMenu.id);
      if (index >= 0) {
        _visibleSharedMenus[index] = sharedMenu.markViewedBy(currentUserId);
        notifyListeners();
      }

      await _socialRecipeService.markSharedMenuAsViewed(
          sharedMenu.id, currentUserId);

      AppLogger.info('✅ Menu marked as read: ${sharedMenu.menuTitle}');
    } catch (e) {
      AppLogger.error('Failed to mark menu as read', e);
      _updateVisibleContent();
      notifyListeners();
    }
  }

  // Import status management
  bool isRecipeImported(SharedRecipe sharedRecipe) {
    final currentUserId = _userService.currentUserProfile?.uid;
    return currentUserId != null && sharedRecipe.isImportedBy(currentUserId);
  }

  bool isMenuImported(SharedMenu sharedMenu) {
    final currentUserId = _userService.currentUserProfile?.uid;
    return currentUserId != null && sharedMenu.isImportedBy(currentUserId);
  }

  // Import functionality
  Future<bool> importSharedRecipe(SharedRecipe sharedRecipe) async {
    try {
      _setImporting(true);
      _clearError();

      final success =
          await _socialRecipeService.importSharedRecipe(sharedRecipe.id);

      if (success) {
        final currentUserId = _userService.currentUserProfile?.uid;
        if (currentUserId != null) {
          final index =
              _visibleSharedRecipes.indexWhere((r) => r.id == sharedRecipe.id);
          if (index >= 0) {
            _visibleSharedRecipes[index] =
                sharedRecipe.markImportedBy(currentUserId);
            notifyListeners();
          }
        }

        AppLogger.success(
            '✅ Recipe imported: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to import recipe', e);
      _setError('Kunde inte importera recept: ${e.toString()}');
      return false;
    } finally {
      _setImporting(false);
    }
  }

  Future<bool> importSharedMenu(SharedMenu sharedMenu) async {
    try {
      _setImporting(true);
      _clearError();

      final success =
          await _socialRecipeService.importSharedMenu(sharedMenu.id);

      if (success) {
        final currentUserId = _userService.currentUserProfile?.uid;
        if (currentUserId != null) {
          final index =
              _visibleSharedMenus.indexWhere((m) => m.id == sharedMenu.id);
          if (index >= 0) {
            _visibleSharedMenus[index] =
                sharedMenu.markImportedBy(currentUserId);
            notifyListeners();
          }
        }

        AppLogger.success('✅ Menu imported: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to import menu', e);
      _setError('Kunde inte importera meny: ${e.toString()}');
      return false;
    } finally {
      _setImporting(false);
    }
  }

  // Dismiss functionality
  Future<bool> dismissSharedRecipe(SharedRecipe sharedRecipe) async {
    try {
      _clearError();

      _visibleSharedRecipes.removeWhere((r) => r.id == sharedRecipe.id);
      notifyListeners();

      final success =
          await _socialRecipeService.dismissSharedRecipe(sharedRecipe.id);

      if (!success) {
        _updateVisibleContent();
        notifyListeners();

        if (_socialRecipeService.hasError) {
          _setError(_socialRecipeService.error!);
        }
      } else {
        AppLogger.success(
            '✅ Recipe dismissed: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to dismiss recipe', e);
      _setError('Kunde inte dölja recept: ${e.toString()}');

      _updateVisibleContent();
      notifyListeners();

      return false;
    }
  }

  Future<bool> dismissSharedMenu(SharedMenu sharedMenu) async {
    try {
      _clearError();

      _visibleSharedMenus.removeWhere((m) => m.id == sharedMenu.id);
      notifyListeners();

      final success =
          await _socialRecipeService.dismissSharedMenu(sharedMenu.id);

      if (!success) {
        _updateVisibleContent();
        notifyListeners();

        if (_socialRecipeService.hasError) {
          _setError(_socialRecipeService.error!);
        }
      } else {
        AppLogger.success('✅ Menu dismissed: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to dismiss menu', e);
      _setError('Kunde inte dölja meny: ${e.toString()}');

      _updateVisibleContent();
      notifyListeners();

      return false;
    }
  }

  Future<bool> undismissSharedRecipe(SharedRecipe sharedRecipe) async {
    try {
      final success =
          await _socialRecipeService.undismissSharedRecipe(sharedRecipe.id);

      if (success) {
        _updateVisibleContent();
        notifyListeners();

        AppLogger.success(
            '✅ Recipe restored: ${sharedRecipe.recipeSnapshot.title}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to restore recipe', e);
      return false;
    }
  }

  Future<bool> undismissSharedMenu(SharedMenu sharedMenu) async {
    try {
      final success =
          await _socialRecipeService.undismissSharedMenu(sharedMenu.id);

      if (success) {
        _updateVisibleContent();
        notifyListeners();

        AppLogger.success('✅ Menu restored: ${sharedMenu.menuTitle}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to restore menu', e);
      return false;
    }
  }

  // Refresh functionality
  Future<void> refresh() async {
    await loadSharedContent();
    await refreshFriends(); // ✅ Refresh friends också
  }

  // ==================== HELPER METHODS ====================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
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
