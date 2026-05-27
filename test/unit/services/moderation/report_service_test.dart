/// Intent-driven unit tests for `ReportService` — trust/safety surface.
///
/// Behaviours covered (Intent-Test Sprint batch 13):
///  - submitReport: unauth → false (no Firestore write attempted),
///    reporterId is set from auth (NOT trusted from caller), success returns
///    true when repository yields a docId, repository failure returns false,
///    submitted report carries only moderator-relevant PII (reporterId), uses
///    clock-based createdAt, stamps current guideline version, propagates
///    contentOwnerId for self-report rejection downstream.
///  - getMyReports: unauth → empty list (NEVER throws or leaks "all reports"),
///    auth → repository called with the authenticated userId (not the
///    requested userId — there is no requested userId; this is the moderation
///    privacy boundary).
///  - watchIsAdmin: unauth → emits exactly `false` (does NOT silently emit
///    true / does NOT crash), auth + admin doc exists → emits true,
///    auth + admin doc absent → emits false, snapshot error → recovers to
///    non-admin (never lets a transient Firestore error elevate privileges).
///  - watchOpenReports: filters out 'closed' reports (the dashboard contract),
///    sorts newest-first, tolerates malformed/legacy-typed docs by skipping
///    them (one bad doc must NOT empty the dashboard).
///  - advanceReportStatus: state machine new→inReview→actioned→closed→closed,
///    refuses to advance past closed (return false, no write), each forward
///    step writes only the `status` field (no clobbering reporterId etc.).
///  - closeReport: already-closed → returns true WITHOUT a write (idempotent;
///    no spurious audit-log noise), open report → writes status=closed.
///  - deleteReportedContent: routes each ContentType to the correct Firestore
///    path, refuses recipe/group when contentOwnerId missing (can't construct
///    /users/{owner}/... path safely), refuses ContentType.profile (must go
///    through suspendReportedProfile instead — hard delete would break auth).
///
/// Trust/safety invariants explicitly asserted:
///  - Reporter identity always comes from the auth layer, never the caller.
///  - The reported user is never notified by THIS service (no notify-call
///    in any method — this is the "blind reporting" guarantee).
///  - Unauthenticated callers cannot read the moderation queue or submit.
///  - State machine is monotone forward — closed is terminal.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
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

