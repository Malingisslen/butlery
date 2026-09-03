/// GDPR Article 15 coverage for the `users/{uid}` subcollections BUT-1957 added
/// to the deletion cascade and BUT-1992 added to the export.
///
/// Until this landed, the live-writer collections were erased on
/// account deletion having never been obtainable by their subject first. Which
/// of them belong in the bundle was decided collection by collection by Malin on
/// 2026-09-03 — `ingredients`, `onboarding` and `acquisition` are exported;
/// `rate_limits` and `counters` are exempt on her call, and `report_throttle`
/// because the reports themselves are exported — without having been one of
/// her questions. See `docs/org/adr/ADR-0011`.
///
/// The invariant itself (EXPORT ⊇ DELETION, so this can never silently drift
/// again) is held on the server side by
/// `scenario_exportCoversEveryDeletedSubcollection`. This file proves the reads
/// it discovers actually return the owner's rows and nobody else's.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — account subcollections (BUT-1992)', () {
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

    test('ingredients: the owner gets their library, nobody else\'s', () async {
      await seed(userId, FirestoreCollections.ingredients, 'saffran');
      await seed(userId, FirestoreCollections.ingredients, 'kanel');
      await seed(other, FirestoreCollections.ingredients, 'saffran');

      final rows = await repository.exportUserIngredients(userId);

      expect(rows, hasLength(2));
      expect(
        rows.map((r) => (r['data'] as Map)['marker']),
        everyElement(startsWith('$userId/')),
      );
    });

    test('onboarding: the owner gets their progress', () async {
      await seed(userId, FirestoreCollections.userOnboarding, 'progress');
      await seed(other, FirestoreCollections.userOnboarding, 'progress');

      final rows = await repository.exportOnboardingProgress(userId);

      expect(rows, hasLength(1));
      expect(
        (rows.single['data'] as Map)['marker'],
        '$userId/onboarding/progress',
      );
    });

    test('acquisition: the attribution row is exported unprojected', () async {
      await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userAcquisition)
          .doc('current')
          .set({
            'source': 'instagram',
            'medium': 'social',
            'campaign': 'host-hostmat-2026',
            'firstSeenAt': 'stamp',
          });

      final rows = await repository.exportAcquisition(userId);

      // Malin's explicit call 2026-09-03: unprojected. The campaign name is the
      // field the product seat wanted dropped and she chose to keep, so pinning
      // it by name is what stops a later "tidy-up" from quietly reversing her.
      expect(rows, hasLength(1));
      final data = rows.single['data'] as Map;
      expect(data['source'], 'instagram');
      expect(data['campaign'], 'host-hostmat-2026');
    });

    // Without these, deleting `_guardSelfExport` from all three methods leaves
    // the suite green: every other assertion here is satisfied by the
    // uid-scoped path alone, so the path proves routing and nothing proves the
    // ownership check still runs.
    test('exporting ANOTHER user is refused, not merely empty', () async {
      await seed(other, FirestoreCollections.ingredients, 'saffran');
      await seed(other, FirestoreCollections.userOnboarding, 'progress');
      await seed(other, FirestoreCollections.userAcquisition, 'current');

      await expectLater(
        () => repository.exportUserIngredients(other),
        throwsA(anything),
      );
      await expectLater(
        () => repository.exportOnboardingProgress(other),
        throwsA(anything),
      );
      await expectLater(
        () => repository.exportAcquisition(other),
        throwsA(anything),
      );
      await expectLater(
        () => repository.exportUserSettings(other),
        throwsA(anything),
      );
    });

    test('a user with nothing gets empty lists, not errors', () async {
      expect(await repository.exportUserIngredients(userId), isEmpty);
      expect(await repository.exportOnboardingProgress(userId), isEmpty);
      expect(await repository.exportAcquisition(userId), isEmpty);
    });

    test('every new read honours its cap', () async {
      for (var i = 0; i < 5; i++) {
        await seed(userId, FirestoreCollections.ingredients, 'i$i');
      }
      expect(
        await repository.exportUserIngredients(userId, maxDocuments: 3),
        hasLength(3),
      );
    });

    // BUT-1992: `deleteUserPreferences` sweeps the WHOLE `settings` collection
    // (BUT-1957), while the export read `settings/preferences` by id — so a
    // second settings document was erasable but not exportable, and
    // `firestore.rules` leaves the id unconstrained on an owner-only create.
    test('settings: the whole collection, not just preferences', () async {
      await seed(userId, FirestoreCollections.userSettings, 'preferences');
      await seed(userId, FirestoreCollections.userSettings, 'experimental');
      await seed(other, FirestoreCollections.userSettings, 'preferences');

      final rows = await repository.exportUserSettings(userId);

      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r['id']),
        containsAll(<String>['preferences', 'experimental']),
      );
    });
  });
}
