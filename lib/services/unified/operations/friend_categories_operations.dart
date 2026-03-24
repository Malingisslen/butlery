// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic lists
import 'package:uuid/uuid.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';

/// Friend categories operations handling category CRUD, friend assignment, bulk operations, permissions, and organization analytics.
class FriendsCategoriesOperations {
  final String? Function() _getCurrentUserId;
  final List<FriendCategory> Function() _getCategoriesList;
  final List<UserProfile> Function() _getFriendsList;
  final Map<String, Set<String>> Function()
      _getFriendCategoryRelationshipsInternal;
  final void Function(FriendCategory) _addCategoryInternal;
  final void Function(String, FriendCategory) _updateCategoryInternalCallback;
  final void Function(String) _removeCategoryInternal;
  final void Function(String, String) _addFriendToCategoryInternal;
  final Future<void> Function(FriendCategory) _syncCategoryToFirebaseInternal;
  final Future<void> Function(String) _deleteCategoryFromFirebaseInternal;
  final Future<void> Function() _refresh;
  final FriendsManagementOperations Function() _getManagement;
  final FriendsInvitationsOperations Function() _getInvitations;

  FriendsCategoriesOperations({
    required String? Function() getCurrentUserId,
    required List<FriendCategory> Function() getCategoriesList,
    required List<UserProfile> Function() getFriendsList,
    required Map<String, Set<String>> Function()
        getFriendCategoryRelationshipsInternal,
    required void Function(FriendCategory) addCategoryInternal,
    required void Function(String, FriendCategory) updateCategoryInternal,
    required void Function(String) removeCategoryInternal,
    required void Function(String, String) addFriendToCategoryInternal,
    required Future<void> Function(FriendCategory)
        syncCategoryToFirebaseInternal,
    required Future<void> Function(String) deleteCategoryFromFirebaseInternal,
    required Future<void> Function() refresh,
    required FriendsManagementOperations Function() getManagement,
    required FriendsInvitationsOperations Function() getInvitations,
  })  : _getCurrentUserId = getCurrentUserId,
        _getCategoriesList = getCategoriesList,
        _getFriendsList = getFriendsList,
        _getFriendCategoryRelationshipsInternal =
            getFriendCategoryRelationshipsInternal,
        _addCategoryInternal = addCategoryInternal,
        _updateCategoryInternalCallback = updateCategoryInternal,
        _removeCategoryInternal = removeCategoryInternal,
        _addFriendToCategoryInternal = addFriendToCategoryInternal,
        _syncCategoryToFirebaseInternal = syncCategoryToFirebaseInternal,
        _deleteCategoryFromFirebaseInternal =
            deleteCategoryFromFirebaseInternal,
        _refresh = refresh,
        _getManagement = getManagement,
        _getInvitations = getInvitations;

