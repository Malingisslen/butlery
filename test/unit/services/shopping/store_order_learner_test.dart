// What the phone learns about the order a user shops a store in, and the one
// suggestion a steady habit turns into.

import 'dart:convert';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/store_order_learner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _meat = ShoppingCategory.meat;
const _dairy = ShoppingCategory.dairy;
const _fruit = ShoppingCategory.fruitVeg;

// The store's saved order walks dairy first; the user takes meat first.
const _order = [_fruit, _dairy, _meat];

Future<StoreOrderLearner> _learner([Map<String, Object>? stored]) async {
  SharedPreferences.setMockInitialValues(stored ?? {});
  return StoreOrderLearner(await SharedPreferences.getInstance());
}

/// One visit in which [first] is ticked before [second].
Future<void> _visit(
  StoreOrderLearner learner,
  String first,
  String second, {
  String store = 's1',
  String list = 'l1',
}) async {
  learner.endVisit();
  for (final category in [first, second]) {
    await learner.recordTick(
      userId: 'alice',
      storeId: store,
      listId: list,
      category: category,
    );
  }
}

void main() {
  test('a habit seen often enough is suggested, and not before', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks - 1; i++) {
      await _visit(learner, _meat, _dairy);
    }
    expect(learner.suggestionFor('s1', _order), isNull);

    await _visit(learner, _meat, _dairy);
    final suggestion = learner.suggestionFor('s1', _order)!;
    expect(suggestion.first, _meat);
    expect(suggestion.second, _dairy);
  });

  test('a habit the saved order already follows is not suggested', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _dairy, _meat);
    }
    expect(learner.suggestionFor('s1', _order), isNull);
  });

  test('a mixed habit is not suggested', () async {
    final learner = await _learner();
    for (var i = 0; i < 6; i++) {
      await _visit(learner, _meat, _dairy);
    }
    for (var i = 0; i < 4; i++) {
      await _visit(learner, _dairy, _meat);
    }
    // 6 against 4 is under twice as often.
    expect(learner.suggestionFor('s1', _order), isNull);
  });

  test('a second tick in a category within one visit adds nothing', () async {
    final learner = await _learner();
    learner.endVisit();
    for (final category in [_meat, _meat, _dairy, _dairy]) {
      await learner.recordTick(
        userId: 'alice',
        storeId: 's1',
        listId: 'l1',
        category: category,
      );
    }
    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!,
    );
    expect(stored['stores']['s1'], {'$_meat>$_dairy': 1});
  });

  test('a visit does not carry over to another store or list', () async {
    final learner = await _learner();
    learner.endVisit();
    await learner.recordTick(
      userId: 'alice',
      storeId: 's1',
      listId: 'l1',
      category: _meat,
    );
    await learner.recordTick(
      userId: 'alice',
      storeId: 's2',
      listId: 'l1',
      category: _dairy,
    );
    await learner.recordTick(
      userId: 'alice',
      storeId: 's2',
      listId: 'l2',
      category: _fruit,
    );
    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!,
    );
    expect(stored['stores'], isEmpty);
  });

  test(
    'counts survive a restart and no more than pair counts are kept',
    () async {
      final learner = await _learner();
      await _visit(learner, _meat, _dairy);

      final raw = (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!;
      expect(jsonDecode(raw), {
        'owner': 'alice',
        'stores': {
          's1': {'$_meat>$_dairy': 1},
        },
      });

      final again = await _learner({StoreOrderLearner.storageKey: raw});
      again.load('alice');
      for (var i = 0; i < StoreOrderLearner.minTicks - 1; i++) {
        await _visit(again, _meat, _dairy);
      }
      expect(again.suggestionFor('s1', _order), isNotNull);
    },
  );

  test('what another account left is not read and is dropped', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _meat, _dairy);
    }
    final raw = (await SharedPreferences.getInstance()).getString(
      StoreOrderLearner.storageKey,
    )!;

    final other = await _learner({StoreOrderLearner.storageKey: raw});
    other.load('bob');
    expect(other.suggestionFor('s1', _order), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      ),
      isNull,
    );
  });

  test('answering a pair forgets both directions of it', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _meat, _dairy);
    }
    await _visit(learner, _dairy, _meat);
    final suggestion = learner.suggestionFor('s1', _order)!;
    await learner.forgetPair('alice', 's1', suggestion);

    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!,
    );
    expect(stored['stores'], isEmpty);
  });

  test('counts cleared from the device do not write themselves back', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _meat, _dairy);
    }
    await (await SharedPreferences.getInstance()).remove(
      StoreOrderLearner.storageKey,
    );

    learner.load('alice');
    expect(learner.suggestionFor('s1', _order), isNull);
    await _visit(learner, _dairy, _fruit);
    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!,
    );
    expect(stored['stores']['s1'], {'$_dairy>$_fruit': 1});
  });

  test(
    'a removed store takes its counts with it, also on the device',
    () async {
      final learner = await _learner();
      for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
        await _visit(learner, _meat, _dairy);
        await _visit(learner, _meat, _dairy, store: 's2');
      }
      await learner.forgetStore('alice', 's1');

      expect(learner.suggestionFor('s1', _order), isNull);
      final stored = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          StoreOrderLearner.storageKey,
        )!,
      );
      expect((stored['stores'] as Map).keys, ['s2']);
    },
  );

  test('forgetting a store does not write cleared counts back', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _meat, _dairy);
      await _visit(learner, _meat, _dairy, store: 's2');
    }
    await (await SharedPreferences.getInstance()).remove(
      StoreOrderLearner.storageKey,
    );

    await learner.forgetStore('alice', 's2');

    expect(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      ),
      isNull,
    );
    expect(learner.suggestionFor('s1', _order), isNull);
  });

  test('answering a pair does not write cleared counts back', () async {
    final learner = await _learner();
    for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
      await _visit(learner, _meat, _dairy);
    }
    final suggestion = learner.suggestionFor('s1', _order)!;
    await (await SharedPreferences.getInstance()).remove(
      StoreOrderLearner.storageKey,
    );

    await learner.forgetPair('alice', 's1', suggestion);

    expect(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      ),
      isNull,
    );
  });

  test(
    'a habit exactly twice as common as its opposite is suggested',
    () async {
      final learner = await _learner();
      for (var i = 0; i < 10; i++) {
        await _visit(learner, _meat, _dairy);
      }
      for (var i = 0; i < 5; i++) {
        await _visit(learner, _dairy, _meat);
      }

      expect(learner.suggestionFor('s1', _order), isNotNull);
    },
  );

  test(
    'without device storage nothing throws',
    () async {
      final learner = StoreOrderLearner(null);
      for (var i = 0; i < StoreOrderLearner.minTicks; i++) {
        await _visit(learner, _meat, _dairy);
      }
      // Counts live only in memory without storage; nothing is written.
      expect(learner.suggestionFor('s1', _order), isNotNull);
    },
  );

  test('only the newest stores are kept past the limit', () async {
    final learner = await _learner();
    for (var i = 0; i <= StoreOrderLearner.maxStores; i++) {
      await _visit(learner, _meat, _dairy, store: 'store$i');
    }
    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        StoreOrderLearner.storageKey,
      )!,
    );
    expect((stored['stores'] as Map).length, StoreOrderLearner.maxStores);
    expect((stored['stores'] as Map).containsKey('store0'), isFalse);
  });
}
