// lib/repositories/firebase/modules/shopping_personal_merge_module.dart

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show PersonalMergeRequest, PersonalMergeResult;

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
/// Rows are their own documents in the `items` subcollection, so adding them
/// commutes with anything another device does. The one field both devices
/// share is the parent's `menuItemIds`, which an add extends with
/// `arrayUnion` — that merges on an offline replay as well. Only "Ersätt
/// listan" changes rows that already exist, and only it runs a transaction.
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
  final Future<void> Function({
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
    if (request.replace) {
      try {
        result = await (transactionRunner ?? _runOnBudget)(
          (transaction) =>
              _replace(transaction, uid, server, request, concurrentChange),
        );
      } on FirebaseException catch (e) {
        if (!_offlineCodes.contains(e.code)) rethrow;
        return _mergeFromMemory(uid, base, request);
      }
    } else {
      final added = request.rows(const []);
      await _addBatch(uid, base.id, added, request.generatedForWeek).commit();
      result = PersonalMergeResult(
        list: server.copyWith(
          items: [...server.items, ...added],
          menuItemIds: {
            ...?server.menuItemIds,
            for (final item in added) item.id,
          }.toList(),
          generatedForWeek: request.generatedForWeek,
        ),
        added: added,
        removed: const [],
        concurrentChange: concurrentChange,
      );
    }

    await logPermissionCheck(
      userId: uid,
      resource: 'shopping_list',
      operation: 'menu_merge',
      granted: true,
      details:
          'List: ${base.id}, added: ${result.added.length}, '
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

    await logPermissionCheck(
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

  /// "Ersätt listan" against the server: the recipe rows to take off are the
  /// ones the server's `menuItemIds` names and that still exist, and their
  /// bought ticks are read inside the transaction, so a tick made on another
  /// device a moment ago carries over.
  Future<PersonalMergeResult> _replace(
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
    final menuIds = fromFirestore(parent).menuItemIds ?? const <String>[];

    final removed = <UnifiedShoppingItem>[];
    for (final id in menuIds) {
      final row = await transaction.get(items.doc(id));
      final data = row.data();
      if (row.exists && data != null) {
        removed.add(UnifiedShoppingItem.fromFirestore(data));
      }
    }
    final added = request.rows(removed);
    _checkWriteCount(removed.length + added.length + 1);

    for (final item in removed) {
      transaction.delete(items.doc(item.id));
    }
    for (final item in added) {
      transaction.set(items.doc(item.id), item.toFirestore());
    }
    final addedIds = [for (final item in added) item.id];
    transaction.update(listRef, {
      'menuItemIds': addedIds,
      'generatedForWeek': request.generatedForWeek,
      'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
    });

    final gone = {for (final item in removed) item.id, ...addedIds};
    return PersonalMergeResult(
      list: server.copyWith(
        items: [...server.items.where((i) => !gone.contains(i.id)), ...added],
        menuItemIds: addedIds,
        generatedForWeek: request.generatedForWeek,
      ),
      added: added,
      removed: removed,
      concurrentChange: concurrentChange,
    );
  }

  /// The add, as a batch: the rows, and the parent's `menuItemIds` extended
  /// rather than replaced.
  WriteBatch _addBatch(
    String uid,
    String listId,
    List<UnifiedShoppingItem> added,
    String? generatedForWeek,
  ) {
    _checkWriteCount(added.length + 1);
    final items = _itemsRef(uid, listId);
    final batch = firestore.batch();
    for (final item in added) {
      batch.set(items.doc(item.id), item.toFirestore());
    }
    batch.update(_listRef(uid, listId), {
      'menuItemIds': FieldValue.arrayUnion([for (final i in added) i.id]),
      'generatedForWeek': generatedForWeek,
      'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
    });
    return batch;
  }

  /// Offline: the write is computed from the copy in memory and queued, which
  /// Firestore replays on reconnect. An add is still safe, because it extends
  /// `menuItemIds` with `arrayUnion`. A replace takes off the rows the memory
  /// copy knows of and sets `menuItemIds` outright, so a tick another device
  /// made on a recipe row in the meantime can be lost — the accepted
  /// deviation in `docs/architecture/ACCEPTED_DEVIATIONS.md` (BUT-2140, the
  /// BUT-1683 shape), chosen over a sheet that refuses to replace in a shop.
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
    final removed = request.replace
        ? base.items.where((i) => menuIds.contains(i.id)).toList()
        : const <UnifiedShoppingItem>[];
    final added = request.rows(removed);
    final addedIds = [for (final item in added) item.id];

    final WriteBatch batch;
    if (request.replace) {
      _checkWriteCount(removed.length + added.length + 1);
      final items = _itemsRef(uid, base.id);
      batch = firestore.batch();
      for (final item in removed) {
        batch.delete(items.doc(item.id));
      }
      for (final item in added) {
        batch.set(items.doc(item.id), item.toFirestore());
      }
      batch.update(_listRef(uid, base.id), {
        'menuItemIds': addedIds,
        'generatedForWeek': request.generatedForWeek,
        'updatedAt': Timestamp.fromDate(clock.now().toUtc()),
      });
    } else {
      batch = _addBatch(uid, base.id, added, request.generatedForWeek);
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

    await logPermissionCheck(
      userId: uid,
      resource: 'shopping_list',
      operation: 'menu_merge',
      granted: true,
      details:
          'List: ${base.id}, offline '
          '${request.replace ? 'replace from memory' : 'add (arrayUnion)'}',
    );

    final gone = {for (final item in removed) item.id};
    return PersonalMergeResult(
      list: base.copyWith(
        items: [...base.items.where((i) => !gone.contains(i.id)), ...added],
        menuItemIds: request.replace ? addedIds : [...menuIds, ...addedIds],
        generatedForWeek: request.generatedForWeek,
      ),
      added: added,
      removed: removed,
      concurrentChange: false,
    );
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

  Future<PersonalMergeResult> _runOnBudget(
    Future<PersonalMergeResult> Function(Transaction transaction) handler,
  ) => firestore.runTransaction<PersonalMergeResult>(
    handler,
    timeout: _transactionBudget,
  );

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