  Future<String?> createCategory({
    required String name,
    String description = '',
    bool isPrivate = false,
    String? icon,
    List<String>? initialMemberIds,
  }) async {
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      AppLogger.warning('Cannot create category: User not logged in');
      return null;
    }

    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning('Cannot create category: User ID not available');
      return null;
    }

    if (name.trim().isEmpty) {
      AppLogger.warning('Category name cannot be empty');
      return null;
    }

    if (_categoryNameExists(name.trim())) {
      AppLogger.warning('Category name already exists: $name');
      return null;
    }

    try {
      // Create category internally
      final categoryId = const Uuid().v4();

      final category = FriendCategory(
        id: categoryId,
        name: name.trim(),
        description: description.trim(),
        ownerId: currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        emoji: icon,
        friendUserIds: [currentUserId], // Add owner as member
      );

      _addCategoryInternal(category);
      await _syncCategoryToFirebaseInternal(category);

      // ✅ FIXED: If initial members provided, send invitations instead of directly adding
      // This prevents the "0 invites sent" issue when trying to invite initial members later
      if (initialMemberIds != null && initialMemberIds.isNotEmpty) {
        try {
          int sentCount = 0;
          for (final memberId in initialMemberIds) {
            final sent = await _getInvitations().sendGroupInvitationToUser(
              userId: memberId,
              groupId: categoryId,
            );
            if (sent) sentCount++;
          }
          AppLogger.success(
              '✅ Category created with $sentCount invitations sent: $name');
        } catch (memberError) {
          AppLogger.warning(
              '⚠️ Category created but failed to send some invitations: $memberError');
          // Continue anyway - category was created successfully
        }
      } else {
        AppLogger.success('✅ Category created: $name');
      }

      return categoryId;
    } catch (e) {
      AppLogger.error('Error creating category: $name', e);
      return null;
    }
  }

  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? icon,
    bool? isPrivate,
  }) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      // Try refreshing state before giving up
      await _refresh();
      final refreshedCategory = getCategoryById(categoryId);
      if (refreshedCategory == null) {
        return false;
      }
      return await _performCategoryUpdate(
          refreshedCategory, name, description, icon, isPrivate);
    }

    return await _performCategoryUpdate(
        category, name, description, icon, isPrivate);
  }

  Future<bool> _performCategoryUpdate(
    FriendCategory category,
    String? name,
    String? description,
    String? icon,
    bool? isPrivate,
  ) async {
    final categoryId = category.id;

    if (!_canEditCategory(category)) {
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }

    if (name != null && name.trim().isEmpty) {
      AppLogger.warning('Category name cannot be empty');
      return false;
    }

    try {
      final updatedCategory = category.copyWith(
        name: name?.trim(),
        description: description?.trim(),
        emoji: icon,
        updatedAt: DateTime.now(),
      );

      // Update local state first
      _updateCategoryInternalCallback(categoryId, updatedCategory);

      // Sync to Firebase (single call - duplicate was causing false failure)
      await _syncCategoryToFirebaseInternal(updatedCategory);

      AppLogger.success('Category updated: ${updatedCategory.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating category: $categoryId', e);
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    if (!_canDeleteCategory(category)) {
      AppLogger.warning('No permission to delete category: $categoryId');
      return false;
    }

    try {
      // Remove all friend-category relationships for this category
      final friendCategoryRelationships =
          _getFriendCategoryRelationshipsInternal();
      for (final friendId in friendCategoryRelationships.keys.toList()) {
        friendCategoryRelationships[friendId]?.remove(categoryId);
        if (friendCategoryRelationships[friendId]?.isEmpty == true) {
          friendCategoryRelationships.remove(friendId);
        }
      }

      // Delete from Firebase
      await _deleteCategoryFromFirebaseInternal(categoryId);

      // Use the internal remove method that handles caching and notifications
      _removeCategoryInternal(categoryId);

      AppLogger.success('✅ Category deleted: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting category: $categoryId', e);
      return false;
    }
  }

  Future<bool> addFriendToCategory(String friendId, String categoryId,
      {bool skipFriendshipCheck = false,
      bool skipPermissionCheck = false}) async {
    AppLogger.info(
        '🔄 [ADD_TO_CATEGORY] Starting - friendId: $friendId, categoryId: $categoryId, skipFriendshipCheck: $skipFriendshipCheck, skipPermissionCheck: $skipPermissionCheck');

    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('❌ [ADD_TO_CATEGORY] Category not found: $categoryId');
      return false;
    }

    AppLogger.info('📋 [ADD_TO_CATEGORY] Found category: ${category.name}');

    // ✅ FIXED: Skip friendship check when accepting invitations (users don't need to be friends first)
    if (!skipFriendshipCheck && !_getManagement().isFriend(friendId)) {
      AppLogger.warning('❌ [ADD_TO_CATEGORY] User is not a friend: $friendId');
      return false;
    }

    if (!skipFriendshipCheck) {
      AppLogger.info('✅ [ADD_TO_CATEGORY] Friendship check passed');
    } else {
      AppLogger.info('⏭️ [ADD_TO_CATEGORY] Friendship check skipped');
    }

    if (isFriendInCategory(friendId, categoryId)) {
      AppLogger.warning(
          '⚠️ [ADD_TO_CATEGORY] Friend already in category: $friendId -> $categoryId');
      return true; // Not an error, just already done
    }

    // ✅ FIXED: Skip permission check when accepting invitations (user is joining, not editing)
    if (!skipPermissionCheck && !_canEditCategory(category)) {
      AppLogger.warning(
          '❌ [ADD_TO_CATEGORY] No permission to edit category: $categoryId');
      return false;
    }

    if (!skipPermissionCheck) {
      AppLogger.info('✅ [ADD_TO_CATEGORY] Permission check passed');
    } else {
      AppLogger.info('⏭️ [ADD_TO_CATEGORY] Permission check skipped');
    }

    AppLogger.info('📝 [ADD_TO_CATEGORY] Adding friend to category locally...');
    _addFriendToCategoryInternal(friendId, categoryId);

    AppLogger.info('☁️ [ADD_TO_CATEGORY] Syncing to Firebase...');
    final categoryToSync = getCategoryById(categoryId);
    if (categoryToSync != null) {
      await _syncCategoryToFirebaseInternal(categoryToSync);
      AppLogger.success(
          '✅ [ADD_TO_CATEGORY] Successfully added friend to category and synced');
    } else {
      AppLogger.warning('⚠️ [ADD_TO_CATEGORY] Category not found for sync');
    }

    return true;
  }

  Future<bool> removeFriendFromCategory(
      String friendId, String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    final isInCategory = isFriendInCategory(friendId, categoryId);

    if (!isInCategory) {
      AppLogger.warning('Friend not in category: $friendId -> $categoryId');
      return true; // Not an error, just already removed
    }

    if (!_canEditCategory(category)) {
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }

    try {
      // Remove from friend-category relationships
      final friendCategoryRelationships =
          _getFriendCategoryRelationshipsInternal();

      friendCategoryRelationships[friendId]?.remove(categoryId);
      if (friendCategoryRelationships[friendId]?.isEmpty == true) {
        friendCategoryRelationships.remove(friendId);
      }

      // Update the category's member list
      final updatedMemberIds =
          category.friendUserIds.where((id) => id != friendId).toList();

      final updatedCategory = category.copyWith(
        friendUserIds: updatedMemberIds,
        updatedAt: DateTime.now(),
      );

      // Use the internal update method that handles caching and notifications
      _updateCategoryInternalCallback(categoryId, updatedCategory);

      await _syncCategoryToFirebaseInternal(updatedCategory);

      AppLogger.success(
          '✅ Friend removed from category: $friendId -> $categoryId');

      // Emit event bus notification for UI updates
      GroupEventBus.memberRemoved();

      return true;
    } catch (e) {
      AppLogger.error('Error removing friend from category', e);
      return false;
    }
  }

  Future<bool> moveFriendToCategory({
    required String friendId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    if (fromCategoryId == toCategoryId) {
      return true; // Already in target category
    }

    // Remove from source category
    final removeSuccess =
        await removeFriendFromCategory(friendId, fromCategoryId);
    if (!removeSuccess) return false;

    // Add to target category
    return await addFriendToCategory(friendId, toCategoryId);
  }

  Future<Map<String, bool>> addMultipleFriendsToCategory(
    List<String> friendIds,
    String categoryId,
  ) async {
    final results = <String, bool>{};

    for (final friendId in friendIds) {
      results[friendId] = await addFriendToCategory(friendId, categoryId);
    }

    return results;
  }

  Future<Map<String, bool>> removeMultipleFriendsFromCategory(
    List<String> friendIds,
    String categoryId,
  ) async {
    final results = <String, bool>{};

    for (final friendId in friendIds) {
      results[friendId] = await removeFriendFromCategory(friendId, categoryId);
    }

    return results;
  }

  Future<String?> createCategoryWithFriends({
    required String name,
    String description = '',
    required List<String> friendIds,
  }) async {
    final categoryId = await createCategory(
      name: name,
      description: description,
      initialMemberIds: friendIds,
    );

    return categoryId;
  }

  FriendCategory? getCategoryById(String categoryId) {
    return _getCategoriesList()
        .where((category) => category.id == categoryId)
        .firstOrNull;
  }

  FriendCategory? getCategoryByName(String name) {
    return _getCategoriesList()
        .where((category) => category.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }

  List<FriendCategory> getAllCategories() {
    return _getCategoriesList();
  }

  List<FriendCategory> getOwnedCategories() {
    return _getCategoriesList()
        .where((category) => category.ownerId == _getCurrentUserId())
        .toList();
  }

  List<FriendCategory> getMemberCategories() {
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) return [];

    return _getCategoriesList()
        .where((category) => category.memberIds.contains(_getCurrentUserId()))
        .toList();
  }

  List<UserProfile> getFriendsInCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    if (category == null) return [];

    return _getFriendsList()
        .where((friend) => category.memberIds.contains(friend.uid))
        .toList();
  }

  List<FriendCategory> getCategoriesForFriend(String friendId) {
    return _getCategoriesList()
        .where((category) => category.memberIds.contains(friendId))
        .toList();
  }

  List<UserProfile> getUncategorizedFriends() {
    final categorizedFriendIds = <String>{};

    for (final category in _getCategoriesList()) {
      categorizedFriendIds.addAll(category.memberIds);
    }

    return _getFriendsList()
        .where((friend) => !categorizedFriendIds.contains(friend.uid))
        .toList();
  }

  bool isFriendInCategory(String friendId, String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.memberIds.contains(friendId) ?? false;
  }

  bool _categoryNameExists(String name) {
    return _getCategoriesList()
        .any((category) => category.name.toLowerCase() == name.toLowerCase());
  }

  int getCategoryMemberCount(String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.memberIds.length ?? 0;
  }

  bool isCategoryEmpty(String categoryId) {
    return getCategoryMemberCount(categoryId) == 0;
  }

  Map<String, dynamic> getCategoryStats() {
    final categories = getAllCategories();
    final totalCategories = categories.length;
    final ownedCategories = getOwnedCategories().length;
    final memberCategories = getMemberCategories().length;
    final uncategorizedCount = getUncategorizedFriends().length;

    return {
      'totalCategories': totalCategories,
      'ownedCategories': ownedCategories,
      'memberCategories': memberCategories,
      'uncategorizedFriends': uncategorizedCount,
      'averageMembersPerCategory': totalCategories > 0
          ? categories.map((c) => c.memberIds.length).reduce((a, b) => a + b) /
              totalCategories
          : 0.0,
    };
  }

  bool _canEditCategory(FriendCategory category) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;

    // Can edit if owner
    if (currentUserId == category.ownerId) {
      return true;
    }

    // Or if has admin permissions
    return ServiceLocator.get<PermissionService>().isGroupAdmin(category.id);
  }

  bool _canDeleteCategory(FriendCategory category) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;

    // Can delete if owner
    if (currentUserId == category.ownerId) {
      return true;
    }

    // Or if has delete permissions
    return ServiceLocator.get<PermissionService>().canDeleteGroup(category.id);
  }

  // FUTURE IMPLEMENTATION NOTE: Public/private friend categories
  // When implemented, will need a method to check view permissions:
  // - Public categories: viewable by anyone
  // - Private categories: viewable by owner and members only
  // Implementation will be added when privacy feature is developed

  Future<void> setCategoryPrivacy(String categoryId,
      {required bool isPublic}) async {
    AppLogger.info(
        '🔒 Privacy setting requested for category: $categoryId (public: $isPublic)');

    // Feature not yet implemented — return gracefully instead of crashing
    AppLogger.warning(
        '⚠️ Friend category privacy controls are not yet available');
  }

  List<FriendCategory> get categoriesList => _getCategoriesList();

  Future<void> migrateOwnersAsMembers() async {
    final categories = getAllCategories();

    for (final category in categories) {
      if (!category.friendUserIds.contains(category.ownerId)) {
        final updatedCategory = category.copyWith(
          friendUserIds: [...category.friendUserIds, category.ownerId],
          updatedAt: DateTime.now(),
        );

        _updateCategoryInternalCallback(category.id, updatedCategory);
        await _syncCategoryToFirebaseInternal(updatedCategory);
      }
    }
  }

  Future<bool> assignFriendToCategory(
      String friendId, String categoryId) async {
    return await addFriendToCategory(friendId, categoryId);
  }

  Future<void> refresh() async {
    await _refresh();
  }
}
