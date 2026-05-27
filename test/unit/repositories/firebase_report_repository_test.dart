/// Unit tests for [FirebaseReportRepository].
///
/// BUT-815: locks down that `submitReport` writes the report doc and the
/// per-(reporter, contentOwner) throttle sentinel in the SAME batch. The
/// throttle doc is what the BUT-781 Firestore rule consults to enforce the
/// 24h brigade rate limit; if a future refactor splits these writes, the
/// rule's exists()/get() check finds no doc and the limit silently never
/// engages. This test fails fast in that scenario.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/repositories/firebase/firebase_report_repository.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseReportRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseReportRepository repository;

    const reporterId = 'reporter-uid-1';
    const ownerId = 'owner-uid-2';

    setUp(() async {
      await BaseUnitTest.setupUnit();
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: reporterId, isAuthenticated: true);
      repository = FirebaseReportRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    ContentReport buildReport({
      String? contentOwnerId = ownerId,
      String reporter = reporterId,
    }) {
      return ContentReport(
        id: 'unused-client-id', // overwritten by repo (uses doc().id)
        reporterId: reporter,
        contentType: ContentType.recipe,
        contentId: 'recipe-abc',
        contentOwnerId: contentOwnerId,
        reason: 'spam',
        createdAt: DateTime(2026, 5, 8, 10),
      );
    }

    group('BUT-815: submitReport batch + throttle', () {
      // Intent: prove report doc + throttle sentinel both land. If a refactor
      // splits them into separate batches OR drops the throttle write, this
      // test fails. The "same batch" property is implicit — if the report
      // wrote but the throttle didn't, the `await batch.commit()` couldn't
      // have committed both, so both-present == both-batched.
      test('writes report doc AND throttle sentinel under same commit',
          () async {
        final id = await repository.submitReport(buildReport());

        expect(id, isNotNull, reason: 'submitReport should return new doc id');

        final reportSnap =
            await fakeFirestore.collection(FirestoreCollections.reports).get();
        expect(reportSnap.docs, hasLength(1));
        final reportDoc = reportSnap.docs.single;
        expect(reportDoc.id, equals(id));
        expect(reportDoc.data()['reporterId'], equals(reporterId));
        expect(reportDoc.data()['contentOwnerId'], equals(ownerId));
        expect(reportDoc.data()['contentType'], equals('recipe'));

        // Throttle sentinel: users/{reporter}/report_throttle/{ownerId}
        final throttleSnap = await fakeFirestore
            .collection(FirestoreCollections.users)
            .doc(reporterId)
            .collection(FirestoreCollections.userReportThrottle)
            .doc(ownerId)
            .get();
        expect(throttleSnap.exists, isTrue,
            reason: 'BUT-781 throttle sentinel must be written alongside the '
                'report — without this, brigade rate limit silently inactive');
        expect(throttleSnap.data()!.containsKey('lastReportAt'), isTrue,
            reason: 'throttle doc must carry lastReportAt for the rule check');
      });

      test('rejects missing contentOwnerId without writing either doc',
          () async {
        final id =
            await repository.submitReport(buildReport(contentOwnerId: null));

        expect(id, isNull);

        final reportSnap =
            await fakeFirestore.collection(FirestoreCollections.reports).get();
        expect(reportSnap.docs, isEmpty);

        final throttleSnap = await fakeFirestore
            .collection(FirestoreCollections.users)
            .doc(reporterId)
            .collection(FirestoreCollections.userReportThrottle)
            .get();
        expect(throttleSnap.docs, isEmpty,
            reason: 'rejected report must not leak a throttle write');
      });

      test('rejects self-report without writing either doc', () async {
        final id = await repository
            .submitReport(buildReport(contentOwnerId: reporterId));

        expect(id, isNull);

        final reportSnap =
            await fakeFirestore.collection(FirestoreCollections.reports).get();
        expect(reportSnap.docs, isEmpty);

        final throttleSnap = await fakeFirestore
            .collection(FirestoreCollections.users)
            .doc(reporterId)
            .collection(FirestoreCollections.userReportThrottle)
            .get();
        expect(throttleSnap.docs, isEmpty);
      });
    });
  });
}
