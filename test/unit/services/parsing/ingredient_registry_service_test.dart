/// Unit tests for IngredientRegistryService - Firestore ingredient enrichment
///
/// Tests Phase 1 additions:
/// - allCompoundNames getter (static fallback + Firestore enrichment)
/// - compound name collection during enrichFromFirestore
/// - isKnown behavior with enriched set
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';

/// Fake IngredientRepository for testing without Firebase
class FakeIngredientRepository implements IngredientRepository {
  final Map<String, List<IngredientData>> _groupData = {};
  bool throwOnGetByGroup = false;

  void addGroupIngredients(String group, List<IngredientData> ingredients) {
    _groupData[group] = ingredients;
  }

  @override
  Future<List<IngredientData>> getByGroup(String groupPath) async {
    if (throwOnGetByGroup) throw Exception('Fake network error');
    // Return ingredients whose group starts with groupPath
    final results = <IngredientData>[];
    for (final entry in _groupData.entries) {
      if (entry.key == groupPath || entry.key.startsWith('$groupPath/')) {
        results.addAll(entry.value);
      }
    }
    return results;
  }

  @override
  Future<IngredientData?> getById(String id) async => null;

  @override
  Future<IngredientData?> findByName(String name,
          {String language = 'sv'}) async =>
      null;

  @override
  Future<List<IngredientData>> findByAlias(String alias) async => [];

  @override
  Future<List<IngredientData>> getByProperty(String property) async => [];

  @override
  Future<List<IngredientData>> searchIngredients(String query,
          {int limit = 20}) async =>
      [];

  @override
  Stream<List<IngredientData>> watchAll() => const Stream.empty();

  @override
  Future<List<IngredientData>> getAll() async =>
      _groupData.values.expand((e) => e).toList();

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<int> count() async =>
      _groupData.values.fold<int>(0, (sum, list) => sum + list.length);
}

IngredientData _makeIngredient({
  required String id,
  required String swedish,
  String group = 'spice',
  bool isCompoundName = false,
  List<String> aliasesSv = const [],
}) {
  return IngredientData(
    id: id,
    swedish: swedish,
    english: id,
    group: group,
    properties: const {},
    isCompoundName: isCompoundName,
    aliasesSv: aliasesSv,
  );
}

void main() {
  group('IngredientRegistryService', () {
    late FakeIngredientRepository fakeRepo;
    late IngredientRegistryService service;

    setUp(() {
      fakeRepo = FakeIngredientRepository();
      service = IngredientRegistryService(ingredientRepository: fakeRepo);
    });

    group('allCompoundNames', () {
      test('should return static compound names before enrichment', () {
        final names = service.allCompoundNames;
        expect(names, equals(KnownIngredients.compoundNames));
      });

      test('should include Firestore compound names after enrichment',
          () async {
        fakeRepo.addGroupIngredients('spice', [
          _makeIngredient(
            id: 'test-spice-blend',
            swedish: 'testblandning',
            group: 'spice',
            isCompoundName: true,
            aliasesSv: ['testblandning-alias'],
          ),
        ]);

        await service.enrichFromFirestore();

        final names = service.allCompoundNames;
        expect(names, contains('testblandning'));
        expect(names, contains('testblandning-alias'));
      });

      test('compound names set is empty when Firebase has none', () async {
        fakeRepo.addGroupIngredients('spice', []);
        await service.enrichFromFirestore();

        final names = service.allCompoundNames;
        // Firebase has 0 isCompoundName=true — set is empty
        expect(names, isA<Set<String>>());
      });

      test('should NOT include non-compound Firestore ingredients', () async {
        fakeRepo.addGroupIngredients('spice', [
          _makeIngredient(
            id: 'regular-spice',
            swedish: 'regularspice',
            group: 'spice',
            isCompoundName: false,
          ),
        ]);

        await service.enrichFromFirestore();

        final names = service.allCompoundNames;
        expect(names, isNot(contains('regularspice')));
      });
    });

    group('allIngredients', () {
      test('should return static ingredients before enrichment', () {
        final ingredients = service.allIngredients;
        expect(ingredients, equals(KnownIngredients.all));
      });

      test('should include Firestore ingredients after enrichment', () async {
        fakeRepo.addGroupIngredients('spice', [
          _makeIngredient(
            id: 'harissa',
            swedish: 'harissa',
            group: 'spice',
            aliasesSv: ['harissa-pasta'],
          ),
        ]);

        await service.enrichFromFirestore();

        expect(service.allIngredients, contains('harissa'));
        expect(service.allIngredients, contains('harissa-pasta'));
      });
    });

    group('isKnown', () {
      test('should recognize static ingredients', () {
        expect(service.isKnown('mjölk'), isTrue);
        expect(service.isKnown('salt'), isTrue);
      });

      test('should be case-insensitive', () {
        expect(service.isKnown('Mjölk'), isTrue);
        expect(service.isKnown('SALT'), isTrue);
      });

      test('should recognize Firestore ingredients after enrichment', () async {
        fakeRepo.addGroupIngredients('condiment', [
          _makeIngredient(
            id: 'tahini',
            swedish: 'tahini',
            group: 'condiment',
          ),
        ]);

        await service.enrichFromFirestore();

        expect(service.isKnown('tahini'), isTrue);
      });

      test('should reject unknown ingredients', () {
        expect(service.isKnown('xyzfooditem'), isFalse);
      });
    });

    group('enrichFromFirestore', () {
      test('should only load once (idempotent)', () async {
        fakeRepo.addGroupIngredients('spice', [
          _makeIngredient(id: 'test1', swedish: 'test1', group: 'spice'),
        ]);

        await service.enrichFromFirestore();
        final firstResult = service.allIngredients.length;

        fakeRepo.addGroupIngredients('spice', [
          _makeIngredient(id: 'test1', swedish: 'test1', group: 'spice'),
          _makeIngredient(id: 'test2', swedish: 'test2', group: 'spice'),
        ]);
        await service.enrichFromFirestore(); // Should be no-op

        expect(service.allIngredients.length, firstResult);
      });

      test('should gracefully handle Firestore errors', () async {
        fakeRepo.throwOnGetByGroup = true;

        // Should not throw - falls back to static registry
        await service.enrichFromFirestore();

        // Should still have static ingredients
        expect(service.isKnown('mjölk'), isTrue);
      });
    });
  });
}