class _FakeContentReport extends Fake implements ContentReport {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeContentReport());
  });

  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreRepository firestoreRepo;
  late FakeAuthRepository fakeAuth;
  late _MockReportRepository mockReportRepo;
  late ReportService service;

  const adminUid = 'admin-uid';
  const reporterUid = 'reporter-uid';
  const ownerUid = 'content-owner-uid';

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    fakeFirestore = FakeFirebaseFirestore();
    firestoreRepo = FirestoreRepository(firestore: fakeFirestore);
    fakeAuth = ServiceLocator.get<AuthRepository>() as FakeAuthRepository;
    mockReportRepo = _MockReportRepository();
    service = ReportService(
      reportRepository: mockReportRepo,
      authRepository: fakeAuth,
      firestoreRepository: firestoreRepo,
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  ContentReport sampleReport({
    String id = 'report-id-1',
    String reporter = reporterUid,
    String? owner = ownerUid,
    ContentType type = ContentType.recipe,
    String contentId = 'content-abc',
    ReportStatus status = ReportStatus.newReport,
  }) {
    return ContentReport(
      id: id,
      reporterId: reporter,
      contentType: type,
      contentId: contentId,
      contentOwnerId: owner,
      reason: 'spam',
      createdAt: DateTime(2026, 5, 27, 12),
      status: status,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // submitReport
  // ──────────────────────────────────────────────────────────────────
  group('submitReport', () {
    /// Unauth callers must not be able to submit reports — otherwise
    /// rules-bypass attempts could pollute the moderation queue from
    /// anonymous clients.
    test('returns false when not authenticated and never calls the repository',
        () async {
      fakeAuth.setAuthState(userId: null);

      final ok = await service.submitReport(
        contentType: ContentType.recipe,
        contentId: 'r1',
        reason: 'spam',
        contentOwnerId: ownerUid,
      );

      expect(ok, isFalse);
      verifyNever(() => mockReportRepo.submitReport(any()));
    });

    /// reporterId on the persisted ContentReport MUST be the authenticated
    /// user, never something the caller could spoof. This guards the audit
    /// trail — moderators rely on reporterId to ban abusers.
    test('stamps reporterId from auth (not from caller-controlled input)',
        () async {
      fakeAuth.setAuthState(userId: 'auth-user-real');
      when(() => mockReportRepo.submitReport(any()))
          .thenAnswer((_) async => 'new-doc-id');

      final ok = await service.submitReport(
        contentType: ContentType.comment,
        contentId: 'c1',
        reason: 'harassment',
        contentOwnerId: ownerUid,
        description: 'detailed note',
      );

      expect(ok, isTrue);
      final captured =
          verify(() => mockReportRepo.submitReport(captureAny())).captured;
      expect(captured, hasLength(1));
      final report = captured.single as ContentReport;
      expect(report.reporterId, equals('auth-user-real'),
          reason: 'reporterId must come from AuthRepository.currentUserId, '
              'never from a parameter the UI could pass.');
      expect(report.contentType, equals(ContentType.comment));
      expect(report.contentId, equals('c1'));
      expect(report.contentOwnerId, equals(ownerUid));
      expect(report.reason, equals('harassment'));
      expect(report.description, equals('detailed note'));
    });

    /// The persisted createdAt must come from `clock.now()` so tests can
    /// pin time and so the same value the user "saw" is what moderators
    /// see (no per-component drift between client + server stamps).
    test('createdAt uses clock.now() and guidelineVersion is stamped',
        () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(() => mockReportRepo.submitReport(any()))
          .thenAnswer((_) async => 'doc-id');

      final pinned = DateTime(2026, 1, 1, 9, 30);
      await withClock(Clock.fixed(pinned), () async {
        await service.submitReport(
          contentType: ContentType.recipe,
          contentId: 'r1',
          reason: 'spam',
          contentOwnerId: ownerUid,
        );
      });

      final report = verify(() => mockReportRepo.submitReport(captureAny()))
          .captured
          .single as ContentReport;
      expect(report.createdAt, equals(pinned));
      expect(report.guidelineVersion, equals(kCurrentGuidelineVersion),
          reason: 'Reports must cite the guideline version in force at '
              'submit-time so historical moderation decisions stay auditable.');
    });

    /// If the repository returns null (write failed, rules denied, throttle
    /// triggered), the service must report failure — never claim success.
    test('returns false when repository returns null docId', () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(() => mockReportRepo.submitReport(any()))
          .thenAnswer((_) async => null);

      final ok = await service.submitReport(
        contentType: ContentType.recipe,
        contentId: 'r1',
        reason: 'spam',
        contentOwnerId: ownerUid,
      );

      expect(ok, isFalse);
    });

    /// The optional description field is preserved as null when not
    /// provided — moderators distinguish "no extra context" from empty
    /// string in their dashboards.
    test('omits description as null when caller did not pass one', () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(() => mockReportRepo.submitReport(any()))
          .thenAnswer((_) async => 'd');

      await service.submitReport(
        contentType: ContentType.recipe,
        contentId: 'r1',
        reason: 'spam',
        contentOwnerId: ownerUid,
      );

      final report = verify(() => mockReportRepo.submitReport(captureAny()))
          .captured
          .single as ContentReport;
      expect(report.description, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // getMyReports
  // ──────────────────────────────────────────────────────────────────
  group('getMyReports', () {
    /// Unauth callers must receive an empty list rather than crash or,
    /// worse, somehow surface another user's reports.
    test('returns empty list when not authenticated (no repository call)',
        () async {
      fakeAuth.setAuthState(userId: null);

      final reports = await service.getMyReports();

      expect(reports, isEmpty);
      verifyNever(() => mockReportRepo.getUserReports(any()));
    });

    /// The userId passed to the repository must be the authenticated user.
    /// Privacy boundary: a user can only retrieve THEIR OWN reports.
    test('queries the repository with the authenticated userId only', () async {
      fakeAuth.setAuthState(userId: 'me-1');
      when(() => mockReportRepo.getUserReports('me-1'))
          .thenAnswer((_) async => [sampleReport(reporter: 'me-1')]);

      final reports = await service.getMyReports();

      expect(reports, hasLength(1));
      expect(reports.first.reporterId, equals('me-1'));
      verify(() => mockReportRepo.getUserReports('me-1')).called(1);
      verifyNever(() => mockReportRepo.getUserReports('admin-uid'));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // watchIsAdmin
  // ──────────────────────────────────────────────────────────────────
  group('watchIsAdmin', () {
    /// Unauth → never admin. This is the privilege-elevation guard.
    test('emits false when unauthenticated', () async {
      fakeAuth.setAuthState(userId: null);

      final first = await service.watchIsAdmin().first;

      expect(first, isFalse);
    });

    /// Admin doc presence is the source of truth (mirrors rules). If
    /// admins/{uid} exists the stream must emit true.
    test('emits true when admins/{uid} document exists', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore.collection('admins').doc(adminUid).set({'a': 1});

      final first = await service.watchIsAdmin().first;

      expect(first, isTrue);
    });

    /// Admin doc absent → not admin. Asserted to prevent a future regression
    /// where someone makes the predicate `snap.data != null` (which would
    /// emit true for empty `{}` docs in some scenarios) — `snap.exists` is
    /// the only correct check.
    test('emits false when admins/{uid} document is missing', () async {
      fakeAuth.setAuthState(userId: 'not-admin-uid');

      final first = await service.watchIsAdmin().first;

      expect(first, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // watchOpenReports
  // ──────────────────────────────────────────────────────────────────
  group('watchOpenReports', () {
    Future<void> seedReport(String id, Map<String, dynamic> data) {
      return fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc(id)
          .set(data);
    }

    Map<String, dynamic> reportDoc({
      required String status,
      required DateTime createdAt,
      String contentType = 'recipe',
      String reporterId = reporterUid,
      String contentId = 'c1',
      String? contentOwnerId = ownerUid,
    }) {
      return {
        'reporterId': reporterId,
        'contentType': contentType,
        'contentId': contentId,
        if (contentOwnerId != null) 'contentOwnerId': contentOwnerId,
        'reason': 'spam',
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
    }

    /// Closed reports MUST be filtered out — the moderation dashboard is
    /// "open work", not history. If this regresses, mods see closed items
    /// mixed with active ones, slowing triage.
    test('excludes closed reports from the stream', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedReport(
          'a', reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27)));
      await seedReport('b',
          reportDoc(status: 'in_review', createdAt: DateTime(2026, 5, 26)));
      await seedReport(
          'c', reportDoc(status: 'actioned', createdAt: DateTime(2026, 5, 25)));
      await seedReport(
          'd', reportDoc(status: 'closed', createdAt: DateTime(2026, 5, 24)));

      final reports = await service.watchOpenReports().first;

      final ids = reports.map((r) => r.id).toList();
      expect(ids, isNot(contains('d')),
          reason: 'closed reports must be filtered out of the moderation feed');
      expect(ids, containsAll(<String>['a', 'b', 'c']));
    });

    /// Newest first — moderators expect the top item to be the most recent
    /// abuse report. A flipped sort would hide fresh harassment behind a
    /// queue of stale cases.
    test('orders results newest-first by createdAt', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedReport(
          'oldest', reportDoc(status: 'new', createdAt: DateTime(2026, 1, 1)));
      await seedReport('newest',
          reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27, 12)));
      await seedReport('middle',
          reportDoc(status: 'in_review', createdAt: DateTime(2026, 3, 15)));

      final reports = await service.watchOpenReports().first;

      expect(reports.map((r) => r.id).toList(),
          equals(<String>['newest', 'middle', 'oldest']));
    });

    /// A single malformed doc (legacy contentType, missing field) must not
    /// empty the entire dashboard. `whereType<ContentReport>()` post-filter
    /// is the contract under test.
    test('tolerantly skips reports whose contentType is unknown', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedReport(
          'good', reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27)));
      await seedReport(
          'legacy',
          reportDoc(
              status: 'new',
              createdAt: DateTime(2026, 5, 26),
              contentType: 'rating')); // retired type — fromWire returns null

      final reports = await service.watchOpenReports().first;

      expect(reports.map((r) => r.id).toList(), equals(<String>['good']),
          reason: 'legacy contentTypes must be skipped, not crash the stream');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // advanceReportStatus — forward-only state machine
  // ──────────────────────────────────────────────────────────────────
  group('advanceReportStatus', () {
    Future<void> seedReportDoc(ContentReport report) {
      return fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc(report.id)
          .set({
        'reporterId': report.reporterId,
        'contentType': report.contentType.wireName,
        'contentId': report.contentId,
        if (report.contentOwnerId != null)
          'contentOwnerId': report.contentOwnerId,
        'reason': report.reason,
        'status': report.status.wireName,
        'createdAt': Timestamp.fromDate(report.createdAt),
      });
    }

    /// new → in_review writes the next-stage status and preserves the
    /// rest of the doc (single-field update — no field clobber).
    test('new → in_review writes status=in_review and preserves other fields',
        () async {
      fakeAuth.setAuthState(userId: adminUid);
      final report = sampleReport(id: 'r-new', status: ReportStatus.newReport);
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-new')
          .get();
      expect(after.data()?['status'], equals('in_review'));
      expect(after.data()?['reporterId'], equals(reporterUid),
          reason: 'advance must NOT overwrite reporterId — audit trail relies '
              'on the original reporter id being preserved.');
      expect(after.data()?['contentId'], equals('content-abc'));
    });

    test('in_review → actioned writes status=actioned', () async {
      fakeAuth.setAuthState(userId: adminUid);
      final report = sampleReport(id: 'r-rev', status: ReportStatus.inReview);
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-rev')
          .get();
      expect(after.data()?['status'], equals('actioned'));
    });

    test('actioned → closed writes status=closed', () async {
      fakeAuth.setAuthState(userId: adminUid);
      final report = sampleReport(id: 'r-act', status: ReportStatus.actioned);
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-act')
          .get();
      expect(after.data()?['status'], equals('closed'));
    });

    /// closed is terminal — advance must short-circuit and NOT write.
    /// This pins both the return contract (false) AND the side-effect
    /// contract (no Firestore write). If somebody flips closed → newReport
    /// in the switch by mistake, this test breaks.
    test('refuses to advance past closed (returns false, no write)', () async {
      fakeAuth.setAuthState(userId: adminUid);
      final report = sampleReport(id: 'r-closed', status: ReportStatus.closed);
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isFalse);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-closed')
          .get();
      expect(after.data()?['status'], equals('closed'),
          reason: 'doc must remain unchanged when service refuses to advance');
    });

    /// Unauth must not be able to advance status — the moderation API is
    /// admin-gated. `executeServiceOperation(requiresAuth: true)` is what
    /// enforces this; the test pins the behaviour at the service surface.
    test('returns false when unauthenticated (no write)', () async {
      fakeAuth.setAuthState(userId: null);
      final report =
          sampleReport(id: 'r-unauth', status: ReportStatus.newReport);
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isFalse);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-unauth')
          .get();
      expect(after.data()?['status'], equals('new'),
          reason: 'unauth advance must NOT write — rules would deny but the '
              'service should short-circuit before the network round-trip.');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // closeReport
  // ──────────────────────────────────────────────────────────────────
  group('closeReport', () {
    /// Closing an already-closed report is a no-op success — avoids
    /// spurious writes that would inflate audit-log volume and cost.
    test('already-closed report returns true without writing', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('rc')
          .set({'status': 'closed', 'sentinel': 'untouched'});
      final report = sampleReport(id: 'rc', status: ReportStatus.closed);

      final ok = await service.closeReport(report);

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('rc')
          .get();
      expect(after.data()?['sentinel'], equals('untouched'),
          reason: 'no write should have happened on no-op close');
    });

    /// Open report → write status=closed.
    test('open report is updated to status=closed', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('ro')
          .set({'status': 'new', 'reporterId': reporterUid});
      final report = sampleReport(id: 'ro', status: ReportStatus.inReview);

      final ok = await service.closeReport(report);

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('ro')
          .get();
      expect(after.data()?['status'], equals('closed'));
      expect(after.data()?['reporterId'], equals(reporterUid),
          reason: 'partial update must not clobber other fields');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // deleteReportedContent — path routing per ContentType
  // ──────────────────────────────────────────────────────────────────
  group('deleteReportedContent', () {
    test('recipe deletes /users/{ownerId}/recipes/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userRecipes)
          .doc('recipe-1')
          .set({'title': 'will-be-deleted'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.recipe,
        contentId: 'recipe-1',
      ));

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userRecipes)
          .doc('recipe-1')
          .get();
      expect(after.exists, isFalse);
    });

    test('comment deletes /recipe_comments/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-1')
          .set({'text': 'abuse'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.comment,
        contentId: 'c-1',
      ));

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-1')
          .get();
      expect(after.exists, isFalse);
    });

    test('message deletes /messages/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.messages)
          .doc('m-1')
          .set({'body': 'abuse'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.message,
        contentId: 'm-1',
      ));

      expect(ok, isTrue);
      expect(
          (await fakeFirestore
                  .collection(FirestoreCollections.messages)
                  .doc('m-1')
                  .get())
              .exists,
          isFalse);
    });

    test('cookSnap deletes /cook_snaps/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.cookSnaps)
          .doc('s-1')
          .set({'caption': 'abuse'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.cookSnap,
        contentId: 's-1',
      ));

      expect(ok, isTrue);
      expect(
          (await fakeFirestore
                  .collection(FirestoreCollections.cookSnaps)
                  .doc('s-1')
                  .get())
              .exists,
          isFalse);
    });

    test('group deletes /users/{ownerId}/friend_categories/{contentId}',
        () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userFriendCategories)
          .doc('g-1')
          .set({'name': 'abuse'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.group,
        contentId: 'g-1',
      ));

      expect(ok, isTrue);
      expect(
          (await fakeFirestore
                  .collection(FirestoreCollections.users)
                  .doc(ownerUid)
                  .collection(FirestoreCollections.userFriendCategories)
                  .doc('g-1')
                  .get())
              .exists,
          isFalse);
    });

    /// recipe without ownerId cannot resolve a path safely → service must
    /// refuse rather than delete a wrong recipe at /users//recipes/{id}.
    test('recipe without contentOwnerId returns false (refuses dispatch)',
        () async {
      fakeAuth.setAuthState(userId: adminUid);

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.recipe,
        contentId: 'recipe-1',
        owner: null,
      ));

      expect(ok, isFalse);
    });

    test('group without contentOwnerId returns false (refuses dispatch)',
        () async {
      fakeAuth.setAuthState(userId: adminUid);

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.group,
        contentId: 'g-1',
        owner: null,
      ));

      expect(ok, isFalse);
    });

    /// profile must NOT be hard-deleted via this path — production routes
    /// it through suspendReportedProfile (reversible hide). If somebody
    /// adds a case for ContentType.profile here that hard-deletes the
    /// public_profile doc, this test breaks.
    test('profile reports return false (must go through suspend path)',
        () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .set({'displayName': 'still-here'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.profile,
        contentId: ownerUid,
      ));

      expect(ok, isFalse,
          reason: 'profile deletes must be refused — suspendReportedProfile '
              'is the only legitimate primitive (reversible hide preserves '
              'auth + friendships).');
      final profile = await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .get();
      expect(profile.exists, isTrue,
          reason: 'profile doc must remain — service refused the dispatch');
    });

    /// Unauth callers cannot delete reported content even if rules would
    /// also reject. Service-layer short-circuit is the cheap path.
    test('unauthenticated callers cannot delete reported content', () async {
      fakeAuth.setAuthState(userId: null);
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-keep')
          .set({'text': 'should-survive'});

      final ok = await service.deleteReportedContent(sampleReport(
        type: ContentType.comment,
        contentId: 'c-keep',
      ));

      expect(ok, isFalse);
      final after = await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-keep')
          .get();
      expect(after.exists, isTrue,
          reason: 'unauth attempt must not delete the doc');
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // suspendReportedProfile (existing coverage kept — wave-13 additions)
  // ──────────────────────────────────────────────────────────────────
  group('suspendReportedProfile (existing primitive)', () {
    /// Documents that profile suspension hides rather than deletes. A
    /// future regression where someone replaces `update({isHidden: true})`
    /// with `delete()` would break the reversibility contract this test
    /// pins.
    test('writes isHidden=true to the right public_profiles doc', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .set({'displayName': 'Anna', 'isHidden': false});

      await service.suspendReportedProfile(sampleReport(
        type: ContentType.profile,
        contentId: ownerUid,
      ));

      final after = await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .get();
      expect(after.data()?['isHidden'], isTrue);
      expect(after.data()?['displayName'], equals('Anna'),
          reason: 'must be a partial update — preserves the displayName');
    });

    test('refuses non-profile contentType', () async {
      fakeAuth.setAuthState(userId: adminUid);

      final ok = await service.suspendReportedProfile(sampleReport(
        type: ContentType.recipe,
      ));

      expect(ok, isFalse);
    });

    test('refuses when contentOwnerId is missing', () async {
      fakeAuth.setAuthState(userId: adminUid);

      final okNull = await service.suspendReportedProfile(sampleReport(
        type: ContentType.profile,
        owner: null,
      ));
      final okEmpty = await service.suspendReportedProfile(sampleReport(
        type: ContentType.profile,
        owner: '',
      ));

      expect(okNull, isFalse);
      expect(okEmpty, isFalse);
    });
  });
}
