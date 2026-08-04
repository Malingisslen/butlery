/// GDPR Article 15 coverage for the shared-recipe / shared-menu legs of
/// [FirebaseDataExportRepository].
///
/// BUT-1775 follow-up, and the same disease as BUT-1697/BUT-1724:
/// `exportSharedMenusReceived` queried the top-level `menus` collection filtered
/// on `sharedToUserIds`. `SharedMenu.toFirestore()` emits neither that field nor
/// `sharedByAvatarUrl`, and both writers into `menus` pass an empty recipient
/// list into a factory that never serialises it — so the query was
/// syntactically perfect, threw nothing, and matched zero documents. Every menu
/// anyone had ever shared with the user was missing from their bundle, and the
/// avatar redaction layered on top of that leg was dead code.
///
/// A repository-level Fake (the shape `social_export_manager_test.dart` uses)
/// cannot see a wrong collection or a wrong filter field — it is handed
/// hand-typed rows. These tests run the REAL repository over a fake Firestore
/// seeded the way PRODUCTION writes, so the reader and the writer have to agree.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — shared content received', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'recipient-1';
    const sharerId = 'sharer-9';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
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

    /// Mirrors what `social_menu_operations.shareMenuWithFriends` and
    /// `recipe_sharing_manager._writeToSharedRecipesCollection` write: a
    /// `shared_content` doc carrying BOTH membership spellings plus the sharer's
    /// avatar URL.
    Future<void> seedShare({
      required String id,
      required String contentType,
      List<String> recipients = const [userId],
    }) => firestore.collection(FirestoreCollections.sharedContent).doc(id).set(
      <String, dynamic>{
        'contentType': contentType,
        'title': 'Delat $contentType',
        'sharedByUserId': sharerId,
        'sharedByDisplayName': 'Vännen',
        'sharedByAvatarUrl': 'https://example.test/sharer.png',
        'sharedToUserIds': recipients,
        'isActive': true,
      },
    );

    test('a menu shared with the user is exported', () async {
      await seedShare(id: 'menu-1', contentType: 'menu');

      final result = await repository.exportSharedMenusReceived(userId);

      expect(
        result.map((e) => e['id']),
        contains('menu-1'),
        reason:
            'shared menus live in shared_content, not in the top-level menus '
            'collection the old query read',
      );
    });

    test('a recipe shared with the user is exported', () async {
      await seedShare(id: 'recipe-1', contentType: 'recipe');

      final result = await repository.exportSharedRecipesReceived(userId);

      expect(result.map((e) => e['id']), contains('recipe-1'));
    });

    /// BUT-1798. The third `contentType` this collection has always carried and
    /// nothing exported. A manager-level Fake cannot stand in for this: it
    /// returns hand-typed rows, so it can never see a wrong collection, a wrong
    /// `contentType` literal or a wrong membership field — and all three are
    /// silent, matching zero documents without throwing. That is exactly how
    /// the menu leg stayed dead for a year.
    test('a shopping list shared with the user is exported', () async {
      await seedShare(id: 'list-1', contentType: 'shopping_list');

      final result = await repository.exportSharedShoppingListsReceived(userId);

      expect(result.map((e) => e['id']), contains('list-1'));
    });

    /// The discriminating negative: the collection the export USED to read.
    /// A `menus` document is not a share record and must never stand in for one.
    test(
      'a top-level menus document is not what the menu leg returns',
      () async {
        await firestore
            .collection(FirestoreCollections.menus)
            .doc('legacy-menu')
            .set(<String, dynamic>{
              'menuTitle': 'Sparad meny',
              'sharedByUserId': sharerId,
              'sharedToUserIds': <String>[userId],
            });

        final result = await repository.exportSharedMenusReceived(userId);

        expect(
          result.map((e) => e['id']),
          isNot(contains('legacy-menu')),
          reason:
              'the old query matched this shape and nothing else — the fix is '
              'worthless if the leg still resolves to that collection',
        );
      },
    );

    test('the legs do not bleed into each other by contentType', () async {
      await seedShare(id: 'menu-1', contentType: 'menu');
      await seedShare(id: 'recipe-1', contentType: 'recipe');
      await seedShare(id: 'list-1', contentType: 'shopping_list');

      final menus = await repository.exportSharedMenusReceived(userId);
      final recipes = await repository.exportSharedRecipesReceived(userId);
      final lists = await repository.exportSharedShoppingListsReceived(userId);

      // Three disjoint single-element results. One assertion kills both a wrong
      // `contentType` literal and a collapse of two legs into one.
      expect(menus.map((e) => e['id']), equals(<String>['menu-1']));
      expect(recipes.map((e) => e['id']), equals(<String>['recipe-1']));
      expect(lists.map((e) => e['id']), equals(<String>['list-1']));
    });

    test('a share addressed to someone else is not exported', () async {
      await seedShare(
        id: 'menu-other',
        contentType: 'menu',
        recipients: const ['someone-else'],
      );

      final result = await repository.exportSharedMenusReceived(userId);

      expect(result, isEmpty);
    });

    /// The row the export has to carry for `_dropSharerAvatar` to have anything
    /// to remove. Before the repoint this was always absent, which is what made
    /// the redaction — and the bundle's `data_minimisation` sentence — vacuous.
    test('the exported row carries the field the redaction targets', () async {
      await seedShare(id: 'menu-1', contentType: 'menu');

      final result = await repository.exportSharedMenusReceived(userId);

      expect(
        (result.single['data'] as Map)['sharedByAvatarUrl'],
        isNotNull,
        reason:
            'the avatar strip is only meaningful if the leg returns documents '
            'that actually carry an avatar URL',
      );
    });
  });
}
