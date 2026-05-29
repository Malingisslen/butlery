/// Coordinates shopping-list sharing and collaboration on top of
/// [BaseSocialCoordinator]. Unlike recipes/menus (copy-on-write), shopping
/// lists use **direct collaboration**: callers join the original list rather
/// than importing a copy. See the test header for usage examples.

import 'dart:async';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
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
      : _shoppingService =
            shoppingService ?? ServiceLocator.get<UnifiedShoppingService>();

  Future<UnifiedShoppingList?> getShoppingListById(String listId) async {
    try {
      return _shoppingService.lists.where((l) => l.id == listId).firstOrNull;
    } catch (e) {
      AppLogger.error('Failed to get shopping list by ID $listId: $e');
      return null;
    }
  }

  /// Adds a member to a collaborative shopping list. Routing the join flow
  /// through this adapter seam (not a fresh `ServiceLocator.get`) keeps the
  /// happy path mockable in tests.
  Future<bool> addMember({
    required String listId,
    required String userId,
    required String userDisplayName,
  }) {
    return _shoppingService.collaborative.addMember(
      listId: listId,
      userId: userId,
      userDisplayName: userDisplayName,
    );
  }

  /// Shopping lists use direct collaboration — callers join the original list
  /// rather than importing a copy. Save-through-coordinator is unsupported and
  /// fails loud: any call path reaching this is a wiring bug. Persist via
  /// [UnifiedShoppingService] directly instead.
  Future<String?> saveShoppingList(UnifiedShoppingList shoppingList) async {
    throw UnsupportedError(
      'ShoppingListServiceAdapter.saveShoppingList is not supported — '
      'shopping lists use direct collaboration, not copy-on-write. '
      'Use UnifiedShoppingService directly to persist lists.',
    );
  }
}

