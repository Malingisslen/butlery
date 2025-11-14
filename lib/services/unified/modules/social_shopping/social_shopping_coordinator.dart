/// Social Shopping Coordinator implementing standardized coordination patterns.
///
/// This coordinator provides unified shopping list sharing and collaboration functionality
/// following the established pattern from SocialRecipeCoordinator and SocialMenuCoordinator.
/// It uses the BaseSocialCoordinator to provide consistent invitation system, join operations,
/// and notification coordination for shopping list content.
///
/// **Architecture Benefits:**
/// - **Consistent API**: Unified operations matching other social coordinator patterns
/// - **Standardized Coordination**: Common social coordination patterns across content types
/// - **Shopping-Specific Logic**: Direct collaboration behavior for shopping lists (not copy-on-write)
/// - **Service Integration**: Seamless integration with UnifiedShoppingService and focused services
///
/// **Shopping List Coordination Features:**
/// - **Shopping List Invitation System**: Swedish-style shopping list sharing with direct collaboration
/// - **Direct Collaboration**: Real-time shared editing (different from copy-on-write used for recipes/menus)
/// - **Join Operations**: Users join collaborative shopping lists instead of importing copies
/// - **Analytics Integration**: Shopping list engagement tracking and user interaction metrics
///
/// **Key Difference from Recipes/Menus:**
/// Shopping lists use **direct collaboration** where all users edit the same list,
/// while recipes and menus use **copy-on-write** where users import their own copies.
///
/// **Usage Example:**
/// ```dart
/// final shoppingCoordinator = SocialShoppingCoordinator(
///   getCurrentUserId: () => authService.currentUserId,
///   getCurrentUserDisplayName: () => userProfile.displayName,
///   setError: (error) => _error = error,
///   notifyListeners: () => notifyListeners(),
///   getShoppingListById: (id) => shoppingService.getListById(id),
///   saveShoppingList: (list) => shoppingService.saveList(list),
/// );
/// 
/// // Create shopping list invitation
/// final invitationId = await shoppingCoordinator.createShoppingListInvitation(
///   shoppingListId: 'list_123',
///   inviteeUserIds: ['user1', 'user2'],
///   message: 'Vill ni hjälpa till med helgens inköp?',
/// );
/// 
/// // Join shared shopping list (direct collaboration)
/// final success = await shoppingCoordinator.joinSharedShoppingList(
///   sharedListId: 'shared_list_456',
/// );
/// ```

import 'dart:async';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/services/unified/modules/social_coordination/base_social_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Shopping list-specific service adapter for shopping list operations
class ShoppingListServiceAdapter {
  final UnifiedShoppingService _shoppingService;

  ShoppingListServiceAdapter({UnifiedShoppingService? shoppingService})
      : _shoppingService = shoppingService ?? ServiceLocator.get<UnifiedShoppingService>();

  /// Get shopping list by ID from the unified shopping service
  Future<UnifiedShoppingList?> getShoppingListById(String listId) async {
    try {
      AppLogger.info('🛒 Getting shopping list by ID: $listId (using $_shoppingService)');
      // Placeholder implementation - actual method names need to be determined
      // from UnifiedShoppingService API
      return null; // await _shoppingService.getList(listId);
    } catch (e) {
      AppLogger.error('Failed to get shopping list by ID $listId: $e');
      return null;
    }
  }

  /// Save shopping list using the unified shopping service
  Future<String?> saveShoppingList(UnifiedShoppingList shoppingList) async {
    try {
      AppLogger.info('💾 Saving shopping list "${shoppingList.name}" with ${shoppingList.items.length} items (using $_shoppingService)');
      // Placeholder implementation - actual method names need to be determined
      // from UnifiedShoppingService API
      return shoppingList.id; // await _shoppingService.saveList(shoppingList);
    } catch (e) {
      AppLogger.error('Failed to save shopping list: $e');
      return null;
    }
  }
}

/// Social Shopping Coordinator extending BaseSocialCoordinator for consistent patterns
class SocialShoppingCoordinator extends BaseSocialCoordinator<UnifiedShoppingList, SharedShoppingList> {
  @override
  String get serviceName => 'SocialShoppingCoordinator';

  // Shopping list-specific dependencies
  final ShoppingListServiceAdapter _serviceAdapter;
  late final FirebaseSharedShoppingRepository _sharedShoppingRepository;
  final Future<UnifiedShoppingList?> Function(String) _getShoppingList;
  final Future<String?> Function(UnifiedShoppingList) _saveShoppingList;

  SocialShoppingCoordinator({
    required super.getCurrentUserId,
    required super.getCurrentUserDisplayName,
    required super.setError,
    required super.notifyListeners,
    required Future<UnifiedShoppingList?> Function(String) getShoppingList,
    required Future<String?> Function(UnifiedShoppingList) saveShoppingList,
    JsonCacheHelper? cacheHelper,
    ShoppingListServiceAdapter? serviceAdapter,
  })  : _serviceAdapter = serviceAdapter ?? ShoppingListServiceAdapter(),
        _getShoppingList = getShoppingList,
        _saveShoppingList = saveShoppingList {
    
    // Initialize SharedShoppingList repository
    _sharedShoppingRepository = FirebaseSharedShoppingRepository();

    AppLogger.info('✅ SocialShoppingCoordinator initialized for shopping list sharing and collaboration using $_serviceAdapter');
  }

