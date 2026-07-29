import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// BUT-1723: what a conversion actually did, not just whether it started.
///
/// [newListId] is the copy that was created, or null when the conversion could
/// not run at all. [originalKept] is true when the copy could NOT be confirmed
/// on the server and the SOURCE list was therefore deliberately left in place.
///
/// The caller must branch on it. Converting is confirmed on a dangerous-action
/// dialog that promises the other side disappears — reporting "converted" while
/// both lists still exist tells the owner their list is private when every
/// collaborator still has access, and leaves a silent duplicate behind.
typedef ListConversionResult = ({String? newListId, bool originalKept});

/// Handles collaborative shopping list lifecycle operations (create, convert, query).
class ListLifecycleOperations {
  final List<UnifiedShoppingList> Function() _getCollaborativeLists;
  final List<UnifiedShoppingList> Function() _getPersonalLists;
  final Future<String?> Function({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing,
    bool autoRemoveCompleted,
  })
  _createCollaborativeList;
  final Future<bool> Function(String listId) _deleteList;
  final Future<String?> Function(
    String name, {
    List<UnifiedShoppingItem>? items,
  })
  _createPersonalList;

  /// BUT-1723: server-confirmed item count for a list, or null when it could
  /// not be confirmed. See `ShoppingRepository.confirmPersistedItemCount`.
  final Future<int?> Function(String listId) _confirmPersistedItemCount;

  ListLifecycleOperations({
    required List<UnifiedShoppingList> Function() getCollaborativeLists,
    required List<UnifiedShoppingList> Function() getPersonalLists,
    required Future<String?> Function({
      required String name,
      String? description,
      required List<String> memberIds,
      required Map<String, String> memberDisplayNames,
      List<UnifiedShoppingItem>? items,
      List<String>? categoryIds,
      bool allowGuestEditing,
      bool autoRemoveCompleted,
    })
    createCollaborativeList,
    required Future<bool> Function(String listId) deleteList,
    required Future<String?> Function(
      String name, {
      List<UnifiedShoppingItem>? items,
    })
    createPersonalList,
    required Future<int?> Function(String listId) confirmPersistedItemCount,
  }) : _getCollaborativeLists = getCollaborativeLists,
       _getPersonalLists = getPersonalLists,
       _createCollaborativeList = createCollaborativeList,
       _deleteList = deleteList,
       _createPersonalList = createPersonalList,
       _confirmPersistedItemCount = confirmPersistedItemCount;

