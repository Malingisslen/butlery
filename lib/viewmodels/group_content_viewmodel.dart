// lib/viewmodels/group_content_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Manages content shared within social groups, providing filtering and activity tracking.
///
/// This ViewModel serves as the primary interface for group content management,
/// handling the display and interaction with recipes, menus, and shopping lists
/// shared within a specific social group. It implements reactive state management
/// for real-time content updates and provides comprehensive filtering capabilities.
///
/// Key responsibilities:
/// - Loading and caching group-specific shared content
/// - Managing group activity timeline and feed generation
/// - Providing search and filtering functionality across all content types
/// - Handling group sharing operations with proper state management
/// - Generating group statistics and engagement metrics
///
/// The ViewModel follows MVVM architecture patterns and integrates with the
/// unified social sharing system to provide a seamless group content experience.
///
/// Example usage:
/// ```dart
/// final viewModel = GroupContentViewModel(
///   friendsService: ServiceLocator.get<UnifiedFriendsService>(),
///   sharingRepository: ServiceLocator.get<SocialSharingRepository>(),
/// );
/// await viewModel.initialize(selectedGroup);
/// // Content is now available via getters like groupSharedRecipes
/// ```
class GroupContentViewModel extends ChangeNotifier with StreamManagementMixin {
  final SocialSharingRepository _sharingRepository;

  // ===== STATE MANAGEMENT =====

  // Group state
  FriendCategory? _group;
  
  // Search and filtering state
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // Loading and error state
  bool _isLoading = false;
  String? _error;
  bool _isSharing = false;

  // Content state
  List<SharedContent> _groupSharedContent = [];
  List<SharedRecipe> _groupSharedRecipes = [];
  List<SharedMenu> _groupSharedMenus = [];
  List<UnifiedShoppingList> _groupSharedShoppingLists = [];
  
  // Activity state
  List<Map<String, dynamic>> _groupActivityFeed = [];

  GroupContentViewModel({
    required SocialSharingRepository sharingRepository,
  })  : _sharingRepository = sharingRepository;

  // ===== GETTERS =====

  // Basic state getters
  FriendCategory? get group => _group;
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isSharing => _isSharing;

  // Content getters
  List<SharedContent> get groupSharedContent => List.unmodifiable(_groupSharedContent);
  List<SharedRecipe> get groupSharedRecipes => List.unmodifiable(_groupSharedRecipes);
  List<SharedMenu> get groupSharedMenus => List.unmodifiable(_groupSharedMenus);
  List<UnifiedShoppingList> get groupSharedShoppingLists => List.unmodifiable(_groupSharedShoppingLists);
  List<Map<String, dynamic>> get groupActivityFeed => List.unmodifiable(_groupActivityFeed);

  // Content availability checks
  bool get hasGroupContent => 
      _groupSharedRecipes.isNotEmpty || 
      _groupSharedMenus.isNotEmpty || 
      _groupSharedShoppingLists.isNotEmpty;

  bool get hasGroupActivity => _groupActivityFeed.isNotEmpty;

  // Filtered content
  List<SharedRecipe> get filteredGroupRecipes => _filterRecipes(_groupSharedRecipes, _searchQuery);
  List<SharedMenu> get filteredGroupMenus => _filterMenus(_groupSharedMenus, _searchQuery);
  List<UnifiedShoppingList> get filteredGroupShoppingLists => _filterShoppingLists(_groupSharedShoppingLists, _searchQuery);

  bool get hasFilteredContent => 
      filteredGroupRecipes.isNotEmpty || 
      filteredGroupMenus.isNotEmpty || 
      filteredGroupShoppingLists.isNotEmpty;

  // Content counts
  int get totalGroupRecipes => _groupSharedRecipes.length;
  int get totalGroupMenus => _groupSharedMenus.length;
  int get totalGroupShoppingLists => _groupSharedShoppingLists.length;
  int get totalGroupContent => totalGroupRecipes + totalGroupMenus + totalGroupShoppingLists;

  // Group statistics
  Map<String, dynamic> get groupContentStats => {
    'totalRecipes': totalGroupRecipes,
    'totalMenus': totalGroupMenus,
    'totalShoppingLists': totalGroupShoppingLists,
    'totalContent': totalGroupContent,
    'recentActivity': _groupActivityFeed.take(5).length,
    'groupMembers': _group?.friendCount ?? 0,
  };

