/// Unit tests for [FirebaseMenuLexiconRepository].
///
/// Verifies: Firestore loading, partial categories, empty collection,
/// TTL cache, malformed document handling, and offline resilience.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firebase/firebase_menu_lexicon_repository.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

void main() {
  group('FirebaseMenuLexiconRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseMenuLexiconRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = FirebaseMenuLexiconRepository(firestore: fakeFirestore);
    });

    Future<void> seedCategory(
      String categoryName,
      Map<String, String> entries,
    ) async {
      await fakeFirestore.collection('menu_lexicon').doc(categoryName).set({
        'entries': entries,
        'updatedAt': DateTime.now(),
      });
    }

    test('loads all seeded categories', () async {
      await seedCategory('dietaryStems', {'vegansk': 'vegan', 'lchf': 'lchf'});
      await seedCategory('cuisineStems', {'japanskt': 'japanese'});

      final result = await repository.loadOverrides();

      expect(result.length, 2);
      expect(result[LexiconCategory.dietaryStems], {
        'vegansk': 'vegan',
        'lchf': 'lchf',
      });
      expect(result[LexiconCategory.cuisineStems], {'japanskt': 'japanese'});
    });

    test('returns empty map for empty collection', () async {
      final result = await repository.loadOverrides();
      expect(result, isEmpty);
    });

    test('returns partial data when only some categories exist', () async {
      await seedCategory('themeStems', {'festmat': 'festive'});

      final result = await repository.loadOverrides();

      expect(result.length, 1);
      expect(result[LexiconCategory.themeStems], {'festmat': 'festive'});
      expect(result[LexiconCategory.dietaryStems], isNull);
    });

    test('skips documents with unknown category names', () async {
      await seedCategory('validCategory_dietaryStems', {'x': 'y'});
      await seedCategory('dietaryStems', {'vegansk': 'vegan'});
      await fakeFirestore.collection('menu_lexicon').doc('unknownCategory').set(
        {
          'entries': {'a': 'b'},
        },
      );

      final result = await repository.loadOverrides();

      expect(result.length, 1);
      expect(result[LexiconCategory.dietaryStems], {'vegansk': 'vegan'});
    });

    test('skips documents where entries is not a Map', () async {
      await fakeFirestore.collection('menu_lexicon').doc('dietaryStems').set({
        'entries': 'not-a-map',
      });
      await seedCategory('cuisineStems', {'japanskt': 'japanese'});

      final result = await repository.loadOverrides();

      expect(result.length, 1);
      expect(result[LexiconCategory.cuisineStems], {'japanskt': 'japanese'});
    });

    test('skips non-string entries within a valid map', () async {
      await fakeFirestore.collection('menu_lexicon').doc('dietaryStems').set({
        'entries': {
          'vegansk': 'vegan',
          'invalid_key': 42,
        },
      });

      final result = await repository.loadOverrides();

      expect(result[LexiconCategory.dietaryStems], {'vegansk': 'vegan'});
    });

    test('TTL cache returns cached data on second call', () async {
      await seedCategory('dietaryStems', {'vegansk': 'vegan'});

      final first = await repository.loadOverrides();
      expect(first[LexiconCategory.dietaryStems], {'vegansk': 'vegan'});

      // Mutate Firestore — should NOT be visible due to cache
      await fakeFirestore.collection('menu_lexicon').doc('dietaryStems').update(
        {
          'entries': {'lchf': 'lchf'},
        },
      );

      final second = await repository.loadOverrides();
      expect(second[LexiconCategory.dietaryStems], {'vegansk': 'vegan'});
    });

    test('clearCache forces re-fetch', () async {
      await seedCategory('dietaryStems', {'vegansk': 'vegan'});
      await repository.loadOverrides();

      // Replace with new data and clear cache
      await seedCategory('dietaryStems', {'lchf': 'lchf'});
      repository.clearCache();

      final result = await repository.loadOverrides();
      expect(result[LexiconCategory.dietaryStems], {'lchf': 'lchf'});
    });
  });

  group('FirebaseMenuLexiconRepository offline answer', () {
    late _MockFirestore firestore;
    late _MockCollection collection;
    late _MockQuerySnapshot snapshot;
    late _MockMetadata metadata;
    late FirebaseMenuLexiconRepository repository;

    setUp(() {
      firestore = _MockFirestore();
      collection = _MockCollection();
      snapshot = _MockQuerySnapshot();
      metadata = _MockMetadata();
      when(() => firestore.collection(any())).thenReturn(collection);
      when(() => collection.get()).thenAnswer((_) async => snapshot);
      when(() => snapshot.docs).thenReturn(const []);
      when(() => snapshot.metadata).thenReturn(metadata);
      repository = FirebaseMenuLexiconRepository(firestore: firestore);
    });

    test('a device-cache answer is reported as failed and not kept', () async {
      when(() => metadata.isFromCache).thenReturn(true);

      final first = await repository.loadOverridesWithStatus();
      await repository.loadOverridesWithStatus();

      expect(first.failed, isTrue);
      verify(() => collection.get()).called(2);
    });

    test('a server answer is complete and kept for the TTL', () async {
      when(() => metadata.isFromCache).thenReturn(false);

      final first = await repository.loadOverridesWithStatus();
      await repository.loadOverridesWithStatus();

      expect(first.failed, isFalse);
      verify(() => collection.get()).called(1);
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}
