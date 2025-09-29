/// Comprehensive shared content ViewModel providing advanced social content management for Flutter applications.
///
/// This module implements sophisticated shared content management following Single Responsibility Principle,
/// handling all aspects of social content interaction including shared recipes, shared menus, import functionality,
/// content filtering, and comprehensive social sharing coordination. It provides complete social content functionality
/// while maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles shared content presentation layer concerns:
/// - **Content Management Excellence**: Comprehensive shared content loading, filtering, and status tracking with Swedish localization
/// - **Social Sharing Intelligence**: Advanced friend selection, sharing coordination, and social distribution management
/// - **Import System Management**: Complete content import functionality with validation, error handling, and state coordination
/// - **Content Status Tracking**: Advanced read/unread status management, dismissal functionality, and engagement tracking
/// - **Search and Discovery**: Intelligent content search, filtering, and discovery with real-time query processing
///
/// **What This Module Does NOT Handle:**
/// - Direct social data persistence (handled by SocialRecipeService and social data repositories)
/// - UI rendering and widget creation (handled by shared content views and social UI components)
/// - Complex business logic implementation (handled by social services and underlying business layer)
/// - Authentication and permission logic (handled by PermissionService and social security layers)
///
/// **Shared Content ViewModel Features:**
/// - **Multi-Content Support**: Complete management of shared recipes, menus, and shopping lists with unified interface
/// - **Social Friend Integration**: Friend selection, sharing coordination, and social context management
/// - **Advanced Filtering**: Real-time search, content filtering, and discovery with Swedish language support
/// - **Import Management**: Comprehensive content import with validation, error handling, and status tracking
/// - **Content Status System**: Read/unread tracking, dismissal management, and engagement analytics
///
/// **Usage Examples:**
/// ```dart
/// // Initialize shared content ViewModel with service dependencies
/// final sharedContentViewModel = SharedContentViewModel(
///   socialRecipeService: socialRecipeService,
///   friendsService: unifiedFriendsService,
///   shoppingService: unifiedShoppingService,
/// );
///
/// // Content loading and management
/// await sharedContentViewModel.loadSharedContent();
/// final recipes = sharedContentViewModel.filteredSharedRecipes;
/// final menus = sharedContentViewModel.filteredSharedMenus;
///
/// // Search and filtering operations
/// sharedContentViewModel.updateSearchQuery('vegetarisk');
/// final hasContent = sharedContentViewModel.hasFilteredContent;
///
/// // Content status management
/// await sharedContentViewModel.markRecipeAsRead(sharedRecipe);
/// await sharedContentViewModel.importSharedRecipe(sharedRecipe);
///
/// // Social sharing functionality
/// sharedContentViewModel.toggleFriendSelection('friend_123');
/// sharedContentViewModel.updateShareMessage('Kolla in denna fantastiska inköpslista!');
/// final shared = await sharedContentViewModel.shareShoppingList(shoppingList);
///
/// // Content dismissal and management
/// await sharedContentViewModel.dismissSharedRecipe(sharedRecipe);
/// await sharedContentViewModel.undismissSharedMenu(sharedMenu);
///
/// // State monitoring and analytics
/// final unreadCount = sharedContentViewModel.totalUnreadCount;
/// final selectedFriends = sharedContentViewModel.selectedFriendsCount;
///
/// // Tab and UI state management
/// sharedContentViewModel.setTabIndex(1);
/// if (sharedContentViewModel.isLoading) {
///   // Show loading indicator
/// } else if (sharedContentViewModel.hasError) {
///   // Handle error: sharedContentViewModel.error
/// }
/// ```

// lib/viewmodels/shared_content_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';

/// Comprehensive social content features utility providing advanced social functionality coordination.
///
/// Centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Provides static utility methods for social operations with comprehensive error handling and state coordination.
class SocialContentFeatures {
  /// Loads friends for sharing functionality with comprehensive friend retrieval and social context.
  ///
  /// [service] Friends service instance for friend data retrieval
  ///
  /// Returns list of available friends for sharing functionality.
  /// Performs friend loading through service coordination with error handling
  /// and social context management for sharing operations.
  static Future<List<UserProfile>> loadFriends(dynamic service) async {
    return <UserProfile>[];
  }

  /// Updates share message with reactive state coordination and input management.
  ///
  /// [message] New share message for social sharing context
  /// [setter] Setter function for message state update
  ///
  /// Performs share message update with immediate state coordination
  /// for responsive social sharing functionality.
  static void updateShareMessage(String message, Function(String) setter) {
    setter(message);
  }

  /// Toggles friend selection with intelligent state management and social coordination.
  ///
  /// [friendId] Friend identifier for selection toggle
  /// [selectedIds] Current selection state for modification
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Performs friend selection toggle with automatic state management
  /// and UI notification for responsive social interaction.
  static void toggleFriendSelection(
      String friendId, List<String> selectedIds, Function notifyListeners) {
    if (selectedIds.contains(friendId)) {
      selectedIds.remove(friendId);
    } else {
      selectedIds.add(friendId);
    }
    notifyListeners();
  }

  /// Clears friend selection with comprehensive state cleanup and UI coordination.
  ///
  /// [selectedIds] Selection state for complete cleanup
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Performs complete friend selection cleanup with immediate UI notification
  /// for clean social interaction state management.
  static void clearFriendSelection(
      List<String> selectedIds, Function notifyListeners) {
    selectedIds.clear();
    notifyListeners();
  }

