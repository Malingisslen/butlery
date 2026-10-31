/// What the week menu's follows did to a list, kept for the notice at the top
/// of the list: how several follows net out, what Ångra may still undo, and
/// that the notice survives on the device exactly once.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/shopping/week_list_follow_notice.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';

const _listId = 'list-1';

/// A row as the week plan's sync wrote it (untouched).
UnifiedShoppingItem _row(String id, {double amount = 1}) =>
    WeekListReconciler.stamp([
      UnifiedShoppingItem(id: id, name: 'vara $id', amount: amount, unit: 'st'),
    ], ShoppingRowOrigin.plan).single;

MenuShoppingMergeReceipt _receipt({
  List<String> added = const [],
  List<UnifiedShoppingItem> removed = const [],
  List<UnifiedShoppingItem> changed = const [],
}) => MenuShoppingMergeReceipt(
  listId: _listId,
  listName: 'Inköpslista vecka 24',
  addedItemIds: added,
  removedItems: removed,
  changedItems: changed,
  previousMenuItemIds: const [],
  createdList: false,
);

UnifiedShoppingList _list(List<UnifiedShoppingItem> items) =>
    UnifiedShoppingList(
      id: _listId,
      name: 'Inköpslista vecka 24',
      ownerId: 'u',
      ownerDisplayName: 'U',
      items: items,
      menuItemIds: [for (final i in items) i.id],
    );

