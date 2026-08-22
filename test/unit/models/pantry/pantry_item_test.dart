/// Unit tests for PantryItem + PantryLocation + PantryExpiryStatus.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';

PantryItem _item({
  String id = 'p1',
  String? ingredientId,
  String ingredientName = 'Mjölk',
  double quantity = 1.0,
  String unit = 'l',
  PantryLocation location = PantryLocation.fridge,
  DateTime? expiryDate,
  DateTime? addedAt,
  String? note,
  bool isStaple = false,
}) {
  return PantryItem(
    id: id,
    ingredientId: ingredientId,
    ingredientName: ingredientName,
    quantity: quantity,
    unit: unit,
    location: location,
    expiryDate: expiryDate,
    addedAt: addedAt ?? DateTime.utc(2026, 1, 1),
    note: note,
    isStaple: isStaple,
  );
}

void main() {
  group('PantryLocation.fromTypicalStorage', () {
    test('"refrigerated" → fridge', () {
      expect(
        PantryLocation.fromTypicalStorage('refrigerated'),
        PantryLocation.fridge,
      );
    });

    test('"frozen" → freezer', () {
      expect(
        PantryLocation.fromTypicalStorage('frozen'),
        PantryLocation.freezer,
      );
    });

    test('"ambient" → pantry', () {
      expect(
        PantryLocation.fromTypicalStorage('ambient'),
        PantryLocation.pantry,
      );
    });

    test('null / unknown → pantry (default fallback)', () {
      expect(PantryLocation.fromTypicalStorage(null), PantryLocation.pantry);
      expect(
        PantryLocation.fromTypicalStorage('something-new'),
        PantryLocation.pantry,
      );
    });
  });

  group('serialization', () {
    test('toFirestore omits ingredientId / expiryDate / note when null', () {
      final payload = _item().toFirestore();
      expect(payload.containsKey('ingredientId'), isFalse);
      expect(payload.containsKey('expiryDate'), isFalse);
      expect(payload.containsKey('note'), isFalse);
      expect(payload['location'], 'fridge');
    });

    test('toFirestore includes all optional fields when set', () {
      final payload = _item(
        ingredientId: 'ing-1',
        expiryDate: DateTime.utc(2026, 2, 1),
        note: 'organic',
      ).toFirestore();
      expect(payload['ingredientId'], 'ing-1');
      expect(payload['expiryDate'], isA<Timestamp>());
      expect(payload['note'], 'organic');
    });

    test('fromFirestore round-trips via fake firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final original = _item(
        ingredientId: 'ing-1',
        ingredientName: 'Bröd',
        quantity: 2.0,
        unit: 'st',
        location: PantryLocation.pantry,
        expiryDate: DateTime.utc(2026, 2, 1),
        note: 'butik',
      );
      await firestore
          .collection('pantry')
          .doc(original.id)
          .set(original.toFirestore());
      final doc = await firestore.collection('pantry').doc(original.id).get();
      final restored = PantryItem.fromFirestore(doc);

      expect(restored.id, original.id);
      expect(restored.ingredientId, 'ing-1');
      expect(restored.ingredientName, 'Bröd');
      expect(restored.quantity, 2.0);
      expect(restored.unit, 'st');
      expect(restored.location, PantryLocation.pantry);
      expect(restored.expiryDate!.toUtc(), DateTime.utc(2026, 2, 1));
      expect(restored.note, 'butik');
    });

    // BUT-1279: isStaple is the flag the menu→shopping generator reads to
    // keep pantry staples (salt, olja) off the generated list. Its
    // persistence must round-trip, and the "omit when false" write keeps the
    // common case from bloating every pantry document.
    test('toFirestore omits isStaple when false', () {
      expect(
        _item().toFirestore().containsKey('isStaple'),
        isFalse,
        reason: 'the default (non-staple) case must not write the field',
      );
    });

    test('toFirestore writes isStaple: true when set', () {
      expect(_item(isStaple: true).toFirestore()['isStaple'], true);
    });

    test('fromMap defaults isStaple to false when absent (legacy docs)', () {
      // Intent: pantry items written before BUT-1279 have no isStaple field —
      // they must read back as non-staples, never crash or default to true.
      final p = PantryItem.fromMap({
        'ingredientName': 'X',
        'quantity': 1,
        'unit': 'st',
        'location': 'pantry',
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      }, 'p');
      expect(p.isStaple, isFalse);
    });

    test('isStaple round-trips through firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final original = _item(isStaple: true);
      await firestore
          .collection('pantry')
          .doc(original.id)
          .set(original.toFirestore());
      final doc = await firestore.collection('pantry').doc(original.id).get();
      expect(PantryItem.fromFirestore(doc).isStaple, isTrue);
    });

    test('fromMap unknown location → pantry (default)', () {
      final p = PantryItem.fromMap({
        'ingredientName': 'X',
        'quantity': 1,
        'unit': 'st',
        'location': 'spaceStation', // not a valid enum
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      }, 'p');
      expect(p.location, PantryLocation.pantry);
    });
  });

  group('formattedQuantity', () {
    test('integer values render without decimal', () {
      expect(_item(quantity: 3.0).formattedQuantity, '3');
    });

    // BUT-1910: the separator is a COMMA. This used to be a period, so a
    // shopping item read "1,5" and a pantry item "1.5" one screen apart, for
    // the same kind of number.
    test('fractional values render with a Swedish comma', () {
      expect(_item(quantity: 2.5).formattedQuantity, '2,5');
    });

    test('zero renders as "0"', () {
      expect(_item(quantity: 0).formattedQuantity, '0');
    });

    // This getter seeds the edit sheet's amount field, so the string it emits
    // has to be readable by the parser that field submits through. A format
    // the parser cannot read would silently fall back to the stored amount and
    // look like nothing happened.
    test('round-trips through the parser the edit sheet submits with', () {
      for (final q in <double>[2.5, 0.5, 3.0, 0.25, 1000.75]) {
        expect(
          parseSwedishDecimal(_item(quantity: q).formattedQuantity),
          q,
          reason: 'quantity $q did not survive format -> parse',
        );
      }
    });
  });

  group('expiry computations', () {
    test('isExpired false when no expiryDate', () {
      expect(_item().isExpired, isFalse);
    });

    test('isExpired true when expiry < now', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 1)), () {
        expect(
          _item(expiryDate: DateTime.utc(2026, 4, 1)).isExpired,
          isTrue,
        );
      });
    });

    test('isExpired false when expiry == now (boundary)', () {
      final now = DateTime.utc(2026, 5, 1, 12);
      withClock(Clock.fixed(now), () {
        expect(_item(expiryDate: now).isExpired, isFalse);
      });
    });

    test('daysUntilExpiry returns null when no expiryDate', () {
      expect(_item().daysUntilExpiry, isNull);
    });

    test('daysUntilExpiry is computed at day granularity, ignoring time', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 1, 23, 59)), () {
        // Same day → 0 days
        final sameDay = _item(expiryDate: DateTime.utc(2026, 5, 1, 8));
        expect(sameDay.daysUntilExpiry, 0);

        // Next day → 1 day
        final tomorrow = _item(expiryDate: DateTime.utc(2026, 5, 2, 0, 1));
        expect(tomorrow.daysUntilExpiry, 1);
      });
    });

    test('daysUntilExpiry negative when past', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 5)), () {
        expect(
          _item(expiryDate: DateTime.utc(2026, 5, 1)).daysUntilExpiry,
          -4,
        );
      });
    });
  });

  group('expiryStatus', () {
    test('fresh when no expiry', () {
      expect(_item().expiryStatus, PantryExpiryStatus.fresh);
    });

    test('fresh when > 3 days away', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 1)), () {
        expect(
          _item(expiryDate: DateTime.utc(2026, 5, 10)).expiryStatus,
          PantryExpiryStatus.fresh,
        );
      });
    });

    test('expiringSoon when 0..3 days', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 1)), () {
        expect(
          _item(expiryDate: DateTime.utc(2026, 5, 4)).expiryStatus,
          PantryExpiryStatus.expiringSoon,
        );
        expect(
          _item(expiryDate: DateTime.utc(2026, 5, 1)).expiryStatus,
          PantryExpiryStatus.expiringSoon,
        );
      });
    });

    test('expired when past', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 5)), () {
        expect(
          _item(expiryDate: DateTime.utc(2026, 4, 30)).expiryStatus,
          PantryExpiryStatus.expired,
        );
      });
    });
  });

  group('copyWith', () {
    test('clearIngredientId wipes existing ingredientId', () {
      final copy = _item(ingredientId: 'x').copyWith(clearIngredientId: true);
      expect(copy.ingredientId, isNull);
    });

    test('clearExpiryDate wipes existing expiryDate', () {
      final copy = _item(
        expiryDate: DateTime.utc(2026, 1, 1),
      ).copyWith(clearExpiryDate: true);
      expect(copy.expiryDate, isNull);
    });

    test('clearNote wipes existing note', () {
      final copy = _item(note: 'n').copyWith(clearNote: true);
      expect(copy.note, isNull);
    });

    test('field overrides win over clear flags only when both present', () {
      // Edge case: passing clearIngredientId=true + ingredientId='new'.
      // Per impl: clear flag wins (`clearIngredientId ? null : (... ?? ...)`).
      final copy = _item(
        ingredientId: 'old',
      ).copyWith(clearIngredientId: true, ingredientId: 'new');
      expect(copy.ingredientId, isNull);
    });

    test('partial update preserves untouched fields', () {
      final base = _item(quantity: 1, unit: 'l');
      final copy = base.copyWith(quantity: 2);
      expect(copy.quantity, 2);
      expect(copy.unit, 'l');
      expect(copy.id, base.id);
    });

    test('isStaple is preserved when untouched and toggled when passed', () {
      // BUT-1279: marking/un-marking a staple goes through copyWith; an
      // unrelated edit (e.g. quantity) must not silently clear the flag.
      final staple = _item(isStaple: true);
      expect(
        staple.copyWith(quantity: 5).isStaple,
        isTrue,
        reason: 'editing another field must not reset the staple flag',
      );
      expect(staple.copyWith(isStaple: false).isStaple, isFalse);
      expect(_item().copyWith(isStaple: true).isStaple, isTrue);
    });
  });

  group('equality + hash', () {
    test('id-only equality', () {
      final a = _item(quantity: 1);
      final b = _item(quantity: 99); // same id, different qty
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('identical short-circuit', () {
      final p = _item();
      expect(p == p, isTrue);
    });
  });

  test(
    'toString includes id + ingredientName + quantity + unit + location',
    () {
      final s = _item(quantity: 1.5).toString();
      expect(s, contains('p1'));
      expect(s, contains('Mjölk'));
      expect(s, contains('1.5'));
      expect(s, contains('l'));
      expect(s, contains('fridge'));
    },
  );
}
