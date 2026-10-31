/// BUT-2140: the week menu's merge into a personal list, written per operation
/// against the server's copy (`lägga till` → the
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

import 'dart:async';

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

/// A merge that only adds [fresh]. Built once so every call returns the same
/// ids, as the request contract demands.
PersonalMergeRequest _request(List<UnifiedShoppingItem> fresh) =>
    PersonalMergeRequest(
      generatedForWeek: _weekKey,
      sync: (_) => PersonalMergeWrite(add: fresh),
    );

PersonalMergeRequest _syncRequest(
  PersonalMergeWrite Function(List<UnifiedShoppingItem> listRows) sync,
) => PersonalMergeRequest(generatedForWeek: _weekKey, sync: sync);

FirebaseException _offline() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

/// A transaction whose every call fails as an unreachable server does.
class _UnreachableTransaction extends Fake implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw _offline();
}

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

      test('a sync decides on the server\'s row, so a tick the other device '
          'made a moment ago keeps the row where it is', () async {
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
        List<UnifiedShoppingItem>? seen;

        final result = await module().applyPersonalMerge(
          memory,
          _syncRequest((listRows) {
            seen = listRows;
            return PersonalMergeWrite(
              remove: [
                for (final r in listRows)
                  if (!r.bought) r,
              ],
            );
          }),
        );

        expect(seen!.single.bought, isTrue);
        expect((await storedRows()).keys, unorderedEquals(['own', 'old']));
        expect(await storedMenuIds(), ['old']);
        expect(result.removed, isEmpty);
        expect(result.concurrentChange, isTrue);
      });

      test('a sync is not shown a row the other device deleted, and Ångra has '
          'nothing of it to restore', () async {
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
          _syncRequest(
            (listRows) => PersonalMergeWrite(
              remove: listRows,
              add: [_row('new', 'mjölk')],
            ),
          ),
        );

        expect((await storedRows()).keys, ['new']);
        expect(result.removed.map((i) => i.id), ['old-1']);
        expect(result.list.items.map((i) => i.id), ['new']);
      });

      test(
        'one transaction updates, removes and adds: the stored rows and '
        'menuItemIds follow, and changedFrom holds the row as it was',
        () async {
          final memory = _list(
            [
              _row('own', 'kaffe'),
              _row('upd', 'gul lök'),
              _row('rem', 'pasta'),
            ],
            menuItemIds: ['upd', 'rem'],
          );
          await seedServer(memory);
          firestore.counts.transactionReads = 0;
          final changed = _row('upd', 'gul lök').copyWith(amount: 3);

          final result = await module().applyPersonalMerge(
            memory,
            _syncRequest(
              (listRows) => PersonalMergeWrite(
                update: [changed],
                remove: [listRows.firstWhere((r) => r.id == 'rem')],
                add: [_row('new', 'mjölk')],
              ),
            ),
          );

          final stored = await storedRows();
          expect(stored.keys, unorderedEquals(['own', 'upd', 'new']));
          expect(stored['upd']!.amount, 3);
          expect(await storedMenuIds(), unorderedEquals(['upd', 'new']));
          expect(result.updated.single.amount, 3);
          expect(result.changedFrom.single.id, 'upd');
          expect(result.changedFrom.single.amount, 1);
          expect(result.removed.single.id, 'rem');
          expect(result.added.single.id, 'new');
          expect(
            result.list.items.firstWhere((i) => i.id == 'upd').amount,
            3,
          );
          expect(result.list.menuItemIds, unorderedEquals(['upd', 'new']));
          expect(firestore.counts.transactionReads, 1 + 2);
          expect(firestore.counts.transactionWrites, 1 + 2 + 1);
          expect(firestore.counts.batchWrites, 0);
        },
      );

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

      test('offline sync updates, removes and adds from memory (accepted '
          'deviation, B1)', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('upd', 'gul lök'),
            _row('rem', 'pasta'),
          ],
          menuItemIds: ['upd', 'rem'],
        );
        await seedServer(memory);
        final changed = _row('upd', 'gul lök').copyWith(amount: 3);

        final result =
            await module(
              transactionRunner: (_) async => throw _offline(),
            ).applyPersonalMerge(
              memory,
              _syncRequest(
                (listRows) => PersonalMergeWrite(
                  update: [changed],
                  remove: [listRows.firstWhere((r) => r.id == 'rem')],
                  add: [_row('new', 'mjölk')],
                ),
              ),
            );
        await pumpEventQueue();

        final stored = await storedRows();
        expect(stored.keys, unorderedEquals(['own', 'upd', 'new']));
        expect(stored['upd']!.amount, 3);
        expect(await storedMenuIds(), unorderedEquals(['upd', 'new']));
        expect(result.changedFrom.single.amount, 1);
        expect(result.concurrentChange, isFalse);
      });

      test('a sync cannot overwrite or take off a row the list does not name '
          'in menuItemIds', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('menu', 'gul lök'),
          ],
          menuItemIds: ['menu'],
        );
        await seedServer(memory);

        final result = await module().applyPersonalMerge(
          memory,
          _syncRequest(
            (_) => PersonalMergeWrite(
              update: [_row('own', 'kaffe').copyWith(amount: 9)],
              remove: [_row('own', 'kaffe')],
            ),
          ),
        );

        final stored = await storedRows();
        expect(stored.keys, unorderedEquals(['own', 'menu']));
        expect(stored['own']!.amount, _row('own', 'kaffe').amount);
        expect(result.updated, isEmpty);
        expect(result.removed, isEmpty);
        expect(await storedMenuIds(), ['menu']);
      });

      test('offline also syncs from memory when the platform hides the '
          'handler error (web)', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('old', 'gul lök'),
          ],
          menuItemIds: ['old'],
        );
        await seedServer(memory);

        await module(
          transactionRunner: (handler) async {
            try {
              await handler(_UnreachableTransaction());
            } catch (_) {}
            throw StateError('the web wrapper');
          },
        ).applyPersonalMerge(
          memory,
          _syncRequest(
            (_) => PersonalMergeWrite(
              remove: [_row('old', 'gul lök')],
              add: [_row('new', 'gul lök')],
            ),
          ),
        );
        await pumpEventQueue();

        expect(await storedMenuIds(), ['new']);
      });

      test('a spent transaction budget is treated as offline: the sync is '
          'written from memory', () async {
        final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
        await seedServer(memory);

        final result = await module(
          transactionRunner: (_) async => throw TimeoutException('the budget'),
        ).applyPersonalMerge(memory, _request([_row('a', 'gul lök')]));
        await pumpEventQueue();

        expect(result.added.map((i) => i.id), ['a']);
        expect((await storedRows()).keys, unorderedEquals(['own', 'a']));
      });

      test(
        'a rejection that is not offline still reaches the caller',
        () async {
          final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
          await seedServer(memory);

          await expectLater(
            module(
              transactionRunner: (_) async => throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              ),
            ).applyPersonalMerge(memory, _request([_row('a', 'gul lök')])),
            throwsA(
              isA<FirebaseException>().having(
                (e) => e.code,
                'code',
                'permission-denied',
              ),
            ),
          );
          expect((await storedRows()).keys, ['own']);
        },
      );

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

      test('Ångra after a sync puts the removed and the overwritten rows back '
          'and takes the added ones off', () async {
        final memory = _list(
          [
            _row('own', 'kaffe'),
            _row('upd', 'gul lök'),
            _row('rem', 'pasta'),
          ],
          menuItemIds: ['upd', 'rem'],
        );
        await seedServer(memory);
        final merge = module();
        final result = await merge.applyPersonalMerge(
          memory,
          _syncRequest(
            (listRows) => PersonalMergeWrite(
              update: [_row('upd', 'gul lök').copyWith(amount: 3)],
              remove: [listRows.firstWhere((r) => r.id == 'rem')],
              add: [_row('new', 'mjölk')],
            ),
          ),
        );

        await merge.undoPersonalMerge(
          result.list,
          addedIds: ['new'],
          restore: [...result.removed, ...result.changedFrom],
        );

        final stored = await storedRows();
        expect(stored.keys, unorderedEquals(['own', 'upd', 'rem']));
        expect(stored['upd']!.amount, 1);
        expect(await storedMenuIds(), unorderedEquals(['upd', 'rem']));
      });
    },
  );

  group('a sync the server copy already settles costs no transaction', () {
    var transactionRuns = 0;

    PersonalMergeTransactionRunner countedRunner() => (handler) {
      transactionRuns++;
      return firestore.runTransaction(
        (tx) => handler(_CountingTransaction(tx, firestore.counts)),
      );
    };

    setUp(() => transactionRuns = 0);

    test('nothing to change: the transaction never runs, the server list is '
        'returned and the change made elsewhere is still reported', () async {
      final memory = _list([_row('own', 'kaffe')], menuItemIds: ['old']);
      await seedServer(
        _list(
          [_row('own', 'kaffe'), _row('old', 'pasta'), _row('brod', 'bröd')],
          menuItemIds: ['old'],
        ),
      );

      final result =
          await module(
            transactionRunner: countedRunner(),
          ).applyPersonalMerge(
            memory,
            _syncRequest((_) => const PersonalMergeWrite()),
          );

      expect(transactionRuns, 0);
      expect(firestore.counts.transactionReads, 0);
      expect(audit, ['menu_merge'], reason: 'the permission log still runs');
      expect(result.added, isEmpty);
      expect(result.removed, isEmpty);
      expect(result.updated, isEmpty);
      expect(result.concurrentChange, isTrue);
      expect(
        result.list.items.map((i) => i.id),
        unorderedEquals(['own', 'old', 'brod']),
        reason: 'the view gets the server rows, including the other device\'s',
      );
      expect(result.list.menuItemIds, ['old']);
      expect(
        (await storedRows()).keys,
        unorderedEquals(['own', 'old', 'brod']),
      );
    });

    test('nothing to change while this device\'s own writes wait to sync: '
        'no change is reported', () async {
      final memory = _list([_row('own', 'kaffe')], menuItemIds: ['old']);
      await seedServer(
        _list(
          [_row('own', 'kaffe'), _row('old', 'pasta')],
          menuItemIds: ['old'],
        ),
      );

      final result =
          await module(
            transactionRunner: countedRunner(),
            pending: true,
          ).applyPersonalMerge(
            memory,
            _syncRequest((_) => const PersonalMergeWrite()),
          );

      expect(transactionRuns, 0);
      expect(audit, ['menu_merge']);
      expect(result.concurrentChange, isFalse);
    });

    test('a sync that only touches rows outside menuItemIds changes nothing '
        'and costs no transaction', () async {
      final memory = _list(
        [_row('own', 'kaffe'), _row('old', 'pasta')],
        menuItemIds: ['old'],
      );
      await seedServer(memory);

      final result =
          await module(
            transactionRunner: countedRunner(),
          ).applyPersonalMerge(
            memory,
            _syncRequest(
              (_) => PersonalMergeWrite(
                update: [_row('own', 'kaffe').copyWith(amount: 9)],
                remove: [_row('own', 'kaffe')],
              ),
            ),
          );

      expect(transactionRuns, 0);
      expect(audit, ['menu_merge']);
      expect(result.updated, isEmpty);
      expect(result.removed, isEmpty);
      expect((await storedRows())['own']!.amount, 1);
    });

    test('a server copy that looked changed but is clean when the transaction '
        'reads it writes nothing', () async {
      final own = _row('own', 'kaffe');
      final old = _row('old', 'pasta');
      final memory = _list([own, old], menuItemIds: ['old']);
      // What is stored needs nothing; the copy read first still names a dead
      // id, as it would if another device had cleaned it up in between.
      await seedServer(memory);
      firestore.counts.transactionWrites = 0;

      final result =
          await module(
            transactionRunner: countedRunner(),
            serverRead: (_, _) async =>
                _list([own, old], menuItemIds: ['old', 'gone']),
          ).applyPersonalMerge(
            memory,
            _syncRequest((_) => const PersonalMergeWrite()),
          );

      expect(transactionRuns, 1);
      expect(firestore.counts.transactionWrites, 0);
      expect(result.added, isEmpty);
      expect(result.removed, isEmpty);
      expect(await storedMenuIds(), ['old']);
    });

    test('a sync that changes a row still runs exactly one transaction and '
        'stores the change', () async {
      final memory = _list(
        [_row('own', 'kaffe'), _row('old', 'pasta')],
        menuItemIds: ['old'],
      );
      await seedServer(memory);

      final result =
          await module(
            transactionRunner: countedRunner(),
          ).applyPersonalMerge(
            memory,
            _syncRequest(
              (_) => PersonalMergeWrite(
                update: [_row('old', 'pasta').copyWith(amount: 3)],
              ),
            ),
          );

      expect(transactionRuns, 1);
      expect(result.updated.single.amount, 3);
      expect((await storedRows())['old']!.amount, 3);
    });

    test('a sync whose only difference is the week still runs the '
        'transaction and stores the new week', () async {
      final memory = _list([_row('old', 'pasta')], menuItemIds: ['old']);
      await seedServer(memory);

      final result =
          await module(
            transactionRunner: countedRunner(),
          ).applyPersonalMerge(
            memory,
            PersonalMergeRequest(
              generatedForWeek: '2026-W25',
              sync: (_) => const PersonalMergeWrite(),
            ),
          );

      expect(transactionRuns, 1);
      expect(result.list.generatedForWeek, '2026-W25');
      expect(
        (await lists().doc(_listId).get()).data()!['generatedForWeek'],
        '2026-W25',
      );
    });

    test('a menuItemIds naming a row that no longer exists still runs the '
        'transaction, which drops the dead id', () async {
      final memory = _list(
        [_row('own', 'kaffe'), _row('old', 'pasta')],
        menuItemIds: ['old', 'gone'],
      );
      await seedServer(memory);

      final result =
          await module(
            transactionRunner: countedRunner(),
          ).applyPersonalMerge(
            memory,
            _syncRequest((_) => const PersonalMergeWrite()),
          );

      expect(transactionRuns, 1);
      expect(await storedMenuIds(), ['old']);
      expect(result.added, isEmpty);
    });
  });

  group('cost (BUT-2140 acceptance: N+R+2 writes at most)', () {
    test('an add reads the parent, writes N rows and one parent update, all '
        'in one transaction', () async {
      final memory = _list([_row('own', 'kaffe')], menuItemIds: const []);
      await seedServer(memory);
      firestore.counts.transactionReads = 0;
      firestore.counts.transactionWrites = 0;

      await module().applyPersonalMerge(
        memory,
        _request([_row('a', 'gul lök'), _row('b', 'pasta')]),
      );

      expect(firestore.counts.transactionReads, 1);
      expect(firestore.counts.transactionWrites, 2 + 1);
      expect(firestore.counts.batchWrites, 0);
    });

    test('a sync with nothing to change writes nothing', () async {
      final memory = _list(
        [_row('own', 'kaffe'), _row('old', 'pasta')],
        menuItemIds: ['old'],
      );
      await seedServer(memory);
      firestore.counts.transactionWrites = 0;

      await module().applyPersonalMerge(
        memory,
        _syncRequest((_) => const PersonalMergeWrite()),
      );

      expect(firestore.counts.transactionWrites, 0);
      expect((await storedRows()).keys, unorderedEquals(['own', 'old']));
    });

    test('offline, a sync with nothing to change queues no write', () async {
      final memory = _list(
        [_row('own', 'kaffe'), _row('old', 'pasta')],
        menuItemIds: ['old'],
      );
      await seedServer(memory);

      final result =
          await module(
            serverRead: (_, _) async => throw _offline(),
          ).applyPersonalMerge(
            memory,
            _syncRequest((_) => const PersonalMergeWrite()),
          );
      await pumpEventQueue();

      expect(firestore.counts.batchWrites, 0);
      expect(result.added, isEmpty);
      expect(result.removed, isEmpty);
      expect(result.updated, isEmpty);
      expect((await storedRows()).keys, unorderedEquals(['own', 'old']));
      expect(await storedMenuIds(), ['old']);
    });

    test('a sync with nothing to change still drops the id of a row deleted '
        'elsewhere', () async {
      final memory = _list([_row('own', 'kaffe')], menuItemIds: ['gone']);
      await seedServer(memory);
      firestore.counts.transactionWrites = 0;

      await module().applyPersonalMerge(
        memory,
        _syncRequest((_) => const PersonalMergeWrite()),
      );

      expect(firestore.counts.transactionWrites, 1);
      expect(await storedMenuIds(), isEmpty);
    });
  });
}
