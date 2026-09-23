// P5-U28: skafferi CONFLICT, part A — per-field writes, a nullable quantity,
// and the row's timestamp (produktregler.md:105, :142-148).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';

PantryItem _item({double? quantity = 2, String? note}) => PantryItem(
  id: 'p1',
  ingredientId: 'ing-milk',
  ingredientName: 'Mjölk',
  quantity: quantity,
  unit: 'l',
  location: PantryLocation.fridge,
  addedAt: DateTime.utc(2026, 1, 1),
  expiryDate: DateTime.utc(2026, 2, 1),
  note: note,
);

void main() {
  group('changesFrom', () {
    test('holds only the fields that changed', () {
      final before = _item();
      final after = before.copyWith(
        ingredientName: 'Havremjölk',
        location: PantryLocation.pantry,
      );

      expect(after.changesFrom(before), {
        'ingredientName': 'Havremjölk',
        'location': 'pantry',
      });
    });

    test('is empty when nothing changed', () {
      expect(_item().changesFrom(_item()), isEmpty);
    });

    test('a null quantity never replaces a known amount (§ 2.2)', () {
      final before = _item(quantity: 3);
      final after = before.copyWith(clearQuantity: true);

      expect(after.changesFrom(before), isNot(contains('quantity')));
    });

    test('a known amount replaces an unknown one', () {
      final before = _item(quantity: null);
      final after = before.copyWith(quantity: 4);

      expect(after.changesFrom(before), {'quantity': 4.0});
    });

    test('a cleared optional field is deleted, not left behind', () {
      final before = _item(note: 'öppnad');
      final after = before.copyWith(clearNote: true, clearExpiryDate: true);

      final changes = after.changesFrom(before);
      expect(changes['note'], isA<FieldValue>());
      expect(changes['expiryDate'], isA<FieldValue>());
    });

    test('never carries updatedAt or updatedBy', () {
      final before = _item();
      final after = before.copyWith(
        note: 'x',
        updatedAt: DateTime.utc(2026, 3, 1),
        updatedBy: 'someone',
      );

      expect(after.changesFrom(before).keys, ['note']);
    });
  });

  group('editableFields', () {
    test('leaves out a null quantity so it cannot wipe a stored one', () {
      final fields = _item(quantity: null).editableFields();

      expect(fields, isNot(contains('quantity')));
      expect(fields['ingredientName'], 'Mjölk');
    });
  });

  group('serialization', () {
    test('a stored null quantity reads back as null, not 0', () {
      final item = PantryItem.fromMap({
        'ingredientName': 'Salt',
        'quantity': null,
        'unit': 'st',
        'location': 'spiceRack',
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      }, 'p1');

      expect(item.quantity, isNull);
      expect(item.formattedQuantity, isEmpty);
    });

    test('toFirestore writes a null quantity as a value', () {
      final map = _item(quantity: null).toFirestore();

      expect(map.containsKey('quantity'), isTrue);
      expect(map['quantity'], isNull);
    });

    test('reads updatedAt and updatedBy', () {
      final item = PantryItem.fromMap({
        'ingredientName': 'Salt',
        'quantity': 1,
        'unit': 'st',
        'location': 'spiceRack',
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2, 9)),
        'updatedBy': 'u1',
      }, 'p1');

      expect(item.updatedAt?.toUtc(), DateTime.utc(2026, 1, 2, 9));
      expect(item.updatedBy, 'u1');
    });
  });
}
