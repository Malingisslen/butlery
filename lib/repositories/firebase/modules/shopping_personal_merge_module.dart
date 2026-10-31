// lib/repositories/firebase/modules/shopping_personal_merge_module.dart

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/firestore_transaction_boundary.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show PersonalMergeRequest, PersonalMergeResult, PersonalMergeWrite;

/// Runs the replace transaction. Production binds this to
/// `firestore.runTransaction`; tests inject a runner that fails with the
/// offline codes `fake_cloud_firestore` cannot raise.
typedef PersonalMergeTransactionRunner =
    Future<PersonalMergeResult> Function(
      Future<PersonalMergeResult> Function(Transaction transaction) handler,
    );

/// Reads a personal list and its rows from the server. A test seam for the
/// same reason as [PersonalMergeTransactionRunner]: the fake ignores
/// `GetOptions` and never fails offline.
typedef PersonalListServerRead =
    Future<UnifiedShoppingList> Function(String uid, String listId);

/// BUT-2140: the week menu's merge into a personal list, written per
/// operation so that a change the same account made on another device is not
/// overwritten.
///
/// Rows are their own documents in the `items` subcollection. A sync reads
/// the rows the parent's `menuItemIds` names inside a transaction, so what it
/// overwrites or takes off is the server's current row, and a tick another
/// device made a moment ago keeps that row where it is.
class ShoppingPersonalMergeModule {
  /// Same budget as the shared-list transaction, for the same reason: the
  /// sheet waits on it.
  static const Duration _transactionBudget = Duration(seconds: 8);

  /// The codes that mean no server round-trip happened, so the write may be
  /// computed from the copy in memory instead. Matches the shared-list path.
  static const Set<String> _offlineCodes = {'unavailable', 'deadline-exceeded'};

  /// Firestore's cap on writes in one batch or transaction.
  static const int _maxWrites = 500;

