/// BUT-2140: the rules for what the 30-day "Återställ varor" history keeps.
///
/// If these break, a check-off starts costing history, or the removed-rows
/// array grows without bound inside a document every member reads.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/shopping/restorable_rows.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);

  UnifiedShoppingItem row(
    String id, {
    String name = 'Mjölk',
    double amount = 1,
    bool bought = false,
  }) => UnifiedShoppingItem(
    id: id,
    name: name,
    amount: amount,
    unit: 'l',
    bought: bought,
  );

  UnifiedShoppingList emptyList() => UnifiedShoppingList(
    id: 'l1',
    name: 'Handla',
    ownerId: 'alice',
    ownerDisplayName: 'Alice',
    updatedAt: DateTime.utc(2026, 10, 1),
  );

  ShoppingRowSnapshot snapshot(String id, DateTime at) => ShoppingRowSnapshot(
    id: id,
    name: id,
    amount: 1,
    unit: '',
    category: ShoppingCategory.other,
    at: at,
  );

  group('withPrevious', () {
    test('a check-off leaves previous untouched', () {
      final edited = RestorableRows.withPrevious(
        row('a'),
        row('a', name: 'Havremjölk'),
        now,
      );
      expect(edited.previous?.name, 'Mjölk');

      final ticked = RestorableRows.withPrevious(
        edited,
        edited.togglePurchased(userId: 'bob', userDisplayName: 'Bob'),
        now.add(const Duration(hours: 1)),
      );

      expect(ticked.bought, isTrue);
      expect(ticked.previous, edited.previous);
      expect(ticked.previous?.at, now, reason: 'not re-stamped by a tick');
    });

    test('a claim, a priority and a price are not content', () {
      final before = row('a');
      final after = UnifiedShoppingItem(
        id: 'a',
        name: 'Mjölk',
        amount: 1,
        unit: 'l',
        priority: 5,
        estimatedPrice: 20,
        assignedToUserId: 'bob',
      );
      expect(RestorableRows.withPrevious(before, after, now).previous, isNull);
    });

    test('a missing note and an empty note are the same note', () {
      final before = row('a');
      final after = before.copyWith(note: '');
      expect(RestorableRows.withPrevious(before, after, now).previous, isNull);
    });

    test('a rename sets previous to the content before it', () {
      final edited = RestorableRows.withPrevious(
        row('a'),
        row('a', name: 'Havremjölk'),
        now,
      );
      expect(edited.name, 'Havremjölk');
      expect(edited.previous, ShoppingRowSnapshot.fromItem(row('a'), now));
    });

    test('each of the five content fields counts', () {
      final before = UnifiedShoppingItem(
        id: 'a',
        name: 'Mjölk',
        amount: 1,
        unit: 'l',
        category: ShoppingCategory.dairy,
        note: 'lätt',
      );
      final changed = {
        'name': before.copyWith(name: 'Fil'),
        'amount': before.copyWith(amount: 2),
        'unit': before.copyWith(unit: 'dl'),
        'category': before.copyWith(category: ShoppingCategory.other),
        'note': before.copyWith(note: 'mellan'),
      };
      for (final entry in changed.entries) {
        expect(
          RestorableRows.withPrevious(before, entry.value, now).previous,
          isNotNull,
          reason: '${entry.key} is content',
        );
      }
    });

    test('two edits keep only the latest earlier version', () {
      final first = RestorableRows.withPrevious(
        row('a'),
        row('a', name: 'Havremjölk'),
        now,
      );
      final second = RestorableRows.withPrevious(
        first,
        row('a', name: 'Sojamjölk'),
        now.add(const Duration(minutes: 5)),
      );
      expect(second.previous?.name, 'Havremjölk');
    });

    test('does not stamp a modification time', () {
      final after = row('a', name: 'Fil');
      final stamped = withClock(
        Clock.fixed(DateTime.utc(2030)),
        () => RestorableRows.withPrevious(row('a'), after, now),
      );
      expect(stamped.lastModifiedAt, isNull);
    });
  });

  group('withRemoved', () {
    test('a bought row is not kept', () {
      final list = RestorableRows.withRemoved(emptyList(), [
        row('a'),
        row('b', bought: true),
      ], now);
      expect(list.recentlyRemoved.map((s) => s.id), ['a']);
    });

    test('does not touch updatedAt', () {
      final base = emptyList();
      final list = RestorableRows.withRemoved(base, [row('a')], now);
      expect(list.updatedAt, base.updatedAt);
    });

    test('entry 31 pushes out the oldest', () {
      var list = emptyList();
      for (var i = 0; i < 31; i++) {
        list = RestorableRows.withRemoved(list, [
          row('r$i'),
        ], now.add(Duration(minutes: i)));
      }
      final ids = list.recentlyRemoved.map((s) => s.id).toList();
      expect(ids, hasLength(RestorableRows.maxRemoved));
      expect(ids, isNot(contains('r0')));
      expect(ids.first, 'r1');
      expect(ids.last, 'r30');
    });

    test('a batch larger than the cap keeps the cap, in stable order', () {
      final list = RestorableRows.withRemoved(emptyList(), [
        for (var i = 0; i < 35; i++) row('r$i'),
      ], now);
      expect(list.recentlyRemoved.map((s) => s.id), [
        for (var i = 5; i < 35; i++) 'r$i',
      ]);
    });

    test('30 days and 1 second old is pruned, 30 days exactly stays', () {
      final seeded = emptyList().copyWith(
        recentlyRemoved: [
          snapshot('old', now.subtract(const Duration(days: 30, seconds: 1))),
          snapshot('exact', now.subtract(const Duration(days: 30))),
        ],
      );

      final next = RestorableRows.withRemoved(seeded, [row('new')], now);

      expect(next.recentlyRemoved.map((s) => s.id), ['exact', 'new']);
    });

    test('removing the same row again keeps one entry, the newest', () {
      var list = RestorableRows.withRemoved(emptyList(), [row('a')], now);
      list = RestorableRows.withRemoved(list, [
        row('a', name: 'Fil'),
      ], now.add(const Duration(hours: 1)));
      expect(list.recentlyRemoved, hasLength(1));
      expect(list.recentlyRemoved.single.name, 'Fil');
    });
  });

  group('restorableAt', () {
    test('lists only what is within 30 days, newest first', () {
      final list = emptyList().copyWith(
        recentlyRemoved: [
          snapshot('gone', now.subtract(const Duration(days: 31))),
          snapshot('older', now.subtract(const Duration(days: 3))),
          snapshot('newer', now.subtract(const Duration(hours: 1))),
        ],
      );
      expect(RestorableRows.restorableAt(list, now).map((s) => s.id), [
        'newer',
        'older',
      ]);
    });
  });

  group('storedElements', () {
    // An arrayRemove matches the stored value exactly, so the elements must
    // be the stored ones themselves, never a re-serialised copy.
    test('returns the stored maps for the ids, untouched', () {
      final kept = {'id': 'a', 'amount': 2};
      final again = {'id': 'a', 'amount': 3};
      final other = {'id': 'b', 'amount': 1};
      final found = RestorableRows.storedElements([kept, other, again], {'a'});
      expect(found, hasLength(2));
      expect(identical(found[0], kept), isTrue);
      expect(identical(found[1], again), isTrue);
    });

    test('a missing or malformed array yields nothing', () {
      expect(RestorableRows.storedElements(null, {'a'}), isEmpty);
      expect(RestorableRows.storedElements('x', {'a'}), isEmpty);
      expect(RestorableRows.storedElements(['a', 1], {'a'}), isEmpty);
    });
  });

  group('changedAt and hasRestorable', () {
    UnifiedShoppingList withRows(List<UnifiedShoppingItem> items) =>
        emptyList().copyWith(items: items);

    UnifiedShoppingItem edited(String id, int daysAgo, {double was = 12}) =>
        row(id, name: 'Ägg', amount: 6).withPreviousSnapshot(
          ShoppingRowSnapshot.fromItem(
            row(id, name: 'Ägg', amount: was),
            now.subtract(Duration(days: daysAgo)),
          ),
        );

    test('lists changed rows within 30 days, newest first', () {
      final list = withRows([
        edited('old', 5),
        edited('new', 1),
        edited('x', 31),
      ]);
      expect(RestorableRows.changedAt(list, now).map((r) => r.id), [
        'new',
        'old',
      ]);
    });

    test('a previous equal to the current content is not a change', () {
      final list = withRows([edited('same', 1, was: 6)]);
      expect(RestorableRows.changedAt(list, now), isEmpty);
    });

    test('hasRestorable is true for either kind and false for neither', () {
      expect(RestorableRows.hasRestorable(emptyList(), now), isFalse);
      expect(
        RestorableRows.hasRestorable(withRows([edited('a', 1)]), now),
        isTrue,
      );
      expect(
        RestorableRows.hasRestorable(
          emptyList().copyWith(
            recentlyRemoved: [
              snapshot('r', now.subtract(const Duration(days: 2))),
            ],
          ),
          now,
        ),
        isTrue,
      );
    });
  });
}
