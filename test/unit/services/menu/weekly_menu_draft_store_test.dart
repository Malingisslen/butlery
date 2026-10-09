/// BUT-2157: the week generation's draft is kept on this device, per
/// account, for 30 days since its last change (produktregler.md;
/// ux-beslut.json D-01), and a manual logout deletes the account's own draft
/// only (PQ-12 = A).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';

class _MockPrefs extends Mock implements SharedPreferences {}

final _written = DateTime(2026, 10, 1, 12);

WeeklyMenuDraft _draft({DateTime? at}) => WeeklyMenuDraft(
  prompt: 'tre middagar och en lunch',
  recipeIdsByMealType: const {
    'Middag': ['m1', 'm2', 'm3'],
    'Lunch': ['l1'],
  },
  requestedByMealType: const {'middag': 3, 'lunch': 1},
  lastModifiedAt: at ?? _written,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WeeklyMenuDraftStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = WeeklyMenuDraftStore();
  });

  test('a saved draft comes back with its prompt, order and counts', () async {
    await store.save('malin', _draft());

    final loaded = await withClock(
      Clock.fixed(_written.add(const Duration(days: 1))),
      () => store.load('malin'),
    );

    expect(loaded!.prompt, 'tre middagar och en lunch');
    expect(loaded.recipeIdsByMealType.keys, ['Middag', 'Lunch']);
    expect(loaded.recipeIdsByMealType['Middag'], ['m1', 'm2', 'm3']);
    expect(loaded.requestedByMealType, {'middag': 3, 'lunch': 1});
    expect(loaded.recipeCount, 4);
    expect(loaded.lastModifiedAt, _written);
  });

  test('each account sees only its own draft', () async {
    await store.save('malin', _draft());

    expect(await store.load('johan'), isNull);
  });

  test('kept on day 30, gone and deleted just after', () async {
    await store.save('malin', _draft());
    final prefs = await SharedPreferences.getInstance();

    final onTheDay = await withClock(
      Clock.fixed(_written.add(const Duration(days: 30))),
      () => store.load('malin'),
    );
    expect(onTheDay, isNotNull);

    final after = await withClock(
      Clock.fixed(_written.add(const Duration(days: 30, minutes: 1))),
      () => store.load('malin'),
    );
    expect(after, isNull);
    expect(prefs.containsKey(WeeklyMenuDraftStore.keyFor('malin')), isFalse);
  });

  test('a corrupt draft reads as none and is deleted', () async {
    SharedPreferences.setMockInitialValues({
      WeeklyMenuDraftStore.keyFor('malin'): '{not json',
      WeeklyMenuDraftStore.keyFor('johan'): '{"meals": "x"}',
    });

    expect(await store.load('malin'), isNull);
    expect(await store.load('johan'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('saving an empty draft deletes the kept one', () async {
    await store.save('malin', _draft());
    await store.save(
      'malin',
      WeeklyMenuDraft(
        prompt: 'x',
        recipeIdsByMealType: const {},
        requestedByMealType: const {},
        lastModifiedAt: _written,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(WeeklyMenuDraftStore.keyFor('malin')), isFalse);
  });

  test("clearAll for one account leaves another account's draft", () async {
    await store.save('malin', _draft());
    await store.save('johan', _draft());

    await WeeklyMenuDraftStore.clearAll(userId: 'malin');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WeeklyMenuDraftStore.keyFor('malin')), isNull);
    expect(prefs.getString(WeeklyMenuDraftStore.keyFor('johan')), isNotNull);
  });

  test('clearAll without an account removes every draft and nothing '
      'else', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'stays'});
    await store.save('malin', _draft());
    await store.save('johan', _draft());

    await WeeklyMenuDraftStore.clearAll();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'unrelated'});
  });

  test(
    'a draft that cannot be read reads as none and is not deleted',
    () async {
      // Unlike a corrupt draft, an unreadable store says nothing about the
      // draft in it, so deleting would throw away what may be intact.
      final prefs = _MockPrefs();
      when(() => prefs.getString(any())).thenThrow(StateError('storage gone'));
      final failing = WeeklyMenuDraftStore(prefsProvider: () async => prefs);

      expect(await failing.load('malin'), isNull);

      verify(
        () => prefs.getString(WeeklyMenuDraftStore.keyFor('malin')),
      ).called(1);
      verifyNever(() => prefs.remove(any()));
    },
  );
}
