/// Gap-filling tests for FirebaseIngredientRepository.
///
/// The existing test/unit/repositories/firebase_ingredient_repository_cache_test.dart
/// covers cold/warm/stale cache behaviour. This file covers the remaining
/// uncovered surface:
/// - findByName (alias path + fuzzy match prefix/suffix/substring branches)
/// - findByAlias
/// - getByGroup / getByProperty (group hierarchy + property lookup)
/// - searchIngredients (multi-source scoring)
/// - watchAll / getAll / exists
/// - forceRefresh + cache invalidation listeners
/// - clearCache / dispose
/// - listener-failure swallow path
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';

Future<void> _seedRaw(
  FakeFirebaseFirestore firestore,
  String id,
  Map<String, dynamic> data,
) async {
  await firestore.collection(FirestoreCollections.ingredients).doc(id).set({
    'id': id,
    ...data,
  });
}

Future<void> _seedBasic(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String swedish,
  String english = '',
  String group = 'spice',
  List<String> aliasesSv = const [],
  List<String> aliasesEn = const [],
  List<String> searchTerms = const [],
  List<String> properties = const [],
  bool isCompoundName = false,
}) async {
  await _seedRaw(firestore, id, {
    'swedish': swedish,
    'english': english.isEmpty ? id : english,
    'group': group,
    'properties': properties,
    'aliasesSv': aliasesSv,
    'aliasesEn': aliasesEn,
    'searchTerms': searchTerms,
    'isCompoundName': isCompoundName,
  });
}

