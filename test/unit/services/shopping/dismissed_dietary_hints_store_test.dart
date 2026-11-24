// What a person dismissed under their shopping rows stays on this device,
// per account (BUT-2494).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/shopping/dismissed_dietary_hints_store.dart';

void main() {
  const store = DismissedDietaryHintsStore();
  final entry = DismissedDietaryHintsStore.entry;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'what one account dismissed reads back for it and for nobody else',
    () async {
      await store.write('alice', {
        entry('i1', 'laktos'),
        entry('i2', 'gluten'),
      });

      expect(await store.read('alice'), {'i1|laktos', 'i2|gluten'});
      expect(await store.read('bob'), isEmpty);
    },
  );

  test('a second write replaces the first, so an undo is persisted', () async {
    await store.write('alice', {entry('i1', 'laktos')});
    await store.write('alice', <String>{});

    expect(await store.read('alice'), isEmpty);
  });

  test('past the cap the newest entries are the ones kept', () async {
    final all = [
      for (var i = 0; i < DismissedDietaryHintsStore.maxEntries + 3; i++)
        entry('item$i', 'laktos'),
    ];

    await store.write('alice', all.toSet());

    final kept = await store.read('alice');
    expect(kept, hasLength(DismissedDietaryHintsStore.maxEntries));
    expect(kept, isNot(contains(all.first)));
    expect(kept, contains(all.last));
  });

  test('exactly at the cap nothing is dropped', () async {
    final all = {
      for (var i = 0; i < DismissedDietaryHintsStore.maxEntries; i++)
        entry('item$i', 'laktos'),
    };

    await store.write('alice', all);

    expect(await store.read('alice'), all);
  });

  test('clearAll removes every account\'s key and nothing else', () async {
    SharedPreferences.setMockInitialValues({
      '${DismissedDietaryHintsStore.keyPrefix}alice': ['i1|laktos'],
      '${DismissedDietaryHintsStore.keyPrefix}bob': ['i2|gluten'],
      'unrelated_setting': 'keep',
      'shopping_hint_dismissed_v2_alice': ['other-version'],
    });

    await DismissedDietaryHintsStore.clearAll();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {
      'unrelated_setting',
      'shopping_hint_dismissed_v2_alice',
    });
  });
}