/// Social Shopping Coordinator extending BaseSocialCoordinator for consistent patterns
class SocialShoppingCoordinator
    extends BaseSocialCoordinator<UnifiedShoppingList, SharedShoppingList> {
  @override
  String get serviceName => 'SocialShoppingCoordinator';

  // Shopping list-specific dependencies
  final ShoppingListServiceAdapter _serviceAdapter;
  late final FirebaseSharedShoppingRepository _sharedShoppingRepository;
  final Future<UnifiedShoppingList?> Function(String) _getShoppingList;
  final Future<String?> Function(UnifiedShoppingList) _saveShoppingList;

  /// Cached viewed status (shoppingListId → bool)
  final Map<String, bool> _viewedStatusCache = {};

  /// Cached imported status (shoppingListId → bool)
  final Map<String, bool> _importedStatusCache = {};

  /// Cached dismissed status (shoppingListId → bool)
  final Map<String, bool> _dismissedStatusCache = {};

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
    // Initialize SharedShoppingList repository from DI
    _sharedShoppingRepository =
        ServiceLocator.get<FirebaseSharedShoppingRepository>();

    AppLogger.info(
        '✅ SocialShoppingCoordinator initialized for shopping list sharing and collaboration using $_serviceAdapter');
  }
  @override
  String get contentTypeName => 'shopping_list';

  @override
  String getContentTitle(UnifiedShoppingList content) {
    return content.name;
  }

  @override
  BaseSharedContentRepository<SharedShoppingList> get sharedRepository =>
      _sharedShoppingRepository;

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
      shoppingListId: originalContentId,
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
      items: [], // Note: Items in subcollection - caller should load via repository.getItems()
      allowGuestEditing: false,
    );
  }

  @override
  Future<String?> saveImportedContent(UnifiedShoppingList content) async {
    return await _saveShoppingList(content);
  }

  @override
  Future<String?> createStaticCopyForOwner(
      dynamic originalContent, String ownerId) async {
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
      items: [], // Note: Items in subcollection - caller should load via repository.getItems()
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
      final sharedList =
          await _sharedShoppingRepository.read(sharedShoppingListId);
      if (sharedList == null) {
        AppLogger.error(
            'Shared shopping list not found: $sharedShoppingListId');
        return null;
      }

      // Mark as joined in SharedShoppingList (analytics tracking)
      await _sharedShoppingRepository.markAsJoined(
          sharedShoppingListId, currentUserId);

      // Routed through the injected adapter so the happy path is testable.
      final listId = sharedList.shoppingListId;
      if (listId != null) {
        await _serviceAdapter.addMember(
          listId: listId,
          userId: currentUserId,
          userDisplayName:
              currentUserDisplayName ?? AppLocale.current.displayUnknownUser,
        );
      } else {
        AppLogger.warning('SharedShoppingList missing shoppingListId — '
            'member permissions not updated (pre-migration data)');
      }

      AppLogger.success('✅ Successfully joined shopping list collaboration');
      notifyStateChanged();

      return sharedShoppingListId;
    } catch (e) {
      AppLogger.error('Failed to join shared shopping list: $e');
      setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Get shopping list invitations received by current user
  Future<List<SharedShoppingList>> getReceivedShoppingListInvitations() async {
    return await getReceivedInvitations();
  }

  /// Get all shared shopping lists for a specific user
  /// Phase 3 Session 1: Content loading method for ViewModel migration.
  /// Wraps repository call with error handling and logging.
  Future<List<SharedShoppingList>> getSharedShoppingListsForUser(
      String userId) async {
    try {
      AppLogger.info(
          '📥 Loading shared shopping lists for user ${userId.maskedUserId}');
      return await _sharedShoppingRepository.getSharedContentForUser(userId);
    } catch (e) {
      // BUT-1094: surface inbox-load failures via the shared error banner.
      AppLogger.error(
          'Failed to load shared shopping lists for user ${userId.maskedUserId}',
          e);
      setError(sanitizeErrorForUser(e));
      return [];
    }
  }

  /// Load status for a shopping list from repository and cache it
  /// Phase 3 Session 2: Status caching method for ViewModel migration.
  /// Loads viewed, imported, and dismissed status from repository and caches locally.
  /// BUT-1125: The three Firestore reads run in parallel via [Future.wait] —
  /// they're independent reads with no shared mutable state, so this is a
  /// ~3x latency reduction per call without changing the read count.
  Future<void> loadStatusForShoppingList(
      String shoppingListId, String userId) async {
    try {
      final results = await Future.wait([
        _sharedShoppingRepository.hasViewed(shoppingListId, userId),
        _sharedShoppingRepository.hasEngaged(shoppingListId, userId),
        _sharedShoppingRepository.hasDismissed(shoppingListId, userId),
      ]);
      final viewed = results[0];
      final imported = results[1];
      final dismissed = results[2];

      _viewedStatusCache[shoppingListId] = viewed;
      _importedStatusCache[shoppingListId] = imported;
      _dismissedStatusCache[shoppingListId] = dismissed;
    } catch (e) {
      AppLogger.error(
          'Failed to load status for shopping list $shoppingListId', e);
    }
  }

  /// Load status for all shopping lists in bulk
  /// Phase 3 Session 2: Bulk status loading method for ViewModel migration.
  /// Loads status for multiple shopping lists to populate cache efficiently.
  /// BUT-1125: All per-list status loads run concurrently via [Future.wait]
  /// instead of awaiting each sequentially. For N=20 lists this changes
  /// 60 sequential round-trips into one parallel batch (read count unchanged).
  Future<void> loadStatusForAllShoppingLists(
      List<SharedShoppingList> shoppingLists, String userId) async {
    await Future.wait(
      shoppingLists.map((l) => loadStatusForShoppingList(l.id, userId)),
    );
  }

  /// Check if shopping list is dismissed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isShoppingListDismissed(String shoppingListId) {
    return _dismissedStatusCache[shoppingListId] ?? false;
  }

  /// Check if shopping list is viewed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isShoppingListViewed(String shoppingListId) {
    return _viewedStatusCache[shoppingListId] ?? false;
  }

  /// Check if shopping list is imported using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isShoppingListImported(String shoppingListId) {
    return _importedStatusCache[shoppingListId] ?? false;
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
      return await _sharedShoppingRepository
          .getJoinedShoppingListsForUser(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get joined shopping lists: $e');
      setError(sanitizeErrorForUser(e));
      return [];
    }
  }

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

    final l = AppLocale.current;
    if (totalItems == 0) return l.shoppingListSummaryEmpty;
    if (remainingItems == 0) return l.shoppingListSummaryAllDone(totalItems);
    if (boughtItems == 0) return l.shoppingListSummaryToBuy(totalItems);

    return l.shoppingListSummaryRemaining(remainingItems, totalItems);
  }

  /// Check if user can edit shopping list
  bool canUserEditShoppingList(
      UnifiedShoppingList shoppingList, String userId) {
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

  /// Send shopping list invitation notifications
  Future<void> sendShoppingListInvitationNotifications(
      String listId, List<String> inviteeUserIds) async {
    await sendInvitationNotifications(listId, inviteeUserIds);
  }

  /// Send shopping list sharing notifications
  Future<void> sendShoppingListSharingNotifications(
      String listId, List<String> sharedWithUserIds) async {
    await sendSharingNotifications(listId, sharedWithUserIds);
  }

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
