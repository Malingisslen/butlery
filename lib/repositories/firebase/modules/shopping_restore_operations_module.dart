// lib/repositories/firebase/modules/shopping_restore_operations_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/services/shopping/restorable_rows.dart';

/// BUT-2140: the write half of "Återställ varor" — keeping a row's earlier
/// version and its removal in the same write that changes it, and putting
/// either back.
///
/// [ShoppingItemOperationsModule] owns the six row writes and calls the
/// helpers here from inside them, so the history is written by the same
/// operation as the change it records: on a shared list inside the
/// transaction on the live document, on a personal list in the same batch.
/// The two restore methods are reached from the repository through
/// [ShoppingItemOperationsModule.restore].
class ShoppingRestoreOperationsModule {
  static const String _previousKey = 'previous';

  final FirebaseFirestore firestore;
  final String Function() requireCurrentUserId;
  final Future<UnifiedShoppingList> Function(String listId) requireList;
  final Future<UnifiedShoppingList> Function(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  )
  mutateCollaborativeList;
  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getUserCollection;
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
  final String? Function() resolveDisplayName;

  /// The item module's activity stamp for a shared list, so a restore names
  /// its author the same way every other row write does.
  final UnifiedShoppingList Function(
    UnifiedShoppingList live,
    List<UnifiedShoppingItem> items,
    String uid,
  )
  withItems;

  ShoppingRestoreOperationsModule({
    required this.firestore,
    required this.requireCurrentUserId,
    required this.requireList,
    required this.mutateCollaborativeList,
    required this.getUserCollection,
    required this.validateOwnership,
    required this.logPermissionCheck,
    required this.resolveDisplayName,
    required this.withItems,
  });

  /// [live] with each row in [replacements] swapped in, each carrying the
  /// `previous` its LIVE row implies. The caller's copy of `previous` is never
  /// trusted: it may predate another member's edit.
  static List<UnifiedShoppingItem> replaceRows(
    List<UnifiedShoppingItem> live,
    Map<String, UnifiedShoppingItem> replacements,
    DateTime now,
  ) => [
    for (final existing in live)
      if (replacements[existing.id] case final next?)
        RestorableRows.withPrevious(existing, next, now)
      else
        existing,
  ];

  /// Shared list: [live] without the rows [ids] names, those rows recorded in
  /// `recentlyRemoved` by [RestorableRows.withRemoved] (which skips bought
  /// ones, so "Rensa klart" records nothing).
  UnifiedShoppingList removeRows(
    UnifiedShoppingList live,
    Set<String> ids,
    String uid,
  ) {
    final now = clock.now().toUtc();
    return RestorableRows.withRemoved(
      withItems(live, [
        for (final item in live.items)
          if (!ids.contains(item.id)) item,
      ], uid),
      live.items.where((item) => ids.contains(item.id)),
      now,
    );
  }

  /// Personal list: the document [item] is written as. A content edit
  /// against [before] writes [before]'s content as `previous`; anything else
  /// leaves `previous` out of the write, so a copy in memory that never saw
  /// another device's edit cannot null the `previous` stored there.
  static Map<String, dynamic> personalUpdatePayload(
    UnifiedShoppingItem item,
    UnifiedShoppingItem? before,
    DateTime now,
  ) {
    if (before != null && RestorableRows.contentChanged(before, item)) {
      return RestorableRows.withPrevious(before, item, now).toFirestore();
    }
    return item.toFirestore()..remove(_previousKey);
  }

  /// Personal list: deletes the rows [ids] names in chunked batches, with the
  /// history change for [removed] riding on the first chunk.
  Future<void> deletePersonalRows(
    String uid,
    UnifiedShoppingList list,
    List<String> ids,
    List<UnifiedShoppingItem> removed,
  ) async {
    final parent = getUserCollection(uid).doc(list.id);
    final rows = parent.collection(FirestoreCollections.items);
    var first = true;
    for (final chunk in ids.chunked(kFirestoreBatchSafeChunkSize)) {
      final batch = firestore.batch();
      for (final id in chunk) {
        batch.delete(rows.doc(id));
      }
      if (first && removed.isNotEmpty) {
        _stageRemoved(batch, parent, list, removed);
      }
      first = false;
      await awaitOrLeaveQueued(
        batch.commit(),
        what: 'shopping remove ${chunk.length} rows from ${list.id}',
      );
    }
  }