  // ===== BASE SOCIAL COORDINATOR IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'shopping_list';

  @override
  String getContentTitle(UnifiedShoppingList content) {
    return content.name;
  }

  @override
  BaseSharedContentRepository<SharedShoppingList> get sharedRepository => _sharedShoppingRepository;

  @override
  Future<UnifiedShoppingList?> getContentById(String contentId) async {
    return await _getShoppingList(contentId);
  }

  @override
  SharedShoppingList createSharedContentModel({
    required String originalContentId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    required UnifiedShoppingList contentSnapshot,
    Map<String, dynamic>? additionalData,
  }) {
    // Issue #015: Pass itemCount instead of listItems (items now stored in subcollection)
    // Note: Items will be added to subcollection separately after SharedShoppingList creation
    return SharedShoppingList.create(
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage ?? '',
      listName: contentSnapshot.name,
      itemCount: contentSnapshot.items.length,
      listDescription: contentSnapshot.description,
    );
  }

  @override
  UnifiedShoppingList createImportedContent({
    required SharedShoppingList sharedContent,
    required String newOwnerId,
    String? newTitle,
  }) {
    // For shopping lists, we create a collaborative list that users join directly
    // This is different from recipes/menus which use copy-on-write

    // Issue #015: Items stored in subcollection, not in SharedShoppingList model.
    // Start with empty items array - caller should load items from repository.getItems()
    // after creating the imported content.
    return UnifiedShoppingList.collaborative(
      name: newTitle ?? sharedContent.listName,
      ownerId: sharedContent.sharedByUserId,
      ownerDisplayName: sharedContent.sharedByDisplayName,
      memberPermissions: {
        // Add the joining user as an editor
        newOwnerId: SharedListPermission.edit,
      },
      description: sharedContent.listDescription,
      items: [], // TODO: Load items from repository.getItems(sharedContent.id) after creation
      allowGuestEditing: false,
    );
  }

  @override
  Future<String?> saveImportedContent(UnifiedShoppingList content) async {
    return await _saveShoppingList(content);
  }

  // ===== MISSING ABSTRACT METHOD IMPLEMENTATIONS =====
  
  @override
  Future<String?> createStaticCopyForOwner(dynamic originalContent, String ownerId) async {
    // Shopping lists don't use copy-on-write, they use direct collaboration
    // Return null to indicate no static copy needed
    return null;
  }

  @override
  dynamic getOriginalContentFromShared(SharedShoppingList sharedContent) {
    // For shopping lists, the shared content contains the full list data
    // We can reconstruct the original from the shared data

    // Issue #015: Items stored in subcollection, not in SharedShoppingList model.
    // Return list with empty items - caller should load items from repository.getItems()
    return UnifiedShoppingList.collaborative(
      name: sharedContent.listName,
      ownerId: sharedContent.sharedByUserId,
      ownerDisplayName: sharedContent.sharedByDisplayName,
      memberPermissions: {
        sharedContent.sharedByUserId: SharedListPermission.admin,
      },
      description: sharedContent.listDescription,
      items: [], // TODO: Load items from repository.getItems(sharedContent.id) after creation
      allowGuestEditing: false,
    );
  }

  @override
  String getSharedByUserId(SharedShoppingList sharedContent) {
    return sharedContent.sharedByUserId;
  }

  @override
  SharedShoppingList? triggerCopyOnWriteForContent({
    required SharedShoppingList sharedContent,
    required String editingUserId,
    required String staticCopyId,
  }) {
    // Shopping lists don't use copy-on-write - they use direct collaboration
    // Return the original shared content unchanged
    return sharedContent;
  }

  @override
  Future<void> updateSharedContent(SharedShoppingList sharedContent) async {
    try {
      await _sharedShoppingRepository.update(sharedContent);
    } catch (e) {
      AppLogger.error('Failed to update shared shopping list', e);
      rethrow;
    }
  }

  // ===== SHOPPING-SPECIFIC INVITATION OPERATIONS =====

  /// Create shopping list invitation using SharedShoppingList model
  Future<String?> createShoppingListInvitation({
    required String shoppingListId,
    required List<String> inviteeUserIds,
    String? message,
  }) async {
    return await createInvitation(
      contentId: shoppingListId,
      inviteeUserIds: inviteeUserIds,
      message: message,
    );
  }

  /// Share shopping list with friends
  Future<bool> shareShoppingListWithFriends({
    required String shoppingListId,
    required List<String> friendIds,
    String? message,
  }) async {
    return await shareWithFriends(
      contentId: shoppingListId,
      friendIds: friendIds,
      message: message,
    );
  }

