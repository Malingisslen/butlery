import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_search_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// BUT-840: user search must read the canonical `public_profiles` doc (kept
/// fresh on every profile save, including rename), not the bare `users/{uid}`
/// root doc — which never carries displayName/avatarUrl. These tests pin that
/// contract: search returns fresh names, respects the `isSearchable` toggle,
/// excludes moderation-hidden profiles, and maps the count fields correctly.
void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSearchRepository repo;

  Future<void> seedProfile(
    String uid, {
    required String displayName,
    bool isSearchable = true,
    bool isHidden = false,
    String? avatarUrl,
    int publicRecipeCount = 0,
    int friendsCount = 0,
  }) {
    return firestore
        .collection(FirestoreCollections.publicProfiles)
        .doc(uid)
        .set({
          'displayName': displayName,
          'isSearchable': isSearchable,
          'isHidden': isHidden,
          'avatarUrl': avatarUrl,
          'publicRecipeCount': publicRecipeCount,
          'friendsCount': friendsCount,
        });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSearchRepository(firestore: firestore);
  });

  test(
    'returns a searchable profile by name with mapped count fields',
    () async {
      await seedProfile(
        'u1',
        displayName: 'Anna',
        avatarUrl: 'a.png',
        publicRecipeCount: 5,
        friendsCount: 3,
      );

      final result = await repo.searchUsers('anna');

      expect(result.hits, hasLength(1));
      final hit = result.hits.single;
      expect(hit.id, 'u1');
      expect(hit.displayName, 'Anna');
      expect(hit.avatarUrl, 'a.png');
      expect(
        hit.recipeCount,
        5,
        reason: 'maps publicRecipeCount → recipeCount',
      );
      expect(hit.followerCount, 3, reason: 'maps friendsCount → followerCount');
    },
  );

  test(
    'reflects a renamed display name (the BUT-840 freshness contract)',
    () async {
      await seedProfile('u1', displayName: 'Anna');

      expect((await repo.searchUsers('anna')).hits.single.displayName, 'Anna');

      // Simulate a profile rename writing the canonical public_profiles doc.
      await firestore
          .collection(FirestoreCollections.publicProfiles)
          .doc('u1')
          .update({'displayName': 'Annika'});

      final afterRename = await repo.searchUsers('annika');
      expect(afterRename.hits, hasLength(1));
      expect(
        afterRename.hits.single.displayName,
        'Annika',
        reason: 'search reads the canonical doc, so the new name is returned',
      );
      // The old name no longer matches.
      expect((await repo.searchUsers('anna xyz')).hits, isEmpty);
    },
  );

  test('excludes a profile that is not searchable', () async {
    await seedProfile('u1', displayName: 'Hidden Hanna', isSearchable: false);

    expect((await repo.searchUsers('hanna')).hits, isEmpty);
  });

  test('excludes a moderation-hidden profile even when searchable', () async {
    await seedProfile(
      'u1',
      displayName: 'Banned Bert',
      isSearchable: true,
      isHidden: true,
    );

    expect((await repo.searchUsers('bert')).hits, isEmpty);
  });

  test('empty query returns all searchable, non-hidden profiles', () async {
    await seedProfile('u1', displayName: 'Anna');
    await seedProfile('u2', displayName: 'Bob');
    await seedProfile('u3', displayName: 'Private Pim', isSearchable: false);
    await seedProfile('u4', displayName: 'Hidden Hal', isHidden: true);

    final result = await repo.searchUsers('');

    expect(
      result.hits.map((h) => h.displayName),
      unorderedEquals(['Anna', 'Bob']),
    );
  });
}