  /// Personal list: stages on [batch] the history change removing [removed]
  /// makes to [list]'s parent document — one `update` with the new entries as
  /// `arrayUnion`, and, when entries expired or fell past the cap, a second
  /// `update` taking them out with `arrayRemove`. Two updates because one
  /// cannot carry two transforms on the same field. Both are set operations,
  /// so an offline replay merges with what another device added meanwhile.
  ///
  /// [list] is the parent document the caller already read for routing, so
  /// this costs no read. The dropped entries are therefore re-serialised from
  /// that parsed copy rather than sent as stored; `arrayRemove` matches by
  /// value.
  void _stageRemoved(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> parent,
    UnifiedShoppingList list,
    Iterable<UnifiedShoppingItem> removed,
  ) {
    final next = RestorableRows.withRemoved(
      list,
      removed,
      clock.now().toUtc(),
    ).recentlyRemoved;
    final before = list.recentlyRemoved.toSet();
    final after = next.toSet();
    final added = [
      for (final s in next)
        if (!before.contains(s)) s.toFirestore(),
    ];
    final dropped = [
      for (final s in list.recentlyRemoved)
        if (!after.contains(s)) s.toFirestore(),
    ];
    if (added.isNotEmpty) {
      batch.update(parent, {
        UnifiedShoppingList.recentlyRemovedKey: FieldValue.arrayUnion(added),
      });
    }
    if (dropped.isNotEmpty) {
      batch.update(parent, {
        UnifiedShoppingList.recentlyRemovedKey: FieldValue.arrayRemove(dropped),
      });
    }
  }

