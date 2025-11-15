/// Shared Shopping List ViewModel providing shopping list-specific shared content management.
///
/// This specialized ViewModel handles all shared shopping list operations including loading,
/// joining, dismissing, and direct collaboration. It extends the base shared content
/// ViewModel but implements direct collaboration instead of copy-on-write, demonstrating
/// the flexibility of the base class architecture.
///
/// **Key Difference**: Shopping lists use **direct collaboration** where all users edit
/// the same list, while recipes and menus use **copy-on-write** collaboration.
///
/// **Responsibilities:**
/// - **Shopping List Loading**: Load shared shopping lists from repository with proper filtering
/// - **Join Operations**: Handle shopping list joining with direct collaboration
/// - **Status Management**: Track viewed/joined status and dismissal state
/// - **Direct Collaboration**: Support real-time collaborative editing
/// - **Search Integration**: Implement shopping list-specific search functionality
///
/// **Integration Points:**
/// - **SocialShoppingCoordinator**: For invitation and sharing operations
/// - **FirebaseSharedShoppingRepository**: For data persistence and retrieval
/// - **SharedShoppingList Model**: With direct collaboration support
/// - **UnifiedShoppingService**: For collaborative list management
///
/// **Usage Example:**
/// ```dart
/// final shoppingViewModel = SharedShoppingViewModel();
/// await shoppingViewModel.loadContent();
///
/// // Search functionality
/// shoppingViewModel.updateSearchQuery('handla');
/// final searchResults = shoppingViewModel.filteredContent;
///
/// // Shopping list operations
/// final listId = await shoppingViewModel.joinSharedShoppingList(sharedList);
/// await shoppingViewModel.dismissSharedShoppingList(sharedList);
/// ```

