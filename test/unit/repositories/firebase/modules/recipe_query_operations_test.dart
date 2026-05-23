/// Unit tests for RecipeQueryOperations.
///
/// Three thin "find recipes by X" query wrappers — by personalTagId, by
/// sourceUrl, by titleLower. All depend only on `getCollectionForUser`
/// and a `fromFirestore` factory, so we drive them end-to-end against
/// `FakeFirebaseFirestore`. Tests pin the short-circuit guards
/// (null userId / empty input), the limit cap, and the
/// title-normalization (trim + lowercase) contract.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/modules/recipe_query_operations.dart';

const _userId = 'alice';

CollectionReference<Map<String, dynamic>> _userRecipes(
        FakeFirebaseFirestore firestore, String uid) =>
    firestore.collection('users').doc(uid).collection('recipes');

Recipe _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final core = (doc.data()?['core'] as Map?) ?? const {};
  return Recipe(
    core: RecipeCore(
      id: doc.id,
      title: core['title'] as String? ?? '',
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    type: RecipeType.personal,
  );
}

RecipeQueryOperations _ops(FakeFirebaseFirestore firestore) {
  return RecipeQueryOperations(
    getCollectionForUser: (uid) => _userRecipes(firestore, uid),
    fromFirestore: _fromFirestore,
  );
}

Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  required String id,
  String? title,
  String? titleLower,
  String? sourceUrl,
  List<String> tagIds = const [],
  DateTime? updatedAt,
}) async {
  await _userRecipes(firestore, _userId).doc(id).set({
    'core': {
      'title': title ?? id,
      if (titleLower != null) 'titleLower': titleLower,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      'personalTagIds': tagIds,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.utc(2026, 1, 1)),
    },
  });
}

void main() {
  group('fetchRecipesByTagId', () {
    test('returns empty list when userId is null', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).fetchRecipesByTagId(null, 'tag-a'), isEmpty);
    });

    test('returns recipes carrying the tag, newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore,
          id: 'r1', tagIds: ['tag-a'], updatedAt: DateTime.utc(2026, 1, 1));
      await _seed(firestore,
          id: 'r2',
          tagIds: ['tag-a', 'tag-b'],
          updatedAt: DateTime.utc(2026, 1, 3));
      await _seed(firestore,
          id: 'r3', tagIds: ['tag-b'], updatedAt: DateTime.utc(2026, 1, 2));

      final result =
          await _ops(firestore).fetchRecipesByTagId(_userId, 'tag-a');
      expect(result.map((r) => r.id), ['r2', 'r1']);
    });

    test('honours the limit cap', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 5; i++) {
        await _seed(firestore,
            id: 'r$i',
            tagIds: ['tag-a'],
            updatedAt: DateTime.utc(2026, 1, 1 + i));
      }
      final result =
          await _ops(firestore).fetchRecipesByTagId(_userId, 'tag-a', limit: 2);
      expect(result, hasLength(2));
    });

    test('returns empty list when no recipes carry the tag', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'r1', tagIds: ['tag-x']);
      expect(
        await _ops(firestore).fetchRecipesByTagId(_userId, 'missing'),
        isEmpty,
      );
    });
  });

  group('findBySourceUrl', () {
    test('returns empty list when url is empty', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).findBySourceUrl(_userId, ''), isEmpty);
    });

    test('returns empty list when userId is null', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).findBySourceUrl(null, 'https://x.example'),
          isEmpty);
    });

    test('returns only exact-url matches', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'r1', sourceUrl: 'https://x.example/a');
      await _seed(firestore, id: 'r2', sourceUrl: 'https://x.example/a');
      await _seed(firestore, id: 'r3', sourceUrl: 'https://other.example');

      final result =
          await _ops(firestore).findBySourceUrl(_userId, 'https://x.example/a');
      expect(result.map((r) => r.id).toSet(), {'r1', 'r2'});
    });

    test('caps at 5 results', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 7; i++) {
        await _seed(firestore, id: 'r$i', sourceUrl: 'https://same.example');
      }
      final result = await _ops(firestore)
          .findBySourceUrl(_userId, 'https://same.example');
      expect(result, hasLength(5));
    });
  });

  group('findByTitle', () {
    test('returns empty list when title is empty', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).findByTitle(_userId, ''), isEmpty);
    });

    test('returns empty list when title is whitespace-only', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).findByTitle(_userId, '   '), isEmpty);
    });

    test('returns empty list when userId is null', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _ops(firestore).findByTitle(null, 'pasta'), isEmpty);
    });

    test('matches normalized (trim + lowercase) titleLower', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'r1', title: 'Pasta', titleLower: 'pasta');
      await _seed(firestore, id: 'r2', title: 'Soup', titleLower: 'soup');

      // Caller passes ' PASTA ' — module trims + lowercases → 'pasta'.
      final result = await _ops(firestore).findByTitle(_userId, '  PASTA  ');
      expect(result.map((r) => r.id), ['r1']);
    });

    test('caps at 5 results', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 7; i++) {
        await _seed(firestore, id: 'r$i', title: 'Pasta', titleLower: 'pasta');
      }
      final result = await _ops(firestore).findByTitle(_userId, 'pasta');
      expect(result, hasLength(5));
    });

    test('no match returns empty list', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, id: 'r1', titleLower: 'soup');
      expect(
        await _ops(firestore).findByTitle(_userId, 'pasta'),
        isEmpty,
      );
    });
  });
}