  /// Puts the removed row [entry] back on [listId] with its old id, and takes
  /// [entry] out of `recentlyRemoved` in the same write. The restorer is
  /// stamped as `addedBy`, so a shared list's erasure trail names them.
  ///
  /// An entry is matched on its row id alone: the copy a caller holds may
  /// carry a different `at` than the stored one. Every entry with that id
  /// goes, and the row is built from the newest stored one, not the caller's.
  ///
  /// When a row with that id is already on the list (restored by someone
  /// else, or twice), nothing is added and only the entry goes. When the list
  /// holds no entry with that id (another member restored it first), nothing
  /// is written. Returns the row as written, or null when nothing was put
  /// back. An entry older than 30 days is refused.
  Future<UnifiedShoppingItem?> restoreRemovedRow(
    String listId,
    ShoppingRowSnapshot entry,
  ) async {
    final uid = requireCurrentUserId();
    final now = clock.now().toUtc();
    final list = await requireList(listId);
    ShoppingRowSnapshot? storedEntry(UnifiedShoppingList l) => maxBy(
      l.recentlyRemoved.where((s) => s.id == entry.id && s.restorableAt(now)),
      (s) => s.at,
    );
    // Checked on the copy just loaded (the cache, offline) so a stale entry
    // costs no write: offline, even an unchanged list would queue the whole
    // cached `items` array.
    if (storedEntry(list) == null) return null;

    UnifiedShoppingItem? written;
    if (list.type == ListType.collaborative) {
      await mutateCollaborativeList(listId, (live) {
        written = null;
        final liveEntry = storedEntry(live);
        if (liveEntry == null) return live;
        UnifiedShoppingList withoutEntry(UnifiedShoppingList l) => l.copyWith(
          recentlyRemoved: [
            for (final s in l.recentlyRemoved)
              if (s.id != entry.id) s,
          ],
          updatedAt: l.updatedAt,
        );
        if (live.items.any((item) => item.id == entry.id)) {
          return withoutEntry(live);
        }
        final row = _stampedRestore(liveEntry, uid, now);
        written = row;
        return withoutEntry(withItems(live, [...live.items, row], uid));
      });
    } else {
      await _requireOwner(uid, list, listId);
      final parent = getUserCollection(uid).doc(listId);
      final rowRef = parent
          .collection(FirestoreCollections.items)
          .doc(entry.id);
      final snapshot = await parent.get();
      final liveEntry = storedEntry(
        UnifiedShoppingList.fromFirestore(snapshot),
      );
      // The stored values, not re-serialised ones: `arrayRemove` matches by
      // exact value.
      final stored = RestorableRows.storedElements(
        snapshot.data()?[UnifiedShoppingList.recentlyRemovedKey],
        {entry.id},
      );
      if (liveEntry == null || stored.isEmpty) return null;
      final row = _stampedRestore(liveEntry, uid, now);
      final batch = firestore.batch();
      if (!(await rowRef.get()).exists) {
        batch.set(rowRef, row.toFirestore());
        written = row;
      }
      batch.update(parent, {
        UnifiedShoppingList.recentlyRemovedKey: FieldValue.arrayRemove(stored),
        'updatedAt': Timestamp.fromDate(now),
      });
      await awaitOrLeaveQueued(
        batch.commit(),
        what: 'shopping restore ${entry.id}',
      );
    }

    await logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'restore_removed',
      granted: true,
      details:
          'List: $listId, Item: ${entry.id}, Type: ${list.type}, '
          'restored: ${written != null}',
    );
    return written;
  }

  /// Swaps row [itemId]'s content with its `previous`, so what it replaces
  /// becomes the new `previous` and the restore can itself be undone. Returns
  /// the row as written, or null when the row is gone or has no `previous`
  /// from the last 30 days.
  Future<UnifiedShoppingItem?> restoreChangedRow(
    String listId,
    String itemId,
  ) async {
    final uid = requireCurrentUserId();
    final now = clock.now().toUtc();
    final list = await requireList(listId);

    UnifiedShoppingItem? written;
    if (list.type == ListType.collaborative) {
      // Same reason as in [restoreRemovedRow]: nothing to swap, no write.
      final loaded = list.items.firstWhereOrNull((i) => i.id == itemId);
      if (loaded == null || _swapped(loaded, uid, now) == null) return null;
      await mutateCollaborativeList(listId, (live) {
        written = null;
        final current = live.items.firstWhereOrNull((i) => i.id == itemId);
        final swapped = current == null ? null : _swapped(current, uid, now);
        if (swapped == null) return live;
        written = swapped;
        return withItems(live, [
          for (final item in live.items) item.id == itemId ? swapped : item,
        ], uid);
      });
    } else {
      await _requireOwner(uid, list, listId);
      final rowRef = getUserCollection(
        uid,
      ).doc(listId).collection(FirestoreCollections.items).doc(itemId);
      final data = (await rowRef.get()).data();
      final swapped = data == null
          ? null
          : _swapped(UnifiedShoppingItem.fromFirestore(data), uid, now);
      if (swapped == null) return null;
      await awaitOrLeaveQueued(
        rowRef.update(swapped.toFirestore()),
        what: 'shopping restore version $itemId',
      );
      written = swapped;
    }

    await logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'restore_changed',
      granted: true,
      details:
          'List: $listId, Item: $itemId, Type: ${list.type}, '
          'restored: ${written != null}',
    );
    return written;
  }

  Future<void> _requireOwner(
    String uid,
    UnifiedShoppingList list,
    String listId,
  ) => validateOwnership(
    currentUserId: uid,
    resourceOwnerId: list.ownerId,
    resourceType: 'shopping_list',
    resourceId: listId,
  );

  UnifiedShoppingItem _stampedRestore(
    ShoppingRowSnapshot entry,
    String uid,
    DateTime now,
  ) {
    final name = resolveDisplayName().orEmpty();
    return UnifiedShoppingItem(
      id: entry.id,
      name: entry.name,
      amount: entry.amount,
      unit: entry.unit,
      category: entry.category,
      note: entry.note,
      addedByUserId: uid,
      addedByDisplayName: name,
      addedAt: now,
      lastModifiedByUserId: uid,
      lastModifiedByDisplayName: name,
      lastModifiedAt: now,
    );
  }

  /// [current] with its `previous` content and [current]'s own content as the
  /// new `previous`, or null when there is nothing restorable.
  UnifiedShoppingItem? _swapped(
    UnifiedShoppingItem current,
    String uid,
    DateTime now,
  ) {
    final previous = current.previous;
    if (previous == null || !previous.restorableAt(now)) return null;
    return current
        .copyWith(
          name: previous.name,
          amount: previous.amount,
          unit: previous.unit,
          category: previous.category,
          note: previous.note,
          clearNote: previous.note.orEmpty().isEmpty,
          lastModifiedByUserId: uid,
          lastModifiedByDisplayName: resolveDisplayName().orEmpty(),
          lastModifiedAt: now,
        )
        .withPreviousSnapshot(ShoppingRowSnapshot.fromItem(current, now));
  }
}
