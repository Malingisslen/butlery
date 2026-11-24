// The on-device allergy reminders for the rows on screen (BUT-2494). The
// choices, the ingredient lookup and the account are injected, so what is
// pinned is what the controller decides and keeps, not the data sources.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/shopping/dismissed_dietary_hints_store.dart';
import 'package:butlery/services/shopping/shopping_dietary_hints.dart';
import 'package:butlery/viewmodels/shopping/shopping_dietary_hints_controller.dart';

const _butter = (id: 'row-butter', name: 'Smör');
const _rice = (id: 'row-rice', name: 'Ris');

const _properties = <String, Set<String>>{
  'Smör': {'contains-lactose', 'dairy'},
  'Ris': {'plant-based'},
  'Mjölk': {'contains-lactose', 'dairy'},
};

const _lactoseHint = ShoppingDietaryHint(
  choiceKey: 'laktos',
  kind: ShoppingDietaryHintKind.chooseFreeVariant,
);

class _Harness {
  Set<String> choices = {'laktos'};
  String? uid = 'alice';
  bool lookupFails = false;
  int choiceLoads = 0;
  final List<List<String>> lookups = [];

  late final controller = ShoppingDietaryHintsController(
    loadChoices: () async {
      choiceLoads++;
      return choices;
    },
    lookup: (names) async {
      lookups.add(List.of(names));
      if (lookupFails) throw StateError('ingredient data unreachable');
      return [for (final name in names) _properties[name]];
    },
    currentUserId: () => uid,
  );
}