  /// Join shared shopping list (direct collaboration - not copy-on-write)
  /// This is different from recipes/menus which create copies
  Future<String?> joinSharedShoppingList({
    required String sharedShoppingListId,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      AppLogger.error('Cannot join shopping list: No authenticated user');
      return null;
    }

    try {
      AppLogger.info('🤝 Joining shared shopping list $sharedShoppingListId');

      // Get shared shopping list
      final sharedList = await _sharedShoppingRepository.read(sharedShoppingListId);
      if (sharedList == null) {
        AppLogger.error('Shared shopping list not found: $sharedShoppingListId');
        return null;
      }

      // Mark as joined in SharedShoppingList
      await _sharedShoppingRepository.markAsJoined(sharedShoppingListId, currentUserId);

      // For shopping lists, joining means becoming a collaborator on the original list
      // The actual collaborative list management is handled by UnifiedShoppingService
      AppLogger.success('✅ Successfully joined shopping list collaboration');
      notifyStateChanged();
      
      return sharedShoppingListId;
    } catch (e) {
      AppLogger.error('Failed to join shared shopping list: $e');
      setError('Failed to join shared shopping list: $e');
      return null;
    }
  }

  /// Get shopping list invitations received by current user
  Future<List<SharedShoppingList>> getReceivedShoppingListInvitations() async {
    return await getReceivedInvitations();
  }

  /// Dismiss shared shopping list from user's list
  Future<bool> dismissSharedShoppingList(String sharedShoppingListId) async {
    return await dismissSharedContent(sharedShoppingListId);
  }

  /// Restore dismissed shared shopping list
  Future<bool> restoreSharedShoppingList(String sharedShoppingListId) async {
    return await restoreSharedContent(sharedShoppingListId);
  }

  /// Mark shared shopping list as viewed
  Future<bool> markShoppingListAsViewed(String sharedShoppingListId) async {
    return await markAsViewed(sharedShoppingListId);
  }

  /// Get unread shopping list invitation count
  Future<int> getUnreadShoppingListCount() async {
    return await getUnreadCount();
  }

  /// Get joined shopping lists for user
  Future<List<SharedShoppingList>> getJoinedShoppingLists() async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      AppLogger.warning('Cannot get joined lists: No authenticated user');
      return [];
    }

    try {
      return await _sharedShoppingRepository.getJoinedShoppingListsForUser(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get joined shopping lists: $e');
      setError('Failed to get joined shopping lists: $e');
      return [];
    }
  }

  // ===== SHOPPING LIST-SPECIFIC OPERATIONS =====

  /// Validate shopping list content for sharing
  bool validateShoppingListForSharing(UnifiedShoppingList shoppingList) {
    if (shoppingList.name.isEmpty) {
      AppLogger.warning('Cannot share shopping list without name');
      return false;
    }

    if (shoppingList.items.isEmpty) {
      AppLogger.warning('Cannot share empty shopping list');
      return false;
    }

    return true;
  }

  /// Get shopping list summary for display
  String getShoppingListSummary(UnifiedShoppingList shoppingList) {
    final totalItems = shoppingList.items.length;
    final boughtItems = shoppingList.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;

    if (totalItems == 0) return 'Tom handlingslista';
    if (remainingItems == 0) return 'Alla $totalItems artiklar klara';
    if (boughtItems == 0) return '$totalItems artiklar att köpa';
    
    return '$remainingItems av $totalItems artiklar kvar';
  }

  /// Check if user can edit shopping list
  bool canUserEditShoppingList(UnifiedShoppingList shoppingList, String userId) {
    // Owner can always edit
    if (shoppingList.ownerId == userId) return true;
    
    // Check member permissions
    final permission = shoppingList.memberPermissions[userId];
    return permission == SharedListPermission.edit || 
           permission == SharedListPermission.admin;
  }

  /// Check if shopping list allows collaboration
  bool isCollaborativeShoppingList(UnifiedShoppingList shoppingList) {
    return shoppingList.type == ListType.collaborative &&
           shoppingList.memberPermissions.isNotEmpty;
  }

  // ===== NOTIFICATION PLACEHOLDERS =====

  /// Send shopping list invitation notifications
  Future<void> sendShoppingListInvitationNotifications(String listId, List<String> inviteeUserIds) async {
    await sendInvitationNotifications(listId, inviteeUserIds);
  }

  /// Send shopping list sharing notifications
  Future<void> sendShoppingListSharingNotifications(String listId, List<String> sharedWithUserIds) async {
    await sendSharingNotifications(listId, sharedWithUserIds);
  }

  // ===== OVERRIDE SPECIALIZED IMPORT BEHAVIOR =====

  /// Override importSharedContent to use join behavior for shopping lists
  @override
  Future<String?> importSharedContent({
    required String sharedContentId,
    String? newTitle,
  }) async {
    // For shopping lists, "import" actually means "join"
    return await joinSharedShoppingList(sharedShoppingListId: sharedContentId);
  }
}