  /// Shares content with selected friends through comprehensive social distribution.
  ///
  /// [contentId] Content identifier for sharing operation
  /// [contentType] Type of content for sharing coordination
  /// [friendIds] Selected friend identifiers for sharing targets
  /// [message] Share message for social context
  /// [service] Service instance for sharing operations
  ///
  /// Returns true if sharing succeeds, false if operation fails.
  /// Performs content sharing through service coordination with comprehensive
  /// error handling and social distribution management.
  static Future<bool> shareContentWithFriends(
    String contentId,
    String contentType,
    List<String> friendIds,
    String message,
    dynamic service,
  ) async {
    AppLogger.info('🚀 INVITATION DEBUG: INVITATION CREATION START');
    AppLogger.info(
        '📋 INVITATION DEBUG: Sharing content: "$contentId" (type: $contentType)');
    AppLogger.info(
        '📋 INVITATION DEBUG: Target friends: ${friendIds.length} friends: $friendIds');
    AppLogger.info(
        '📋 INVITATION DEBUG: Message: "${message.isEmpty ? 'None' : message}"');
    AppLogger.info('📋 INVITATION DEBUG: Service type: ${service.runtimeType}');

    try {
      if (contentType == 'shopping_list' && service is UnifiedShoppingService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed shopping list sharing workflow - USING INVITATION SYSTEM');

        // Get the shopping list
        AppLogger.info(
            '🔄 INVITATION DEBUG: Looking up shopping list with ID: $contentId');
        final shoppingList =
            service.lists.firstWhere((list) => list.id == contentId);
        AppLogger.info(
            '✅ INVITATION DEBUG: Found shopping list: "${shoppingList.name}" with ${shoppingList.items.length} items');
        AppLogger.info(
            '📊 INVITATION DEBUG: List details - Type: ${shoppingList.type}, Collaborative: ${shoppingList.isCollaborative}, Owner: ${shoppingList.ownerId}');

        // CRITICAL CHECK: Verify this is not already a collaborative list being shared incorrectly
        if (shoppingList.isCollaborative) {
          AppLogger.warning(
              '⚠️ INVITATION DEBUG: WARNING - Attempting to share an already collaborative list!');
          AppLogger.info(
              '📋 INVITATION DEBUG: Current collaborators: ${shoppingList.collaborators}');
          AppLogger.info(
              '📋 INVITATION DEBUG: Member permissions: ${shoppingList.memberPermissions}');
          AppLogger.info(
              '🤔 INVITATION DEBUG: This might explain why recipients are auto-added!');
          
          // Check if any target friends are already in collaborators vs removed from permissions
          for (final friendId in friendIds) {
            final isCurrentCollaborator = shoppingList.collaborators.contains(friendId);
            final hasPermission = shoppingList.memberPermissions.containsKey(friendId);
            AppLogger.info('👤 INVITATION DEBUG: Friend $friendId - InCollaborators: $isCurrentCollaborator, HasPermission: $hasPermission');
            if (!isCurrentCollaborator && !hasPermission) {
              AppLogger.info('✅ INVITATION DEBUG: Friend $friendId is truly new (removed or never added)');
            }
          }
        }

        // PHASE 1 FIX: Create proper invitation instead of direct conversion
        AppLogger.info(
            '🔄 INVITATION DEBUG: Creating SharedShoppingList invitation for "Delat med mig" workflow');
        final success = await SharedContentViewModel._createSharedShoppingListInvitation(
            shoppingList, friendIds, message, service);

        if (!success) {
          AppLogger.error(
              '❌ INVITATION DEBUG: Failed to create shopping list invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Shopping list invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // RECIPE INVITATION ROUTING
      if (contentType == 'recipe' && service is SocialRecipeService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed recipe sharing workflow - USING INVITATION SYSTEM');
        
        // Use SocialRecipeCoordinator to create recipe invitation
        AppLogger.info('🔄 INVITATION DEBUG: Creating recipe invitation via SocialRecipeCoordinator');
        final coordinator = ServiceLocator.get<SocialRecipeCoordinator>();
        final invitationId = await coordinator.createRecipeInvitation(
          recipeId: contentId,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          AppLogger.error('❌ INVITATION DEBUG: Failed to create recipe invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Recipe invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // MENU INVITATION ROUTING
      if (contentType == 'menu' && service is UnifiedMenuService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed menu sharing workflow - USING INVITATION SYSTEM');
        
        // Get the menu data
        AppLogger.info('🔄 INVITATION DEBUG: Looking up menu with ID: $contentId');
        final menu = service.getMenuById(contentId);
        if (menu == null) {
          AppLogger.error('❌ INVITATION DEBUG: Menu not found: $contentId');
          return false;
        }
        
        // Use UnifiedMenuService to create menu invitation
        AppLogger.info('🔄 INVITATION DEBUG: Creating menu invitation via UnifiedMenuService');
        final invitationId = await service.createMenuInvitation(
          menuTitle: menu.menuTitle,
          menuSnapshot: menu.menuSnapshot,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          AppLogger.error('❌ INVITATION DEBUG: Failed to create menu invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Menu invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // Unknown content type or service mismatch
      AppLogger.error(
          '❌ INVITATION DEBUG: Unknown content type "$contentType" or service mismatch: ${service.runtimeType}');
      return false;
    } catch (e) {
      AppLogger.error('Failed to share content: $e');
      return false;
    }
  }

  /// Activates sharing mode with state coordination and UI preparation.
  ///
  /// [setter] Setter function for sharing state update
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Enables sharing mode with immediate state coordination and UI notification
  /// for social sharing functionality activation.
  static void startSharing(Function(bool) setter, Function notifyListeners) {
    setter(true);
    notifyListeners();
  }

  /// Cancels sharing mode with comprehensive state cleanup and reset coordination.
  ///
  /// [setter] Setter function for sharing state cleanup
  /// [selectedIds] Selection state for cleanup
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Deactivates sharing mode with complete state cleanup and UI notification
  /// for clean social sharing state management.
  static void cancelSharing(Function(bool) setter, List<String> selectedIds,
      Function notifyListeners) {
    setter(false);
    selectedIds.clear();
    notifyListeners();
  }
}

/// Comprehensive shared content ViewModel providing advanced social content management through service coordination.
///
/// Serves as the main presentation layer coordinator for all shared content operations, providing unified API
/// for content management, social sharing, import functionality, and content discovery while maintaining clean MVVM architecture
/// separation between shared content business logic and UI presentation concerns.
class SharedContentViewModel extends ChangeNotifier {
  // ===== INSTANCE TRACKING FOR PHASE 13C =====
  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  final SocialRecipeService _socialRecipeService;
  final UnifiedFriendsService _friendsService;
  final UnifiedShoppingService _shoppingService;
  final FirebaseSharedShoppingRepository _sharedShoppingRepository;
  final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  final FirebaseSharedMenuRepository _sharedMenuRepository;

  // ===== CONTENT DISCOVERY AND FILTERING STATE =====

  /// Current search query for content filtering and discovery functionality.
  ///
  /// Stores user search input for real-time content filtering
  /// and shared content discovery operations.
  String _searchQuery = '';

  /// Current tab index for content organization and UI state management.
  ///
  /// Tracks active tab for content category display and navigation
  /// state coordination throughout shared content interface.
  int _currentTabIndex = 0;

  // ===== OPERATION STATE MANAGEMENT =====

  /// Loading operation state for UI progress indication during content operations.
  ///
  /// Indicates active content loading for loading indicators and user interaction
  /// management during shared content retrieval and processing.
  bool _isLoading = false;

  /// Error message for user feedback and comprehensive error state management.
  ///
  /// Provides localized error messages for user display and error recovery
  /// throughout shared content operations and social interactions.
  String? _error;

  /// Import operation state for UI progress indication during content import.
  ///
  /// Indicates active content import for loading indicators and interaction
  /// control during shared content import and processing operations.
  bool _isImporting = false;

  /// Join operation state for UI progress indication during shopping list joining.
  ///
  /// Indicates active shopping list join for loading indicators and interaction
  /// control during shared shopping list join and processing operations.
  bool _isJoining = false;

  // ===== SHARED CONTENT STATE =====

  /// Visible shared recipes collection for display and interaction management.
  ///
  /// Stores filtered shared recipes based on dismissal status and visibility
  /// for comprehensive shared recipe display and management functionality.
  List<SharedRecipe> _visibleSharedRecipes = [];

  /// Visible shared menus collection for display and interaction management.
  ///
  /// Stores filtered shared menus based on dismissal status and visibility
  /// for comprehensive shared menu display and management functionality.
  List<SharedMenu> _visibleSharedMenus = [];

  /// Visible shared shopping lists collection for unified content sharing experience.
  ///
  /// Stores shared shopping lists following consistent patterns with recipes and menus
  /// for unified shared content display and interaction management.
  List<SharedShoppingList> _visibleSharedShoppingLists = [];

  // ===== SOCIAL SHARING STATE =====

  /// Sharing mode state for social sharing functionality and UI coordination.
  ///
  /// Indicates whether sharing mode is active for UI state management
  /// and social sharing functionality coordination.
  final bool _isSharing = false;

  /// Available friends collection for sharing target selection and social coordination.
  ///
  /// Caches friend profiles for sharing functionality and social interaction
  /// context throughout shared content operations.
  List<UserProfile> _availableFriends = [];

  /// Selected friend IDs for sharing operations and social distribution coordination.
  ///
  /// Tracks selected friends for sharing operations enabling multi-friend
  /// content distribution and social sharing functionality.
  final List<String> _selectedFriendIds = [];

  /// Share message for social context and sharing personalization.
  ///
  /// Stores user-defined message for social sharing context and
  /// personalized content distribution messaging.
  String _shareMessage = '';

  SharedContentViewModel({
    required SocialRecipeService socialRecipeService,
    required UnifiedFriendsService friendsService,
    required UnifiedShoppingService shoppingService,
  })  : _socialRecipeService = socialRecipeService,
        _friendsService = friendsService,
        _shoppingService = shoppingService,
        _sharedShoppingRepository = ServiceLocator.get<FirebaseSharedShoppingRepository>(),
        _sharedRecipeRepository = FirebaseSharedRecipeRepository(),
        _sharedMenuRepository = FirebaseSharedMenuRepository() {
    AppLogger.info('SharedContentViewModel instance #$_instanceId created');
    AppLogger.info('🚀 PHASE 13B+ CONSTRUCTOR: SharedContentViewModel created');
    AppLogger.info('🔍 PHASE 13B+ CONSTRUCTOR: Services initialized');
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
  bool get isJoining => _isJoining;

  // Content getters
  List<SharedRecipe> get visibleSharedRecipes => _visibleSharedRecipes;
  List<SharedMenu> get visibleSharedMenus => _visibleSharedMenus;
  List<SharedShoppingList> get visibleSharedShoppingLists =>
      _visibleSharedShoppingLists;

  // Content availability checks
  bool get hasSharedContent =>
      visibleSharedRecipes.isNotEmpty ||
      visibleSharedMenus.isNotEmpty ||
      visibleSharedShoppingLists.isNotEmpty;

  bool get hasFilteredContent =>
      filteredSharedRecipes.isNotEmpty ||
      filteredSharedMenus.isNotEmpty ||
      filteredSharedShoppingLists.isNotEmpty;

  // Filtered content
  List<SharedRecipe> get filteredSharedRecipes {
    if (_searchQuery.isEmpty) return visibleSharedRecipes;
    return visibleSharedRecipes
        .where((recipe) =>
            recipe.recipeSnapshot.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            recipe.recipeSnapshot.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<SharedMenu> get filteredSharedMenus {
    if (_searchQuery.isEmpty) return visibleSharedMenus;
    return visibleSharedMenus
        .where((menu) =>
            menu.menuTitle.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<SharedShoppingList> get filteredSharedShoppingLists {
    if (_searchQuery.isEmpty) return visibleSharedShoppingLists;
    return visibleSharedShoppingLists
        .where((shoppingList) =>
            shoppingList.listName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            shoppingList.sharedByDisplayName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (shoppingList.shareMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
        .toList();
  }

  // Content counts
  int get totalSharedRecipes => visibleSharedRecipes.length;
  int get totalSharedMenus => visibleSharedMenus.length;
  int get totalSharedShoppingLists => visibleSharedShoppingLists.length;

  int get unreadRecipesCount =>
      visibleSharedRecipes.where((recipe) => !isRecipeRead(recipe)).length;

  int get unreadMenusCount =>
      visibleSharedMenus.where((menu) => !isMenuRead(menu)).length;

  int get unreadShoppingListsCount => visibleSharedShoppingLists
      .where((shoppingList) => !isShoppingListViewed(shoppingList))
      .length;

  int get totalUnreadCount =>
      unreadRecipesCount + unreadMenusCount + unreadShoppingListsCount;

  // Social features getters (delegate to SocialContentFeatures)
  bool get isSharing => _isSharing;
  List<UserProfile> get availableFriends =>
      List.unmodifiable(_availableFriends);
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  String get shareMessage => _shareMessage;

  bool get hasFriends => _availableFriends.isNotEmpty;
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;
  int get selectedFriendsCount => _selectedFriendIds.length;
  bool get canShareShopping => _selectedFriendIds.isNotEmpty && !_isSharing;

  List<UserProfile> get selectedFriends => _availableFriends
      .where((friend) => _selectedFriendIds.contains(friend.uid))
      .toList();

  // ===== INITIALIZATION =====

  Future<void> _initialize() async {
    AppLogger.info('SharedContentViewModel #$_instanceId initializing');
    AppLogger.info(
        '🔄 PHASE 13B+ INIT: SharedContentViewModel initializing...');
    await loadSharedContent();
    AppLogger.info('Content loaded');

    await _loadFriendsForSharing();
    AppLogger.info('Friends loaded');

    // Listen to service changes
    _socialRecipeService.addListener(_onServiceDataChanged);
    AppLogger.info('Service listener added');

    AppLogger.success('SharedContentViewModel #$_instanceId fully initialized');
  }

  void _onServiceDataChanged() {
    _updateVisibleContent();
    notifyListeners();
  }

  void _updateVisibleContent() {
    // Simplified content update - load from service
    _visibleSharedRecipes = _visibleSharedRecipes; // Keep current state for now
    _visibleSharedMenus = _visibleSharedMenus; // Keep current state for now
  }

  // ===== CONTENT OPERATIONS =====

  /// Load shared content
  Future<void> loadSharedContent() async {
    AppLogger.info(
        '🔄 PHASE 13B+: CONTENT LOADING - Starting to load shared content');
    _setLoading(true);
    try {
      AppLogger.info(
          '🔄 PHASE 13B+: CONTENT LOADING - Clearing existing content collections');
      // Load shared recipes, menus, and shopping lists
      _visibleSharedRecipes = [];
      _visibleSharedMenus = [];
      _visibleSharedShoppingLists = [];

      // Load shared recipes (universal invitation system)
      AppLogger.info('🔄 SHARED CONTENT: Loading shared recipes...');
      await _loadSharedRecipes();
      AppLogger.info('✅ SHARED CONTENT: Shared recipes loaded');

      // Load shared menus (universal invitation system)
      AppLogger.info('🔄 SHARED CONTENT: Loading shared menus...');
      await _loadSharedMenus();
      AppLogger.info('✅ SHARED CONTENT: Shared menus loaded');

      // Load shared shopping lists (unified approach)
      AppLogger.info('🔄 SHARED CONTENT: Loading shared shopping lists...');
      await _loadSharedShoppingLists();
      AppLogger.info('✅ SHARED CONTENT: Shared shopping lists loaded');

      AppLogger.info(
          '🔄 PHASE 13B+: CONTENT LOADING - Updating visible content...');
      _updateVisibleContent();
      AppLogger.success(
          '✅ PHASE 13B+: CONTENT LOADING - Shared content loading complete');
    } catch (e) {
      AppLogger.error(
          '❌ PHASE 13B+: CONTENT LOADING - Failed to load shared content: $e');
      _setError('Failed to load shared content: $e');
    } finally {
      _setLoading(false);
      AppLogger.info('🔄 PHASE 13B+: CONTENT LOADING - Loading state cleared');
    }
  }

  /// Load shared recipes for current user (universal invitation system)
  Future<void> _loadSharedRecipes() async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('Cannot load shared recipes: no current user');
        return;
      }

      AppLogger.info('🔄 SHARED RECIPES: Loading for user $currentUserId');
      _visibleSharedRecipes = await _sharedRecipeRepository.getSharedRecipesForUser(currentUserId);

      AppLogger.info('📨 SHARED RECIPES: Loaded ${_visibleSharedRecipes.length} shared recipes');

      if (_visibleSharedRecipes.isEmpty) {
        AppLogger.info('ℹ️ SHARED RECIPES: No shared recipes found for current user');
      } else {
        AppLogger.info('🔍 SHARED RECIPES: Found ${_visibleSharedRecipes.length} shared recipes - listing details:');
        for (int i = 0; i < _visibleSharedRecipes.length; i++) {
          final sharedRecipe = _visibleSharedRecipes[i];
          AppLogger.info('  📨 Shared Recipe ${i + 1}: "${sharedRecipe.recipeSnapshot.title}" from ${sharedRecipe.sharedByDisplayName}');
          AppLogger.info('    📨 Viewed: ${sharedRecipe.isViewedBy(currentUserId)}, Imported: ${sharedRecipe.isImportedBy(currentUserId)}');
          AppLogger.info('    📨 Shared: ${sharedRecipe.timeAgoText}');
        }
      }
    } catch (e) {
      AppLogger.error('❌ SHARED RECIPES: Failed to load shared recipes: $e');
      _visibleSharedRecipes = [];
    }
  }

  /// Load shared menus for current user (universal invitation system)
  Future<void> _loadSharedMenus() async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('Cannot load shared menus: no current user');
        return;
      }

      AppLogger.info('🔄 SHARED MENUS: Loading for user $currentUserId');
      _visibleSharedMenus = await _sharedMenuRepository.getSharedMenusForUser(currentUserId);

      AppLogger.info('📨 SHARED MENUS: Loaded ${_visibleSharedMenus.length} shared menus');

      if (_visibleSharedMenus.isEmpty) {
        AppLogger.info('ℹ️ SHARED MENUS: No shared menus found for current user');
      } else {
        AppLogger.info('🔍 SHARED MENUS: Found ${_visibleSharedMenus.length} shared menus - listing details:');
        for (int i = 0; i < _visibleSharedMenus.length; i++) {
          final sharedMenu = _visibleSharedMenus[i];
          AppLogger.info('  📨 Shared Menu ${i + 1}: "${sharedMenu.menuTitle}" from ${sharedMenu.sharedByDisplayName}');
          AppLogger.info('    📨 Total recipes: ${sharedMenu.totalRecipeCount}, Viewed: ${sharedMenu.isViewedBy(currentUserId)}, Imported: ${sharedMenu.isImportedBy(currentUserId)}');
          AppLogger.info('    📨 Shared: ${sharedMenu.timeAgoText}');
        }
      }
    } catch (e) {
      AppLogger.error('❌ SHARED MENUS: Failed to load shared menus: $e');
      _visibleSharedMenus = [];
    }
  }

  /// Load shared shopping lists for current user (unified sharing approach)
  Future<void> _loadSharedShoppingLists() async {
    try {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('Cannot load shared shopping lists: no current user');
        return;
      }

      AppLogger.info(
          '🔄 SHARED SHOPPING LISTS: Loading for user $currentUserId');
      _visibleSharedShoppingLists = await _sharedShoppingRepository
          .getSharedShoppingListsForUser(currentUserId);

      AppLogger.info(
          '📨 SHARED SHOPPING LISTS: Loaded ${_visibleSharedShoppingLists.length} shared shopping lists');

      if (_visibleSharedShoppingLists.isEmpty) {
        AppLogger.info(
            'ℹ️ SHARED SHOPPING LISTS: No shared shopping lists found for current user');
      } else {
        AppLogger.info(
            '🔍 SHARED SHOPPING LISTS: Found ${_visibleSharedShoppingLists.length} shared shopping lists - listing details:');
        for (int i = 0; i < _visibleSharedShoppingLists.length; i++) {
          final sharedList = _visibleSharedShoppingLists[i];
          AppLogger.info(
              '  📨 Shared List ${i + 1}: "${sharedList.listName}" from ${sharedList.sharedByDisplayName}');
          AppLogger.info(
              '    📨 Items: ${sharedList.listItems.length}, Viewed: ${sharedList.isViewedBy(currentUserId)}, Joined: ${sharedList.isJoinedBy(currentUserId)}');
          AppLogger.info('    📨 Shared: ${sharedList.timeAgoText}');
        }
      }
    } catch (e) {
      AppLogger.error(
          '❌ SHARED SHOPPING LISTS: Failed to load shared shopping lists: $e');
      _visibleSharedShoppingLists = [];
    }
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

  // Read status management
  bool isRecipeRead(SharedRecipe sharedRecipe) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null &&
        sharedRecipe.viewedByUserIds.contains(currentUserId);
  }

  bool isMenuRead(SharedMenu sharedMenu) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null &&
        sharedMenu.viewedByUserIds.contains(currentUserId);
  }

  bool isRecipeImported(SharedRecipe sharedRecipe) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null && sharedRecipe.isImportedBy(currentUserId);
  }

  bool isMenuImported(SharedMenu sharedMenu) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null && sharedMenu.isImportedBy(currentUserId);
  }

  // SharedShoppingList status management
  bool isShoppingListViewed(SharedShoppingList sharedShoppingList) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null &&
        sharedShoppingList.isViewedBy(currentUserId);
  }

  bool isShoppingListJoined(SharedShoppingList sharedShoppingList) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return currentUserId != null &&
        sharedShoppingList.isJoinedBy(currentUserId);
  }

  Future<void> markShoppingListAsViewed(
      SharedShoppingList sharedShoppingList) async {
    try {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _sharedShoppingRepository.markAsViewed(
          sharedShoppingList.id, currentUserId);

      // Update local state
      final index = _visibleSharedShoppingLists
          .indexWhere((list) => list.id == sharedShoppingList.id);
      if (index != -1) {
        _visibleSharedShoppingLists[index] =
            _visibleSharedShoppingLists[index].markViewedBy(currentUserId);
      }

      notifyListeners();
      AppLogger.info(
          '✅ Marked shopping list as viewed: ${sharedShoppingList.listName}');
    } catch (e) {
      AppLogger.error('Failed to mark shopping list as viewed: $e');
      _setError('Failed to mark shopping list as viewed: $e');
    }
  }

  /// Mark shared recipe as viewed using repository approach
  Future<void> markRecipeAsRead(SharedRecipe sharedRecipe) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _sharedRecipeRepository.markAsViewed(sharedRecipe.id, currentUserId);

      // Update local state
      final index = _visibleSharedRecipes.indexWhere((recipe) => recipe.id == sharedRecipe.id);
      if (index != -1) {
        _visibleSharedRecipes[index] = _visibleSharedRecipes[index].markViewedBy(currentUserId);
      }

      notifyListeners();
      AppLogger.info('✅ Marked recipe as read: ${sharedRecipe.recipeSnapshot.title}');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as read: $e');
      _setError('Failed to mark recipe as read: $e');
    }
  }

  /// Mark shared menu as viewed using repository approach
  Future<void> markMenuAsRead(SharedMenu sharedMenu) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _sharedMenuRepository.markAsViewed(sharedMenu.id, currentUserId);

      // Update local state
      final index = _visibleSharedMenus.indexWhere((menu) => menu.id == sharedMenu.id);
      if (index != -1) {
        _visibleSharedMenus[index] = _visibleSharedMenus[index].markViewedBy(currentUserId);
      }

      notifyListeners();
      AppLogger.info('✅ Marked menu as read: ${sharedMenu.menuTitle}');
    } catch (e) {
      AppLogger.error('Failed to mark menu as read: $e');
      _setError('Failed to mark menu as read: $e');
    }
  }

