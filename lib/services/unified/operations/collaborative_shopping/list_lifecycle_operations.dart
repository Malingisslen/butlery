import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
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
///
/// [notInvited] are the chosen friends the invitation did not go out to (BUT-2089).
/// The list stays converted either way; the caller names them.
typedef ListConversionResult = ({
  String? newListId,
  bool originalKept,
  List<String> notInvited,
});

/// A freshly created shared list and the friends it could not invite.
typedef CreatedSharedList = ({String? listId, List<String> notInvited});

/// Handles collaborative shopping list lifecycle operations (create, convert, query).
class ListLifecycleOperations {
  final List<UnifiedShoppingList> Function() _getCollaborativeLists;
  final List<UnifiedShoppingList> Function() _getPersonalLists;
  final Future<String?> Function({
    required String name,
    String? description,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing,
    bool autoRemoveCompleted,
  })
  _createCollaborativeList;

  /// Invites [userIds] to a list; a seat is only ever taken by accepting.
  final Future<ListInviteSummary> Function(
    String listId,
    List<String> userIds,
    String permission,
  )
  _inviteMembers;
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
      List<UnifiedShoppingItem>? items,
      List<String>? categoryIds,
      bool allowGuestEditing,
      bool autoRemoveCompleted,
    })
    createCollaborativeList,
    required Future<ListInviteSummary> Function(
      String listId,
      List<String> userIds,
      String permission,
    )
    inviteMembers,
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
       _inviteMembers = inviteMembers,
       _confirmPersistedItemCount = confirmPersistedItemCount;

  /// Creates the list with only the caller seated, then invites [memberIds].
  /// A failed invite keeps the list: [CreatedSharedList.notInvited] names who
  /// is missing, and the list id is null only when the create itself failed.
  Future<CreatedSharedList> createListAndInvite({
    required String name,
    String? description,
    required List<String> memberIds,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    final listId = await _createCollaborativeList(
      name: name,
      description: description,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );
    if (listId == null || memberIds.isEmpty) {
      return (listId: listId, notInvited: const <String>[]);
    }
    try {
      final summary = await _inviteMembers(
        listId,
        memberIds,
        allowGuestEditing ? 'edit' : 'view',
      );
      return (listId: listId, notInvited: summary.notInvited);
    } catch (e) {
      AppLogger.error('Inviting to the new shared list failed', e);
      return (listId: listId, notInvited: List.of(memberIds));
    }
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
    String? description,
  }) async {
    UnifiedShoppingList? personalList;
    try {
      personalList = _getPersonalLists().firstWhere(
        (list) => list.id == personalListId,
      );
    } catch (e) {
      AppLogger.error('Cannot convert: Personal list not found');
      return (
        newListId: null,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    final created = await createListAndInvite(
      name: personalList.name,
      description: description ?? personalList.description,
      memberIds: memberIds,
      items: personalList.items,
    );
    final collaborativeId = created.listId;

    if (collaborativeId == null) {
      return (
        newListId: null,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    final keepOriginal = !await _copyIsSafeToTrust(
      collaborativeId,
      personalList.items.length,
    );
    if (!keepOriginal) await _deleteList(personalListId);
    return (
      newListId: collaborativeId,
      originalKept: keepOriginal,
      notInvited: created.notInvited,
    );
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
      return (
        newListId: null,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    if (!ServiceLocator.get<PermissionService>().isShoppingListOwner(
      collaborativeList.id,
    )) {
      AppLogger.error('Cannot convert: Only owner can convert to personal');
      return (
        newListId: null,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    final personalId = await _createPersonalList(
      collaborativeList.name,
      items: _withoutForeignAttribution(collaborativeList.items),
    );

    if (personalId == null) {
      return (
        newListId: null,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    if (await _copyIsSafeToTrust(personalId, collaborativeList.items.length)) {
      await _deleteList(collaborativeListId);
      return (
        newListId: personalId,
        originalKept: false,
        notInvited: const <String>[],
      );
    }

    return (
      newListId: personalId,
      originalKept: true,
      notInvited: const <String>[],
    );
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
      // BUT-2140: a snapshot holds no name or uid, so the strip keeps it.
      previous: item.previous,
    );
  }
}
