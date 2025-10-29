// lib/services/unified/modules/shopping_list_management_module.dart

import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';

/// Shopping list management module for all list CRUD operations.
class ShoppingListManagementModule {
  final ShoppingRepository repository;
  final List<UnifiedShoppingList> lists;
  final String? Function() getActiveListId;
  final void Function(String?) setActiveListId;
  final void Function() notifyListeners;
  final String? Function() getCurrentUserId;
  final String? Function() getCurrentUserDisplayName;
  final Future<void> Function() saveActiveListId;

  ShoppingListManagementModule({
    required this.repository,
    required this.lists,
    required this.getActiveListId,
    required this.setActiveListId,
    required this.notifyListeners,
    required this.getCurrentUserId,
    required this.getCurrentUserDisplayName,
    required this.saveActiveListId,
  });

  Future<String?> createPersonalList(String name, {List<dynamic>? items}) async {
    try {
      // Create UnifiedShoppingList object
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: getCurrentUserId() ?? '',
        ownerDisplayName: getCurrentUserDisplayName() ?? 'Du',
        items: (items ?? []).map((item) =>
            item is UnifiedShoppingItem ? item : UnifiedShoppingItem(
              name: item.toString(),
              amount: 1,
            )).toList(),
        type: ListType.personal,
      );

      // Save to repository
      final savedList = await repository.create(newList);

      // Add to lists array
      lists.add(savedList);
      notifyListeners();

      return savedList.id;
    } catch (e) {
      return null;
    }
  }

  Future<String?> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    try {
      final currentUserId = getCurrentUserId();
      final currentUserDisplayName = getCurrentUserDisplayName();

      if (currentUserId == null || currentUserDisplayName == null) {
        AppLogger.error('Cannot create collaborative list: User not authenticated');
        return null;
      }

      // Create member permissions with owner and members
      final memberPermissions = <String, SharedListPermission>{};

      // Add owner with admin permissions
      memberPermissions[currentUserId] = SharedListPermission.admin;

      // Add members with appropriate permissions
      for (final memberId in memberIds) {
        if (memberId != currentUserId) { // Don't duplicate owner
          memberPermissions[memberId] = allowGuestEditing
              ? SharedListPermission.edit
              : SharedListPermission.view;
        }
      }

      // Create UnifiedShoppingList object for collaborative sharing
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: currentUserId,
        ownerDisplayName: currentUserDisplayName,
        description: description,
        items: items ?? [],
        type: ListType.collaborative,
        memberPermissions: memberPermissions,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
        lastActivityByUserId: currentUserId,
        lastActivityByDisplayName: currentUserDisplayName,
      );

      // Save to Firebase repository
      final savedList = await repository.create(newList);

      // Add to local lists array
      lists.add(savedList);
      notifyListeners();

      AppLogger.success('Created collaborative list: ${savedList.name} with ${memberIds.length} members');
      return savedList.id;
    } catch (e) {
      AppLogger.error('Failed to create collaborative list: $e');
      return null;
    }
  }

  /// Create collaborative list from invitation - preserves original sender as owner
  Future<String?> createCollaborativeListFromInvitation({
    required String name,
    String? description,
    required String ownerId,
    required String ownerDisplayName,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    try {
      // Create member permissions with specified owner and members
      final memberPermissions = <String, SharedListPermission>{};

      // Add owner with admin permissions
      memberPermissions[ownerId] = SharedListPermission.admin;

      // Add members with appropriate permissions
      for (final memberId in memberIds) {
        if (memberId != ownerId) { // Don't duplicate owner
          memberPermissions[memberId] = allowGuestEditing
              ? SharedListPermission.edit
              : SharedListPermission.view;
        }
      }

      // Create UnifiedShoppingList object for collaborative sharing
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: ownerId,  // Use specified owner, not current user
        ownerDisplayName: ownerDisplayName,
        description: description,
        items: items ?? [],
        type: ListType.collaborative,
        memberPermissions: memberPermissions,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
        lastActivityByUserId: ownerId,  // Initial activity by owner
        lastActivityByDisplayName: ownerDisplayName,
        collaborativeOrigin: 'shared', // Mark as created from sharing to prevent duplicates
      );

      // Save to Firebase repository
      final savedList = await repository.create(newList);

      // Add to local lists array
      lists.add(savedList);
      notifyListeners();

      AppLogger.success('Created collaborative list from invitation: ${savedList.name} with owner: $ownerDisplayName');
      return savedList.id;
    } catch (e) {
      AppLogger.error('Failed to create collaborative list from invitation: $e');
      return null;
    }
  }

  Future<bool> updateList(UnifiedShoppingList list) async {
    try {
      // Update in Firebase
      await repository.update(list);

      // Update local state
      final listIndex = lists.indexWhere((l) => l.id == list.id);
      if (listIndex >= 0) {
        lists[listIndex] = list;
        notifyListeners();
      }

      AppLogger.success('Updated list: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update list', e);
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      // Find the list to delete
      final listIndex = lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      // Delete from Firebase
      await repository.delete(listId);

      // Remove from local state
      lists.removeAt(listIndex);

      // Reset active list if we deleted it
      if (getActiveListId() == listId) {
        setActiveListId(null);
      }

      // Notify UI to update
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rename a shopping list with real Firebase integration
  Future<bool> renameList(String listId, String newName) async {
    try {
      // Find the list to rename
      final listIndex = lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final oldList = lists[listIndex];

      // Update in Firebase
      await repository.update(oldList.copyWith(name: newName));

      // Update local state
      lists[listIndex] = oldList.copyWith(name: newName);
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setActiveList(String listId) async {
    try {
      // Find the list to set as active
      final listExists = lists.any((list) => list.id == listId);
      if (listExists) {
        setActiveListId(listId);

        // Persist the active list ID to cache
        await saveActiveListId();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String exportListAsText(String listId) => 'Mock shopping list export';
}