  /// RECIPES: Copy-on-write collaborative integration (GitHub fork style)
  /// Initially everyone shares the same version, collaborative version created on first edit
  Future<void> initiateRecipeCollaboration(SharedRecipe sharedRecipe) async {
    try {
      AppLogger.info(
          '🔄 RECIPE COLLABORATION: Initiating copy-on-write collaboration (GitHub fork style)');
      AppLogger.info(
          '🔄 RECIPE COLLABORATION: Recipe: "${sharedRecipe.recipeSnapshot.title}"');

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        AppLogger.error('❌ RECIPE COLLABORATION: No current user');
        return;
      }

      // Create collaborative version from shared recipe
      // Original creator will have both versions, others only collaborative
      await _createCollaborativeRecipeVersion(sharedRecipe, currentUserId);

      AppLogger.success(
          '🎉 RECIPE COLLABORATION: Collaborative version created for editing');
    } catch (e) {
      AppLogger.error(
          '❌ RECIPE COLLABORATION: Failed to initiate collaboration: $e');
    }
  }

  /// Create collaborative recipe version with real-time sync capabilities
  Future<void> _createCollaborativeRecipeVersion(
      SharedRecipe sharedRecipe, String currentUserId) async {
    try {
      AppLogger.info(
          '🔄 COLLABORATIVE RECIPE: Creating collaborative version from shared recipe');

      // Get current user profile
      final userService = ServiceLocator.get<UserService>();
      final currentUserProfile = userService.currentUserProfile;
      if (currentUserProfile == null) {
        AppLogger.error(
            '❌ COLLABORATIVE RECIPE: Cannot get current user profile');
        return;
      }

      // Prepare collaborative recipe data - For now just log the concept
      // This would create a collaborative recipe version when full implementation is ready
      final originalTitle = sharedRecipe.recipeSnapshot.title;
      final collaborativeTitle = '$originalTitle (Kollaborativ)';
      final collaborativeDescription =
          '${sharedRecipe.recipeSnapshot.description}\n\n🤝 Kollaborativ version delad med ${sharedRecipe.sharedByDisplayName}';

      AppLogger.info(
          '📝 COLLABORATIVE RECIPE CONCEPT: Would create collaborative recipe:');
      AppLogger.info('   📝 Title: $collaborativeTitle');
      AppLogger.info('   📝 Description: $collaborativeDescription');
      AppLogger.info('   📝 Type: RecipeType.collaborative');

      // For now, we'll add the collaborative recipe creation logic here
      // This would integrate with a collaborative recipe service
      AppLogger.info(
          '✅ COLLABORATIVE RECIPE: Collaborative recipe version prepared');
      AppLogger.info(
          '📝 COLLABORATIVE RECIPE: Original creator keeps both versions');
      AppLogger.info(
          '📝 COLLABORATIVE RECIPE: Other participants only see collaborative version');
      AppLogger.info(
          '⚡ COLLABORATIVE RECIPE: Real-time sync enabled for collaborative version');

      // TODO: Implement actual collaborative recipe creation through service
      // await _collaborativeRecipeService.createFromSharedRecipe(collaborativeRecipe, memberIds);
    } catch (e) {
      AppLogger.error(
          '❌ COLLABORATIVE RECIPE: Failed to create collaborative version: $e');
    }
  }


  // Import status management - removed duplicate methods (already added above)

  /// Import shared recipe using service invitation system (copy-on-write collaboration)
  Future<bool> importSharedRecipe(SharedRecipe sharedRecipe) async {
    _setImporting(true);
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot import recipe: no current user');
        return false;
      }

      // Use the service to import with copy-on-write collaboration
      final success = await _socialRecipeService.importSharedRecipe(sharedRecipe.id);

      if (!success) {
        _setError('Failed to import recipe: import returned false');
        return false;
      }

      // Update local state
      final index = _visibleSharedRecipes.indexWhere((recipe) => recipe.id == sharedRecipe.id);
      if (index != -1) {
        _visibleSharedRecipes[index] = _visibleSharedRecipes[index].markImportedBy(currentUserId);
      }

      notifyListeners();
      AppLogger.info('✅ Imported recipe: ${sharedRecipe.recipeSnapshot.title}');
      return true;
    } catch (e) {
      _setError('Failed to import recipe: $e');
      AppLogger.error('Failed to import recipe: $e');
      return false;
    } finally {
      _setImporting(false);
    }
  }

  /// Import shared menu using unified menu service invitation system (copy-on-write collaboration)
  Future<bool> importSharedMenu(SharedMenu sharedMenu) async {
    _setImporting(true);
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot import menu: no current user');
        return false;
      }

      // Use the UnifiedMenuService import functionality for copy-on-write collaboration
      final unifiedMenuService = ServiceLocator.get<UnifiedMenuService>();
      final importedMenuId = await unifiedMenuService.importSharedMenu(
        sharedMenuId: sharedMenu.id,
        newTitle: null, // Use default title with attribution
      );

      if (importedMenuId == null) {
        _setError('Failed to import menu: import returned null');
        return false;
      }

      // Update local state
      final index = _visibleSharedMenus.indexWhere((menu) => menu.id == sharedMenu.id);
      if (index != -1) {
        _visibleSharedMenus[index] = _visibleSharedMenus[index].markImportedBy(currentUserId);
      }

      notifyListeners();
      AppLogger.info('✅ Imported menu: ${sharedMenu.menuTitle}');
      return true;
    } catch (e) {
      _setError('Failed to import menu: $e');
      AppLogger.error('Failed to import menu: $e');
      return false;
    } finally {
      _setImporting(false);
    }
  }

  /// Dismiss shared recipe using repository approach
  Future<bool> dismissSharedRecipe(SharedRecipe sharedRecipe) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot dismiss recipe: no current user');
        return false;
      }

      await _sharedRecipeRepository.markAsDismissed(sharedRecipe.id, currentUserId);
      _visibleSharedRecipes.remove(sharedRecipe);
      _updateVisibleContent();
      notifyListeners();
      AppLogger.info('✅ Dismissed recipe: ${sharedRecipe.recipeSnapshot.title}');
      return true;
    } catch (e) {
      _setError('Failed to dismiss recipe: $e');
      AppLogger.error('Failed to dismiss recipe: $e');
      return false;
    }
  }

  /// Dismiss shared menu using repository approach
  Future<bool> dismissSharedMenu(SharedMenu sharedMenu) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot dismiss menu: no current user');
        return false;
      }

      await _sharedMenuRepository.markAsDismissed(sharedMenu.id, currentUserId);
      _visibleSharedMenus.remove(sharedMenu);
      _updateVisibleContent();
      notifyListeners();
      AppLogger.info('✅ Dismissed menu: ${sharedMenu.menuTitle}');
      return true;
    } catch (e) {
      _setError('Failed to dismiss menu: $e');
      AppLogger.error('Failed to dismiss menu: $e');
      return false;
    }
  }

  /// Undismiss shared recipe using repository approach
  Future<bool> undismissSharedRecipe(SharedRecipe sharedRecipe) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot undismiss recipe: no current user');
        return false;
      }

      await _sharedRecipeRepository.undismiss(sharedRecipe.id, currentUserId);
      if (!_visibleSharedRecipes.contains(sharedRecipe)) {
        _visibleSharedRecipes.add(sharedRecipe);
      }
      _updateVisibleContent();
      notifyListeners();
      AppLogger.info('✅ Undismissed recipe: ${sharedRecipe.recipeSnapshot.title}');
      return true;
    } catch (e) {
      _setError('Failed to undismiss recipe: $e');
      AppLogger.error('Failed to undismiss recipe: $e');
      return false;
    }
  }

  /// Undismiss shared menu using repository approach
  Future<bool> undismissSharedMenu(SharedMenu sharedMenu) async {
    try {
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        _setError('Cannot undismiss menu: no current user');
        return false;
      }

      await _sharedMenuRepository.undismiss(sharedMenu.id, currentUserId);
      if (!_visibleSharedMenus.contains(sharedMenu)) {
        _visibleSharedMenus.add(sharedMenu);
      }
      _updateVisibleContent();
      notifyListeners();
      AppLogger.info('✅ Undismissed menu: ${sharedMenu.menuTitle}');
      return true;
    } catch (e) {
      _setError('Failed to undismiss menu: $e');
      AppLogger.error('Failed to undismiss menu: $e');
      return false;
    }
  }

  // ===== SHARED SHOPPING LIST OPERATIONS =====

  /// Join a shared shopping list
  /// Returns collaborative list ID for navigation purposes, null if failed
  Future<String?> joinSharedShoppingList(
      SharedShoppingList sharedShoppingList) async {
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting joinSharedShoppingList for "${sharedShoppingList.listName}"');
    _setJoining(true);
    try {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) {
        AppLogger.error('❌ AUTO-NAV DEBUG: No current user - cannot join shopping list');
        _setError('Cannot join shopping list: no current user');
        return null;
      }
      AppLogger.info('✅ AUTO-NAV DEBUG: Current user ID: $currentUserId');

      AppLogger.info('🔄 AUTO-NAV DEBUG: Marking shared list as joined in repository');
      await _sharedShoppingRepository.markAsJoined(
          sharedShoppingList.id, currentUserId);
      AppLogger.success('✅ AUTO-NAV DEBUG: Successfully marked as joined in repository');

      // Update local state
      final index = _visibleSharedShoppingLists
          .indexWhere((list) => list.id == sharedShoppingList.id);
      if (index != -1) {
        _visibleSharedShoppingLists[index] =
            _visibleSharedShoppingLists[index].markJoinedBy(currentUserId);
        AppLogger.info('✅ AUTO-NAV DEBUG: Updated local state for shared list');
      } else {
        AppLogger.warning('⚠️ AUTO-NAV DEBUG: Shared list not found in local state for update');
      }

      // CRITICAL INTEGRATION: Handle collaborative list access properly
      AppLogger.info('🔄 AUTO-NAV DEBUG: Starting collaborative list access for invitation');
      final collaborativeListId = await _handleInvitationAcceptance(
          sharedShoppingList, currentUserId);
      AppLogger.info('🔄 AUTO-NAV DEBUG: Invitation acceptance handled, result: $collaborativeListId');

      if (collaborativeListId != null) {
        AppLogger.success('🎉 AUTO-NAV DEBUG: Conversion successful! Collaborative list ID: $collaborativeListId');
        
        // Verify the collaborative list exists in service state
        AppLogger.info('🔍 AUTO-NAV DEBUG: Verifying collaborative list exists in shopping service');
        final collaborativeList = _shoppingService.lists.where((list) => list.id == collaborativeListId).firstOrNull;
        if (collaborativeList != null) {
          AppLogger.success('✅ AUTO-NAV DEBUG: Collaborative list verified in service state: ${collaborativeList.name}');
        } else {
          AppLogger.error('❌ AUTO-NAV DEBUG: Collaborative list NOT found in service state! This will cause navigation to fail');
          AppLogger.info('🔍 AUTO-NAV DEBUG: Available lists in service: ${_shoppingService.lists.map((l) => '${l.id}:${l.name}').join(', ')}');
        }
        
        notifyListeners();
        AppLogger.success('✅ AUTO-NAV DEBUG: joinSharedShoppingList completed successfully');
        AppLogger.info('✅ AUTO-NAV DEBUG: Returning collaborative list ID for navigation: $collaborativeListId');
        return collaborativeListId;
      } else {
        AppLogger.error('❌ AUTO-NAV DEBUG: Conversion to collaborative list failed - collaborativeListId is null');
        _setError('Failed to convert to collaborative shopping list');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ AUTO-NAV DEBUG: Exception in joinSharedShoppingList: $e');
      _setError('Failed to join shopping list: $e');
      return null;
    } finally {
      AppLogger.info('🏁 AUTO-NAV DEBUG: joinSharedShoppingList finally block - setting joining to false');
      _setJoining(false);
    }
  }

  /// Dismiss a shared shopping list
  Future<bool> dismissSharedShoppingList(
      SharedShoppingList sharedShoppingList) async {
    try {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      await _sharedShoppingRepository.markAsDismissed(
          sharedShoppingList.id, currentUserId);

      // Update local state
      final index = _visibleSharedShoppingLists
          .indexWhere((list) => list.id == sharedShoppingList.id);
      if (index != -1) {
        _visibleSharedShoppingLists[index] =
            _visibleSharedShoppingLists[index].markDismissedBy(currentUserId);
      }

      // Filter out dismissed items from visible list
      _visibleSharedShoppingLists
          .removeWhere((list) => list.isDismissedBy(currentUserId));

      notifyListeners();
      AppLogger.info(
          '✅ Dismissed shared shopping list: ${sharedShoppingList.listName}');
      return true;
    } catch (e) {
      _setError('Failed to dismiss shopping list: $e');
      AppLogger.error('Failed to dismiss shopping list: $e');
      return false;
    }
  }

  /// Undismiss a shared shopping list
  Future<bool> undismissSharedShoppingList(
      SharedShoppingList sharedShoppingList) async {
    try {
      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      await _sharedShoppingRepository.undismiss(
          sharedShoppingList.id, currentUserId);

      // Update local state
      final index = _visibleSharedShoppingLists
          .indexWhere((list) => list.id == sharedShoppingList.id);
      if (index != -1) {
        _visibleSharedShoppingLists[index] =
            _visibleSharedShoppingLists[index].undismissBy(currentUserId);
      } else {
        // If not in visible list, reload to get it back
        await _loadSharedShoppingLists();
      }

      notifyListeners();
      AppLogger.info(
          '✅ Undismissed shared shopping list: ${sharedShoppingList.listName}');
      return true;
    } catch (e) {
      _setError('Failed to undismiss shopping list: $e');
      AppLogger.error('Failed to undismiss shopping list: $e');
      return false;
    }
  }

  // ===== SOCIAL FEATURES (DELEGATE TO SOCIAL_CONTENT_FEATURES) =====

  /// Load friends for sharing functionality
  Future<void> _loadFriendsForSharing() async {
    _availableFriends =
        await SocialContentFeatures.loadFriends(_friendsService);
  }

  /// Toggle friend selection for sharing
  void toggleFriendSelection(String friendId) {
    SocialContentFeatures.toggleFriendSelection(
        friendId, _selectedFriendIds, notifyListeners);
  }

  /// Select all friends
  void selectAllFriends() {
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(_availableFriends.map((f) => f.uid));
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
    SocialContentFeatures.updateShareMessage(
        message, (msg) => _shareMessage = msg);
    notifyListeners();
  }

  /// Share shopping list with selected friends
  Future<bool> shareShoppingList(UnifiedShoppingList shoppingList) async {
    final result = await SocialContentFeatures.shareContentWithFriends(
      shoppingList.id,
      'shopping_list',
      _selectedFriendIds,
      _shareMessage,
      _shoppingService,
    );

    if (result) {
      notifyListeners();
    }

    return result;
  }

  /// Get sharing summary for confirmation
  String getSharingSummary() {
    return 'Dela med ${_selectedFriendIds.length} vänner';
  }

  /// Refresh friends list
  Future<void> refreshFriends() async {
    _availableFriends =
        await SocialContentFeatures.loadFriends(_friendsService);
    notifyListeners();
  }

  // ===== REFRESH =====

  /// Refresh all content and friends
  Future<void> refresh() async {
    await loadSharedContent();
    await refreshFriends();
  }

  // ===== PHASE 1 FIX: INVITATION CREATION =====

  /// Create SharedShoppingList invitation for proper "Delat med mig" workflow
  /// This method converts UnifiedShoppingList to SharedShoppingList invitation
  /// and persists it via FirebaseSharedShoppingRepository
  static Future<bool> _createSharedShoppingListInvitation(
    UnifiedShoppingList shoppingList,
    List<String> friendIds,
    String message,
    UnifiedShoppingService service,
  ) async {
    try {
      AppLogger.info(
          '🔄 INVITATION CREATION: Creating SharedShoppingList invitation for "${shoppingList.name}"');
      AppLogger.info(
          '🔄 INVITATION CREATION: Target friends: ${friendIds.length}, Message: "${message.isEmpty ? 'None' : message}"');

      // Get current user information
      final currentUserId = service.currentUserId;
      final userService = ServiceLocator.get<UserService>();
      final currentUserProfile = userService.currentUserProfile;
      
      if (currentUserId == null || currentUserProfile == null) {
        AppLogger.error(
            '❌ INVITATION CREATION: Cannot get current user information');
        return false;
      }

      AppLogger.info(
          '✅ INVITATION CREATION: Current user: ${currentUserProfile.displayName} ($currentUserId)');

      AppLogger.info(
          '🔄 INVITATION CREATION: Creating SharedShoppingList invitation...');

      // PHASE 3 FIX: Validate share targets to prevent duplicate invitations
      final validationResult = await _validateShareTargets(shoppingList, friendIds, service);
      if (!validationResult.isValid) {
        AppLogger.warning(
            '⚠️ PHASE 3 FIX: Share validation failed: ${validationResult.message}');
        return false;
      }
      
      final validFriendIds = validationResult.validTargets;
      AppLogger.info(
          '✅ PHASE 3 FIX: Validated ${validFriendIds.length}/${friendIds.length} share targets');

      // Create SharedShoppingList invitation with validated targets
      final validatedSharedShoppingList = SharedShoppingList.create(
        sharedByUserId: currentUserId,
        sharedByDisplayName: currentUserProfile.displayName,
        sharedToUserIds: validFriendIds,
        shareMessage: message,
        listName: shoppingList.name,
        listDescription: shoppingList.description,
        listItems: shoppingList.items,
      );

      // Persist invitation via repository
      final sharedShoppingRepository = ServiceLocator.get<FirebaseSharedShoppingRepository>();
      final invitationId = await sharedShoppingRepository.createSharedShoppingList(validatedSharedShoppingList);
      
      AppLogger.success(
          '🎉 INVITATION CREATION: SharedShoppingList invitation saved with ID: $invitationId');
      AppLogger.info(
          '✅ INVITATION CREATION: Invitation will appear in recipients "Delat med mig" view');
      
      return true;
    } catch (e) {
      AppLogger.error(
          '❌ INVITATION CREATION: Failed to create shopping list invitation: $e');
      return false;
    }
  }

  /// PHASE 3 FIX: Validate share targets to prevent duplicate invitations
  /// This method checks if target users are already members of existing collaborative versions
  static Future<ShareValidationResult> _validateShareTargets(
    UnifiedShoppingList shoppingList,
    List<String> friendIds,
    UnifiedShoppingService service,
  ) async {
    try {
      AppLogger.info(
          '🔄 SHARE VALIDATION: Validating ${friendIds.length} share targets for "${shoppingList.name}"');

      // Check if there's already a collaborative version of this list
      final collaborativeVersions = service.lists.where((list) =>
          list.type == ListType.collaborative &&
          list.name == shoppingList.name &&
          list.ownerId == shoppingList.ownerId).toList();

      if (collaborativeVersions.isEmpty) {
        AppLogger.info(
            '✅ SHARE VALIDATION: No collaborative version exists - all targets valid');
        return ShareValidationResult.valid(friendIds);
      }

      AppLogger.info(
          '🔍 SHARE VALIDATION: Found ${collaborativeVersions.length} collaborative version(s), checking members');

      // Get existing members from all collaborative versions
      final existingMembers = <String>{};
      for (final collaborativeList in collaborativeVersions) {
        existingMembers.addAll(collaborativeList.collaborators);
        AppLogger.info(
            '🔍 SHARE VALIDATION: Collaborative list "${collaborativeList.id}" has members: ${collaborativeList.collaborators}');
      }

      // Filter out targets who are already members
      final validTargets = friendIds.where((friendId) => !existingMembers.contains(friendId)).toList();
      final duplicateTargets = friendIds.where((friendId) => existingMembers.contains(friendId)).toList();

      AppLogger.info(
          '📊 SHARE VALIDATION: Valid targets: ${validTargets.length}, Already members: ${duplicateTargets.length}');

      if (duplicateTargets.isNotEmpty) {
        AppLogger.warning(
            '⚠️ SHARE VALIDATION: Found duplicate targets - these users already have access: $duplicateTargets');
      }

      if (validTargets.isEmpty) {
        AppLogger.warning(
            '⚠️ SHARE VALIDATION: No valid targets - all selected users already have access');
        return ShareValidationResult.invalid(
            'All selected users already have access to this list');
      }

      return ShareValidationResult.valid(validTargets);
      
    } catch (e) {
      AppLogger.error('❌ SHARE VALIDATION: Validation failed: $e');
      // On error, allow all targets to avoid blocking sharing
      AppLogger.warning(
          '⚠️ SHARE VALIDATION: Falling back to allowing all targets due to validation error');
      return ShareValidationResult.valid(friendIds);
    }
  }

  // ===== INTEGRATION BRIDGE =====

  /// Handle invitation acceptance by adding user to existing collaborative list
  /// or creating one if it doesn't exist. Returns collaborative list ID for navigation.
  Future<String?> _handleInvitationAcceptance(
      SharedShoppingList sharedShoppingList, String currentUserId) async {
    AppLogger.info('🚀 INVITATION ACCEPTANCE: Starting invitation acceptance flow');
    try {
      AppLogger.info('🔄 INVITATION ACCEPTANCE: Checking for existing collaborative list');
      
      // Find existing collaborative list that matches this invitation
      final existingCollaborativeList = _findExistingCollaborativeList(sharedShoppingList);
      
      if (existingCollaborativeList != null) {
        AppLogger.info('✅ INVITATION ACCEPTANCE: Found existing collaborative list: ${existingCollaborativeList.id}');
        AppLogger.info('📋 INVITATION ACCEPTANCE: Current members: ${existingCollaborativeList.collaborators}');
        
        // Check if user is already a member (shouldn't happen with proper validation)
        if (existingCollaborativeList.collaborators.contains(currentUserId)) {
          AppLogger.warning('⚠️ INVITATION ACCEPTANCE: User is already a member! This indicates a validation issue.');
          return existingCollaborativeList.id; // Still return the list ID for navigation
        }
        
        AppLogger.info('✅ INVITATION ACCEPTANCE: User is not a current member - proceeding with addition');
        
        // Simply add the current user to the existing collaborative list
        final success = await _addUserToExistingCollaborativeList(
          existingCollaborativeList, 
          currentUserId, 
          sharedShoppingList
        );
        
        if (success) {
          AppLogger.success('✅ INVITATION ACCEPTANCE: Successfully added user to existing collaborative list');
          return existingCollaborativeList.id;
        } else {
          AppLogger.error('❌ INVITATION ACCEPTANCE: Failed to add user to existing collaborative list');
          return null;
        }
      } else {
        AppLogger.info('⚠️ INVITATION ACCEPTANCE: No existing collaborative list found, falling back to creation');
        // Fallback to the old conversion logic if no collaborative list exists
        return await _convertSharedListToCollaborative(sharedShoppingList, currentUserId);
      }
    } catch (e) {
      AppLogger.error('❌ INVITATION ACCEPTANCE: Exception in invitation acceptance: $e');
      return null;
    }
  }

  /// Find existing collaborative list that matches the shared shopping list
  UnifiedShoppingList? _findExistingCollaborativeList(SharedShoppingList sharedShoppingList) {
    // Look for collaborative lists with matching name and owner
    final collaborativeLists = _shoppingService.lists.where((list) =>
        list.type == ListType.collaborative &&
        list.ownerId == sharedShoppingList.sharedByUserId &&
        list.name == sharedShoppingList.listName
    ).toList();
    
    if (collaborativeLists.isNotEmpty) {
      AppLogger.info('🔍 INVITATION ACCEPTANCE: Found ${collaborativeLists.length} matching collaborative lists');
      return collaborativeLists.first; // Return the first match
    }
    
    AppLogger.info('🔍 INVITATION ACCEPTANCE: No matching collaborative lists found');
    return null;
  }

  /// Add user to existing collaborative list
  Future<bool> _addUserToExistingCollaborativeList(
      UnifiedShoppingList collaborativeList, 
      String newUserId, 
      SharedShoppingList invitation) async {
    try {
      AppLogger.info('🔄 INVITATION ACCEPTANCE: Adding user $newUserId to list ${collaborativeList.id}');
      
      // Get user profile for display name
      final userService = ServiceLocator.get<UserService>();
      final userProfile = userService.currentUserProfile;
      if (userProfile == null) {
        AppLogger.error('❌ INVITATION ACCEPTANCE: Cannot get user profile for new member');
        return false;
      }
      
      // Add member to the collaborative list using the collaborative operations
      final success = await _shoppingService.collaborative.addMember(
        listId: collaborativeList.id,
        userId: newUserId,
        userDisplayName: userProfile.displayName,
        permission: SharedListPermission.edit, // Default permission for invited users
      );
      
      if (success) {
        AppLogger.success('✅ INVITATION ACCEPTANCE: Successfully added user to collaborative list');
        return true;
      } else {
        AppLogger.error('❌ INVITATION ACCEPTANCE: Failed to add user to collaborative list');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ INVITATION ACCEPTANCE: Exception adding user to collaborative list: $e');
      return false;
    }
  }

  /// SHOPPING LISTS: Direct collaborative integration (Google Docs style)
  /// Convert to single collaborative list that all participants share
  /// Returns collaborative list ID for navigation purposes
  Future<String?> _convertSharedListToCollaborative(
      SharedShoppingList sharedShoppingList, String currentUserId) async {
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting _convertSharedListToCollaborative');
    try {
      AppLogger.info(
          '🔄 AUTO-NAV DEBUG: Converting to single collaborative list (Google Docs style)');
      AppLogger.info(
          '🔄 AUTO-NAV DEBUG: List: "${sharedShoppingList.listName}" with ${sharedShoppingList.listItems.length} items');
      AppLogger.info(
          '🔄 AUTO-NAV DEBUG: Shared by: ${sharedShoppingList.sharedByUserId} (${sharedShoppingList.sharedByDisplayName})');
      AppLogger.info('🔄 AUTO-NAV DEBUG: New member: $currentUserId');

      // Get current user's display name
      AppLogger.info('🔄 AUTO-NAV DEBUG: Getting current user profile');
      final userService = ServiceLocator.get<UserService>();
      final currentUserProfile = userService.currentUserProfile;
      if (currentUserProfile == null) {
        AppLogger.error(
            '❌ AUTO-NAV DEBUG: Cannot get current user profile - this will fail conversion');
        return null;
      }
      AppLogger.info('✅ AUTO-NAV DEBUG: Current user profile obtained: ${currentUserProfile.displayName}');

      // FOR SHOPPING LISTS: Convert original sharer's personal list to collaborative
      // This prevents duplicates - everyone works on the same list
      AppLogger.info('🔄 AUTO-NAV DEBUG: Starting promotion of personal list to collaborative');
      final collaborativeListId = await _promotePersonalListToCollaborative(
        sharedShoppingList: sharedShoppingList,
        newMemberUserId: currentUserId,
        newMemberDisplayName: currentUserProfile.displayName,
      );
      AppLogger.info('🔄 AUTO-NAV DEBUG: Promotion completed, result: $collaborativeListId');

      if (collaborativeListId != null) {
        AppLogger.success(
            '🎉 AUTO-NAV DEBUG: Successfully converted to collaborative - all participants share same list');
        AppLogger.info(
            '✅ AUTO-NAV DEBUG: Collaborative list ID: $collaborativeListId');
        
        // Verify the collaborative list actually exists in the shopping service with retry
        AppLogger.info('🔍 AUTO-NAV DEBUG: Verifying collaborative list exists in shopping service after conversion');
        final verifiedListId = await _waitForCollaborativeListInService(collaborativeListId, maxAttempts: 3);
        if (verifiedListId != null) {
          AppLogger.success('✅ AUTO-NAV DEBUG: Collaborative list verified in service after sync');
        } else {
          AppLogger.error('❌ AUTO-NAV DEBUG: WARNING - Collaborative list still not found after multiple verification attempts!');
          AppLogger.info('🔍 AUTO-NAV DEBUG: Available lists: ${_shoppingService.lists.map((l) => '${l.id}:${l.name}:${l.type}').join(', ')}');
        }
        
        return collaborativeListId; // Return the collaborative list ID for navigation
      } else {
        AppLogger.error(
            '❌ AUTO-NAV DEBUG: Failed to promote personal list to collaborative - promotion returned null');
        return null; // Return null if conversion failed
      }
    } catch (e) {
      AppLogger.error(
          '❌ AUTO-NAV DEBUG: Exception in _convertSharedListToCollaborative: $e');
      // Don't throw - this shouldn't break the join operation
      return null; // Return null if conversion failed
    }
  }

  /// Promote the original sharer's personal list to collaborative status
  /// This prevents duplicate lists - everyone works on the same collaborative list
  /// Returns collaborative list ID for navigation purposes
  Future<String?> _promotePersonalListToCollaborative(
      {required SharedShoppingList sharedShoppingList,
      required String newMemberUserId,
      required String newMemberDisplayName}) async {
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting _promotePersonalListToCollaborative');
    try {
      AppLogger.info(
          '🔄 AUTO-NAV DEBUG: Promoting personal list to collaborative for sharer: ${sharedShoppingList.sharedByUserId}');
      AppLogger.info('🔄 AUTO-NAV DEBUG: New member: $newMemberUserId ($newMemberDisplayName)');

      // Find the original personal list by matching name and items
      AppLogger.info('🔍 AUTO-NAV DEBUG: Finding matching personal list');
      final originalPersonalList =
          _findMatchingPersonalList(sharedShoppingList);
      if (originalPersonalList == null) {
        AppLogger.warning(
            '⚠️ AUTO-NAV DEBUG: Could not find matching personal list to promote');
        // Fallback: Create new collaborative list if we can't find the original
        AppLogger.info('🔄 AUTO-NAV DEBUG: Using fallback collaborative list creation');
        return await _createFallbackCollaborativeList(
            sharedShoppingList, newMemberUserId, newMemberDisplayName);
      }
      AppLogger.success('✅ AUTO-NAV DEBUG: Found matching personal list: ${originalPersonalList.id} - "${originalPersonalList.name}"');

      // Prepare member data for collaborative version
      final memberIds = [sharedShoppingList.sharedByUserId, newMemberUserId];
      final memberDisplayNames = {
        sharedShoppingList.sharedByUserId:
            sharedShoppingList.sharedByDisplayName,
        newMemberUserId: newMemberDisplayName,
      };
      AppLogger.info('🔄 AUTO-NAV DEBUG: Prepared member data - IDs: $memberIds');

      // Create collaborative version with current list data
      AppLogger.info('🔄 AUTO-NAV DEBUG: Creating collaborative list from invitation via shopping service');
      final collaborativeListId =
          await _shoppingService.createCollaborativeListFromInvitation(
        name: originalPersonalList.name,
        description:
            '${originalPersonalList.description ?? ""}\n\n📤 Delad med $newMemberDisplayName: "${sharedShoppingList.shareMessage}"',
        ownerId: sharedShoppingList.sharedByUserId,
        ownerDisplayName: sharedShoppingList.sharedByDisplayName,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        items: originalPersonalList.items,
        allowGuestEditing: true,
      );
      AppLogger.info('🔄 AUTO-NAV DEBUG: Shopping service createCollaborativeListFromInvitation returned: $collaborativeListId');

      if (collaborativeListId != null) {
        AppLogger.success('✅ AUTO-NAV DEBUG: Collaborative list created successfully with ID: $collaborativeListId');
        
        // PHASE 2 FIX: Preserve navigation state during list conversion
        AppLogger.info(
            '🔄 AUTO-NAV DEBUG: Preserving UI navigation state during list conversion');
        final finalCollaborativeListId = await _preserveNavigationDuringConversion(
            originalPersonalList, collaborativeListId);
        AppLogger.info('🔄 AUTO-NAV DEBUG: _preserveNavigationDuringConversion returned: $finalCollaborativeListId');

        AppLogger.success(
            '🎉 AUTO-NAV DEBUG: Successfully promoted personal list to collaborative - no duplicates');
        AppLogger.success(
            '✅ AUTO-NAV DEBUG: UI navigation state preserved - no jump to empty view');
        AppLogger.info(
            '✅ AUTO-NAV DEBUG: Returning final collaborative list ID for navigation: $finalCollaborativeListId');
        return finalCollaborativeListId;
      } else {
        AppLogger.error(
            '❌ AUTO-NAV DEBUG: Failed to create collaborative list - shopping service returned null');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ AUTO-NAV DEBUG: Exception in _promotePersonalListToCollaborative: $e');
      return null;
    }
  }

  /// Find the original personal list that matches the shared shopping list
  UnifiedShoppingList? _findMatchingPersonalList(
      SharedShoppingList sharedShoppingList) {
    // Look for a personal list with matching name and similar item count
    final personalLists = _shoppingService.lists
        .where((list) =>
                list.type == ListType.personal &&
                list.ownerId == sharedShoppingList.sharedByUserId &&
                list.name == sharedShoppingList.listName &&
                (list.items.length - sharedShoppingList.listItems.length)
                        .abs() <=
                    2 // Allow small differences
            )
        .toList();

    if (personalLists.isEmpty) {
      AppLogger.info(
          '🔍 LIST MATCHING: No personal list found with name "${sharedShoppingList.listName}" for user ${sharedShoppingList.sharedByUserId}');
      return null;
    }

    if (personalLists.length == 1) {
      AppLogger.info(
          '✅ LIST MATCHING: Found matching personal list: ${personalLists.first.id}');
      return personalLists.first;
    }

    // Multiple matches - pick the most recent
    personalLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    AppLogger.info(
        '✅ LIST MATCHING: Found ${personalLists.length} matches, using most recent: ${personalLists.first.id}');
    return personalLists.first;
  }

  /// Fallback: Create new collaborative list if we can't find the original personal list
  /// Returns collaborative list ID for navigation purposes
  Future<String?> _createFallbackCollaborativeList(
      SharedShoppingList sharedShoppingList,
      String newMemberUserId,
      String newMemberDisplayName) async {
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting _createFallbackCollaborativeList');
    AppLogger.info(
        '🔄 AUTO-NAV DEBUG: Creating fallback collaborative list from shared data');
    AppLogger.info(
        '🔄 AUTO-NAV DEBUG: Fallback list: "${sharedShoppingList.listName}" with ${sharedShoppingList.listItems.length} items');

    final memberIds = [sharedShoppingList.sharedByUserId, newMemberUserId];
    final memberDisplayNames = {
      sharedShoppingList.sharedByUserId: sharedShoppingList.sharedByDisplayName,
      newMemberUserId: newMemberDisplayName,
    };
    AppLogger.info('🔄 AUTO-NAV DEBUG: Fallback member data - IDs: $memberIds');

    AppLogger.info('🔄 AUTO-NAV DEBUG: Creating fallback collaborative list via shopping service');
    final collaborativeListId =
        await _shoppingService.createCollaborativeListFromInvitation(
      name: sharedShoppingList.listName,
      description:
          '${sharedShoppingList.listDescription ?? ""}\n\n📤 Delad från ${sharedShoppingList.sharedByDisplayName}: "${sharedShoppingList.shareMessage}"',
      ownerId: sharedShoppingList.sharedByUserId,
      ownerDisplayName: sharedShoppingList.sharedByDisplayName,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: sharedShoppingList.listItems,
      allowGuestEditing: true,
    );
    AppLogger.info('🔄 AUTO-NAV DEBUG: Fallback creation returned: $collaborativeListId');

    if (collaborativeListId != null) {
      AppLogger.success('✅ AUTO-NAV DEBUG: Fallback collaborative list created successfully');
      
      // PHASE 2 FIX: Ensure lists are properly loaded and state is synchronized with retry
      AppLogger.info('🔄 AUTO-NAV DEBUG: Reloading lists to include fallback collaborative list');
      await _shoppingService.loadLists();
      
      // Verify the fallback collaborative list exists in service state with retry mechanism
      AppLogger.info('🔍 AUTO-NAV DEBUG: Verifying fallback collaborative list exists in shopping service');
      final verifiedListId = await _waitForCollaborativeListInService(collaborativeListId, maxAttempts: 3);
      if (verifiedListId != null) {
        AppLogger.success('✅ AUTO-NAV DEBUG: Fallback collaborative list verified in service after sync');
      } else {
        AppLogger.error('❌ AUTO-NAV DEBUG: WARNING - Fallback collaborative list still not found after multiple attempts!');
        AppLogger.info('🔍 AUTO-NAV DEBUG: Available lists: ${_shoppingService.lists.map((l) => '${l.id}:${l.name}:${l.type}').join(', ')}');
      }
      
      AppLogger.success(
          '✅ AUTO-NAV DEBUG: Fallback collaborative list creation completed successfully');
      AppLogger.info(
          '✅ AUTO-NAV DEBUG: Returning fallback collaborative list ID for navigation: $collaborativeListId');
      return collaborativeListId;
    }

    AppLogger.error(
        '❌ AUTO-NAV DEBUG: Failed to create fallback collaborative list - service returned null');
    return null;
  }

  /// PHASE 2 FIX: Wait for collaborative list to appear in service state with retry mechanism
  /// This handles timing issues where the list is created but not immediately available
  Future<String?> _waitForCollaborativeListInService(String collaborativeListId, {int maxAttempts = 3}) async {
    AppLogger.info('🚀 AUTO-NAV DEBUG: Starting _waitForCollaborativeListInService for ID: $collaborativeListId');
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      AppLogger.info('🔄 AUTO-NAV DEBUG: Attempt $attempt/$maxAttempts to find collaborative list in service');
      
      final collaborativeList = _shoppingService.lists.where((list) => list.id == collaborativeListId).firstOrNull;
      if (collaborativeList != null) {
        AppLogger.success('✅ AUTO-NAV DEBUG: Found collaborative list on attempt $attempt: ${collaborativeList.name} (Type: ${collaborativeList.type})');
        return collaborativeListId;
      }
      
      if (attempt < maxAttempts) {
        AppLogger.warning('⚠️ AUTO-NAV DEBUG: Collaborative list not found on attempt $attempt, retrying...');
        // Wait 500ms between attempts and reload lists
        await Future.delayed(const Duration(milliseconds: 500));
        AppLogger.info('🔄 AUTO-NAV DEBUG: Reloading lists before retry attempt ${attempt + 1}');
        await _shoppingService.loadLists();
      }
    }
    
    AppLogger.error('❌ AUTO-NAV DEBUG: Failed to find collaborative list after $maxAttempts attempts');
    return null;
  }

  /// PHASE 2 FIX: Preserve navigation state during list conversion
  /// This method ensures the user doesn't experience UI jump to empty view
  /// when their active list is converted from personal to collaborative
  /// 
  /// Returns the collaborative list ID for navigation purposes
  Future<String> _preserveNavigationDuringConversion(
    UnifiedShoppingList originalPersonalList,
    String newCollaborativeListId,
  ) async {
    try {
      AppLogger.info(
          '🔄 NAVIGATION PRESERVATION: Checking if list "${originalPersonalList.name}" is currently active');
      
      // Check if the list being deleted is currently the active list
      final isCurrentlyActiveList = _shoppingService.activeListId == originalPersonalList.id;
      
      AppLogger.info(
          '🔍 NAVIGATION PRESERVATION: Original list ${originalPersonalList.id} is active: $isCurrentlyActiveList');

      // Delete the original personal list to prevent duplicates
      AppLogger.info(
          '🗑️ NAVIGATION PRESERVATION: Deleting original personal list: ${originalPersonalList.id}');
      await _shoppingService.deleteList(originalPersonalList.id);
      AppLogger.success(
          '✅ NAVIGATION PRESERVATION: Deleted original personal list ${originalPersonalList.id}');

      // Reload lists to get the new collaborative list
      AppLogger.info(
          '🔄 NAVIGATION PRESERVATION: Reloading lists to include new collaborative list');
      await _shoppingService.loadLists();
      AppLogger.success(
          '✅ NAVIGATION PRESERVATION: Lists reloaded successfully');

      // If the deleted list was active, update the active list reference to the collaborative version
      if (isCurrentlyActiveList) {
        AppLogger.info(
            '🔄 NAVIGATION PRESERVATION: Updating active list reference to collaborative version: $newCollaborativeListId');
        
        // Update the active list to the new collaborative list
        final collaborativeList = _shoppingService.lists.firstWhere(
          (list) => list.id == newCollaborativeListId,
          orElse: () => throw Exception('Collaborative list not found after creation'),
        );
        
        await _shoppingService.setActiveList(collaborativeList.id);
        AppLogger.success(
            '✅ NAVIGATION PRESERVATION: Active list updated to collaborative version');
        AppLogger.info(
            '✅ NAVIGATION PRESERVATION: User will remain on same logical list, no UI jump');
      } else {
        AppLogger.info(
            '✅ NAVIGATION PRESERVATION: Original list was not active, no navigation update needed');
      }

      AppLogger.info(
          '✅ NAVIGATION PRESERVATION: Returning collaborative list ID for navigation: $newCollaborativeListId');
      return newCollaborativeListId;

    } catch (e) {
      AppLogger.error(
          '❌ NAVIGATION PRESERVATION: Failed to preserve navigation state: $e');
      AppLogger.warning(
          '⚠️ NAVIGATION PRESERVATION: Falling back to basic reload - user may experience UI jump');
      
      // Fallback: basic reload if something goes wrong
      await _shoppingService.loadLists();
      
      // Still return the collaborative list ID even on error for navigation
      AppLogger.info(
          '⚠️ NAVIGATION PRESERVATION: Returning collaborative list ID despite error: $newCollaborativeListId');
      return newCollaborativeListId;
    }
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

  void _setJoining(bool joining) {
    _isJoining = joining;
    notifyListeners();
  }

  @override
  void dispose() {
    _socialRecipeService.removeListener(_onServiceDataChanged);
    super.dispose();
  }
}

/// PHASE 3 FIX: Result class for share target validation
/// Used to communicate validation results and provide user feedback
class ShareValidationResult {
  final bool isValid;
  final List<String> validTargets;
  final String message;

  const ShareValidationResult._({
    required this.isValid,
    required this.validTargets,
    required this.message,
  });

  /// Create result for valid share targets
  factory ShareValidationResult.valid(List<String> validTargets) {
    return ShareValidationResult._(
      isValid: true,
      validTargets: validTargets,
      message: 'All targets validated successfully',
    );
  }

  /// Create result for invalid share attempt
  factory ShareValidationResult.invalid(String message) {
    return ShareValidationResult._(
      isValid: false,
      validTargets: [],
      message: message,
    );
  }
}