  final String Function() requireCurrentUserId;
  final FirebaseFirestore firestore;
  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getUserCollection;
  final UnifiedShoppingList Function(DocumentSnapshot<Map<String, dynamic>> doc)
  fromFirestore;
  final Future<void> Function({
    required String currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    required String resourceId,
  })
  validateOwnership;
  final void Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  })
  logPermissionCheck;

  /// Test seams. Null in production.
  final PersonalMergeTransactionRunner? transactionRunner;
  final PersonalListServerRead? serverRead;
  final Future<bool> Function(String uid, String listId)? pendingWrites;

  ShoppingPersonalMergeModule({
    required this.firestore,
    required this.requireCurrentUserId,
    required this.getUserCollection,
    required this.fromFirestore,
    required this.validateOwnership,
    required this.logPermissionCheck,
    this.transactionRunner,
    this.serverRead,
    this.pendingWrites,
  });

  DocumentReference<Map<String, dynamic>> _listRef(String uid, String id) =>
      getUserCollection(uid).doc(id);

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid, String id) =>
      _listRef(uid, id).collection(FirestoreCollections.items);

  Future<PersonalMergeResult> applyPersonalMerge(
    UnifiedShoppingList base,
    PersonalMergeRequest request,
  ) async {
    final uid = requireCurrentUserId();
    // Read before the server: a write of this device's own that has not
    // synced yet is in memory but not on the server, and would otherwise be
    // announced as another device's change.
    final pending = await (pendingWrites ?? _hasPendingWrites)(uid, base.id);

    final UnifiedShoppingList server;
    try {
      server = await (serverRead ?? _readFromServer)(uid, base.id);
    } on FirebaseException catch (e) {
      if (!_offlineCodes.contains(e.code)) rethrow;
      return _mergeFromMemory(uid, base, request);
    }
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: server.ownerId,
      resourceType: 'shopping_list',
      resourceId: base.id,
    );
    final concurrentChange = !pending && _differs(base, server);

    final PersonalMergeResult result;
    try {
      result = await runTransactionKeepingHandlerError(
        transactionRunner ??
            budgetedTransactionRunner<PersonalMergeResult>(
              firestore,
              _transactionBudget,
            ),
        (transaction) =>
            _sync(transaction, uid, server, request, concurrentChange),
      );
    } on FirebaseException catch (e) {
      if (!_offlineCodes.contains(e.code)) rethrow;
      return _mergeFromMemory(uid, base, request);
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_list',
      operation: 'menu_merge',
      granted: true,
      details:
          'List: ${base.id}, added: ${result.added.length}, '
          'updated: ${result.updated.length}, '
          'removed: ${result.removed.length}',
    );
    return result;
  }

  Future<UnifiedShoppingList> undoPersonalMerge(
    UnifiedShoppingList base, {
    required List<String> addedIds,
    required List<UnifiedShoppingItem> restore,
  }) async {
    final uid = requireCurrentUserId();
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: base.ownerId,
      resourceType: 'shopping_list',
      resourceId: base.id,
    );
    _checkWriteCount(addedIds.length + restore.length + 2);

    final items = _itemsRef(uid, base.id);
    final listRef = _listRef(uid, base.id);
    final batch = firestore.batch();
    for (final id in addedIds) {
      batch.delete(items.doc(id));
    }
    for (final item in restore) {
      batch.set(items.doc(item.id), item.toFirestore());
    }
    // Two updates because one update cannot carry two transforms on the same
    // field. Both replay as merges, so neither needs the server's copy.
    batch.update(listRef, {
      'menuItemIds': FieldValue.arrayRemove(addedIds),
      'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
    });
    if (restore.isNotEmpty) {
      batch.update(listRef, {
        'menuItemIds': FieldValue.arrayUnion([
          for (final item in restore) item.id,
        ]),
      });
    }
    await awaitOrLeaveQueued(
      batch.commit(),
      what: 'shopping undo merge on ${base.id}',
    );

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_list',
      operation: 'menu_merge_undo',
      granted: true,
      details: 'List: ${base.id}, removed: ${addedIds.length}',
    );

    final added = addedIds.toSet();
    final restoredIds = {for (final item in restore) item.id};
    return base.copyWith(
      items: [
        ...base.items.where(
          (i) => !added.contains(i.id) && !restoredIds.contains(i.id),
        ),
        ...restore,
      ],
      menuItemIds: [
        ...?base.menuItemIds?.where(
          (id) => !added.contains(id) && !restoredIds.contains(id),
        ),
        ...restoredIds,
      ],
    );
  }

  /// The sync against the server: the rows it compares with are the ones the
  /// server's `menuItemIds` names and that still exist, read inside the
  /// transaction.
  Future<PersonalMergeResult> _sync(
    Transaction transaction,
    String uid,
    UnifiedShoppingList server,
    PersonalMergeRequest request,
    bool concurrentChange,
  ) async {
    final listRef = _listRef(uid, server.id);
    final items = _itemsRef(uid, server.id);
    final parent = await transaction.get(listRef);
    if (!parent.exists) throw _notFound(server.id);
    final stored = fromFirestore(parent);
    final menuIds = stored.menuItemIds ?? const <String>[];

    final current = <UnifiedShoppingItem>[];
    for (final id in menuIds) {
      final row = await transaction.get(items.doc(id));
      final data = row.data();
      if (row.exists && data != null) {
        current.add(UnifiedShoppingItem.fromFirestore(data));
      }
    }
    final write = _within(request.sync(current), current);
    _checkWriteCount(
      write.remove.length + write.add.length + write.update.length + 1,
    );
    // The follow runs after every save of the week, and most saves change no
    // row: such a sync writes nothing, so no device's listener fires for it.
    if (write.isEmpty &&
        current.length == menuIds.length &&
        stored.generatedForWeek == request.generatedForWeek) {
      return PersonalMergeResult(
        list: server,
        added: const [],
        removed: const [],
        concurrentChange: concurrentChange,
      );
    }

    for (final item in write.remove) {
      transaction.delete(items.doc(item.id));
    }
    for (final item in [...write.add, ...write.update]) {
      transaction.set(items.doc(item.id), item.toFirestore());
    }
    final removedIds = {for (final item in write.remove) item.id};
    final nextMenuIds = [
      for (final row in current)
        if (!removedIds.contains(row.id)) row.id,
      for (final item in write.add) item.id,
    ];
    transaction.update(listRef, {
      'menuItemIds': nextMenuIds,
      'generatedForWeek': request.generatedForWeek,
      'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
    });

    return PersonalMergeResult(
      list: _applied(server, write).copyWith(
        menuItemIds: nextMenuIds,
        generatedForWeek: request.generatedForWeek,
      ),
      added: write.add,
      updated: write.update,
      changedFrom: _before(current, write.update),
      removed: write.remove,
      concurrentChange: concurrentChange,
    );
  }

  /// Offline: the write is computed from the copy in memory and queued, which
  /// Firestore replays on reconnect. `menuItemIds` is changed with
  /// `arrayUnion`/`arrayRemove`, which merge on replay. A row the sync
  /// overwrites or takes off is the memory copy's, so a tick another device
  /// made on it in the meantime can be lost — the accepted deviation in
  /// `docs/architecture/ACCEPTED_DEVIATIONS.md` (BUT-2140, the BUT-1683
  /// shape), chosen over a sheet that refuses to write in a shop.
  Future<PersonalMergeResult> _mergeFromMemory(
    String uid,
    UnifiedShoppingList base,
    PersonalMergeRequest request,
  ) async {
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: base.ownerId,
      resourceType: 'shopping_list',
      resourceId: base.id,
    );
    final menuIds = (base.menuItemIds ?? const <String>[]).toSet();
    final current = base.items.where((i) => menuIds.contains(i.id)).toList();
    final write = _within(request.sync(current), current);
    _checkWriteCount(
      write.remove.length + write.add.length + write.update.length + 2,
    );
    if (write.isEmpty &&
        current.length == menuIds.length &&
        base.generatedForWeek == request.generatedForWeek) {
      return PersonalMergeResult(
        list: base,
        added: const [],
        removed: const [],
        concurrentChange: false,
      );
    }

    final items = _itemsRef(uid, base.id);
    final listRef = _listRef(uid, base.id);
    final batch = firestore.batch();
    for (final item in write.remove) {
      batch.delete(items.doc(item.id));
    }
    for (final item in [...write.add, ...write.update]) {
      batch.set(items.doc(item.id), item.toFirestore());
    }
    // Two updates because one update cannot carry two transforms on the same
    // field.
    batch.update(listRef, {
      'menuItemIds': FieldValue.arrayUnion([
        for (final item in write.add) item.id,
      ]),
      'generatedForWeek': request.generatedForWeek,
      'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
    });
    if (write.remove.isNotEmpty) {
      batch.update(listRef, {
        'menuItemIds': FieldValue.arrayRemove([
          for (final item in write.remove) item.id,
        ]),
      });
    }
    // Not awaited: offline the future settles only once the write reaches the
    // server, while the local cache already holds it.
    unawaited(
      batch.commit().catchError(
        (Object e) => AppLogger.warning(
          'Queued menu merge into personal list ${base.id} was rejected: $e',
          'ShoppingRepository',
        ),
      ),
    );

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_list',
      operation: 'menu_merge',
      granted: true,
      details: 'List: ${base.id}, offline sync from memory',
    );

    final removedIds = {for (final item in write.remove) item.id};
    return PersonalMergeResult(
      list: _applied(base, write).copyWith(
        menuItemIds: [
          ...menuIds.where((id) => !removedIds.contains(id)),
          for (final item in write.add) item.id,
        ],
        generatedForWeek: request.generatedForWeek,
      ),
      added: write.add,
      updated: write.update,
      changedFrom: _before(current, write.update),
      removed: write.remove,
      concurrentChange: false,
    );
  }

  /// [write] with only the overwrites and removals of rows in [current], so
  /// a sync can never change a row the user typed by hand.
  static PersonalMergeWrite _within(
    PersonalMergeWrite write,
    List<UnifiedShoppingItem> current,
  ) {
    final known = {for (final item in current) item.id};
    return PersonalMergeWrite(
      add: write.add.where((i) => !known.contains(i.id)).toList(),
      update: write.update.where((i) => known.contains(i.id)).toList(),
      remove: write.remove.where((i) => known.contains(i.id)).toList(),
    );
  }

  /// [list] with [write] applied to its rows, in their order.
  static UnifiedShoppingList _applied(
    UnifiedShoppingList list,
    PersonalMergeWrite write,
  ) {
    final removed = {for (final item in write.remove) item.id};
    final updated = {for (final item in write.update) item.id: item};
    return list.copyWith(
      items: [
        for (final item in list.items)
          if (!removed.contains(item.id)) updated[item.id] ?? item,
        ...write.add,
      ],
    );
  }

  /// The rows of [current] that [updated] overwrites, as they were.
  static List<UnifiedShoppingItem> _before(
    List<UnifiedShoppingItem> current,
    List<UnifiedShoppingItem> updated,
  ) {
    final ids = {for (final item in updated) item.id};
    return List.unmodifiable(current.where((i) => ids.contains(i.id)));
  }

  Future<UnifiedShoppingList> _readFromServer(String uid, String listId) async {
    const server = GetOptions(source: Source.server);
    final parent = await _listRef(uid, listId).get(server);
    if (!parent.exists) throw _notFound(listId);
    final rows = await _itemsRef(uid, listId).get(server);
    return fromFirestore(parent).copyWith(
      items: [
        for (final doc in rows.docs)
          UnifiedShoppingItem.fromFirestore(doc.data()),
      ],
    );
  }

  Future<bool> _hasPendingWrites(String uid, String listId) async {
    const cache = GetOptions(source: Source.cache);
    try {
      final parent = await _listRef(uid, listId).get(cache);
      if (parent.metadata.hasPendingWrites) return true;
      final rows = await _itemsRef(uid, listId).get(cache);
      return rows.metadata.hasPendingWrites;
    } on FirebaseException {
      // A cache miss: nothing of this list is held locally, so nothing of it
      // is waiting to sync.
      return false;
    }
  }

  /// Whether the server's list differs from the copy in memory in its rows,
  /// a row's name, amount or tick, or its `menuItemIds`.
  static bool _differs(UnifiedShoppingList memory, UnifiedShoppingList server) {
    final mineIds = (memory.menuItemIds ?? const <String>[]).toSet();
    final theirIds = (server.menuItemIds ?? const <String>[]).toSet();
    if (mineIds.length != theirIds.length || !mineIds.containsAll(theirIds)) {
      return true;
    }
    final mine = {for (final item in memory.items) item.id: item};
    if (mine.length != server.items.length) return true;
    for (final row in server.items) {
      final known = mine[row.id];
      if (known == null ||
          known.bought != row.bought ||
          known.amount != row.amount ||
          known.name != row.name) {
        return true;
      }
    }
    return false;
  }

  static void _checkWriteCount(int writes) {
    if (writes > _maxWrites) {
      throw StateError(
        'A menu merge of $writes writes exceeds the $_maxWrites-write limit '
        'of one batch',
      );
    }
  }

  static ResourceNotFoundException _notFound(String listId) =>
      ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
}
