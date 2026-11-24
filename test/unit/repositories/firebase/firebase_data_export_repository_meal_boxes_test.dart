/// GDPR Article 15 coverage for `users/{uid}/meal_boxes` (BUT-2486 part 5): the
/// real export repository over a fake Firestore, driven through the real
/// section manager, so the path, the ownership guard, the cap of 200 and the
/// manager's wiring of both are each pinned by something that would redden.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';
import 'package:butlery/services/account/export/preferences_export_manager.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository meal boxes (BUT-2486 part 5)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'user-abc';
    const other = 'user-other';

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

    Future<void> seed(String owner, String collection, String id) => firestore
        .collection(FirestoreCollections.users)
        .doc(owner)
        .collection(collection)
        .doc(id)
        .set({'marker': '$owner/$collection/$id'});

    test('the owner gets their boxes, not another user\'s and not the '
        'neighbouring trash', () async {
      await seed(userId, FirestoreCollections.mealBoxes, 'box-a');
      await seed(userId, FirestoreCollections.mealBoxes, 'box-b');
      await seed(other, FirestoreCollections.mealBoxes, 'box-a');
      await seed(userId, FirestoreCollections.userTrash, 'decoy');

      final rows = await repository.exportMealBoxes(userId);

      expect(rows.map((r) => r['id']).toSet(), {'box-a', 'box-b'});
      expect(
        rows.map((r) => (r['data'] as Map)['marker']),
        everyElement(startsWith('$userId/meal_boxes/')),
      );
      await expectLater(
        () => repository.exportMealBoxes(other),
        throwsA(anything),
      );
    });

    test('an empty collection is an empty list, not an error', () async {
      expect(await repository.exportMealBoxes(userId), isEmpty);
    });

    test('the cap is 200', () {
      expect(ExportPaginationHelper.exportLimits['user_meal_boxes'], 200);
    });

    test('the section ships the boxes and flags a read past 200 as '
        'truncated, so the manager names the cap type that binds', () async {
      for (var i = 0; i < 201; i++) {
        await seed(userId, FirestoreCollections.mealBoxes, 'box-$i');
      }
      final manager = PreferencesExportManager(
        dataExportRepository: repository,
      );

      final result = await manager.exportAccountSubcollections(userId);

      expect((result['meal_boxes'] as List), hasLength(200));
      expect(result['meal_boxes_truncated'], isTrue);
    });

    test(
      'exactly 200 boxes is a complete section, not a truncated one',
      () async {
        for (var i = 0; i < 200; i++) {
          await seed(userId, FirestoreCollections.mealBoxes, 'box-$i');
        }
        final manager = PreferencesExportManager(
          dataExportRepository: repository,
        );

        final result = await manager.exportAccountSubcollections(userId);

        expect((result['meal_boxes'] as List), hasLength(200));
        expect(result.containsKey('meal_boxes_truncated'), isFalse);
      },
    );
  });
}
