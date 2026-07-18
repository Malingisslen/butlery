/// BUT-1475: the TTL background refresh must re-fetch ONLY ingredients changed
/// since the last load (a delta query on `updatedAt`) instead of downloading
/// the whole collection every hour — while still converging on adds and edits,
/// and falling back to a full reload when docs carry no `updatedAt` baseline.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';

void main() {
  group('FirebaseIngredientRepository delta refresh (BUT-1475)', () {
    late FakeFirebaseFirestore firestore;

    Future<void> seed(
      String id, {
      required String swedish,
      required DateTime updatedAt,
      List<String> properties = const [],
      List<String> aliasesSv = const [],
    }) async {
      await firestore.collection(FirestoreCollections.ingredients).doc(id).set({
        'id': id,
        'swedish': swedish,
        'english': id,
        'group': 'spice',
        'properties': properties,
        'aliasesSv': aliasesSv,
        'aliasesEn': <String>[],
        'updatedAt': Timestamp.fromDate(updatedAt),
      });
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('picks up a NEW doc added after the load baseline', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      await seed('cinnamon', swedish: 'kanel', updatedAt: t0);
      await seed('cardamom', swedish: 'kardemumma', updatedAt: t0);

      final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
      final repo = FirebaseIngredientRepository(
        firestore: firestore,
        cacheTtl: const Duration(hours: 1),
        now: clock.read,
      );

      await repo.findByName('kanel');
      expect(await repo.count(), 2);

      // A new ingredient synced later (newer updatedAt than the baseline).
      await seed(
        'saffron',
        swedish: 'saffran',
        updatedAt: DateTime.utc(2026, 1, 1, 13),
      );

      // Cross the TTL so the next read triggers the background delta refresh.
      clock.advance(const Duration(hours: 1, minutes: 5));
      await repo.findByName('anything');
      await _drainMicrotasks();

      expect(await repo.count(), 3);
      expect((await repo.findByName('saffran'))!.id, 'saffron');
    });

    test(
      'delta refresh SKIPS a doc whose updatedAt predates the baseline '
      '(proves a filtered delta query, not a full reload)',
      () async {
        // This is the read-cost guard BUT-1475 exists to deliver, and the one
        // the convergence tests above cannot catch: they all still pass if the
        // refresh secretly re-downloads the whole collection. Here a doc lands
        // carrying an updatedAt OLDER than the load baseline — a full reload
        // would pull it in; a delta query filtered on `updatedAt > baseline`
        // must not. The assertion flips the moment the delta query is reverted
        // to a full re-fetch.
        final t0 = DateTime.utc(2026, 1, 1, 12);
        await seed('cinnamon', swedish: 'kanel', updatedAt: t0);

        final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
        final repo = FirebaseIngredientRepository(
          firestore: firestore,
          cacheTtl: const Duration(hours: 1),
          now: clock.read,
        );

        await repo.findByName('kanel');
        expect(await repo.count(), 1);

        // Lands with an updatedAt BEFORE the baseline (12:00).
        await seed(
          'olddoc',
          swedish: 'gammalkrydda',
          updatedAt: DateTime.utc(2026, 1, 1, 11),
        );

        clock.advance(const Duration(hours: 1, minutes: 5));
        await repo.findByName('anything');
        await _drainMicrotasks();

        // A full reload would make this 2 and resolve 'gammalkrydda'.
        expect(await repo.count(), 1);
        expect(await repo.findByName('gammalkrydda'), isNull);
      },
    );

    test(
      'reflects an EDITED doc and drops its stale alias index entry',
      () async {
        final t0 = DateTime.utc(2026, 1, 1, 12);
        await seed(
          'cinnamon',
          swedish: 'kanel',
          updatedAt: t0,
          aliasesSv: ['gammaltalias'],
        );

        final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
        final repo = FirebaseIngredientRepository(
          firestore: firestore,
          cacheTtl: const Duration(hours: 1),
          now: clock.read,
        );

        await repo.findByName('kanel');
        // The old alias resolves before the edit (exact alias index, no fuzzy).
        expect(await repo.findByAlias('gammaltalias'), hasLength(1));

        // Admin edits the ingredient: new property, alias removed (new updatedAt).
        await seed(
          'cinnamon',
          swedish: 'kanel',
          updatedAt: DateTime.utc(2026, 1, 1, 13),
          properties: ['nytt-marker'],
          aliasesSv: const [],
        );

        clock.advance(const Duration(hours: 1, minutes: 5));
        await repo.findByName('anything');
        await _drainMicrotasks();

        // The edited property is now visible (delta merge landed)...
        expect(await repo.getByProperty('nytt-marker'), hasLength(1));
        // ...and the removed alias's stale index entry is gone (index rebuild).
        expect(await repo.findByAlias('gammaltalias'), isEmpty);
        expect(await repo.count(), 1);
      },
    );

    test(
      'forceRefresh does a FULL reload (picks up a doc the delta query skips)',
      () async {
        // Complements the delta-skip test: forceRefresh must guarantee a
        // complete re-fetch, so it picks up an older-than-baseline doc that a
        // delta query would miss. Guards the forceRefresh contract and the
        // _inFlightIsFull coalescing fix (a forceReload never settles for a
        // partial delta).
        final t0 = DateTime.utc(2026, 1, 1, 12);
        await seed('cinnamon', swedish: 'kanel', updatedAt: t0);

        final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
        final repo = FirebaseIngredientRepository(
          firestore: firestore,
          cacheTtl: const Duration(hours: 1),
          now: clock.read,
        );

        await repo.findByName('kanel');
        expect(await repo.count(), 1);

        await seed(
          'olddoc',
          swedish: 'gammalkrydda',
          updatedAt: DateTime.utc(2026, 1, 1, 11),
        );

        await repo.forceRefresh();

        expect(await repo.count(), 2);
        expect((await repo.findByName('gammalkrydda'))!.id, 'olddoc');
      },
    );

    test('falls back to a full reload when docs carry no updatedAt', () async {
      // Legacy docs without updatedAt → no delta baseline → full reload path.
      await firestore
          .collection(FirestoreCollections.ingredients)
          .doc('cinnamon')
          .set({
            'id': 'cinnamon',
            'swedish': 'kanel',
            'english': 'cinnamon',
            'group': 'spice',
            'properties': <String>[],
            'aliasesSv': <String>[],
            'aliasesEn': <String>[],
          });

      final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
      final repo = FirebaseIngredientRepository(
        firestore: firestore,
        cacheTtl: const Duration(hours: 1),
        now: clock.read,
      );

      await repo.findByName('kanel');
      expect(await repo.count(), 1);

      await firestore
          .collection(FirestoreCollections.ingredients)
          .doc('saffron')
          .set({
            'id': 'saffron',
            'swedish': 'saffran',
            'english': 'saffron',
            'group': 'spice',
            'properties': <String>[],
            'aliasesSv': <String>[],
            'aliasesEn': <String>[],
          });

      clock.advance(const Duration(hours: 1, minutes: 5));
      await repo.findByName('anything');
      await _drainMicrotasks();

      // Full-reload fallback still converges on the new doc.
      expect(await repo.count(), 2);
      expect((await repo.findByName('saffran'))!.id, 'saffron');
    });
  });
}

Future<void> _drainMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Mutable wall-clock for TTL tests.
class _Clock {
  DateTime _now;
  _Clock(this._now);

  DateTime read() => _now;
  void advance(Duration d) => _now = _now.add(d);
}
