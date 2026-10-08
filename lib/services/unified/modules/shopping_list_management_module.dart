// lib/services/unified/modules/shopping_list_management_module.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
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

  Future<String?> createPersonalList(
    String name, {
    List<dynamic>? items,
  }) async {
    try {
      // Create UnifiedShoppingList object
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: getCurrentUserId().orEmpty(),
        // Stamp empty, never a placeholder: this string is persisted, and
        // every display site already guards `isNotEmpty` (BUT-1697).
        ownerDisplayName: getCurrentUserDisplayName().orEmpty(),
        items: (items ?? [])
            .map(
              (item) => item is UnifiedShoppingItem
                  ? item
                  : UnifiedShoppingItem(
                      name: item.toString(),
                      amount: 1,
                    ),
            )
            .toList(),
        type: ListType.personal,
      );

      // Save to repository
      final savedList = await repository.create(newList);

      // Add to lists array
      lists.add(savedList);
      notifyListeners();

      return savedList.id;
    } catch (e) {
      // BUT-1784: swallowed without a trace, this was the one create path in
      // the module that left nothing behind — a permission denial, an offline
      // refusal and a malformed name all came back as an identical `null`, and
      // the dialog reported success over every one of them.
      AppLogger.error('Failed to create personal list', e);
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
      // Deliberately NOT part of the authentication guard: the display name is
      // resolved from the user PROFILE, which may not have loaded yet, and
      // refusing to create the list over a missing label would be a worse
      // failure than an unnamed owner (BUT-1697).
      final currentUserDisplayName = getCurrentUserDisplayName();

      if (currentUserId == null) {
        AppLogger.error(
          'Cannot create collaborative list: User not authenticated',
        );
        return null;
      }

      // Create member permissions with owner and members
      final memberPermissions = <String, SharedListPermission>{};

      // Add owner with admin permissions
      memberPermissions[currentUserId] = SharedListPermission.admin;

      // Add members with appropriate permissions
      for (final memberId in memberIds) {
        if (memberId != currentUserId) {
          // Don't duplicate owner
          memberPermissions[memberId] = allowGuestEditing
              ? SharedListPermission.edit
              : SharedListPermission.view;
        }
      }

      // Create UnifiedShoppingList object for collaborative sharing
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: currentUserId,
        ownerDisplayName: currentUserDisplayName.orEmpty(),
        description: description,
        items: items ?? [],
        type: ListType.collaborative,
        memberPermissions: memberPermissions,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
        lastActivityByUserId: currentUserId,
        lastActivityByDisplayName: currentUserDisplayName.orEmpty(),
      );

      // Save to Firebase repository
      final savedList = await repository.create(newList);

      // Add to local lists array
      lists.add(savedList);
      notifyListeners();

      AppLogger.success(
        'Created collaborative list: ${savedList.name} with ${memberIds.length} members',
      );
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
        if (memberId != ownerId) {
          // Don't duplicate owner
          memberPermissions[memberId] = allowGuestEditing
              ? SharedListPermission.edit
              : SharedListPermission.view;
        }
      }

      // Create UnifiedShoppingList object for collaborative sharing
      final newList = UnifiedShoppingList(
        name: name,
        ownerId: ownerId, // Use specified owner, not current user
        ownerDisplayName: ownerDisplayName,
        description: description,
        items: items ?? [],
        type: ListType.collaborative,
        memberPermissions: memberPermissions,
        allowGuestEditing: allowGuestEditing,
        autoRemoveCompleted: autoRemoveCompleted,
        lastActivityByUserId: ownerId, // Initial activity by owner
        lastActivityByDisplayName: ownerDisplayName,
        collaborativeOrigin:
            'shared', // Mark as created from sharing to prevent duplicates
      );

      // Save to Firebase repository
      final savedList = await repository.create(newList);

      // Add to local lists array
      lists.add(savedList);
      notifyListeners();

      AppLogger.success(
        'Created collaborative list from invitation: ${savedList.name} with owner: $ownerDisplayName',
      );
      return savedList.id;
    } catch (e) {
      AppLogger.error(
        'Failed to create collaborative list from invitation: $e',
      );
      return null;
    }
  }

  Future<bool> updateList(UnifiedShoppingList list) async {
    try {
      final previous = lists.where((l) => l.id == list.id).firstOrNull;

      // Update in Firebase
      await repository.update(list);
      if (list.type != ListType.collaborative) {
        await _persistPersonalItems(previous, list);
      }

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

  /// A personal list's items live in its `items` subcollection, which is what
  /// the next launch reads; `update` writes only the parent document
  /// (BUT-1723). The change is taken against the copy in memory, never the
  /// stored rows, so a stale caller cannot delete a row it never saw, and a
  /// row passed through unchanged costs no write.
  Future<void> _persistPersonalItems(
    UnifiedShoppingList? previous,
    UnifiedShoppingList list,
  ) async {
    final before = <String, UnifiedShoppingItem>{
      for (final item in previous?.items ?? const <UnifiedShoppingItem>[])
        item.id: item,
    };
    final changed = list.items
        .where((item) => !identical(before[item.id], item))
        .toList();
    final keptIds = {for (final item in list.items) item.id};
    final removedIds = before.keys
        .where((id) => !keptIds.contains(id))
        .toList();

    if (changed.isNotEmpty) {
      await repository.addItemsBatch(list.id, changed);
    }
    if (removedIds.isNotEmpty) {
      await repository.removeItemsBatch(list.id, removedIds);
    }
  }

  /// BUT-2140: the week menu's merge into the personal list [listId]. The
  /// local copy is replaced with the repository's result, which is built on
  /// the server's rows, so rows another device added show up here. Rethrows,
  /// so the caller can tell a failed merge from one that wrote nothing.
  Future<PersonalMergeResult> applyPersonalMerge(
    String listId,
    PersonalMergeRequest request,
  ) async {
    final base = lists.firstWhere((l) => l.id == listId);
    final result = await repository.applyPersonalMerge(base, request);
    _replaceLocal(result.list);
    return result;
  }

  /// BUT-2140: Ångra for [applyPersonalMerge]. Rethrows, as it does.
  Future<void> undoPersonalMerge(
    String listId,
    List<String> addedIds,
    List<UnifiedShoppingItem> restore,
  ) async {
    final base = lists.firstWhere((l) => l.id == listId);
    final undone = await repository.undoPersonalMerge(
      base,
      addedIds: addedIds,
      restore: restore,
    );
    _replaceLocal(undone);
  }

  /// Re-finds the list after the await: the collaborative snapshot handler
  /// rebuilds the same `lists` instance during the round-trip.
  void _replaceLocal(UnifiedShoppingList list) {
    final index = lists.indexWhere((l) => l.id == list.id);
    if (index >= 0) {
      lists[index] = list;
      notifyListeners();
    }
  }

  /// BUT-1726: persist a membership change on a collaborative list.
  ///
  /// [base] is the copy the change was computed from — see
  /// [ShoppingRepository.updateCollaborativeListMembership]. Rethrows rather
  /// than swallowing: the caller has to be able to tell "removed" from "the
  /// list moved under you", and local state must NOT be updated when the write
  /// was refused. That mismatch is the whole defect this replaced — the member
  /// disappeared from the screen while the server still had them.
  Future<UnifiedShoppingList> updateListMembership(
    UnifiedShoppingList updated,
    UnifiedShoppingList base,
  ) async {
    final saved = await repository.updateCollaborativeListMembership(
      updated,
      base,
      intent: MembershipWriteIntent.ordinary,
    );

    final listIndex = lists.indexWhere((l) => l.id == saved.id);
    if (listIndex >= 0) {
      lists[listIndex] = saved;
      notifyListeners();
    }

    AppLogger.success('Updated membership on list: ${saved.name}');
    return saved;
  }

  /// BUT-1718: the signed-in user removes their own key from [base]'s members.
  ///
  /// Local state is handled the way [deleteList] does it, not the way
  /// [updateListMembership] does: after a departure the list is GONE from this
  /// user's view — the collaborative stream filters on
  /// `memberPermissions.<uid>` — so leaving the stale copy in [lists] would
  /// keep a list on screen that the server has already stopped serving, and
  /// whose next snapshot is a permission denial.
  Future<void> leaveList(
    UnifiedShoppingList updated,
    UnifiedShoppingList base,
  ) async {
    await repository.updateCollaborativeListMembership(
      updated,
      base,
      intent: MembershipWriteIntent.selfRemoval,
    );

    // Re-find after the await: the collaborative snapshot handler rebuilds the
    // same `lists` instance during the round-trip, so an index captured before
    // it can point at a different list by now.
    final leftIndex = lists.indexWhere((l) => l.id == base.id);
    if (leftIndex >= 0) {
      lists.removeAt(leftIndex);
    }

    if (getActiveListId() == base.id) {
      setActiveListId(null);
    }

    notifyListeners();
    AppLogger.success('Left shared list: ${base.name}');
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

      // Re-find after the await: the collaborative snapshot handler rebuilds the
      // same `lists` instance during the round-trip, so the index captured
      // above can point at a different list by now. A stale `removeAt` would drop a list
      // that still exists and leave the deleted one on screen — or throw
      // RangeError if the collaborative set shrank.
      final deletedIndex = lists.indexWhere((list) => list.id == listId);
      if (deletedIndex >= 0) {
        lists.removeAt(deletedIndex);
      }

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

      // Re-find after the await: the collaborative snapshot handler rebuilds the
      // same `lists` instance during the round-trip, so the index captured
      // above can point at a different list by now. Writing `oldList` into a
      // drifted slot would overwrite another list with a copy of this one.
      final renamedIndex = lists.indexWhere((list) => list.id == listId);
      if (renamedIndex >= 0) {
        lists[renamedIndex] = lists[renamedIndex].copyWith(name: newName);
      }
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

  String exportListAsText(String listId) {
    final matches = lists.where((l) => l.id == listId);
    if (matches.isEmpty) return '';
    final list = matches.first;

    final buffer = StringBuffer();
    buffer.writeln('Inköpslista: ${list.name}');
    buffer.writeln('');

    // Group items by category
    final categorized = <String, List<UnifiedShoppingItem>>{};
    for (final item in list.items) {
      final category = item.category.isEmpty
          ? ShoppingCategory.other
          : item.category;
      categorized.putIfAbsent(category, () => []).add(item);
    }

    // Sort categories alphabetically for stable output
    final sortedCategories = categorized.keys.toList()..sort();

    for (final category in sortedCategories) {
      buffer.writeln(category);
      for (final item in categorized[category]!) {
        final check = item.bought ? '☑' : '☐';
        buffer.writeln('$check ${item.displayText}');
      }
      buffer.writeln('');
    }

    return buffer.toString().trimRight();
  }
}
