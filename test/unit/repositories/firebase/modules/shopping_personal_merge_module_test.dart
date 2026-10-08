/// BUT-2140: the week menu's merge into a personal list, written per operation
/// against the server's copy (flows-roles-budget.md:47, `lägga till` → the
/// list was changed at the same time → your rows are added and nothing is
/// overwritten).
///
/// Every fixture makes the copy in memory and the stored list differ the way
/// another device signed in to the same account would: rows it added, a merge
/// it ran, a tick or a delete it made. What these tests do NOT prove is
/// atomicity: `FakeFirebaseFirestore.runTransaction` is a passthrough without
/// isolation or retry, and the fake ignores `GetOptions`, so the offline and
/// pending-write cases go through the module's seams.
library;

// The counting doubles implement two sealed cloud_firestore types; that is the
// only way to count what a batch and a transaction write.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_personal_merge_module.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';

const _uid = 'merge-user';
const _listId = 'week-list';
const _weekKey = '2026-W24';

class _Counts {
  int batchWrites = 0;
  int transactionReads = 0;
  int transactionWrites = 0;
}

class _CountingBatch implements WriteBatch {
  _CountingBatch(this._inner, this._counts);
  final WriteBatch _inner;
  final _Counts _counts;

  @override
  Future<void> commit() => _inner.commit();

  @override
  void delete(DocumentReference document) {
    _counts.batchWrites++;
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _counts.batchWrites++;
    _inner.set(document, data, options);
  }

  @override
  void update(DocumentReference document, Map<Object, Object?> data) {
    _counts.batchWrites++;
    _inner.update(document, data);
  }
}

class _CountingTransaction implements Transaction {
  _CountingTransaction(this._inner, this._counts);
  final Transaction _inner;
  final _Counts _counts;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    _counts.transactionReads++;
    return _inner.get(documentReference);
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    _counts.transactionWrites++;
    return _inner.delete(documentReference);
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _counts.transactionWrites++;
    return _inner.set(documentReference, data, options);
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _counts.transactionWrites++;
    return _inner.update(documentReference, data);
  }
}

class _CountingFirestore extends FakeFirebaseFirestore {
  final counts = _Counts();

  @override
  WriteBatch batch() => _CountingBatch(super.batch(), counts);
}

UnifiedShoppingItem _row(
  String id,
  String name, {
  String unit = 'st',
  bool bought = false,
}) => UnifiedShoppingItem(
  id: id,
  name: name,
  amount: 1,
  unit: unit,
  bought: bought,
);

UnifiedShoppingList _list(
  List<UnifiedShoppingItem> items, {
  List<String>? menuItemIds,
}) => UnifiedShoppingList(
  id: _listId,
  name: 'Inköpslista v.24',
  ownerId: _uid,
  ownerDisplayName: 'Test',
  items: items,
  generatedForWeek: _weekKey,
  menuItemIds: menuItemIds,
);

/// Rows the merge adds. Built once so every call returns the same ids, as the
/// request contract demands; a bought tick is carried by name and unit.
PersonalMergeRequest _request(
  List<UnifiedShoppingItem> fresh, {
  bool replace = false,
}) => PersonalMergeRequest(
  replace: replace,
  generatedForWeek: _weekKey,
  rows: (removed) {
    final bought = {
      for (final r in removed)
        if (r.bought) '${r.name}|${r.unit}',
    };
    return [
      for (final f in fresh)
        bought.contains('${f.name}|${f.unit}') ? f.copyWith(bought: true) : f,
    ];
  },
);

FirebaseException _offline() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

