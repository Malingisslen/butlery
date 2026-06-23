/// Unit tests for FirebasePantryRepository.
///
/// Pure-Dart; uses FakeFirebaseFirestore. Targets ~52 unhit lines in
/// lib/repositories/firebase/firebase_pantry_repository.dart.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';

const _alice = 'user-alice';

FirebasePantryRepository _repo(FakeFirebaseFirestore firestore) {
  return FirebasePantryRepository(firestore: firestore);
}

PantryItem _item({
  String id = '',
  String? ingredientId,
  String name = 'Mjölk',
  double qty = 1.0,
  String unit = 'l',
  PantryLocation location = PantryLocation.fridge,
  DateTime? expiry,
  DateTime? addedAt,
}) {
  return PantryItem(
    id: id,
    ingredientId: ingredientId,
    ingredientName: name,
    quantity: qty,
    unit: unit,
    location: location,
    expiryDate: expiry,
    addedAt: addedAt ?? DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('add', () {
    test('auto-assigns id when empty', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final id = await repo.add(_alice, _item(name: 'Bröd'));

      expect(id, isNotEmpty);
      final doc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('pantry')
          .doc(id)
          .get();
      expect(doc.data()?['ingredientName'], 'Bröd');
    });

    test('uses provided id when set', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final id = await repo.add(_alice, _item(id: 'my-id', name: 'Smör'));

      expect(id, 'my-id');
    });
  });

  group('update', () {
    test('overwrites existing item', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final id = await repo.add(_alice, _item(id: 'i1', name: 'Original'));

      await repo.update(_alice, _item(id: id, name: 'Updated', qty: 5.0));

      final doc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('pantry')
          .doc(id)
          .get();
      expect(doc.data()?['ingredientName'], 'Updated');
      expect(doc.data()?['quantity'], 5.0);
    });
  });

  group('remove', () {
    test('deletes the doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1'));

      await repo.remove(_alice, 'i1');

      final doc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('pantry')
          .doc('i1')
          .get();
      expect(doc.exists, isFalse);
    });
  });

  group('getAll', () {
    test('returns all items for user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1', name: 'A'));
      await repo.add(_alice, _item(id: 'i2', name: 'B'));

      final items = await repo.getAll(_alice);

      expect(items.map((i) => i.id).toSet(), {'i1', 'i2'});
    });

    test('returns empty when no items', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.getAll(_alice), isEmpty);
    });
  });

  group('watchAll', () {
    test('emits current items as stream', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1', name: 'A'));

      final first = await repo.watchAll(_alice).first;
      expect(first.length, 1);
      expect(first.first.id, 'i1');
    });
  });

  group('getByIngredientId', () {
    test('returns matching item', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(
        _alice,
        _item(id: 'i1', ingredientId: 'ing-mjolk', name: 'Mjölk'),
      );

      final got = await repo.getByIngredientId(_alice, 'ing-mjolk');
      expect(got, isNotNull);
      expect(got!.id, 'i1');
    });

    test('returns null when no match', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(ingredientId: 'ing-other'));

      expect(await repo.getByIngredientId(_alice, 'ing-mjolk'), isNull);
    });
  });

  group('getExpiringSoon', () {
    test('returns items expiring before cutoff', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () async {
        // Expires in 3 days — within 7-day cutoff.
        await repo.add(
          _alice,
          _item(id: 'i1', expiry: DateTime.utc(2026, 1, 4), name: 'Soon'),
        );
        // Expires in 30 days — outside 7-day cutoff.
        await repo.add(
          _alice,
          _item(id: 'i2', expiry: DateTime.utc(2026, 2, 1), name: 'Later'),
        );

        final expiring = await repo.getExpiringSoon(_alice, 7);
        expect(expiring.map((i) => i.id), ['i1']);
      });
    });

    test('returns empty when no items expiring', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.getExpiringSoon(_alice, 7), isEmpty);
    });
  });

  group('exportAllByUser', () {
    test('returns items as id+data maps', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1', name: 'Mjölk'));
      await repo.add(_alice, _item(id: 'i2', name: 'Bröd'));

      final export = await repo.exportAllByUser(_alice);
      expect(export.length, 2);
      expect(export.first.containsKey('id'), isTrue);
      expect(export.first.containsKey('data'), isTrue);
    });

    test('respects maxDocuments limit', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      for (var i = 0; i < 5; i++) {
        await repo.add(_alice, _item(id: 'i$i', name: 'Item$i'));
      }

      final export = await repo.exportAllByUser(_alice, maxDocuments: 3);
      expect(export.length, 3);
    });
  });

  group('deleteAll', () {
    test('removes all items for user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1'));
      await repo.add(_alice, _item(id: 'i2'));
      await repo.add(_alice, _item(id: 'i3'));

      await repo.deleteAll(_alice);

      expect(await repo.getAll(_alice), isEmpty);
    });

    test('no-op when no items', () async {
      final repo = _repo(FakeFirebaseFirestore());
      await repo.deleteAll(_alice);
    });
  });
}