// lib/viewmodels/shared_content/shared_shopping_viewmodel.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized ViewModel for shared shopping list management and operations.
///
/// Implements direct collaboration model where users join and edit the same list,
/// different from the copy-on-write model used for recipes and menus.
///
/// Note (Issue #014): Uses status caching for synchronous filtering/counting.
/// Status loaded from Firestore subcollections and cached for performance.
class SharedShoppingViewModel
    extends BaseSharedContentViewModel<SharedShoppingList> {
  // ===== DEPENDENCIES =====

  late final SocialShoppingCoordinator _socialShoppingCoordinator;
  late final UnifiedShoppingService _shoppingService;
  late final FirebaseSharedShoppingRepository
      _sharedShoppingRepository; // TODO: Remove in Phase 3 - still used for status cache loading

  // ===== STATUS CACHING (ISSUE #014) =====

  /// Cached viewed status (listId → bool)
  final Map<String, bool> _viewedStatusCache = {};

  /// Cached joined status (listId → bool)
  final Map<String, bool> _joinedStatusCache = {};

  /// Cached dismissed status (listId → bool)
  final Map<String, bool> _dismissedStatusCache = {};

  // ===== CONSTRUCTOR =====

  SharedShoppingViewModel({
    SocialShoppingCoordinator? socialShoppingCoordinator,
    UnifiedShoppingService? shoppingService,
    FirebaseSharedShoppingRepository?
        sharedShoppingRepository, // TODO: Remove in Phase 3
  }) {
    _socialShoppingCoordinator = socialShoppingCoordinator ??
        ServiceLocator.get<SocialShoppingCoordinator>();
    _shoppingService =
        shoppingService ?? ServiceLocator.get<UnifiedShoppingService>();
    _sharedShoppingRepository = sharedShoppingRepository ??
        ServiceLocator.get<
            FirebaseSharedShoppingRepository>(); // TODO: Remove in Phase 3

    AppLogger.info(
        'SharedShoppingViewModel initialized with direct collaboration support');
  }

  /// Load status for a shopping list from repository and cache it
  Future<void> _loadStatusForList(String listId, String userId) async {
    try {
      final viewed = await _sharedShoppingRepository.hasViewed(listId, userId);
      final joined = await _sharedShoppingRepository.hasEngaged(listId, userId);
      final dismissed =
          await _sharedShoppingRepository.hasDismissed(listId, userId);

      _viewedStatusCache[listId] = viewed;
      _joinedStatusCache[listId] = joined;
      _dismissedStatusCache[listId] = dismissed;
    } catch (e) {
      AppLogger.error('Failed to load status for list $listId', e);
    }
  }

  /// Load status for all shopping lists in bulk
  Future<void> _loadStatusForAllLists(
      List<SharedShoppingList> lists, String userId) async {
    for (final list in lists) {
      await _loadStatusForList(list.id, userId);
    }
  }

  /// Check if list is dismissed using cache (falls back to false if not cached)
  bool _isDismissed(String listId) {
    return _dismissedStatusCache[listId] ?? false;
  }

  /// Check if list is viewed using cache (falls back to false if not cached)
  bool _isViewed(String listId) {
    return _viewedStatusCache[listId] ?? false;
  }

  /// Check if list is joined using cache (falls back to false if not cached)
  bool _isJoined(String listId) {
    return _joinedStatusCache[listId] ?? false;
  }

  // ===== BASE CLASS IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'shopping_list';

  @override
  Future<List<SharedShoppingList>> loadContentFromRepository() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
        '🔄 Loading shared shopping lists from coordinator for user: $userId');
    final shoppingLists =
        await _socialShoppingCoordinator.getSharedShoppingListsForUser(userId);

    // Load status for all lists to populate cache (Issue #014)
    await _loadStatusForAllLists(shoppingLists, userId);

    // Filter out dismissed shopping lists for main content view using cache
    final visibleLists =
        shoppingLists.where((list) => !_isDismissed(list.id)).toList();

    AppLogger.info(
        '✅ Loaded ${shoppingLists.length} shared shopping lists (${visibleLists.length} visible)');
    return visibleLists;
  }

  @override
  String getContentTitle(SharedShoppingList content) {
    return content.listName;
  }

  @override
  bool contentMatchesSearch(SharedShoppingList content, String searchQuery) {
    final query = searchQuery.toLowerCase();

    return content.listName.toLowerCase().contains(query) ||
        content.sharedByDisplayName.toLowerCase().contains(query) ||
        (content.shareMessage?.toLowerCase().contains(query) ?? false) ||
        (content.listDescription?.toLowerCase().contains(query) ?? false);
    // Note (Issue #015): Items now in subcollection, can't search without loading all items
  }

  @override
  Future<List<SharedShoppingList>> loadContentWithPagination({
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
        '🔄 Loading shared shopping lists with pagination (limit: $limit, cursor: ${startAfter != null})');
    final shoppingLists =
        await _sharedShoppingRepository.getSharedContentForUser(
      userId,
      limit: limit,
      startAfter: startAfter,
    );

    // Load status for all lists to populate cache (Issue #014)
    await _loadStatusForAllLists(shoppingLists, userId);

    // Filter out dismissed shopping lists for main content view using cache
    final visibleLists =
        shoppingLists.where((list) => !_isDismissed(list.id)).toList();

    AppLogger.info(
        '✅ Loaded ${shoppingLists.length} shared shopping lists (${visibleLists.length} visible)');
    return visibleLists;
  }

  @override
  DocumentSnapshot? getLastDocumentFromContent(
      List<SharedShoppingList> content) {
    return null; // Will be enhanced when repository returns document snapshots
  }

  // ===== SHOPPING LIST-SPECIFIC GETTERS =====

  /// Get unviewed shopping lists count (using cache - Issue #014)
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;

    return content.where((list) => !_isViewed(list.id)).length;
  }

  /// Get shopping lists shared by current user
  List<SharedShoppingList> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((list) => list.sharedByUserId == userId).toList();
  }

  /// Get shopping lists that can be joined (using cache - Issue #014)
  List<SharedShoppingList> get joinableShoppingLists {
    final userId = currentUserId;
    if (userId == null) return [];

    return content
        .where((list) => !_isJoined(list.id) && list.sharedByUserId != userId)
        .toList();
  }

  /// Get joined shopping lists (using cache - Issue #014)
  List<SharedShoppingList> get joinedShoppingLists {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((list) => _isJoined(list.id)).toList();
  }

  /// Get total items across all shopping lists
  /// Issue #015: Uses itemCount field (items in subcollection)
  int get totalItemsInLists {
    return content.fold(0, (total, list) => total + list.itemCount);
  }

  /// Get shopping lists with items
  /// Issue #015: Uses itemCount field (items in subcollection)
  List<SharedShoppingList> get listsWithItems {
    return content.where((list) => list.itemCount > 0).toList();
  }

  // ===== SHOPPING LIST OPERATIONS =====

  /// Join shared shopping list (direct collaboration)
  ///
  /// Unlike recipes/menus, shopping lists use direct collaboration where
  /// all users edit the same list. Returns collaborative list ID for navigation.
  ///
  /// Note (Issue #014): Updates cache instead of local model state.
  Future<String?> joinSharedShoppingList(SharedShoppingList sharedList) async {
    return await executeOperation(
      'Join shopping list "${getContentTitle(sharedList)}"',
      () async {
        final collaborativeListId =
            await _socialShoppingCoordinator.joinSharedShoppingList(
          sharedShoppingListId: sharedList.id,
        );

        if (collaborativeListId != null) {
          // Update cache to reflect joined status (Issue #014)
          _joinedStatusCache[sharedList.id] = true;
          notifyListeners(); // Notify UI to refresh

          AppLogger.success('✅ Joined shopping list for direct collaboration');
        }

        return collaborativeListId;
      },
    );
  }

  /// Dismiss shared shopping list from user's list
  Future<bool> dismissSharedShoppingList(SharedShoppingList sharedList) async {
    final result = await executeOperation(
      'Dismiss shopping list "${getContentTitle(sharedList)}"',
      () async {
        await _socialShoppingCoordinator
            .dismissSharedShoppingList(sharedList.id);
        return true;
      },
    );

    if (result == true) {
      // Remove from local collection
      removeContent(sharedList);
    }

    return result ?? false;
  }

  /// Restore dismissed shopping list to user's list
  Future<bool> undismissSharedShoppingList(
      SharedShoppingList sharedList) async {
    final result = await executeOperation(
      'Restore shopping list "${getContentTitle(sharedList)}"',
      () async {
        await _socialShoppingCoordinator
            .restoreSharedShoppingList(sharedList.id);
        return true;
      },
    );

    if (result == true) {
      // Add back to local collection if not already present
      if (!content.any((l) => l.id == sharedList.id)) {
        addContent(sharedList);
      }
    }

    return result ?? false;
  }

  /// Mark shopping list as viewed
  ///
  /// Note (Issue #014): Updates cache instead of local model state.
  Future<bool> markAsViewed(SharedShoppingList sharedList) async {
    final result = await executeOperation(
      'Mark shopping list as viewed "${getContentTitle(sharedList)}"',
      () async {
        // Check if already viewed to avoid unnecessary operations (using cache)
        if (_isViewed(sharedList.id)) {
          return true;
        }

        await _socialShoppingCoordinator
            .markShoppingListAsViewed(sharedList.id);

        // Update cache (Issue #014)
        _viewedStatusCache[sharedList.id] = true;
        notifyListeners(); // Notify UI to refresh

        return true;
      },
    );

    return result ?? false;
  }

  // ===== STATUS CHECKING METHODS =====

  /// Check if shopping list is viewed by current user (using cache - Issue #014)
  bool isShoppingListViewed(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isViewed(list.id);
  }

  /// Check if shopping list is joined by current user (using cache - Issue #014)
  bool isShoppingListJoined(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isJoined(list.id);
  }

  /// Check if shopping list is dismissed by current user (using cache - Issue #014)
  bool isShoppingListDismissed(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _isDismissed(list.id);
  }

  // ===== SHOPPING LIST-SPECIFIC OPERATIONS =====

  /// Get shopping list summary for display
  /// Issue #015: Items in subcollection - can't determine checked/unchecked without loading items
  String getShoppingListSummary(SharedShoppingList list) {
    final totalItems = list.itemCount;
    // Note: Can't determine checkedItems without loading from repository.getItems()
    const checkedItems = 0; // TODO: Load items if detailed stats needed
    final remainingItems = totalItems;

    if (totalItems == 0) return 'Tom handlingslista';
    if (remainingItems == 0) return 'Alla $totalItems artiklar klara';
    if (checkedItems == 0) return '$totalItems artiklar att köpa';

    return '$remainingItems av $totalItems artiklar kvar';
  }

  /// Get time ago text for shopping list
  String getShoppingListTimeAgo(SharedShoppingList list) {
    final now = DateTime.now();
    final difference = now.difference(list.sharedAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Check if shopping list can be edited by current user (using cache - Issue #014)
  bool canEditShoppingList(SharedShoppingList list) {
    // For shopping lists, users can edit if they've joined the collaborative list
    final userId = currentUserId;
    if (userId == null) return false;

    // Owner can always edit
    if (list.sharedByUserId == userId) return true;

    // Joined users can edit (direct collaboration)
    return _isJoined(list.id);
  }

  /// Get collaborative shopping list from service
  UnifiedShoppingList? getCollaborativeList(SharedShoppingList sharedList) {
    // Try to find the corresponding collaborative list in the shopping service
    return _shoppingService.lists
        .where((list) =>
            list.type == ListType.collaborative &&
            list.name.contains(sharedList.listName))
        .firstOrNull;
  }

  // ===== BULK OPERATIONS =====

  /// Mark all shopping lists as viewed
  ///
  /// Note (Issue #014): Uses cache to identify unviewed lists, then updates cache after marking.
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;

    await executeOperation(
      'Mark all shopping lists as viewed',
      () async {
        final unviewedLists =
            content.where((list) => !_isViewed(list.id)).toList();

        for (final list in unviewedLists) {
          await _sharedShoppingRepository.markAsViewed(list.id, userId);
          // Update cache (Issue #014)
          _viewedStatusCache[list.id] = true;
        }

        // Notify UI to refresh
        notifyListeners();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }

  /// Get shopping lists by sharing status (using cache - Issue #014)
  List<SharedShoppingList> getShoppingListsByStatus({
    bool? isViewed,
    bool? isJoined,
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((list) {
      if (isViewed != null && _isViewed(list.id) != isViewed) return false;
      if (isJoined != null && _isJoined(list.id) != isJoined) return false;
      if (isDismissed != null && _isDismissed(list.id) != isDismissed) {
        return false;
      }
      return true;
    }).toList();
  }

  // ===== ANALYTICS =====

  /// Get shopping list engagement statistics (using cache - Issue #014)
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};

    return {
      'total': content.length,
      'unread': content.where((l) => !_isViewed(l.id)).length,
      'joined': content.where((l) => _isJoined(l.id)).length,
      'sharedByMe': content.where((l) => l.sharedByUserId == userId).length,
      'totalItems': totalItemsInLists,
      'withItems': content.where((l) => l.itemCount > 0).length,
    };
  }

  /// Get item completion statistics across all lists
  /// Issue #015: Items in subcollection - returns count-based stats only
  /// For detailed completion stats, need to load items from repository.getItems()
  Map<String, int> getItemCompletionStats() {
    int totalItems = 0;

    for (final list in content) {
      totalItems += list.itemCount;
    }

    // Note: Can't determine completed vs remaining without loading all items
    return {
      'totalItems': totalItems,
      'completedItems': 0, // TODO: Load items if completion tracking needed
      'remainingItems': totalItems,
      'completionPercentage': 0,
    };
  }

  /// Get most common items across shopping lists
  /// Issue #015: Items in subcollection - not available without loading all items
  /// This method would require calling repository.getItems() for each list
  Map<String, int> getMostCommonItems({int limit = 10}) {
    // Note: Items now in subcollection, can't analyze without loading from repository
    // TODO: If this feature is needed, implement async version that loads items
    return {};

    /* Original implementation (requires items to be loaded):
    final itemCount = <String, int>{};

    for (final list in content) {
      for (final item in list.listItems) {
        final itemName = item.name.toLowerCase().trim();
        itemCount[itemName] = (itemCount[itemName] ?? 0) + 1;
      }
    }

    final sortedItems = itemCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedItems.take(limit));
    */
  }
}
