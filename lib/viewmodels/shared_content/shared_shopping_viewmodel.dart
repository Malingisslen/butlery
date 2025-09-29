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
class SharedShoppingViewModel extends BaseSharedContentViewModel<SharedShoppingList> {
  
  // ===== DEPENDENCIES =====
  
  late final FirebaseSharedShoppingRepository _sharedShoppingRepository;
  late final SocialShoppingCoordinator _socialShoppingCoordinator;
  late final UnifiedShoppingService _shoppingService;

  // ===== CONSTRUCTOR =====
  
  SharedShoppingViewModel({
    FirebaseSharedShoppingRepository? sharedShoppingRepository,
    SocialShoppingCoordinator? socialShoppingCoordinator,
    UnifiedShoppingService? shoppingService,
  }) {
    _sharedShoppingRepository = sharedShoppingRepository ?? ServiceLocator.get<FirebaseSharedShoppingRepository>();
    _socialShoppingCoordinator = socialShoppingCoordinator ?? ServiceLocator.get<SocialShoppingCoordinator>();
    _shoppingService = shoppingService ?? ServiceLocator.get<UnifiedShoppingService>();
    
    AppLogger.info('SharedShoppingViewModel initialized with direct collaboration support');
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
    
    AppLogger.info('🔄 Loading shared shopping lists from repository for user: $userId');
    final shoppingLists = await _sharedShoppingRepository.getSharedShoppingListsForUser(userId);
    
    // Filter out dismissed shopping lists for main content view
    final visibleLists = shoppingLists.where((list) => !list.isDismissedBy(userId)).toList();
    
    AppLogger.info('✅ Loaded ${shoppingLists.length} shared shopping lists (${visibleLists.length} visible)');
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
           (content.listDescription?.toLowerCase().contains(query) ?? false) ||
           content.listItems.any((item) => item.name.toLowerCase().contains(query));
  }

  // ===== SHOPPING LIST-SPECIFIC GETTERS =====
  
  /// Get unviewed shopping lists count
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;
    
