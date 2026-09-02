/// GDPR Article 15 coverage for the device-token leg of
/// [FirebaseDataExportRepository].
///
/// BUT-1990: two readers stood here and NEITHER could ever return a row, so the
/// export's `fcm_tokens` section was empty for every user who had ever
/// registered a device, and `notification_preferences` reported
/// `fcm_token_registered: false` for all of them.
///
///   * one asked for `users/{uid}/fcm_tokens` — a subcollection no writer in
///     `lib/` or `functions/src/` has ever written, and which `firestore.rules`
///     grants no read on, so it was denied as well as empty;
///   * the other asked for `user_fcm_tokens/{uid}` by document id, but the id
///     is `{userId}_{deviceId}` (see the rules block and
///     `FirebaseDeviceRepository`), so it missed every real document.
///
/// The decisive fixture is therefore the DOC ID: it is deliberately not the
/// bare uid, because a fixture keyed on the uid would pass under the old
/// doc-id reader and prove nothing.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — FCM tokens (BUT-1990)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'user-abc';

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

    /// Mirrors the shape `FirebaseDeviceRepository` writes: a per-device
    /// document whose id is `{userId}_{deviceId}` and which carries the owner
    /// in a `userId` FIELD. The field is what both the read rule and the
    /// deletion cascade match on.
    Future<void> seedDevice(String deviceId, {String owner = userId}) =>
        firestore
            .collection(FirestoreCollections.userFcmTokens)
            .doc('${owner}_$deviceId')
            .set({
              'userId': owner,
              'token': 'tok-$deviceId',
              'isActive': true,
            });

    test('returns every device the user has registered', () async {
      await seedDevice('pixel');
      await seedDevice('ipad');

      final rows = await repository.exportFcmTokensForUser(userId);

      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r['token']),
        containsAll(<String>['tok-pixel', 'tok-ipad']),
      );
    });

    test('does not return another user\'s device', () async {
      await seedDevice('pixel');
      await seedDevice('pixel', owner: 'user-other');

      final rows = await repository.exportFcmTokensForUser(userId);

      expect(rows, hasLength(1));
      expect(rows.single['token'], 'tok-pixel');
      expect(rows.single['userId'], userId);
    });

    test('a user with no devices gets an empty list, not an error', () async {
      expect(await repository.exportFcmTokensForUser(userId), isEmpty);
    });

    test('honours the row cap', () async {
      for (var i = 0; i < 5; i++) {
        await seedDevice('d$i');
      }

      final rows = await repository.exportFcmTokensForUser(
        userId,
        maxDocuments: 3,
      );

      expect(rows, hasLength(3));
    });
  });
}
