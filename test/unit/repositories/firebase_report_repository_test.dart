/// Unit tests for [FirebaseReportRepository].
///
/// BUT-815: locks down that `submitReport` writes the report doc and the
/// per-(reporter, contentOwner) throttle sentinel in the SAME batch. The
/// throttle doc is what the BUT-781 Firestore rule consults to enforce the
/// 24h brigade rate limit; if a future refactor splits these writes, the
/// rule's exists()/get() check finds no doc and the limit silently never
/// engages. This test fails fast in that scenario.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_reason.dart';
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
      String id = '',
    }) {
      return ContentReport(
        id: id,
        reporterId: reporter,
        contentType: ContentType.recipe,
        contentId: 'recipe-abc',
        contentOwnerId: contentOwnerId,
        reason: ReportReason.spam.wireName,
        createdAt: DateTime(2026, 5, 8, 10),
      );
    }

    group('BUT-2154: report id chosen by the caller', () {
      Future<List<String>> reportIds() async =>
          (await fakeFirestore.collection(FirestoreCollections.reports).get())
              .docs
              .map((d) => d.id)
              .toList();

      test('writes the report under the id it was given', () async {
        final id = await repository.submitReport(buildReport(id: 'minted-1'));

        expect(id, 'minted-1');
        expect(await reportIds(), ['minted-1']);
      });

      test('a second submit with the same id leaves one report', () async {
        await repository.submitReport(buildReport(id: 'minted-1'));
        await repository.submitReport(buildReport(id: 'minted-1'));

        expect(await reportIds(), ['minted-1']);
      });

      test('an empty id still gets an auto id', () async {
        final id = await repository.submitReport(buildReport());

        expect(id, isNotEmpty);
        expect(await reportIds(), [id]);
      });

      test('newReportId returns distinct ids and writes nothing', () async {
        final a = repository.newReportId();
        final b = repository.newReportId();

        expect(a, isNotEmpty);
        expect(a, isNot(b));
        expect(await reportIds(), isEmpty);
      });
    });

    group('BUT-2154: a refused write under an id already filed', () {
      // The rules refuse a retry under the same id (the emulator suite pins
      // that in reports-rules.test.ts); the fake does not enforce rules, so
      // the refusal is staged by a batch whose commit throws.
      late _RefusingFirestore refusing;

      setUp(() {
        refusing = _RefusingFirestore();
        repository = FirebaseReportRepository(
          firestore: refusing,
          authRepository: mockAuth,
          timestampProvider: const TestTimestampProvider(),
        );
      });

      test('counts as sent when the report is already there', () async {
        await refusing
            .collection(FirestoreCollections.reports)
            .doc('report-1')
            .set({'reporterId': reporterId});

        final id = await repository.submitReport(buildReport(id: 'report-1'));

        expect(id, 'report-1');
      });

      test('fails when the report is not there', () async {
        final id = await repository.submitReport(buildReport(id: 'report-2'));

        expect(id, isNull);
      });

      // Under the real rules a reporter cannot read a report that does not
      // exist, so the read-back is refused rather than answering "missing".
      test('fails when the read-back is refused too', () async {
        refusing.refuseReportReads = true;

        final id = await repository.submitReport(buildReport(id: 'report-3'));

        expect(id, isNull);
        expect(refusing.refusedReads, 1);
      });
    });

    group('BUT-815: submitReport batch + throttle', () {
      // Intent: prove report doc + throttle sentinel both land. If a refactor
      // splits them into separate batches OR drops the throttle write, this
      // test fails. The "same batch" property is implicit — if the report
      // wrote but the throttle didn't, the `await batch.commit()` couldn't
      // have committed both, so both-present == both-batched.
      test(
        'writes report doc AND throttle sentinel under same commit',
        () async {
          final id = await repository.submitReport(buildReport());

          expect(
            id,
            isNotNull,
            reason: 'submitReport should return new doc id',
          );

          final reportSnap = await fakeFirestore
              .collection(FirestoreCollections.reports)
              .get();
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
          expect(
            throttleSnap.exists,
            isTrue,
            reason:
                'BUT-781 throttle sentinel must be written alongside the '
                'report — without this, brigade rate limit silently inactive',
          );
          expect(
            throttleSnap.data()!.containsKey('lastReportAt'),
            isTrue,
            reason: 'throttle doc must carry lastReportAt for the rule check',
          );
        },
      );

      test(
        'rejects missing contentOwnerId without writing either doc',
        () async {
          final id = await repository.submitReport(
            buildReport(contentOwnerId: null),
          );

          expect(id, isNull);

          final reportSnap = await fakeFirestore
              .collection(FirestoreCollections.reports)
              .get();
          expect(reportSnap.docs, isEmpty);

          final throttleSnap = await fakeFirestore
              .collection(FirestoreCollections.users)
              .doc(reporterId)
              .collection(FirestoreCollections.userReportThrottle)
              .get();
          expect(
            throttleSnap.docs,
            isEmpty,
            reason: 'rejected report must not leak a throttle write',
          );
        },
      );

      test('rejects self-report without writing either doc', () async {
        final id = await repository.submitReport(
          buildReport(contentOwnerId: reporterId),
        );

        expect(id, isNull);

        final reportSnap = await fakeFirestore
            .collection(FirestoreCollections.reports)
            .get();
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

class _RefusingBatch extends Mock implements WriteBatch {
  @override
  Future<void> commit() async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );
}

class _RefusingFirestore extends FakeFirebaseFirestore {
  bool refuseReportReads = false;
  int refusedReads = 0;
  int _reportCollectionCalls = 0;

  @override
  WriteBatch batch() => _RefusingBatch();

  // The first call builds the write's ref; a later one is the read-back,
  // refused here the way the rules refuse it.
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (refuseReportReads &&
        path == FirestoreCollections.reports &&
        _reportCollectionCalls++ > 0) {
      refusedReads++;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return super.collection(path);
  }
}