  Future<String?> createList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    return await _createCollaborativeList(
      name: name,
      description: description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );
  }

  List<UnifiedShoppingList> getAllLists() {
    return _getCollaborativeLists();
  }

  UnifiedShoppingList? getListById(String id) {
    try {
      return _getCollaborativeLists().firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  List<UnifiedShoppingList> getOwnedLists() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _getCollaborativeLists()
        .where((list) => permissionService.isShoppingListOwner(list.id))
        .toList();
  }

  List<UnifiedShoppingList> getSharedWithMe() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _getCollaborativeLists()
        .where(
          (list) =>
              !permissionService.isShoppingListOwner(list.id) &&
              permissionService.canViewShoppingList(list.id),
        )
        .toList();
  }

  Future<ListConversionResult> convertPersonalToCollaborative({
    required String personalListId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? description,
  }) async {
    UnifiedShoppingList? personalList;
    try {
      personalList = _getPersonalLists().firstWhere(
        (list) => list.id == personalListId,
      );
    } catch (e) {
      AppLogger.error('Cannot convert: Personal list not found');
      return (newListId: null, originalKept: false);
    }

    final collaborativeId = await createList(
      name: personalList.name,
      description: description ?? personalList.description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: personalList.items,
    );

    if (collaborativeId == null) {
      return (newListId: null, originalKept: false);
    }

    if (await _copyIsSafeToTrust(collaborativeId, personalList.items.length)) {
      await _deleteList(personalListId);
      return (newListId: collaborativeId, originalKept: false);
    }

    return (newListId: collaborativeId, originalKept: true);
  }

  /// BUT-1723: has the copy actually landed on the SERVER with every row?
  ///
  /// A conversion is a copy followed by a delete, and the delete is
  /// irreversible. The old gate was "the create call returned an id", which a
  /// Firestore write satisfies from the local cache before it has left the
  /// device — and, until the fan-out fix in `FirebaseShoppingRepository.create`,
  /// even a fully successful personal create persisted zero items. Either way
  /// the source was destroyed on the strength of an empty copy.
  ///
  /// An unconfirmed answer keeps BOTH lists. A duplicate the user can delete is
  /// a nuisance; the alternative is a shopping list that no longer exists.
  Future<bool> _copyIsSafeToTrust(String copyId, int expectedItems) async {
    final persisted = await _confirmPersistedItemCount(copyId);
    if (persisted != null && persisted >= expectedItems) return true;

    AppLogger.warning(
      'Keeping the original list: the copy $copyId has '
      '${persisted ?? "an unconfirmed number of"} of $expectedItems item(s) '
      'on the server',
    );
    return false;
  }

  Future<ListConversionResult> convertCollaborativeToPersonal(
    String collaborativeListId,
  ) async {
    final collaborativeList = getListById(collaborativeListId);
    if (collaborativeList == null) {
      AppLogger.error('Cannot convert: Collaborative list not found');
      return (newListId: null, originalKept: false);
    }

    if (!ServiceLocator.get<PermissionService>().isShoppingListOwner(
      collaborativeList.id,
    )) {
      AppLogger.error('Cannot convert: Only owner can convert to personal');
      return (newListId: null, originalKept: false);
    }

    final personalId = await _createPersonalList(
      collaborativeList.name,
      items: _withoutForeignAttribution(collaborativeList.items),
    );

    if (personalId == null) {
      return (newListId: null, originalKept: false);
    }

    if (await _copyIsSafeToTrust(personalId, collaborativeList.items.length)) {
      await _deleteList(collaborativeListId);
      return (newListId: personalId, originalKept: false);
    }

    return (newListId: personalId, originalKept: true);
  }

  /// BUT-1723 (review): the personal copy must not carry OTHER members'
  /// identities.
  ///
  /// The copy lands in `users/{me}/unified_shopping_lists/{id}` — a tree no
  /// other user's account-deletion cascade can query — and since the BUT-1723
  /// fan-out the rows persist in the `items` subcollection that reads treat as
  /// truth. A collaborator's uid and display name copied in here would
  /// therefore outlive their own account erasure indefinitely.
  ///
  /// What a row records happening (name, amount, `bought`, the timestamps) is
  /// the converting owner's own data and is kept; WHO did it is dropped unless
  /// it was the owner themselves.
  List<UnifiedShoppingItem> _withoutForeignAttribution(
    List<UnifiedShoppingItem> items,
  ) {
    final me = ServiceLocator.get<PermissionService>().currentUserId;
    return items.map((item) => _stripForeignIdentities(item, me)).toList();
  }

  UnifiedShoppingItem _stripForeignIdentities(
    UnifiedShoppingItem item,
    String? currentUserId,
  ) {
    // A display name is dropped with the uid it belongs to — an unattributable
    // name is still a name, and null uid means it cannot be mine either.
    bool isMine(String? userId) => userId != null && userId == currentUserId;

    final keepAdded = isMine(item.addedByUserId);
    final keepPurchased = isMine(item.purchasedByUserId);
    final keepModified = isMine(item.lastModifiedByUserId);
    final keepAssigned = isMine(item.assignedToUserId);

    return UnifiedShoppingItem(
      id: item.id,
      name: item.name,
      amount: item.amount,
      unit: item.unit,
      category: item.category,
      bought: item.bought,
      addedByUserId: keepAdded ? item.addedByUserId : null,
      addedByDisplayName: keepAdded ? item.addedByDisplayName : null,
      addedAt: item.addedAt,
      purchasedByUserId: keepPurchased ? item.purchasedByUserId : null,
      purchasedByDisplayName: keepPurchased
          ? item.purchasedByDisplayName
          : null,
      purchasedAt: item.purchasedAt,
      lastModifiedByUserId: keepModified ? item.lastModifiedByUserId : null,
      lastModifiedByDisplayName: keepModified
          ? item.lastModifiedByDisplayName
          : null,
      lastModifiedAt: item.lastModifiedAt,
      note: item.note,
      estimatedPrice: item.estimatedPrice,
      priority: item.priority,
      assignedToUserId: keepAssigned ? item.assignedToUserId : null,
      assignedToDisplayName: keepAssigned ? item.assignedToDisplayName : null,
      // A claim without a claimer is noise, so its timestamp goes with it.
      assignedAt: keepAssigned ? item.assignedAt : null,
    );
  }
}
