/// FirebaseMenuCollaborationRepository: who a collaborative menu edit is
/// attributed to (BUT-2009).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_menu_collaboration_repository.dart';
import 'package:butlery/services/attribution_source.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  const userId = 'user-123';
  const menuId = 'menu-1';

  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late FirebaseMenuCollaborationRepository repository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository();
    // The Auth account carries a DIFFERENT name from the profile, so a writer
    // pointed back at Auth stores the wrong one.
    auth.setAuthState(
      user: FakeUser(uid: userId, displayName: 'Google Anna'),
      userId: userId,
      isAuthenticated: true,
    );
    final userService = MockUserService();
    when(() => userService.attributionDisplayName).thenReturn('Profil Anna');

    repository = FirebaseMenuCollaborationRepository(
      firestore: firestore,
      authRepository: auth,
      attribution: AttributionSource(userService: () => userService),
    );

    await firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(menuId)
        .set({
          'sharedByUserId': userId,
          'allowCollaboration': true,
          'sharedToUserIds': <String>[],
          'collaboratorIds': <String>[],
          'menuSnapshot': {'Måndag': <Map<String, dynamic>>[]},
        });
  });

  Future<Map<String, dynamic>> menuDoc() async =>
      (await firestore
              .collection(FirestoreCollections.sharedContent)
              .doc(menuId)
              .get())
          .data()!;

  test('addRecipeToMenu stamps the PROFILE name as last editor', () async {
    final ok = await repository.addRecipeToMenu(
      menuId: menuId,
      category: 'Måndag',
      recipe: RecipeFactory.build(id: 'r1'),
    );

    expect(ok, isTrue);
    final data = await menuDoc();
    expect(data['lastUpdatedBy'], userId);
    expect(data['lastUpdatedByDisplayName'], 'Profil Anna');
  });

  test('removeRecipeFromMenu stamps the PROFILE name as last editor', () async {
    await repository.addRecipeToMenu(
      menuId: menuId,
      category: 'Måndag',
      recipe: RecipeFactory.build(id: 'r1'),
    );
    // Overwrite the stamp so the assertion measures the removal's own write.
    await firestore
        .collection(FirestoreCollections.sharedContent)
        .doc(menuId)
        .update({'lastUpdatedByDisplayName': 'stale'});

    final ok = await repository.removeRecipeFromMenu(
      menuId: menuId,
      category: 'Måndag',
      recipeId: 'r1',
    );

    expect(ok, isTrue);
    expect((await menuDoc())['lastUpdatedByDisplayName'], 'Profil Anna');
  });

  test('a signed-out caller writes nothing and gets false', () async {
    // Positive control: the same call lands while signed in.
    expect(
      await repository.addRecipeToMenu(
        menuId: menuId,
        category: 'Måndag',
        recipe: RecipeFactory.build(id: 'r1'),
      ),
      isTrue,
    );
    final before = await menuDoc();

    auth.setAuthState(user: null, userId: null, isAuthenticated: false);

    expect(
      await repository.addRecipeToMenu(
        menuId: menuId,
        category: 'Måndag',
        recipe: RecipeFactory.build(id: 'r2'),
      ),
      isFalse,
    );
    expect(
      await repository.removeRecipeFromMenu(
        menuId: menuId,
        category: 'Måndag',
        recipeId: 'r1',
      ),
      isFalse,
    );
    expect(
      await repository.enableCollaboration(
        menuId: menuId,
        collaboratorIds: const ['intruder'],
      ),
      isFalse,
    );
    expect(await menuDoc(), before);
  });
}