void main() {
  late _Harness h;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = _Harness();
  });

  tearDown(() => h.controller.dispose());

  test(
    'a row whose item holds a household choice gets a hint, others none',
    () async {
      await h.controller.update([_butter, _rice]);

      expect(h.controller.hintsFor(_butter.id), [_lactoseHint]);
      expect(h.controller.hintsFor(_rice.id), isEmpty);
      expect(h.controller.hasVisibleHints, isTrue);
    },
  );

  test('listeners hear when the hints are published', () async {
    var notified = 0;
    h.controller.addListener(() => notified++);

    await h.controller.update([_butter]);

    expect(notified, greaterThanOrEqualTo(1));
  });

  test(
    'with no household choices the ingredient data is never asked',
    () async {
      h.choices = {};

      await h.controller.update([_butter, _rice]);

      expect(h.lookups, isEmpty);
      expect(h.controller.hintsFor(_butter.id), isEmpty);
      expect(h.controller.hasVisibleHints, isFalse);
    },
  );

  test('signed out: no choices read, no lookup, no hints', () async {
    h.uid = null;

    await h.controller.update([_butter]);

    expect(h.choiceLoads, 0);
    expect(h.lookups, isEmpty);
    expect(h.controller.hasVisibleHints, isFalse);
  });

  test(
    'each name is looked up once across updates, new names only after',
    () async {
      await h.controller.update([_butter]);
      await h.controller.update([_butter, _rice]);
      await h.controller.update([
        _rice,
        _butter,
        (id: 'row-butter-2', name: 'Smör'),
      ]);

      expect(h.lookups, [
        ['Smör'],
        ['Ris'],
      ]);
      // The second butter row reuses what the first name resolved to.
      expect(h.controller.hintsFor('row-butter-2'), [_lactoseHint]);
    },
  );

  test(
    'the household choices are asked again on every recompute',
    () async {
      h.choices = {};
      await h.controller.update([_butter]);
      expect(h.controller.hasVisibleHints, isFalse);

      h.choices = {'laktos'};
      await h.controller.update([_butter, _rice]);

      expect(h.choiceLoads, 2);
      expect(h.controller.hintsFor(_butter.id), [_lactoseHint]);
    },
  );

  test('an identical update does no work', () async {
    await h.controller.update([_butter]);
    await h.controller.update([_butter]);

    expect(h.lookups, hasLength(1));
    expect(h.choiceLoads, 1);
  });

  test(
    'a failed lookup shows no hint and is not retried per rebuild',
    () async {
      h.lookupFails = true;

      await h.controller.update([_butter]);
      await h.controller.update([_butter, _rice]);

      expect(h.controller.hintsFor(_butter.id), isEmpty);
      expect(h.lookups, [
        ['Smör'],
        ['Ris'],
      ]);
    },
  );

  group('dismissal', () {
    test(
      'dismissing hides that hint and keeps it hidden on a new controller',
      () async {
        await h.controller.update([_butter]);

        await h.controller.dismiss(_butter.id, 'laktos');

        expect(h.controller.hintsFor(_butter.id), isEmpty);
        expect(
          await const DismissedDietaryHintsStore().read('alice'),
          {DismissedDietaryHintsStore.entry(_butter.id, 'laktos')},
        );

        final reopened = _Harness();
        addTearDown(reopened.controller.dispose);
        await reopened.controller.update([_butter]);
        expect(reopened.controller.hintsFor(_butter.id), isEmpty);
      },
    );

    test('undo brings the hint back and persists the removal', () async {
      await h.controller.update([_butter]);
      await h.controller.dismiss(_butter.id, 'laktos');

      await h.controller.undoDismiss(_butter.id, 'laktos');

      expect(h.controller.hintsFor(_butter.id), [_lactoseHint]);
      expect(await const DismissedDietaryHintsStore().read('alice'), isEmpty);
    });

    test(
      'dismissing the only hint leaves no visible hint on the list',
      () async {
        await h.controller.update([_butter, _rice]);
        expect(h.controller.hasVisibleHints, isTrue);

        await h.controller.dismiss(_butter.id, 'laktos');

        expect(h.controller.hasVisibleHints, isFalse);
      },
    );

    test('dismissing one row leaves the same hint on another row', () async {
      const second = (id: 'row-butter-2', name: 'Smör');
      await h.controller.update([_butter, second]);

      await h.controller.dismiss(_butter.id, 'laktos');

      expect(h.controller.hintsFor(second.id), [_lactoseHint]);
      expect(h.controller.hasVisibleHints, isTrue);
    });

    test(
      'the dismissals of another account on this phone do not apply',
      () async {
        await const DismissedDietaryHintsStore().write('alice', {
          DismissedDietaryHintsStore.entry(_butter.id, 'laktos'),
        });
        h.uid = 'bob';

        await h.controller.update([_butter]);

        expect(h.controller.hintsFor(_butter.id), [_lactoseHint]);
      },
    );

    test(
      'a dismiss after the account changed is not written to the store',
      () async {
        await h.controller.update([_butter]);
        h.uid = 'bob';

        await h.controller.dismiss(_butter.id, 'laktos');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
        expect(await const DismissedDietaryHintsStore().read('alice'), isEmpty);
      },
    );

    test('nothing is persisted while signed out', () async {
      h.uid = null;
      await h.controller.update([_butter]);

      await h.controller.dismiss(_butter.id, 'laktos');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('an account change', () {
    test('reloads the choices and the dismissals of the new account', () async {
      await const DismissedDietaryHintsStore().write('alice', {
        DismissedDietaryHintsStore.entry(_butter.id, 'laktos'),
      });
      await h.controller.update([_butter]);
      expect(h.controller.hintsFor(_butter.id), isEmpty);

      h.uid = 'bob';
      h.choices = {'laktos', 'gluten'};
      await h.controller.update([_butter]);

      expect(h.choiceLoads, 2);
      expect(h.controller.hintsFor(_butter.id), [_lactoseHint]);
    });

    test('signing out drops the hints that were showing', () async {
      await h.controller.update([_butter]);
      expect(h.controller.hasVisibleHints, isTrue);

      h.uid = null;
      await h.controller.update([_butter]);

      expect(h.controller.hasVisibleHints, isFalse);
    });

    test(
      'names are looked up again for the new account, not carried over',
      () async {
        await h.controller.update([_butter]);

        h.uid = 'bob';
        await h.controller.update([_butter]);

        expect(h.lookups, [
          ['Smör'],
          ['Smör'],
        ]);
      },
    );
  });

  test('an update after dispose is ignored without error', () async {
    final other = _Harness();
    final controller = other.controller;
    controller.dispose();

    await controller.update([_butter]);

    expect(controller.hasVisibleHints, isFalse);
  });
}
