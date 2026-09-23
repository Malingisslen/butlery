/// Unit tests for FirebasePantryRepository.
///
/// Pure-Dart; uses FakeFirebaseFirestore.
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

  // P5-U28: per field, the latest change wins (produktregler.md:105, :142).
  group('updateFields', () {
    Future<Map<String, dynamic>?> read(
      FakeFirebaseFirestore f,
      String id,
    ) async =>
        (await f
                .collection('users')
                .doc(_alice)
                .collection('pantry')
                .doc(id)
                .get())
            .data();

    test(
      'writes only the changed fields plus updatedAt and updatedBy',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        final base = _item(id: 'i1', name: 'Original', qty: 3);
        await repo.add(_alice, base);

        await repo.updateFields(
          _alice,
          'i1',
          base.copyWith(ingredientName: 'Updated').changesFrom(base),
        );

        final data = await read(firestore, 'i1');
        expect(data?['ingredientName'], 'Updated');
        expect(data?['quantity'], 3);
        expect(data?['updatedBy'], _alice);
        expect(data?['updatedAt'], isNotNull);
      },
    );

    test(
      'two devices changing different fields of one row keep both',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        final base = _item(id: 'i1', name: 'Mjölk', qty: 2);
        await repo.add(_alice, base);

        // Both devices start from the same row.
        final phone = base.copyWith(note: 'laktosfri');
        final tablet = base.copyWith(location: PantryLocation.freezer);
        await repo.updateFields(_alice, 'i1', phone.changesFrom(base));
        await repo.updateFields(_alice, 'i1', tablet.changesFrom(base));

        final data = await read(firestore, 'i1');
        expect(data?['note'], 'laktosfri');
        expect(data?['location'], 'freezer');
        expect(data?['ingredientName'], 'Mjölk');
      },
    );

    test('an unknown amount never wipes a known one', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final base = _item(id: 'i1', qty: 3);
      await repo.add(_alice, base);

      final hasSome = base.copyWith(clearQuantity: true, note: 'har hemma');
      await repo.updateFields(_alice, 'i1', hasSome.changesFrom(base));

      expect((await read(firestore, 'i1'))?['quantity'], 3);
    });

    test('no change writes nothing, not even a timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final base = _item(id: 'i1');
      await repo.add(_alice, base);

      await repo.updateFields(_alice, 'i1', base.changesFrom(base));

      expect((await read(firestore, 'i1'))?.containsKey('updatedAt'), isFalse);
    });
  });

  group('adjustQuantity', () {
    test('two partial tick-offs of 2 from 6 leave 2, not 4', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(_alice, _item(id: 'i1', qty: 6));

      // "Bocka av 2 av 6" from two devices (produktregler.md:146).
      await repo.adjustQuantity(_alice, 'i1', -2);
      await repo.adjustQuantity(_alice, 'i1', -2);

      final data =
          (await firestore
                  .collection('users')
                  .doc(_alice)
                  .collection('pantry')
                  .doc('i1')
                  .get())
              .data();
      expect(data?['quantity'], 2);
      expect(data?['updatedBy'], _alice);
    });
  });

  group('nullable quantity', () {
    test('an item without an amount is stored, read back and exported as '
        'null', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.add(
        _alice,
        _item(id: 'i1', name: 'Salt').copyWith(clearQuantity: true),
      );

      final item = (await repo.getAll(_alice)).single;
      expect(item.quantity, isNull);
      expect(item.formattedQuantity, isEmpty);

      final exported = await repo.exportAllByUser(_alice);
      final data = exported.single['data'] as Map<String, dynamic>;
      expect(data.containsKey('quantity'), isTrue);
      expect(data['quantity'], isNull);
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
