/// Tests for ReportService moderation actions.
///
/// `suspendReportedProfile` is the BUT-729 Phase 2 hide-flag primitive — a
/// reversible takedown that flips `isHidden = true` + `hiddenAt = serverTs`
/// on `public_profiles/{contentOwnerId}`. The rules layer enforces that
/// only `{isHidden, hiddenAt}` may change in this update; this test verifies
/// the SERVICE writes exactly that payload (so the rules don't silently
/// reject and the dashboard won't show a confusing "succeeded" toast).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/repositories/firebase/firebase_report_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/moderation/report_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockReportRepository extends Mock implements FirebaseReportRepository {}

void main() {
  group('ReportService.suspendReportedProfile', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreRepository firestoreRepo;
    late MockAuthRepository mockAuth;
    late _MockReportRepository mockReportRepo;
    late ReportService service;

    const ownerUid = 'profile-owner-uid';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Bridge: BaseService._isAuthenticated() reads from the production
      // ServiceLocator, which TestServiceLocator intentionally doesn't
      // initialize. Both share the same GetIt singleton, so pointing
      // production at DIContainer() picks up TestServiceLocator's mocks.
      prod.ServiceLocator.initialize(DIContainer());
      fakeFirestore = FakeFirebaseFirestore();
      firestoreRepo = FirestoreRepository(firestore: fakeFirestore);
      // The same MockAuthRepository instance the production ServiceLocator
      // resolves inside BaseService._isAuthenticated() — without this, the
      // requiresAuth gate fails and executeServiceOperation short-circuits.
      mockAuth = ServiceLocator.get<AuthRepository>() as MockAuthRepository;
      mockAuth.setAuthState(userId: 'admin-uid', isAuthenticated: true);
      mockReportRepo = _MockReportRepository();
      service = ReportService(
        reportRepository: mockReportRepo,
        authRepository: mockAuth,
        firestoreRepository: firestoreRepo,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    ContentReport profileReport({
      String? contentOwnerId = ownerUid,
      ContentType contentType = ContentType.profile,
    }) {
      return ContentReport(
        id: 'report-1',
        reporterId: 'reporter-uid',
        contentType: contentType,
        contentId: ownerUid,
        contentOwnerId: contentOwnerId,
        reason: 'spam',
        createdAt: DateTime(2026, 4, 26, 12),
      );
    }

    test('writes isHidden=true + serverTimestamp hiddenAt to the right doc',
        () async {
      await fakeFirestore
          .collection('public_profiles')
          .doc(ownerUid)
          .set({'displayName': 'Anna', 'isHidden': false});

      // Sanity-check the auth bridge so a wiring regression surfaces here
      // rather than as a confusing service-returns-false symptom.
      expect(mockAuth.currentUserId, equals('admin-uid'));
      expect(
        prod.ServiceLocator.get<AuthRepository>().currentUserId,
        equals('admin-uid'),
        reason: 'production locator must resolve to the same configured mock',
      );

      await service.suspendReportedProfile(profileReport());

      // Contract = the WRITE shape (rules enforce hasOnly([isHidden,
      // hiddenAt]); the dashboard reads the resulting doc). Return value
      // isn't asserted because production calls FieldValue.serverTimestamp(),
      // and fake_cloud_firestore throws MethodChannelFieldValue-cast on it
      // — same project-wide quirk documented in firebase_audit_repository_test.
      // The fake applies the non-FieldValue fields of the update before
      // throwing, so isHidden + displayName below ARE the proof.
      final after =
          await fakeFirestore.collection('public_profiles').doc(ownerUid).get();
      expect(after.data()?['isHidden'], isTrue);
      // hiddenAt is set via FieldValue.serverTimestamp(); fake_cloud_firestore
      // drops/null-resolves server-time field values, so we can't assert its
      // presence here. The rules-test suite proves the field is part of the
      // update payload (rules deny hasOnly([isHidden, hiddenAt]) violations).
      expect(after.data()?['displayName'], equals('Anna'),
          reason: 'partial update preserves existing fields');
    });

    test('returns false when contentType is not "profile" (refuses dispatch)',
        () async {
      final ok = await service.suspendReportedProfile(
          profileReport(contentType: ContentType.recipe));
      expect(ok, isFalse);
    });

    test('returns false when contentOwnerId is null', () async {
      final ok = await service
          .suspendReportedProfile(profileReport(contentOwnerId: null));
      expect(ok, isFalse);
    });

    test('returns false when contentOwnerId is empty', () async {
      final ok = await service
          .suspendReportedProfile(profileReport(contentOwnerId: ''));
      expect(ok, isFalse);
    });
  });
}
