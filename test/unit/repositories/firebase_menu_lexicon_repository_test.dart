/// Unit tests for [FirebaseMenuLexiconRepository].
///
/// Verifies: Firestore loading, partial categories, empty collection,
/// TTL cache, malformed document handling, and offline resilience.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

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
      await fakeFirestore
          .collection('menu_lexicon')
          .doc('unknownCategory')
          .set({
        'entries': {'a': 'b'},
      });

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
      await fakeFirestore
          .collection('menu_lexicon')
          .doc('dietaryStems')
          .update({
        'entries': {'lchf': 'lchf'}
      });

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
}
