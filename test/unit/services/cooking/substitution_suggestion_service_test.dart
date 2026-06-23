/// BUT-202: Unit tests for [SubstitutionSuggestionService].
///
/// Proves:
/// 1. A 3-substitute Firestore doc is fetched, parsed, and returned in order.
/// 2. A 2nd call for the same ingredient hits the LRU cache — the lookup
///    service is invoked once, not twice.
/// 3. A missing Firestore doc returns an empty list (no throw).
/// 4. An unmatched ingredient (null lookup) returns an empty list.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

class _MockLookupService extends Mock implements IngredientLookupService {}

IngredientData _ingredient(String id, String swedish) => IngredientData(
  id: id,
  swedish: swedish,
  english: swedish,
  group: 'other',
  properties: const {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fake;
  late FirestoreRepository firestore;
  late _MockLookupService lookup;
  late SubstitutionSuggestionService service;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    fake = FakeFirebaseFirestore();
    firestore = FirestoreRepository(firestore: fake);
    lookup = _MockLookupService();
    service = SubstitutionSuggestionService(
      firestoreRepository: firestore,
      lookupService: lookup,
    );
  });

  group('suggestFor', () {
    test('returns up to 3 parsed substitutes from Firestore', () async {
      when(() => lookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient('smetana', 'smetana')],
          unmatched: const [],
        ),
      );

      await fake.collection('ingredient_substitutions').doc('smetana').set({
        'substitutes': [
          {'name': 'yoghurt', 'ratio': 1.0, 'context': 'i bakning'},
          {'name': 'crème fraîche', 'ratio': 0.75},
          {'name': 'kvarg', 'ratio': 1.0},
        ],
      });

      final result = await service.suggestFor('smetana');

      expect(result, hasLength(3));
      expect(result[0].name, 'yoghurt');
      expect(result[0].ratio, 1.0);
      expect(result[0].context, 'i bakning');
      expect(result[1].name, 'crème fraîche');
      expect(result[1].ratio, 0.75);
      expect(result[1].context, isNull);
      expect(result[2].name, 'kvarg');
    });

    test('caps at 3 results even when the doc contains more', () async {
      when(() => lookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient('mjolk', 'mjölk')],
          unmatched: const [],
        ),
      );

      await fake.collection('ingredient_substitutions').doc('mjolk').set({
        'substitutes': [
          {'name': 'a', 'ratio': 1.0},
          {'name': 'b', 'ratio': 1.0},
          {'name': 'c', 'ratio': 1.0},
          {'name': 'd', 'ratio': 1.0},
        ],
      });

      final result = await service.suggestFor('mjölk');
      expect(result, hasLength(3));
      expect(result.map((s) => s.name), ['a', 'b', 'c']);
    });

    test('second call for the same ingredient hits the LRU cache', () async {
      // The behavioral contract we care about: repeated lookups of the same
      // ingredient must not cost extra Firestore reads. Proxy check: the
      // lookup service is invoked exactly once across two calls.
      when(() => lookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient('smor', 'smör')],
          unmatched: const [],
        ),
      );

      await fake.collection('ingredient_substitutions').doc('smor').set({
        'substitutes': [
          {'name': 'margarin', 'ratio': 1.0},
        ],
      });

      final first = await service.suggestFor('smör');
      final second = await service.suggestFor('smör');

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(second.first.name, 'margarin');
      verify(() => lookup.lookupFromRaw(any())).called(1);
    });

    test('returns empty list when the substitutions doc is missing', () async {
      when(() => lookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient('exotic-thing', 'exotic-thing')],
          unmatched: const [],
        ),
      );

      final result = await service.suggestFor('exotic-thing');
      expect(result, isEmpty);
    });

    test('returns empty list when ingredient lookup has no match', () async {
      when(() => lookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: const [],
          unmatched: const ['gibberish-xyz'],
        ),
      );

      final result = await service.suggestFor('gibberish-xyz');
      expect(result, isEmpty);
      // Proves we didn't waste a Firestore read on an unmatched name.
    });

    test(
      'empty / whitespace-only input returns empty list synchronously',
      () async {
        expect(await service.suggestFor(''), isEmpty);
        expect(await service.suggestFor('   '), isEmpty);
        verifyNever(() => lookup.lookupFromRaw(any()));
      },
    );

    // BUT-610 (offline hardening): the ingredient lookup lazily loads the
    // global ingredient cache via a one-shot Firestore `.get()`. On a cold
    // offline cache that read throws `unavailable` instead of returning data.
    // suggestFor's docstring promises it "Never throws ... resolve to []", and
    // the cooking-mode substitution tap (cooking_mode_view._showSubstitutionSheet)
    // awaits it with NO try/catch — so a propagated throw is an unhandled
    // exception mid-cook. This proves the lookup failure is swallowed to [].
    test('returns empty list (no throw) when the ingredient lookup throws '
        'offline', () async {
      when(() => lookup.lookupFromRaw(any())).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Failed to get document because the client is offline.',
        ),
      );

      // Must not throw — the offline cooking-mode tap depends on this contract.
      final result = await service.suggestFor('smetana');
      expect(result, isEmpty);
    });
  });
}
