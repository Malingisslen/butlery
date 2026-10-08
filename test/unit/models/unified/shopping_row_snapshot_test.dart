/// BUT-2140: the stored shape of the restore history, and what it must never
/// carry (a name or a user id would survive account deletion and leak into
/// other members' GDPR exports).
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/shopping/restorable_rows.dart';

void main() {
  final at = DateTime.utc(2026, 10, 8, 12, 30);

  // A row carrying every attribution field, so a snapshot that copied one
  // would show it.
  final attributed = UnifiedShoppingItem(
    id: 'a',
    name: 'Mjölk',
    amount: 1.5,
    unit: 'l',
    category: ShoppingCategory.dairy,
    note: 'lätt',
    addedByUserId: 'uid-alice',
    addedByDisplayName: 'Alice A',
    purchasedByUserId: 'uid-bob',
    purchasedByDisplayName: 'Bob B',
    lastModifiedByUserId: 'uid-bob',
    lastModifiedByDisplayName: 'Bob B',
    assignedToUserId: 'uid-cecilia',
    assignedToDisplayName: 'Cecilia C',
  );

  Iterable<String> allKeys(Object? node) sync* {
    if (node is Map) {
      for (final e in node.entries) {
        yield e.key.toString();
        yield* allKeys(e.value);
      }
    } else if (node is List) {
      for (final v in node) {
        yield* allKeys(v);
      }
    }
  }

  UnifiedShoppingList listWithHistory() {
    final edited = RestorableRows.withPrevious(
      attributed,
      attributed.copyWith(name: 'Havremjölk'),
      at,
    );
    return RestorableRows.withRemoved(
      UnifiedShoppingList(
        id: 'l1',
        name: 'x',
        ownerId: 'uid-alice',
        ownerDisplayName: 'Alice A',
        items: [edited],
      ),
      [attributed],
      at,
    );
  }

  group('ShoppingRowSnapshot', () {
    test(
      'holds exactly id, name, amount, unit, category, note and the time',
      () {
        final snapshot = ShoppingRowSnapshot.fromItem(attributed, at);
        const expected = {
          'id',
          'name',
          'amount',
          'unit',
          'category',
          'note',
          'at',
        };
        expect(snapshot.toFirestore().keys.toSet(), expected);
        expect(snapshot.toJson().keys.toSet(), expected);
      },
    );

    test(
      'a full list carries no *UserId or *DisplayName inside a snapshot',
      () {
        final list = listWithHistory();

        for (final serialised in [list.toFirestore(), list.toJson()]) {
          final snapshots = [
            ...(serialised['recentlyRemoved'] as List),
            (serialised['items'] as List).cast<Map>().single['previous'],
          ];
          expect(snapshots, hasLength(2));
          final offending = allKeys(
            snapshots,
          ).where((k) => k.endsWith('UserId') || k.endsWith('DisplayName'));
          expect(offending, isEmpty);

          final encoded = jsonEncode(
            snapshots,
            toEncodable: (o) =>
                o is Timestamp ? o.toDate().toIso8601String() : o,
          );
          for (final value in [
            'uid-alice',
            'uid-bob',
            'uid-cecilia',
            'Alice A',
            'Bob B',
            'Cecilia C',
          ]) {
            expect(encoded, isNot(contains(value)));
          }
        }
      },
    );

    test('round-trips through the Firestore and JSON shapes', () {
      final snapshot = ShoppingRowSnapshot.fromItem(attributed, at);
      expect(ShoppingRowSnapshot.fromMap(snapshot.toFirestore()), snapshot);
      expect(ShoppingRowSnapshot.fromMap(snapshot.toJson()), snapshot);
    });

    test('a list and its row round-trip previous and recentlyRemoved', () {
      final list = listWithHistory();

      final fromFirestore = UnifiedShoppingList.fromMap(
        'l1',
        list.toFirestore(),
      );
      final fromJson = UnifiedShoppingList.fromJson(list.toJson());
      for (final reread in [fromFirestore, fromJson]) {
        expect(reread.recentlyRemoved, list.recentlyRemoved);
        expect(reread.items.single.previous, list.items.single.previous);
        expect(reread.items.single.previous, isNotNull);
      }
    });

    test('a list written before the feature reads as having no history', () {
      final legacy = UnifiedShoppingList.fromMap('l', {
        'name': 'x',
        'ownerId': 'o',
        'ownerDisplayName': 'O',
        'items': [
          {'id': 'a', 'name': 'Mjölk', 'amount': 1},
        ],
      });
      expect(legacy.recentlyRemoved, isEmpty);
      expect(legacy.items.single.previous, isNull);
    });

    test('a malformed entry is skipped, the good ones survive', () {
      final good = ShoppingRowSnapshot.fromItem(attributed, at).toFirestore();
      final list = UnifiedShoppingList.fromMap('l', {
        'name': 'x',
        'ownerId': 'o',
        'ownerDisplayName': 'O',
        'recentlyRemoved': [
          good,
          {'id': 'no-name-no-time'},
          'not a map',
        ],
        'items': [
          {'id': 'a', 'name': 'Mjölk', 'amount': 1, 'previous': 'garbage'},
        ],
      });
      expect(list.recentlyRemoved, hasLength(1));
      expect(list.items.single.previous, isNull);
    });

    test('copyWith, claim, release and tick all keep previous', () {
      final edited = listWithHistory().items.single;
      expect(edited.previous, isNotNull);
      expect(edited.copyWith(priority: 4).previous, edited.previous);
      expect(
        edited.assign(userId: 'u', displayName: 'U').previous,
        edited.previous,
      );
      expect(edited.unassign().previous, edited.previous);
      expect(edited.togglePurchased().previous, edited.previous);
    });

    // F2: the array sits in a document every member reads, so 30 entries of
    // generous free text must stay well inside Firestore's limits.
    test('30 entries of long text serialise under 16 KB', () {
      var list = UnifiedShoppingList(
        name: 'x',
        ownerId: 'o',
        ownerDisplayName: 'O',
      );
      for (var i = 0; i < 40; i++) {
        list = RestorableRows.withRemoved(list, [
          UnifiedShoppingItem(
            id: '$i-a-fairly-long-uuid-v4-like-0000-0000-0000-000000000000',
            name: 'N' * 100,
            amount: 1234.5,
            unit: 'förpackning',
            category: ShoppingCategory.fruitVeg,
            note: 'x' * 200,
          ),
        ], at.add(Duration(minutes: i)));
      }

      final bytes = utf8
          .encode(jsonEncode(list.toJson()['recentlyRemoved']))
          .length;
      expect(list.recentlyRemoved, hasLength(30));
      expect(bytes, lessThan(16 * 1024));
    });
  });
}