void main() {
  late _CountingFirestore firestore;
  late List<String> audit;

  CollectionReference<Map<String, dynamic>> lists() => firestore
      .collection(FirestoreCollections.users)
      .doc(_uid)
      .collection(FirestoreCollections.unifiedShoppingLists);

  CollectionReference<Map<String, dynamic>> rows() =>
      lists().doc(_listId).collection(FirestoreCollections.items);

  ShoppingPersonalMergeModule module({
    PersonalMergeTransactionRunner? transactionRunner,
    PersonalListServerRead? serverRead,
    bool pending = false,
  }) => ShoppingPersonalMergeModule(
    firestore: firestore,
    requireCurrentUserId: () => _uid,
    getUserCollection: (uid) => firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.unifiedShoppingLists),
    fromFirestore: UnifiedShoppingList.fromFirestore,
    validateOwnership:
        ({
          required String currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          required String resourceId,
        }) async {
          expect(resourceOwnerId, currentUserId);
        },
    logPermissionCheck:
        ({
          required String userId,
          required String resource,
          required String operation,
          required bool granted,
          String? details,
        }) async => audit.add(operation),
    transactionRunner:
        transactionRunner ??
        (handler) => firestore.runTransaction(
          (tx) => handler(_CountingTransaction(tx, firestore.counts)),
        ),
    serverRead: serverRead,
    pendingWrites: (_, _) async => pending,
  );

  /// Stores [list] as the server holds it: the parent document and one
  /// document per row in `items`.
  Future<void> seedServer(UnifiedShoppingList list) async {
    await lists().doc(_listId).set(list.toFirestore());
    for (final item in list.items) {
      await rows().doc(item.id).set(item.toFirestore());
    }
  }

  Future<Map<String, UnifiedShoppingItem>> storedRows() async => {
    for (final doc in (await rows().get()).docs)
      doc.id: UnifiedShoppingItem.fromFirestore(doc.data()),
  };

  Future<List<String>> storedMenuIds() async =>
      ((await lists().doc(_listId).get()).data()!['menuItemIds'] as List)
          .cast<String>();

  setUp(() {
    firestore = _CountingFirestore();
    audit = [];
  });

  group(
    'TR::FLOW::02::lägga-till::listan-ändrad-av-annan-person-samtidigt',
    () {
      test(
        'another device added a row and ran its own merge: every row stays, '
        'menuItemIds keeps theirs and ours, and the change is reported',
        () async {
          final own = _row('own', 'kaffe');
          final memory = _list([own], menuItemIds: const []);
          // The other device: "bröd" typed in, and a merge that put "x" there.
          await seedServer(
            _list(
              [own, _row('brod', 'bröd'), _row('x', 'ris')],
              menuItemIds: ['x'],
            ),
          );
          final ours = [_row('a', 'gul lök'), _row('b', 'mjölk', unit: 'dl')];

          final result = await module().applyPersonalMerge(
            memory,
            _request(ours),
          );

          expect(result.concurrentChange, isTrue);
          expect(
            (await storedRows()).keys,
            unorderedEquals(['own', 'brod', 'x', 'a', 'b']),
          );
          expect(await storedMenuIds(), unorderedEquals(['x', 'a', 'b']));
          expect(
            result.list.items.map((i) => i.id),
            containsAll(['brod', 'x']),
            reason: 'the view shows the other device\'s rows at once',
          );
          expect(result.list.menuItemIds, unorderedEquals(['x', 'a', 'b']));
          expect(audit, ['menu_merge']);
        },
      );

      test('nothing changed elsewhere: no change is reported', () async {
        final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
        await seedServer(memory);

        final result = await module().applyPersonalMerge(
          memory,
          _request([_row('a', 'gul lök')]),
        );

        expect(result.concurrentChange, isFalse);
        expect((await storedRows()).keys, unorderedEquals(['own', 'a']));
      });

      test(
        'Ersätt listan carries over a tick the other device made on a recipe '
        'row',
        () async {
          final memory = _list(
            [
              _row('own', 'kaffe'),
              _row('old', 'gul lök'),
            ],
            menuItemIds: ['old'],
          );
          await seedServer(
            _list(
              [
                _row('own', 'kaffe'),
                _row('old', 'gul lök', bought: true),
              ],
              menuItemIds: ['old'],
            ),
          );

          final result = await module().applyPersonalMerge(
            memory,
            _request([_row('new', 'gul lök')], replace: true),
          );

          final stored = await storedRows();
          expect(stored.keys, unorderedEquals(['own', 'new']));
          expect(stored['new']!.bought, isTrue);
          expect(await storedMenuIds(), ['new']);
          expect(result.removed.single.bought, isTrue);
          expect(result.concurrentChange, isTrue);
        },
      );

      test('Ersätt listan does not bring back a recipe row the other device '
          'deleted, and Ångra has nothing of it to restore', () async {
        final memory = _list(
          [
            _row('old-1', 'gul lök'),
            _row('old-2', 'pasta'),
          ],
          menuItemIds: ['old-1', 'old-2'],
        );
        // The other device deleted "pasta"; menuItemIds still names it.
        await seedServer(
          _list([_row('old-1', 'gul lök')], menuItemIds: ['old-1', 'old-2']),
        );

        final result = await module().applyPersonalMerge(
          memory,
          _request([_row('new', 'mjölk')], replace: true),
        );

        expect((await storedRows()).keys, ['new']);
        expect(result.removed.map((i) => i.id), ['old-1']);
        expect(result.list.items.map((i) => i.id), ['new']);
      });

      test('offline: the rows are queued from memory, nothing is reported, and '
          'menuItemIds is extended with arrayUnion, not overwritten', () async {
        final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
        // What the server holds that this device never saw.
        await seedServer(
          _list([_row('own', 'kaffe'), _row('x', 'ris')], menuItemIds: ['x']),
        );

        final result = await module(
          serverRead: (_, _) async => throw _offline(),
        ).applyPersonalMerge(memory, _request([_row('a', 'gul lök')]));
        await pumpEventQueue();

        expect(result.concurrentChange, isFalse);
        expect((await storedRows()).keys, unorderedEquals(['own', 'x', 'a']));
        expect(await storedMenuIds(), unorderedEquals(['x', 'a']));
        expect(result.list.items.map((i) => i.id), ['own', 'a']);
      });

      test('offline Ersätt listan replaces from memory (accepted deviation, '
          'B1)', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('old', 'gul lök', bought: true),
          ],
          menuItemIds: ['old'],
        );
        await seedServer(memory);

        final result =
            await module(
              transactionRunner: (_) async => throw _offline(),
            ).applyPersonalMerge(
              memory,
              _request([_row('new', 'gul lök')], replace: true),
            );
        await pumpEventQueue();

        final stored = await storedRows();
        expect(stored.keys, unorderedEquals(['own', 'new']));
        expect(stored['new']!.bought, isTrue);
        expect(await storedMenuIds(), ['new']);
        expect(result.concurrentChange, isFalse);
      });

      test('writes of this device still waiting to sync are not reported as '
          'another device\'s change', () async {
        final memory = _list([
          _row('own', 'kaffe'),
          _row('unsynced', 'te'),
        ], menuItemIds: const []);
        await seedServer(_list([_row('own', 'kaffe')], menuItemIds: const []));

        final result = await module(
          pending: true,
        ).applyPersonalMerge(memory, _request([_row('a', 'gul lök')]));

        expect(result.concurrentChange, isFalse);
      });

      test('Ångra after a change elsewhere takes off only our rows and our '
          'ids', () async {
        final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
        await seedServer(
          _list([_row('own', 'kaffe'), _row('x', 'ris')], menuItemIds: ['x']),
        );
        final merge = module();
        final result = await merge.applyPersonalMerge(
          memory,
          _request([_row('a', 'gul lök'), _row('b', 'pasta')]),
        );

        final undone = await merge.undoPersonalMerge(
          result.list,
          addedIds: ['a', 'b'],
          restore: result.removed,
        );

        expect((await storedRows()).keys, unorderedEquals(['own', 'x']));
        expect(await storedMenuIds(), ['x']);
        expect(undone.items.map((i) => i.id), unorderedEquals(['own', 'x']));
        expect(undone.menuItemIds, ['x']);
      });

      test('Ångra after Ersätt listan puts the server\'s removed rows back and '
          'takes ours off', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('old', 'gul lök'),
          ],
          menuItemIds: ['old'],
        );
        await seedServer(memory);
        final merge = module();
        final result = await merge.applyPersonalMerge(
          memory,
          _request([_row('new', 'gul lök')], replace: true),
        );

        await merge.undoPersonalMerge(
          result.list,
          addedIds: ['new'],
          restore: result.removed,
        );

        expect((await storedRows()).keys, unorderedEquals(['own', 'old']));
        expect(await storedMenuIds(), ['old']);
      });
    },
  );

  group('cost (BUT-2140 acceptance: N+R+2 writes at most)', () {
    test('an add writes N rows and one narrow parent update, in no '
        'transaction', () async {
      final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
      await seedServer(memory);
      firestore.counts.batchWrites = 0;

      await module().applyPersonalMerge(
        memory,
        _request([_row('a', 'gul lök'), _row('b', 'pasta')]),
      );

      expect(firestore.counts.batchWrites, 2 + 1);
      expect(firestore.counts.transactionReads, 0);
      expect(firestore.counts.transactionWrites, 0);
    });

    test('a replace reads the parent and the R recipe rows in its '
        'transaction and writes R deletes, N rows and the parent', () async {
      final memory = _list(
        [
          _row('own', 'kaffe'),
          _row('old-1', 'gul lök'),
          _row('old-2', 'pasta'),
        ],
        menuItemIds: ['old-1', 'old-2'],
      );
      await seedServer(memory);
      firestore.counts.batchWrites = 0;

      await module().applyPersonalMerge(
        memory,
        _request([_row('new', 'mjölk')], replace: true),
      );

      expect(firestore.counts.transactionReads, 1 + 2);
      expect(firestore.counts.transactionWrites, 2 + 1 + 1);
      expect(firestore.counts.batchWrites, 0);
    });
  });
}