    return content.where((list) => !list.isViewedBy(userId)).length;
  }
  
  /// Get shopping lists shared by current user
  List<SharedShoppingList> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((list) => list.sharedByUserId == userId).toList();
  }
  
  /// Get shopping lists that can be joined
  List<SharedShoppingList> get joinableShoppingLists {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((list) => 
        !list.isJoinedBy(userId) && 
        list.sharedByUserId != userId
    ).toList();
  }
  
  /// Get joined shopping lists
  List<SharedShoppingList> get joinedShoppingLists {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((list) => list.isJoinedBy(userId)).toList();
  }
  
  /// Get total items across all shopping lists
  int get totalItemsInLists {
    return content.fold(0, (sum, list) => sum + list.listItems.length);
  }
  
  /// Get shopping lists with items
  List<SharedShoppingList> get listsWithItems {
    return content.where((list) => list.listItems.isNotEmpty).toList();
  }

  // ===== SHOPPING LIST OPERATIONS =====
  
  /// Join shared shopping list (direct collaboration)
  /// 
  /// Unlike recipes/menus, shopping lists use direct collaboration where
  /// all users edit the same list. Returns collaborative list ID for navigation.
  Future<String?> joinSharedShoppingList(SharedShoppingList sharedList) async {
    return await executeOperation(
      'Join shopping list "${getContentTitle(sharedList)}"',
      () async {
        final collaborativeListId = await _socialShoppingCoordinator.joinSharedShoppingList(
          sharedShoppingListId: sharedList.id,
        );
        
        if (collaborativeListId != null) {
          // Update local state to reflect joined status
          final userId = currentUserId!;
          final updatedList = sharedList.markJoinedBy(userId);
          updateContent(sharedList, updatedList);
          
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
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        await _sharedShoppingRepository.markAsDismissed(sharedList.id, userId);
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
  Future<bool> undismissSharedShoppingList(SharedShoppingList sharedList) async {
    final result = await executeOperation(
      'Restore shopping list "${getContentTitle(sharedList)}"',
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        await _sharedShoppingRepository.undismiss(sharedList.id, userId);
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
  Future<bool> markAsViewed(SharedShoppingList sharedList) async {
    final result = await executeOperation(
      'Mark shopping list as viewed "${getContentTitle(sharedList)}"',
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        // Check if already viewed to avoid unnecessary operations
        if (sharedList.isViewedBy(userId)) {
          return true;
        }
        
        await _sharedShoppingRepository.markAsViewed(sharedList.id, userId);
        
        // Update local state
        final updatedList = sharedList.markViewedBy(userId);
        updateContent(sharedList, updatedList);
        
        return true;
      },
    );
    
    return result ?? false;
  }

  // ===== STATUS CHECKING METHODS =====
  
  /// Check if shopping list is viewed by current user
  bool isShoppingListViewed(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return list.isViewedBy(userId);
  }
  
  /// Check if shopping list is joined by current user
  bool isShoppingListJoined(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return list.isJoinedBy(userId);
  }
  
  /// Check if shopping list is dismissed by current user
  bool isShoppingListDismissed(SharedShoppingList list) {
    final userId = currentUserId;
    if (userId == null) return false;
    return list.isDismissedBy(userId);
  }

  // ===== SHOPPING LIST-SPECIFIC OPERATIONS =====
  
  /// Get shopping list summary for display
  String getShoppingListSummary(SharedShoppingList list) {
    final totalItems = list.listItems.length;
    final checkedItems = list.listItems.where((item) => item.bought).length;
    final remainingItems = totalItems - checkedItems;
    
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
  
  /// Check if shopping list can be edited by current user
  bool canEditShoppingList(SharedShoppingList list) {
    // For shopping lists, users can edit if they've joined the collaborative list
    final userId = currentUserId;
    if (userId == null) return false;
    
    // Owner can always edit
    if (list.sharedByUserId == userId) return true;
    
    // Joined users can edit (direct collaboration)
    return list.isJoinedBy(userId);
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
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;
    
    await executeOperation(
      'Mark all shopping lists as viewed',
      () async {
        final unviewedLists = content.where((list) => !list.isViewedBy(userId)).toList();
        
        for (final list in unviewedLists) {
          await _sharedShoppingRepository.markAsViewed(list.id, userId);
        }
        
        // Refresh content to update local state
        await loadContent();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }
  
  /// Get shopping lists by sharing status
  List<SharedShoppingList> getShoppingListsByStatus({
    bool? isViewed,
    bool? isJoined, 
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((list) {
      if (isViewed != null && list.isViewedBy(userId) != isViewed) return false;
      if (isJoined != null && list.isJoinedBy(userId) != isJoined) return false;
      if (isDismissed != null && list.isDismissedBy(userId) != isDismissed) return false;
      return true;
    }).toList();
  }

  // ===== ANALYTICS =====
  
  /// Get shopping list engagement statistics
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};
    
    return {
      'total': content.length,
      'unread': content.where((l) => !l.isViewedBy(userId)).length,
      'joined': content.where((l) => l.isJoinedBy(userId)).length,
      'sharedByMe': content.where((l) => l.sharedByUserId == userId).length,
      'totalItems': totalItemsInLists,
      'withItems': content.where((l) => l.listItems.isNotEmpty).length,
    };
  }
  
  /// Get item completion statistics across all lists
  Map<String, int> getItemCompletionStats() {
    int totalItems = 0;
    int completedItems = 0;
    
    for (final list in content) {
      totalItems += list.listItems.length;
      completedItems += list.listItems.where((item) => item.bought).length;
    }
    
    return {
      'totalItems': totalItems,
      'completedItems': completedItems,
      'remainingItems': totalItems - completedItems,
      'completionPercentage': totalItems > 0 ? ((completedItems / totalItems) * 100).round() : 0,
    };
  }
  
  /// Get most common items across shopping lists
  Map<String, int> getMostCommonItems({int limit = 10}) {
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
  }
}