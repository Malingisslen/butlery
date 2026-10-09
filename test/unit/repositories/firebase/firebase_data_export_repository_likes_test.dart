/// `FirebaseDataExportRepository.exportLikesByUser` (BUT-2114): the likes
/// collection-group read behind the Art. 15 `comment_likes` section.
///
/// Backed by `FakeFirebaseFirestore`, because the two things worth proving
/// live in the repository and not in the manager that consumes it: the
/// `userId` filter on a collection GROUP (the collection name `likes` is shared
/// by every parent), and the parent derivation from the document path.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository.exportLikesByUser', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;

    const userId = 'user-requester';
    const otherUid = 'user-someone-else';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'returns only the requester\'s likes, each naming its parent',
      () async {
        await firestore.doc('recipe_comments/c1/likes/$userId').set({
          'userId': userId,
          'likedAt': 'when-1',
        });
        await firestore.doc('recipe_comments/c1/likes/$otherUid').set({
          'userId': otherUid,
          'likedAt': 'when-2',
        });
        await firestore.doc('recipe_comments/c2/likes/$userId').set({
          'userId': userId,
          'likedAt': 'when-3',
        });

        final rows = await repository.exportLikesByUser(userId);

        expect(rows, hasLength(2));
        expect(
          rows.map((r) => r['parent_id']),
          unorderedEquals(['c1', 'c2']),
        );
        expect(
          rows.every((r) => r['parent_collection'] == 'recipe_comments'),
          isTrue,
        );
        final first = rows.firstWhere((r) => r['parent_id'] == 'c1');
        expect(first['data'], {'userId': userId, 'likedAt': 'when-1'});
      },
    );

    test(
      'a like under another top-level collection names that collection',
      () async {
        await firestore.doc('recipes/r1/likes/$userId').set({'userId': userId});

        final rows = await repository.exportLikesByUser(userId);

        expect(rows.single['parent_collection'], 'recipes');
        expect(rows.single['parent_id'], 'r1');
      },
    );

    test('a like whose parent is nested below the top level has no '
        'collection, so it can never match a top-level name', () async {
      // `recipe_comments/c1/replies/x/likes/<uid>`: the parent's collection is
      // `replies`, which is not top-level.
      await firestore.doc('recipe_comments/c1/replies/x/likes/$userId').set({
        'userId': userId,
      });

      final rows = await repository.exportLikesByUser(userId);

      expect(rows.single['parent_id'], 'x');
      expect(rows.single['parent_collection'], isNull);
    });

    test('forwards the cap as the query limit', () async {
      for (var i = 0; i < 4; i++) {
        await firestore.doc('recipe_comments/c$i/likes/$userId').set({
          'userId': userId,
        });
      }

      final rows = await repository.exportLikesByUser(userId, maxDocuments: 3);

      expect(rows, hasLength(3));
    });

    test('a user with no likes gets an empty list', () async {
      await firestore.doc('recipe_comments/c1/likes/$otherUid').set({
        'userId': otherUid,
      });

      expect(await repository.exportLikesByUser(userId), isEmpty);
    });

    test('refuses to read another user\'s likes', () async {
      await expectLater(
        repository.exportLikesByUser(otherUid),
        throwsA(anything),
      );
    });
  });
}
