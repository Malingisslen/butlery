/// BUT-1815: a revoked person must lose the "Delat med mig" card, whichever of
/// the two writers made the row.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  const me = 'owner-1';
  const recipeId = 'recipe-1';

  late FakeFirebaseFirestore firestore;
  late FirebaseSharedRecipeRepository repository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: me, displayName: 'Owner'),
        userId: me,
        isAuthenticated: true,
      );
    repository = FirebaseSharedRecipeRepository(
      firestore: firestore,
      authRepository: auth,
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<void> seedRow(
    String id, {
    required String recipeKey,
    String sharedBy = me,
    String forRecipe = recipeId,
    List<String> to = const [me, 'anna', 'bo'],
  }) async {
    final ref = firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(id);
    await ref.set({
      'sharedByUserId': sharedBy,
      recipeKey: forRecipe,
      'sharedToUserIds': to,
    });
    for (final uid in to) {
      await ref.collection(FirestoreCollections.members).doc(uid).set({
        'userId': uid,
      });
    }
  }

  Future<List<dynamic>> recipientsOf(String id) async {
    final doc = await firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(id)
        .get();
    return doc.data()!['sharedToUserIds'] as List<dynamic>;
  }

  Future<bool> hasMemberRow(String id, String uid) async {
    final doc = await firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(id)
        .collection(FirestoreCollections.members)
        .doc(uid)
        .get();
    return doc.exists;
  }

  group('removeRecipientsFromOwnShares', () {
    test('trims a row written under originalRecipeId', () async {
      await seedRow('repo-row', recipeKey: 'originalRecipeId');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: ['anna'],
      );

      expect(await recipientsOf('repo-row'), unorderedEquals([me, 'bo']));
    });

    test('trims a row written under recipeId', () async {
      await seedRow('manager-row', recipeKey: 'recipeId');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: ['anna'],
      );

      expect(await recipientsOf('manager-row'), unorderedEquals([me, 'bo']));
    });

    test('trims every row the sender made of the recipe', () async {
      await seedRow('a', recipeKey: 'originalRecipeId');
      await seedRow('b', recipeKey: 'recipeId');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: ['anna', 'bo'],
      );

      expect(await recipientsOf('a'), [me]);
      expect(await recipientsOf('b'), [me]);
    });

    test('deletes the removed person\'s member row only', () async {
      await seedRow('repo-row', recipeKey: 'originalRecipeId');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: ['anna'],
      );

      expect(await hasMemberRow('repo-row', 'anna'), isFalse);
      expect(await hasMemberRow('repo-row', 'bo'), isTrue);
    });

    test('leaves another sender\'s row and other recipes alone', () async {
      await seedRow('theirs', recipeKey: 'recipeId', sharedBy: 'someone-else');
      await seedRow('other', recipeKey: 'recipeId', forRecipe: 'recipe-2');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: ['anna'],
      );

      expect(await recipientsOf('theirs'), contains('anna'));
      expect(await recipientsOf('other'), contains('anna'));
    });

    test('an empty list touches nothing', () async {
      await seedRow('repo-row', recipeKey: 'originalRecipeId');

      await repository.removeRecipientsFromOwnShares(
        recipeId: recipeId,
        userIds: [],
      );

      expect(await recipientsOf('repo-row'), hasLength(3));
    });
  });
}