void main() {
  group('findByName — alias + fuzzy match branches', () {
    test('returns null for empty input', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'cinnamon', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.findByName(''), isNull);
    });

    test('finds via alias index (sv)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'chicken',
        swedish: 'kyckling',
        aliasesSv: const ['kycklingfile'],
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final got = await repo.findByName('kycklingfile');
      expect(got?.id, 'chicken');
    });

    test('finds via search term index', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'tomato',
        swedish: 'tomat',
        searchTerms: const ['röd frukt'],
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      // 'röd frukt' → normalize → 'rod frukt'. Search by the normalized term.
      final got = await repo.findByName('rod frukt');
      expect(got?.id, 'tomato');
    });

    test(
      'cross-language lookup: english query finds swedish-named entry',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedBasic(
          firestore,
          id: 'cinnamon',
          swedish: 'kanel',
          english: 'cinnamon',
        );
        final repo = FirebaseIngredientRepository(firestore: firestore);

        // Default language='sv' tries swedish then english.
        final got = await repo.findByName('cinnamon');
        expect(got?.id, 'cinnamon');
      },
    );

    test(
      'fuzzy prefix match: short query matches longer index entry',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedBasic(firestore, id: 'chicken', swedish: 'kycklingbrost');
        final repo = FirebaseIngredientRepository(firestore: firestore);

        // 'kyckling' is a prefix of 'kycklingbrost'.
        final got = await repo.findByName('kyckling');
        expect(got?.id, 'chicken');
      },
    );

    test('fuzzy substring requires min 3 chars (H1 guard)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'radish', swedish: 'radisor');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      // 2-char query — substring matching is skipped, only exact lookups.
      // 'ri' wouldn't match anything via exact paths.
      expect(await repo.findByName('ri'), isNull);
    });

    test('returns null when no match found', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'cinnamon', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.findByName('xyz-not-real-zzz'), isNull);
    });

    test('language=en routes to english index first', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'cinnamon',
        swedish: 'kanel',
        english: 'cinnamon',
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final got = await repo.findByName('cinnamon', language: 'en');
      expect(got?.id, 'cinnamon');
    });
  });

  group('findByAlias', () {
    test('returns single matching ingredient when alias exists', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'chicken',
        swedish: 'kyckling',
        aliasesSv: const ['kycklingfile'],
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final got = await repo.findByAlias('kycklingfile');
      expect(got.map((i) => i.id), ['chicken']);
    });

    test('returns empty for unknown alias', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.findByAlias('does-not-exist'), isEmpty);
    });

    test('returns empty for empty alias string', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.findByAlias(''), isEmpty);
    });
  });

  group('getByGroup / getByProperty', () {
    test('getByGroup filters by group path', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'chicken',
        swedish: 'kyckling',
        group: 'meat/poultry',
      );
      await _seedBasic(
        firestore,
        id: 'beef',
        swedish: 'nötkött',
        group: 'meat/beef',
      );
      await _seedBasic(
        firestore,
        id: 'kanel',
        swedish: 'kanel',
        group: 'spice',
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      // group hierarchy: 'meat' should match both meat/poultry and meat/beef.
      final meats = await repo.getByGroup('meat');
      expect(meats.map((i) => i.id).toSet(), {'chicken', 'beef'});
    });

    test('getByProperty filters by property tag', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'cinnamon',
        swedish: 'kanel',
        properties: const ['warm_spice'],
      );
      await _seedBasic(
        firestore,
        id: 'salt',
        swedish: 'salt',
        properties: const ['savory'],
      );
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final warmSpices = await repo.getByProperty('warm_spice');
      expect(warmSpices.map((i) => i.id), ['cinnamon']);
    });
  });

  group('searchIngredients', () {
    test('exact match scores highest, ordered by score descending', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(
        firestore,
        id: 'kyckling',
        swedish: 'kyckling',
        aliasesSv: const ['kycklingfile'],
      );
      await _seedBasic(
        firestore,
        id: 'kycklingbrost',
        swedish: 'kycklingbrost',
      );
      await _seedBasic(firestore, id: 'andkyckling', swedish: 'andkyckling');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final results = await repo.searchIngredients('kyckling');
      // Exact 'kyckling' should rank first.
      expect(results.first.id, 'kyckling');
    });

    test('honours limit', () async {
      final firestore = FakeFirebaseFirestore();
      for (final s in ['a', 'b', 'c', 'd', 'e']) {
        await _seedBasic(
          firestore,
          id: 'i$s',
          swedish: 'kanel$s',
          english: 'cinnamon$s',
        );
      }
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final results = await repo.searchIngredients('kanel', limit: 2);
      expect(results.length, 2);
    });

    test('returns empty list for empty query', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.searchIngredients(''), isEmpty);
    });
  });

  group('bulk + existence + count helpers', () {
    test('getAll returns all cached ingredients', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'a', swedish: 'kanel');
      await _seedBasic(firestore, id: 'b', swedish: 'salt');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final all = await repo.getAll();
      expect(all.map((i) => i.id).toSet(), {'a', 'b'});
    });

    test('exists true for cached id, false otherwise', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.exists('kanel'), isTrue);
      expect(await repo.exists('ghost'), isFalse);
    });

    test('count returns cache size', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'a', swedish: 'a');
      await _seedBasic(firestore, id: 'b', swedish: 'b');
      await _seedBasic(firestore, id: 'c', swedish: 'c');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      expect(await repo.count(), 3);
    });

    test('watchAll emits the cached snapshot once', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      final first = await repo.watchAll().first;
      expect(first.length, 1);
      expect(first.first.id, 'kanel');
    });
  });

  group('initialize / forceRefresh / cache invalidation', () {
    test('initialize warms cache', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      await repo.initialize();
      expect(await repo.count(), 1);
    });

    test('forceRefresh fires invalidation listeners', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      var fired = 0;
      repo.addCacheInvalidationListener(() => fired++);

      await repo.forceRefresh();
      expect(fired, 1);
    });

    test('forceRefresh picks up new Firestore docs', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      await repo.initialize();
      expect(await repo.count(), 1);

      await _seedBasic(firestore, id: 'salt', swedish: 'salt');
      await repo.forceRefresh();

      expect(await repo.count(), 2);
    });

    test('cache invalidation continues when one listener throws', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      var goodFired = 0;
      repo.addCacheInvalidationListener(() {
        throw StateError('boom');
      });
      repo.addCacheInvalidationListener(() => goodFired++);

      // Should not throw — the bad listener gets swallowed and the good one
      // still runs.
      await repo.forceRefresh();
      expect(goodFired, 1);
    });

    test('removeCacheInvalidationListener stops firing', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      var fired = 0;
      void listener() {
        fired++;
      }

      repo.addCacheInvalidationListener(listener);
      repo.removeCacheInvalidationListener(listener);

      await repo.forceRefresh();
      expect(fired, 0);
    });
  });

  group('clearCache + dispose', () {
    test('clearCache resets cache state so next read refetches', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);
      await repo.initialize();
      expect(await repo.count(), 1);

      await _seedBasic(firestore, id: 'salt', swedish: 'salt');
      repo.clearCache();

      // Next call re-fetches and now sees the new doc.
      expect(await repo.count(), 2);
    });

    test('dispose clears invalidation listeners', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedBasic(firestore, id: 'kanel', swedish: 'kanel');
      final repo = FirebaseIngredientRepository(firestore: firestore);

      var fired = 0;
      repo.addCacheInvalidationListener(() => fired++);
      repo.dispose();

      await repo.forceRefresh();
      expect(fired, 0);
    });
  });
}