  // ===== INITIALIZATION =====

  /// Initializes the ViewModel with a specific group and loads its content.
  ///
  /// This method sets up the ViewModel to work with the specified group,
  /// loads all shared content for that group, and prepares the activity feed.
  /// Must be called before accessing any group content.
  ///
  /// @param [group] The social group to manage content for
  /// @throws Exception if content loading fails
  Future<void> initialize(FriendCategory group) async {
    _group = group;
    await loadGroupContent();
    AppLogger.info('🏷️ GroupContentViewModel initialized for group: ${group.name}');
  }

  // ===== CONTENT OPERATIONS =====

  /// Loads all content shared to the current group from the repository.
  ///
  /// Fetches shared recipes, menus, and shopping lists from the social sharing
  /// repository, filters them by group membership, and organizes them by type.
  /// Also generates the group activity feed based on sharing timestamps.
  ///
  /// The method handles authentication through the repository layer and
  /// provides comprehensive error handling with user-friendly messages.
  ///
  /// @throws Exception if repository access fails or network issues occur
  Future<void> loadGroupContent() async {
    if (_group == null) {
      AppLogger.error('Cannot load group content: No group specified');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info('📥 Loading content for group: ${_group!.name}');

      // Get shared content from repository filtered by group
      // Using placeholder user ID - actual user ID is managed by the auth layer
      final sharedContentStream = _sharingRepository.getSharedWithMe('current_user_id');
      final sharedContent = await sharedContentStream.first;
      
      // Filter content shared to this specific group
      _groupSharedContent = sharedContent.where((content) {
        return content.sharedWithGroupIds.contains(_group!.id);
      }).toList();

      // Separate content by type
      _groupSharedRecipes = _groupSharedContent
          .where((content) => content.contentType == 'recipe')
          .map((content) => _convertToSharedRecipe(content))
          .where((recipe) => recipe != null)
          .cast<SharedRecipe>()
          .toList();

      _groupSharedMenus = _groupSharedContent
          .where((content) => content.contentType == 'menu')
          .map((content) => _convertToSharedMenu(content))
          .where((menu) => menu != null)
          .cast<SharedMenu>()
          .toList();

      _groupSharedShoppingLists = _groupSharedContent
          .where((content) => content.contentType == 'shopping_list')
          .map((content) => _convertToShoppingList(content))
          .where((list) => list != null)
          .cast<UnifiedShoppingList>()
          .toList();

      // Load group activity feed
      await _loadGroupActivityFeed();

      AppLogger.success('✅ Loaded ${_groupSharedContent.length} items for group: ${_group!.name}');
    } catch (e) {
      AppLogger.error('❌ Failed to load group content', e);
      _setError('Kunde inte ladda gruppinnehåll: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Load group activity feed
  Future<void> _loadGroupActivityFeed() async {
    try {
      AppLogger.info('📋 Loading activity feed for group: ${_group!.name}');

      // Create activity feed from shared content
      _groupActivityFeed = _groupSharedContent.map((content) {
        return {
          'id': content.id,
          'type': content.contentType,
          'title': _getContentTitle(content),
          'ownerName': content.metadata['ownerDisplayName'] ?? 'Okänd användare',
          'ownerAvatarUrl': content.metadata['ownerAvatarUrl'],
          'sharedAt': content.sharedAt,
          'action': 'shared_to_group',
          'groupName': _group!.name,
          'metadata': content.metadata,
        };
      }).toList();

      // Sort by date (most recent first)
      _groupActivityFeed.sort((a, b) {
        final aDate = a['sharedAt'] as DateTime;
        final bDate = b['sharedAt'] as DateTime;
        return bDate.compareTo(aDate);
      });

      AppLogger.success('✅ Loaded ${_groupActivityFeed.length} activity items');
    } catch (e) {
      AppLogger.error('❌ Failed to load group activity feed', e);
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    AppLogger.info('🔍 Group search query updated: "$query"');
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
    AppLogger.info('🧹 Group search cleared');
  }

  /// Set tab index
  void setTabIndex(int index) {
    if (index != _currentTabIndex) {
      _currentTabIndex = index;
      notifyListeners();
      AppLogger.info('📑 Group tab changed to index: $index');
    }
  }

  /// Refresh all group content
  Future<void> refresh() async {
    await loadGroupContent();
  }

  // ===== GROUP SHARING OPERATIONS =====

  /// Shares content to the current group and refreshes the group content.
  ///
  /// Adds the specified content to the group's shared content collection
  /// through the social sharing repository. Automatically refreshes the
  /// group content list to include the newly shared item.
  ///
  /// @param [content] The content to share with the group
  /// @returns True if sharing succeeded, false otherwise
  /// @throws Exception if sharing fails due to permissions or network issues
  Future<bool> shareContentToGroup(SharedContent content) async {
    if (_group == null) {
      AppLogger.error('Cannot share to group: No group specified');
      return false;
    }

    _setSharing(true);
    
    try {
      AppLogger.info('📤 Sharing content to group: ${_group!.name}');
      
      await _sharingRepository.shareToGroup(_group!.id, content);
      
      // Reload group content to include the new share
      await loadGroupContent();
      
      AppLogger.success('✅ Content shared to group successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to share content to group', e);
      _setError('Kunde inte dela innehåll till gruppen: ${e.toString()}');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Get group sharing statistics
  Future<Map<String, dynamic>> getGroupSharingStats() async {
    if (_group == null) return {};

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final groupOperations = friendsService.groupSharing;
      
      return groupOperations.getGroupSharingStats(_group!.id);
    } catch (e) {
      AppLogger.error('❌ Failed to get group sharing stats', e);
      return {};
    }
  }

  // ===== HELPER METHODS =====

  /// Filter recipes by search query
  List<SharedRecipe> _filterRecipes(List<SharedRecipe> recipes, String query) {
    if (query.isEmpty) return recipes;
    
    final lowerQuery = query.toLowerCase();
    return recipes.where((recipe) {
      return recipe.recipeSnapshot.title.toLowerCase().contains(lowerQuery) ||
             (recipe.recipeSnapshot.description.toLowerCase().contains(lowerQuery)) ||
             (recipe.sharedByDisplayName.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Filter menus by search query
  List<SharedMenu> _filterMenus(List<SharedMenu> menus, String query) {
    if (query.isEmpty) return menus;
    
    final lowerQuery = query.toLowerCase();
    return menus.where((menu) {
      return menu.menuTitle.toLowerCase().contains(lowerQuery) ||
             (menu.shareMessage?.toLowerCase().contains(lowerQuery) ?? false) ||
             (menu.sharedByDisplayName.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Filter shopping lists by search query
  List<UnifiedShoppingList> _filterShoppingLists(List<UnifiedShoppingList> lists, String query) {
    if (query.isEmpty) return lists;
    
    final lowerQuery = query.toLowerCase();
    return lists.where((list) {
      return list.name.toLowerCase().contains(lowerQuery) ||
             (list.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Convert SharedContent to SharedRecipe
  SharedRecipe? _convertToSharedRecipe(SharedContent content) {
    try {
      if (content.contentType != 'recipe') return null;
      
      // Create a simplified Recipe snapshot from metadata
      final recipeSnapshot = Recipe(
        core: RecipeCore(
          id: content.contentId,
          title: content.metadata['title'] ?? 'Namnlöst recept',
          description: content.metadata['description'] ?? '',
          ingredients: List<String>.from(content.metadata['ingredients'] ?? []),
          instructions: List<String>.from(content.metadata['instructions'] ?? []),
          imageUrls: content.metadata['imageUrl'] != null ? [content.metadata['imageUrl'] as String] : [],
          mealType: content.metadata['mealType'] ?? 'Middag',
          portions: content.metadata['portions'] as int?,
          timeMinutes: content.metadata['timeMinutes'] as int?,
          rating: (content.metadata['rating'] as num?)?.toDouble(),
          tags: List<String>.from(content.metadata['tags'] ?? []),
          sourceUrl: content.metadata['sourceUrl'] as String?,
          createdAt: content.sharedAt,
          updatedAt: content.sharedAt,
        ),
        type: RecipeType.shared,
      );
      
      return SharedRecipe(
        id: content.id,
        originalRecipeId: content.contentId,
        sharedByUserId: content.ownerId,
        sharedByDisplayName: content.metadata['ownerDisplayName'] ?? 'Okänd användare',
        sharedToUserIds: content.sharedWithUserIds,
        sharedAt: content.sharedAt,
        shareMessage: content.metadata['shareMessage'] as String?,
        allowImport: true,
        viewedByUserIds: content.viewedBy.keys.toList(),
        engagedByUserIds: content.acceptedBy.keys.toList(),
        dismissedByUserIds: content.declinedBy.keys.toList(),
        recipeSnapshot: recipeSnapshot,
      );
    } catch (e) {
      AppLogger.error('Failed to convert SharedContent to SharedRecipe', e);
      return null;
    }
  }

  /// Convert SharedContent to SharedMenu
  SharedMenu? _convertToSharedMenu(SharedContent content) {
    try {
      if (content.contentType != 'menu') return null;
      
      // Create a simplified menu snapshot from metadata
      final menuSnapshot = content.metadata['menuSnapshot'] as Map<String, dynamic>? ?? {};
      final reconstructedMenu = <String, List<Recipe>>{};
      
      // Reconstruct menu from metadata if available
      for (final entry in menuSnapshot.entries) {
        final recipeList = <Recipe>[];
        final recipes = entry.value as List<dynamic>? ?? [];
        
        for (final recipeData in recipes) {
          try {
            if (recipeData is Map<String, dynamic>) {
              final recipe = Recipe(
                core: RecipeCore(
                  id: recipeData['id'] ?? '',
                  title: recipeData['title'] ?? 'Namnlöst recept',
                  description: recipeData['description'] ?? '',
                  ingredients: List<String>.from(recipeData['ingredients'] ?? []),
                  instructions: List<String>.from(recipeData['instructions'] ?? []),
                  imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
                  mealType: recipeData['mealType'] ?? 'Middag',
                  portions: recipeData['portions'] as int?,
                  timeMinutes: recipeData['timeMinutes'] as int?,
                  rating: (recipeData['rating'] as num?)?.toDouble(),
                  tags: List<String>.from(recipeData['tags'] ?? []),
                  sourceUrl: recipeData['sourceUrl'] as String?,
                  createdAt: content.sharedAt,
                  updatedAt: content.sharedAt,
                ),
                type: RecipeType.shared,
              );
              recipeList.add(recipe);
            }
          } catch (e) {
            // Skip invalid recipes
            continue;
          }
        }
        reconstructedMenu[entry.key] = recipeList;
      }
      
      return SharedMenu(
        id: content.id,
        sharedByUserId: content.ownerId,
        sharedByDisplayName: content.metadata['ownerDisplayName'] ?? 'Okänd användare',
        sharedToUserIds: content.sharedWithUserIds,
        sharedAt: content.sharedAt,
        shareMessage: content.metadata['shareMessage'] as String?,
        menuTitle: content.metadata['title'] ?? 'Namnlös meny',
        menuSnapshot: reconstructedMenu,
        viewedByUserIds: content.viewedBy.keys.toList(),
        engagedByUserIds: content.acceptedBy.keys.toList(),
        dismissedByUserIds: content.declinedBy.keys.toList(),
      );
    } catch (e) {
      AppLogger.error('Failed to convert SharedContent to SharedMenu', e);
      return null;
    }
  }

  /// Convert SharedContent to UnifiedShoppingList
  UnifiedShoppingList? _convertToShoppingList(SharedContent content) {
    try {
      if (content.contentType != 'shopping_list') return null;
      
      // This is a simplified conversion - in a real implementation,
      // you'd need to properly reconstruct the shopping list from the metadata
      return UnifiedShoppingList.personal(
        name: content.metadata['listName'] ?? 'Namnlös lista',
        ownerId: content.ownerId,
        ownerDisplayName: content.metadata['ownerDisplayName'] ?? 'Okänd användare',
      );
    } catch (e) {
      AppLogger.error('Failed to convert SharedContent to UnifiedShoppingList', e);
      return null;
    }
  }

  /// Get content title from metadata
  String _getContentTitle(SharedContent content) {
    switch (content.contentType) {
      case 'recipe':
        return content.metadata['title'] ?? 'Namnlöst recept';
      case 'menu':
        return content.metadata['title'] ?? 'Namnlös meny';
      case 'shopping_list':
        return content.metadata['listName'] ?? 'Namnlös lista';
      default:
        return 'Okänt innehåll';
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

  void _setSharing(bool sharing) {
    _isSharing = sharing;
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