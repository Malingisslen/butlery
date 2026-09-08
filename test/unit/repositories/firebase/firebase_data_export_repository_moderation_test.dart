/// The moderation-counter projection in [FirebaseDataExportRepository]
/// (BUT-2046 follow-up, 2026-09-08).
///
/// Written because three commit gates independently found the same hole: every
/// test of this section faked the REPOSITORY method, so the allowlist inside it
/// was executed by nothing and `return raw;` left both suites green.
///
/// Backed by `FakeFirebaseFirestore` rather than a fake repository, for the
/// same reason `chat_group_export_test.dart` is: a projection can only be
/// proven against a document that carries MORE than the projection keeps.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository.exportModerationCounters', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'user-requester';
    const reporterUid = 'user-who-reported-them';

    final lastReportedAt = DateTime.utc(2026, 4, 5, 6, 7, 8);

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

    Future<void> seed(Map<String, dynamic> data) => firestore
        .collection(FirestoreCollections.userModeration)
        .doc(userId)
        .set(data);

    test('keeps the two counters and drops everything else', () async {
      await seed({
        'totalReports': 3,
        'lastReportedAt': Timestamp.fromDate(lastReportedAt),
        // A field nobody has decided about.
        'internalRiskScore': 0.92,
        // The legacy shape, each entry naming another person.
        'reportHistory': [
          {'reportId': 'r1', 'reporterId': reporterUid, 'reason': 'spam'},
        ],
      });

      final result = await repository.exportModerationCounters(userId);

      // EXACT key set, not `contains`: the section is a projection by
      // decision, so widening it should have to be a deliberate edit here.
      expect(result!.keys.toSet(), {'totalReports', 'lastReportedAt'});
      expect(result['totalReports'], 3);
    });

    test('omits a counter the document does not carry', () async {
      await seed({'totalReports': 1});

      final result = await repository.exportModerationCounters(userId);

      // `containsKey`, not a null check: a present-but-null key would claim
      // the document holds a value it does not.
      expect(result!.containsKey('lastReportedAt'), isFalse);
      expect(result.keys.toSet(), {'totalReports'});
    });

    test('a user who has never been reported gets null', () async {
      final result = await repository.exportModerationCounters(userId);
      expect(result, isNull);
    });

    test('refuses to read another person\'s record', () async {
      await seed({'totalReports': 3});
      // The rules limb denies this too, but the repository must not depend on
      // rules to be the only control — this guard runs before the read.
      await expectLater(
        repository.exportModerationCounters('somebody-else'),
        throwsA(anything),
      );
    });
  });
}
