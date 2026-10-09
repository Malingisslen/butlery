/// FirebaseMenuCollaborationRepository: signed-out callers write nothing.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_menu_collaboration_repository.dart';

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
    auth.setAuthState(
      user: FakeUser(uid: userId, displayName: 'Google Anna'),
      userId: userId,
      isAuthenticated: true,
    );
    repository = FirebaseMenuCollaborationRepository(
      firestore: firestore,
      authRepository: auth,
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

  test('a signed-out caller writes nothing and gets false', () async {
    // Positive control: the same call lands while signed in.
    expect(
      await repository.enableCollaboration(
        menuId: menuId,
        collaboratorIds: const ['friend'],
      ),
      isTrue,
    );
    final before = await menuDoc();

    auth.setAuthState(user: null, userId: null, isAuthenticated: false);

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