void main() {
  group('merge', () {
    test('counts what a follow added, removed and changed', () {
      final notice = WeekListFollowNotice.merge(
        null,
        _receipt(
          added: ['a', 'b', 'c'],
          removed: [_row('r')],
          changed: [_row('c1')],
        ),
      );

      expect(notice.addedCount, 3);
      expect(notice.removedCount, 1);
      expect(notice.changedCount, 1);
      expect(notice.isEmpty, isFalse);
    });

    test('a row one follow added and the next took off is neither', () {
      final first = WeekListFollowNotice.merge(null, _receipt(added: ['a']));

      final net = WeekListFollowNotice.merge(
        first,
        _receipt(removed: [_row('a')]),
      );

      expect(net.isEmpty, isTrue);
    });

    test('a row changed and then removed counts as removed, with its value '
        'from before the first change', () {
      final before = _row('x', amount: 1);
      final afterChange = _row('x', amount: 5);
      final first = WeekListFollowNotice.merge(
        null,
        _receipt(changed: [before]),
      );

      final net = WeekListFollowNotice.merge(
        first,
        _receipt(removed: [afterChange]),
      );

      expect(net.changedCount, 0);
      expect(net.removed.single.amount, 1);
    });

    test('a row changed twice keeps the value from before the first', () {
      final first = WeekListFollowNotice.merge(
        null,
        _receipt(changed: [_row('x', amount: 1)]),
      );

      final net = WeekListFollowNotice.merge(
        first,
        _receipt(changed: [_row('x', amount: 5)]),
      );

      expect(net.changed.single.amount, 1);
    });

    test('a row added and then changed stays only added', () {
      final first = WeekListFollowNotice.merge(null, _receipt(added: ['a']));

      final net = WeekListFollowNotice.merge(
        first,
        _receipt(changed: [_row('a', amount: 2)]),
      );

      expect(net.addedIds, ['a']);
      expect(net.changedCount, 0);
    });
  });

  group('undoAgainst', () {
    test('includes added, changed and removed rows nobody has touched', () {
      final notice = WeekListFollowNotice.merge(
        null,
        _receipt(
          added: ['a'],
          changed: [_row('c', amount: 1)],
          removed: [_row('r')],
        ),
      );
      final current = _list([_row('a'), _row('c', amount: 3)]);

      final undo = notice.undoAgainst(current);

      expect(undo.addedItemIds, ['a']);
      expect(undo.changedItems.single.id, 'c');
      expect(undo.removedItems.single.id, 'r');
      expect(undo.listId, _listId);
    });

    test('an added row the user ticked is not removed', () {
      final notice = WeekListFollowNotice.merge(null, _receipt(added: ['a']));
      final current = _list([_row('a').copyWith(bought: true)]);

      expect(notice.undoAgainst(current).addedItemIds, isEmpty);
    });

    test('an added row the user changed is not removed', () {
      final notice = WeekListFollowNotice.merge(null, _receipt(added: ['a']));
      final current = _list([_row('a').copyWith(amount: 9)]);

      expect(notice.undoAgainst(current).addedItemIds, isEmpty);
    });

    test('an added row already gone from the list is not asked for', () {
      final notice = WeekListFollowNotice.merge(null, _receipt(added: ['a']));

      expect(notice.undoAgainst(_list([])).addedItemIds, isEmpty);
    });

    test('a changed row the user ticked is not restored', () {
      final notice = WeekListFollowNotice.merge(
        null,
        _receipt(changed: [_row('c', amount: 1)]),
      );
      final current = _list([_row('c', amount: 3).copyWith(bought: true)]);

      expect(notice.undoAgainst(current).changedItems, isEmpty);
    });

    test('a changed row the user edited since is not restored', () {
      final notice = WeekListFollowNotice.merge(
        null,
        _receipt(changed: [_row('c', amount: 1)]),
      );
      final current = _list([_row('c', amount: 3).copyWith(amount: 7)]);

      expect(notice.undoAgainst(current).changedItems, isEmpty);
    });

    test(
      'a removed row whose id is back on the list is not put back twice',
      () {
        final notice = WeekListFollowNotice.merge(
          null,
          _receipt(removed: [_row('r')]),
        );

        expect(notice.undoAgainst(_list([_row('r')])).removedItems, isEmpty);
      },
    );
  });

  group('store', () {
    late SharedPreferences prefs;
    late WeekListFollowNoticeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = WeekListFollowNoticeStore(prefs);
    });

    test('a recorded notice is taken once', () async {
      await store.record(_receipt(added: ['a', 'b'], removed: [_row('r')]));

      final first = await store.take(_listId);
      final second = await store.take(_listId);

      expect(first, isNotNull);
      expect(first!.addedIds, ['a', 'b']);
      expect(first.removed.single.id, 'r');
      expect(second, isNull);
    });

    test('a taken notice is gone from the device', () async {
      await store.record(_receipt(added: ['a']));
      await store.take(_listId);

      expect(prefs.containsKey(WeekListFollowNoticeStore.storageKey), isFalse);
    });

    test('a notice put back after it was taken is taken again', () async {
      await store.record(_receipt(added: ['a']));
      final taken = (await store.take(_listId))!;

      await store.putBack(taken);

      expect((await store.take(_listId))!.addedIds, ['a']);
    });

    test(
      'a notice put back goes under a follow recorded since, netted',
      () async {
        await store.record(_receipt(added: ['a'], changed: [_row('c')]));
        final taken = (await store.take(_listId))!;
        // Since the take: a takes the row a added off, c is changed again.
        await store.record(
          _receipt(
            added: ['b'],
            removed: [_row('a')],
            changed: [_row('c', amount: 2)],
          ),
        );

        await store.putBack(taken);

        final notice = (await store.take(_listId))!;
        expect(notice.addedIds, ['b']);
        expect(notice.removed, isEmpty);
        expect(
          notice.changed.single.amount,
          1,
          reason: 'c keeps its value from before the first follow',
        );
      },
    );

    test('two follows before the list is opened are one notice', () async {
      await store.record(_receipt(added: ['a']));
      await store.record(_receipt(added: ['b']));

      final notice = await store.take(_listId);

      expect(notice!.addedIds, ['a', 'b']);
    });

    test(
      'a notice survives a restart (a new store on the same device)',
      () async {
        await store.record(_receipt(added: ['a']));

        final afterRestart = WeekListFollowNoticeStore(prefs);

        expect((await afterRestart.take(_listId))!.addedIds, ['a']);
      },
    );

    test('a follow that wrote nothing records nothing and leaves the key '
        'absent', () async {
      await store.record(_receipt());

      expect(prefs.containsKey(WeekListFollowNoticeStore.storageKey), isFalse);
      expect(await store.take(_listId), isNull);
    });

    test('a follow that nets a notice away removes it', () async {
      await store.record(_receipt(added: ['a']));
      await store.record(_receipt(removed: [_row('a')]));

      expect(await store.take(_listId), isNull);
      expect(prefs.containsKey(WeekListFollowNoticeStore.storageKey), isFalse);
    });

    test('a notice nobody opened for more than 14 days is dropped', () async {
      final start = DateTime(2026, 10, 1, 12);
      await withClock(Clock.fixed(start), () async {
        await store.record(_receipt(added: ['a']));
      });

      final late = start.add(const Duration(days: 14, minutes: 1));
      final taken = await withClock(
        Clock.fixed(late),
        () => store.take(_listId),
      );

      expect(taken, isNull);
      expect(
        prefs.containsKey(WeekListFollowNoticeStore.storageKey),
        isFalse,
        reason: 'an expired notice leaves the device, not only the screen',
      );
    });

    test('a notice just inside 14 days is still shown', () async {
      final start = DateTime(2026, 10, 1, 12);
      await withClock(Clock.fixed(start), () async {
        await store.record(_receipt(added: ['a']));
      });

      final soon = start.add(const Duration(days: 13));
      final taken = await withClock(
        Clock.fixed(soon),
        () => store.take(_listId),
      );

      expect(taken!.addedIds, ['a']);
    });

    test('corrupt data reads as no notice and does not throw', () async {
      SharedPreferences.setMockInitialValues({
        WeekListFollowNoticeStore.storageKey: '{not json',
      });
      final corrupt = WeekListFollowNoticeStore(
        await SharedPreferences.getInstance(),
      );

      expect(await corrupt.take(_listId), isNull);
      // A new follow still records over the corrupt value.
      await corrupt.record(_receipt(added: ['a']));
      expect((await corrupt.take(_listId))!.addedIds, ['a']);
    });

    test('notices are kept per list', () async {
      await store.record(_receipt(added: ['a']));

      expect(await store.take('other-list'), isNull);
      expect(await store.take(_listId), isNotNull);
    });

    test('without preferences nothing is kept and nothing throws', () async {
      final none = WeekListFollowNoticeStore(null);

      await none.record(_receipt(added: ['a']));

      expect(await none.take(_listId), isNull);
    });
  });
}
