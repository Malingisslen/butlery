// Mocking Firestore's sealed reference types is the repo-standard way to force
// a snapshot error the in-memory fake cannot produce (see fallback_values.dart).
// ignore_for_file: subtype_of_sealed_class

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
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/models/social/report_reason.dart';
import 'package:butlery/repositories/firebase/firebase_report_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/moderation/report_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockReportRepository extends Mock implements FirebaseReportRepository {}

/// Only used to force a snapshot ERROR on admins/{uid} — FakeFirebaseFirestore
/// has no rules engine, so it cannot reproduce the permission-denied every
/// non-admin actually gets in production.
class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

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
  // BUT-2154: the dialog keeps this id across Försök igen. A service that
  // returned '' or a constant would let every attempt mint its own report.
  test('newReportId returns what the repository mints', () {
    var n = 0;
    when(() => mockReportRepo.newReportId()).thenAnswer((_) => 'minted-${++n}');

    expect(service.newReportId(), 'minted-1');
    expect(service.newReportId(), 'minted-2');
    verify(() => mockReportRepo.newReportId()).called(2);
  });

  group('submitReport', () {
    test('passes dishId into the report', () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(
        () => mockReportRepo.submitReport(any()),
      ).thenAnswer((_) async => 'new-doc-id');

      final ok = await service.submitReport(
        reportId: 'rid',
        contentType: ContentType.menuDish,
        contentId: 'menu-1',
        reason: ReportReason.misattribution,
        contentOwnerId: ownerUid,
        dishId: 'dish-1',
      );

      expect(ok, isTrue);
      final report =
          verify(
                () => mockReportRepo.submitReport(captureAny()),
              ).captured.single
              as ContentReport;
      expect(report.dishId, 'dish-1');
      expect(report.contentType, ContentType.menuDish);
      expect(report.reason, 'misattribution');
    });

    /// Unauth callers must not be able to submit reports — otherwise
    /// rules-bypass attempts could pollute the moderation queue from
    /// anonymous clients.
    test(
      'returns false when not authenticated and never calls the repository',
      () async {
        fakeAuth.setAuthState(userId: null);

        final ok = await service.submitReport(
          reportId: 'rid',
          contentType: ContentType.recipe,
          contentId: 'r1',
          reason: ReportReason.spam,
          contentOwnerId: ownerUid,
        );

        expect(ok, isFalse);
        verifyNever(() => mockReportRepo.submitReport(any()));
      },
    );

    /// reporterId on the persisted ContentReport MUST be the authenticated
    /// user, never something the caller could spoof. This guards the audit
    /// trail — moderators rely on reporterId to ban abusers.
    test(
      'stamps reporterId from auth (not from caller-controlled input)',
      () async {
        fakeAuth.setAuthState(userId: 'auth-user-real');
        when(
          () => mockReportRepo.submitReport(any()),
        ).thenAnswer((_) async => 'new-doc-id');

        final ok = await service.submitReport(
          reportId: 'rid',
          contentType: ContentType.comment,
          contentId: 'c1',
          reason: ReportReason.harassment,
          contentOwnerId: ownerUid,
          description: 'detailed note',
        );

        expect(ok, isTrue);
        final captured = verify(
          () => mockReportRepo.submitReport(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final report = captured.single as ContentReport;
        expect(
          report.reporterId,
          equals('auth-user-real'),
          reason:
              'reporterId must come from AuthRepository.currentUserId, '
              'never from a parameter the UI could pass.',
        );
        expect(report.contentType, equals(ContentType.comment));
        expect(report.contentId, equals('c1'));
        expect(report.contentOwnerId, equals(ownerUid));
        expect(report.reason, equals('harassment'));
        expect(report.description, equals('detailed note'));
      },
    );

    /// The persisted createdAt must come from `clock.now()` so tests can
    /// pin time and so the same value the user "saw" is what moderators
    /// see (no per-component drift between client + server stamps).
    test(
      'createdAt uses clock.now() and guidelineVersion is stamped',
      () async {
        fakeAuth.setAuthState(userId: reporterUid);
        when(
          () => mockReportRepo.submitReport(any()),
        ).thenAnswer((_) async => 'doc-id');

        final pinned = DateTime(2026, 1, 1, 9, 30);
        await withClock(Clock.fixed(pinned), () async {
          await service.submitReport(
            reportId: 'rid',
            contentType: ContentType.recipe,
            contentId: 'r1',
            reason: ReportReason.spam,
            contentOwnerId: ownerUid,
          );
        });

        final report =
            verify(
                  () => mockReportRepo.submitReport(captureAny()),
                ).captured.single
                as ContentReport;
        expect(report.createdAt, equals(pinned));
        expect(
          report.guidelineVersion,
          equals(kCurrentGuidelineVersion),
          reason:
              'Reports must cite the guideline version in force at '
              'submit-time so historical moderation decisions stay auditable.',
        );
      },
    );

    /// If the repository returns null (write failed, rules denied, throttle
    /// triggered), the service must report failure — never claim success.
    test('returns false when repository returns null docId', () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(
        () => mockReportRepo.submitReport(any()),
      ).thenAnswer((_) async => null);

      final ok = await service.submitReport(
        reportId: 'rid',
        contentType: ContentType.recipe,
        contentId: 'r1',
        reason: ReportReason.spam,
        contentOwnerId: ownerUid,
      );

      expect(ok, isFalse);
    });

    /// The reports create rule admits ids only (BUT-2154), and the id minted
    /// before the first attempt must reach the repository unchanged so a retry
    /// addresses the same document.
    test(
      'stores the reason id and passes reportId through as the doc id',
      () async {
        fakeAuth.setAuthState(userId: reporterUid);
        when(
          () => mockReportRepo.submitReport(any()),
        ).thenAnswer((_) async => 'minted-id');

        final ok = await service.submitReport(
          reportId: 'minted-id',
          contentType: ContentType.recipe,
          contentId: 'r1',
          reason: ReportReason.abuse,
          contentOwnerId: ownerUid,
        );

        expect(ok, isTrue);
        final report =
            verify(
                  () => mockReportRepo.submitReport(captureAny()),
                ).captured.single
                as ContentReport;
        expect(report.reason, 'abuse', reason: 'the wire id, not the label');
        expect(report.id, 'minted-id');
      },
    );

    /// The optional description field is preserved as null when not
    /// provided — moderators distinguish "no extra context" from empty
    /// string in their dashboards.
    test('omits description as null when caller did not pass one', () async {
      fakeAuth.setAuthState(userId: reporterUid);
      when(
        () => mockReportRepo.submitReport(any()),
      ).thenAnswer((_) async => 'd');

      await service.submitReport(
        reportId: 'rid',
        contentType: ContentType.recipe,
        contentId: 'r1',
        reason: ReportReason.spam,
        contentOwnerId: ownerUid,
      );

      final report =
          verify(
                () => mockReportRepo.submitReport(captureAny()),
              ).captured.single
              as ContentReport;
      expect(report.description, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // getMyReports
  // ──────────────────────────────────────────────────────────────────
  group('getMyReports', () {
    /// Unauth callers must receive an empty list rather than crash or,
    /// worse, somehow surface another user's reports.
    test(
      'returns empty list when not authenticated (no repository call)',
      () async {
        fakeAuth.setAuthState(userId: null);

        final reports = await service.getMyReports();

        expect(reports, isEmpty);
        verifyNever(() => mockReportRepo.getUserReports(any()));
      },
    );

    /// The userId passed to the repository must be the authenticated user.
    /// Privacy boundary: a user can only retrieve THEIR OWN reports.
    test('queries the repository with the authenticated userId only', () async {
      fakeAuth.setAuthState(userId: 'me-1');
      when(
        () => mockReportRepo.getUserReports('me-1'),
      ).thenAnswer((_) async => [sampleReport(reporter: 'me-1')]);

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

    /// A snapshot error must EMIT `false`, not merely swallow the error.
    /// rules restrict admins/{uid} reads to admins, so every signed-in
    /// NON-admin gets permission-denied here — that is the normal path, not
    /// an exotic one. `.handleError` cannot emit from its callback, so it
    /// would end the stream with zero events and strand the moderator screen's
    /// StreamBuilder in ConnectionState.waiting forever (infinite spinner,
    /// _NotAuthorized unreachable). The fake can't produce a rules error, so
    /// the repository chain is mocked to return an error stream.
    test(
      'emits false (not an empty stream) when the snapshot errors',
      () async {
        fakeAuth.setAuthState(userId: 'not-admin-uid');
        final erroringRepo = _MockFirestoreRepository();
        final collection = _MockCollectionReference();
        final doc = _MockDocumentReference();
        when(() => erroringRepo.collection('admins')).thenReturn(collection);
        when(() => collection.doc(any())).thenReturn(doc);
        when(doc.snapshots).thenAnswer(
          (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.error(
            FirebaseException(plugin: 'firestore', code: 'permission-denied'),
          ),
        );
        final erroringService = ReportService(
          reportRepository: mockReportRepo,
          authRepository: fakeAuth,
          firestoreRepository: erroringRepo,
        );

        final emitted = await erroringService.watchIsAdmin().first.timeout(
          const Duration(seconds: 2),
        );

        expect(
          emitted,
          isFalse,
          reason:
              'the error must be converted into an explicit non-admin event so '
              'the view can render its not-authorized state',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────
  // isMinorAccount (BUT-1609) — the child-safety signal behind the badge
  // ──────────────────────────────────────────────────────────────────
  group('isMinorAccount', () {
    // isMinorAccount runs through the auth-gated executeServiceOperation, and
    // it is only ever called from the (authenticated) moderator dashboard.
    setUp(() => fakeAuth.setAuthState(userId: adminUid));

    Future<void> seedUser(String uid, Map<String, dynamic> data) =>
        fakeFirestore.collection(FirestoreCollections.users).doc(uid).set(data);

    test('true only when the account doc has isMinor == true', () async {
      await seedUser('u-minor', {'isMinor': true});
      expect(await service.isMinorAccount('u-minor'), isTrue);
    });

    test('false (confirmed adult) when isMinor is absent', () async {
      await seedUser('u-adult', {'displayName': 'Adult'});
      expect(await service.isMinorAccount('u-adult'), isFalse);
    });

    test('false when the account doc is missing', () async {
      expect(await service.isMinorAccount('u-ghost'), isFalse);
    });

    test(
      'false when isMinor is a non-bool value (only literal true flags)',
      () async {
        // A future data glitch writing the string 'true' must NOT flag a minor.
        await seedUser('u-weird', {'isMinor': 'true'});
        expect(await service.isMinorAccount('u-weird'), isFalse);
      },
    );

    test('null (retryable), not false, when the read FAILS', () async {
      // A failed lookup must be distinguishable from a confirmed adult so the
      // caller can retry rather than lock in a wrong "not a minor" — the fake
      // can't produce a rules error, so the get() is mocked to throw.
      final erroringRepo = _MockFirestoreRepository();
      final collection = _MockCollectionReference();
      final doc = _MockDocumentReference();
      when(
        () => erroringRepo.collection(FirestoreCollections.users),
      ).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      when(doc.get).thenThrow(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );
      final erroringService = ReportService(
        reportRepository: mockReportRepo,
        authRepository: fakeAuth,
        firestoreRepository: erroringRepo,
      );

      expect(
        await erroringService.isMinorAccount('u'),
        isNull,
        reason:
            'a failed read must not collapse into a confirmed-adult false — '
            'that would hide a real minor for the whole session',
      );
    });

    test('caches a confirmed result within the 30-min window', () async {
      final users = fakeFirestore.collection(FirestoreCollections.users);
      await users.doc('u-cache').set({'isMinor': true});
      expect(await service.isMinorAccount('u-cache'), isTrue);
      // A later change would read false if the cache were bypassed.
      await users.doc('u-cache').set({'isMinor': false});
      expect(
        await service.isMinorAccount('u-cache'),
        isTrue,
        reason: 'served from the 30-minute cache, not re-read',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // getReportEvidence (BUT-1842) — admin-only text copy of reported content
  // ──────────────────────────────────────────────────────────────────
  group('getReportEvidence', () {
    setUp(() => fakeAuth.setAuthState(userId: adminUid));

    test(
      'a missing document is (evidence: null), not a failed lookup',
      () async {
        final result = await service.getReportEvidence('r-none');

        expect(result, isNotNull);
        expect(result!.evidence, isNull);
      },
    );

    test('parses the document in report_evidence/{id}', () async {
      await fakeFirestore
          .collection(FirestoreCollections.reportEvidence)
          .doc('r1')
          .set({
            'outcome': 'captured',
            'truncated': true,
            'text': {'title': 'Hej', 'description': 'Beskrivning'},
          });
      // Same id in another collection must not be read.
      await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r1')
          .set(
            {
              'outcome': 'missing',
              'text': {'title': 'Fel samling'},
            },
          );

      final evidence = (await service.getReportEvidence('r1'))!.evidence!;

      expect(evidence.reportId, 'r1');
      expect(evidence.outcome, EvidenceOutcome.captured);
      expect(evidence.truncated, isTrue);
      expect(evidence.text, [('title', 'Hej'), ('description', 'Beskrivning')]);
    });

    test(
      'null (retryable), not (evidence: null), when the read FAILS',
      () async {
        final repo = _MockFirestoreRepository();
        final collection = _MockCollectionReference();
        final doc = _MockDocumentReference();
        when(
          () => repo.collection(FirestoreCollections.reportEvidence),
        ).thenReturn(collection);
        when(() => collection.doc(any())).thenReturn(doc);
        when(doc.get).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        );
        final erroringService = ReportService(
          reportRepository: mockReportRepo,
          authRepository: fakeAuth,
          firestoreRepository: repo,
        );

        expect(await erroringService.getReportEvidence('r1'), isNull);
      },
    );

    test('a failure is not cached: the second call reads again', () async {
      final repo = _MockFirestoreRepository();
      final collection = _MockCollectionReference();
      final doc = _MockDocumentReference();
      when(
        () => repo.collection(FirestoreCollections.reportEvidence),
      ).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      when(doc.get).thenThrow(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
      );
      final flaky = ReportService(
        reportRepository: mockReportRepo,
        authRepository: fakeAuth,
        firestoreRepository: repo,
      );

      expect(await flaky.getReportEvidence('r1'), isNull);
      expect(await flaky.getReportEvidence('r1'), isNull);

      verify(doc.get).called(2);
    });

    test('a success is cached within the 1-minute window', () async {
      final evidenceDocs = fakeFirestore.collection(
        FirestoreCollections.reportEvidence,
      );
      await evidenceDocs.doc('r1').set({'outcome': 'missing'});
      expect(
        (await service.getReportEvidence('r1'))!.evidence!.outcome,
        EvidenceOutcome.missing,
      );

      await evidenceDocs.doc('r1').set({'outcome': 'captured'});

      expect(
        (await service.getReportEvidence('r1'))!.evidence!.outcome,
        EvidenceOutcome.missing,
        reason: 'served from the cache, not re-read',
      );
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
        'contentOwnerId': ?contentOwnerId,
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
        'a',
        reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27)),
      );
      await seedReport(
        'b',
        reportDoc(status: 'in_review', createdAt: DateTime(2026, 5, 26)),
      );
      await seedReport(
        'c',
        reportDoc(status: 'actioned', createdAt: DateTime(2026, 5, 25)),
      );
      await seedReport(
        'd',
        reportDoc(status: 'closed', createdAt: DateTime(2026, 5, 24)),
      );

      final reports = await service.watchOpenReports().first;

      final ids = reports.map((r) => r.id).toList();
      expect(
        ids,
        isNot(contains('d')),
        reason: 'closed reports must be filtered out of the moderation feed',
      );
      expect(ids, containsAll(<String>['a', 'b', 'c']));
    });

    /// Newest first — moderators expect the top item to be the most recent
    /// abuse report. A flipped sort would hide fresh harassment behind a
    /// queue of stale cases.
    test('orders results newest-first by createdAt', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedReport(
        'oldest',
        reportDoc(status: 'new', createdAt: DateTime(2026, 1, 1)),
      );
      await seedReport(
        'newest',
        reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27, 12)),
      );
      await seedReport(
        'middle',
        reportDoc(status: 'in_review', createdAt: DateTime(2026, 3, 15)),
      );

      final reports = await service.watchOpenReports().first;

      expect(
        reports.map((r) => r.id).toList(),
        equals(<String>['newest', 'middle', 'oldest']),
      );
    });

    /// A single malformed doc (legacy contentType, missing field) must not
    /// empty the entire dashboard. `whereType<ContentReport>()` post-filter
    /// is the contract under test.
    test('tolerantly skips reports whose contentType is unknown', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedReport(
        'good',
        reportDoc(status: 'new', createdAt: DateTime(2026, 5, 27)),
      );
      await seedReport(
        'legacy',
        reportDoc(
          status: 'new',
          createdAt: DateTime(2026, 5, 26),
          contentType: 'rating',
        ),
      ); // retired type — fromWire returns null

      final reports = await service.watchOpenReports().first;

      expect(
        reports.map((r) => r.id).toList(),
        equals(<String>['good']),
        reason: 'legacy contentTypes must be skipped, not crash the stream',
      );
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
    test(
      'new → in_review writes status=in_review and preserves other fields',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        final report = sampleReport(
          id: 'r-new',
          status: ReportStatus.newReport,
        );
        await seedReportDoc(report);

        final ok = await service.advanceReportStatus(report);

        expect(ok, isTrue);
        final after = await fakeFirestore
            .collection(FirestoreCollections.reports)
            .doc('r-new')
            .get();
        expect(after.data()?['status'], equals('in_review'));
        expect(
          after.data()?['reporterId'],
          equals(reporterUid),
          reason:
              'advance must NOT overwrite reporterId — audit trail relies '
              'on the original reporter id being preserved.',
        );
        expect(after.data()?['contentId'], equals('content-abc'));
      },
    );

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
      expect(
        after.data()?['status'],
        equals('closed'),
        reason: 'doc must remain unchanged when service refuses to advance',
      );
    });

    /// Unauth must not be able to advance status — the moderation API is
    /// admin-gated. `executeServiceOperation(requiresAuth: true)` is what
    /// enforces this; the test pins the behaviour at the service surface.
    test('returns false when unauthenticated (no write)', () async {
      fakeAuth.setAuthState(userId: null);
      final report = sampleReport(
        id: 'r-unauth',
        status: ReportStatus.newReport,
      );
      await seedReportDoc(report);

      final ok = await service.advanceReportStatus(report);

      expect(ok, isFalse);
      final after = await fakeFirestore
          .collection(FirestoreCollections.reports)
          .doc('r-unauth')
          .get();
      expect(
        after.data()?['status'],
        equals('new'),
        reason:
            'unauth advance must NOT write — rules would deny but the '
            'service should short-circuit before the network round-trip.',
      );
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
      expect(
        after.data()?['sentinel'],
        equals('untouched'),
        reason: 'no write should have happened on no-op close',
      );
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
      expect(
        after.data()?['reporterId'],
        equals(reporterUid),
        reason: 'partial update must not clobber other fields',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // deleteReportedContent — path routing per ContentType
  // ──────────────────────────────────────────────────────────────────
  group('deleteReportedContent', () {
    // BUT-2330: the takedown stamps the report in the same batch, so the
    // report has to exist, as it always does in production.
    Future<void> seedSampleReport() => fakeFirestore
        .collection(FirestoreCollections.reports)
        .doc(sampleReport().id)
        .set(sampleReport().toFirestore());

    Future<Object?> storedAction() async =>
        (await fakeFirestore
                .collection(FirestoreCollections.reports)
                .doc(sampleReport().id)
                .get())
            .data()?['moderatorAction'];

    setUp(seedSampleReport);

    test('stamps content_removed on the report with the delete', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-1')
          .set({'text': 'x'});

      final ok = await service.deleteReportedContent(
        sampleReport(type: ContentType.comment, contentId: 'c-1'),
      );

      expect(ok, isTrue);
      expect(await storedAction(), equals('content_removed'));
    });

    test('a closed report refuses the takedown and is not stamped', () async {
      fakeAuth.setAuthState(userId: adminUid);
      final comment = fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-closed');
      await comment.set({'text': 'x'});

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.comment,
          contentId: 'c-closed',
          status: ReportStatus.closed,
        ),
      );

      expect(ok, isFalse);
      expect((await comment.get()).exists, isTrue);
      expect(await storedAction(), isNull);
    });

    Map<String, dynamic> dish(String id) => {'id': id, 'title': 'Rätt $id'};

    Future<void> seedMenu(Map<String, dynamic> snapshot) => fakeFirestore
        .collection(FirestoreCollections.sharedContent)
        .doc('menu-1')
        .set({'menuTitle': 'Veckomeny', 'menuSnapshot': snapshot});

    Future<Map<String, dynamic>> menuDoc() async =>
        (await fakeFirestore
                .collection(FirestoreCollections.sharedContent)
                .doc('menu-1')
                .get())
            .data()!;

    ContentReport dishReport({
      String? dishId = 'd1',
      ReportStatus status = ReportStatus.newReport,
    }) => ContentReport(
      id: 'report-id-1',
      reporterId: reporterUid,
      contentType: ContentType.menuDish,
      contentId: 'menu-1',
      contentOwnerId: ownerUid,
      reason: 'misattribution',
      createdAt: DateTime(2026, 10, 10),
      dishId: dishId,
      status: status,
    );

    test(
      'menuDish removes only the matching dish from every category',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        await seedMenu({
          'Middag': [dish('d1'), dish('d2')],
          'Lunch': [dish('d1'), dish('d3')],
          'Frukost': [dish('d4')],
        });

        final ok = await service.deleteReportedContent(dishReport());

        expect(ok, isTrue);
        final data = await menuDoc();
        final snapshot = data['menuSnapshot'] as Map<String, dynamic>;
        expect(
          (snapshot['Middag'] as List).map((d) => (d as Map)['id']),
          ['d2'],
        );
        expect(
          (snapshot['Lunch'] as List).map((d) => (d as Map)['id']),
          ['d3'],
        );
        expect(
          (snapshot['Frukost'] as List).map((d) => (d as Map)['id']),
          ['d4'],
        );
        expect(
          data['menuTitle'],
          'Veckomeny',
          reason: 'only menuSnapshot is written',
        );
        expect(await storedAction(), equals('content_removed'));
      },
    );

    test(
      'menuDish with no matching dish returns false and writes nothing',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        await seedMenu({
          'Middag': [dish('d2')],
        });

        final ok = await service.deleteReportedContent(dishReport());

        expect(ok, isFalse);
        final snapshot =
            (await menuDoc())['menuSnapshot'] as Map<String, dynamic>;
        expect(snapshot['Middag'], hasLength(1));
        expect(await storedAction(), isNull);
      },
    );

    test(
      'a closed menuDish report refuses the takedown and is not stamped',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        await seedMenu({
          'Middag': [dish('d1')],
        });

        expect(
          await service.deleteReportedContent(
            dishReport(status: ReportStatus.closed),
          ),
          isFalse,
        );
        final snapshot =
            (await menuDoc())['menuSnapshot'] as Map<String, dynamic>;
        expect(snapshot['Middag'], hasLength(1));
        expect(await storedAction(), isNull);
      },
    );

    test('menuDish without a dishId returns false', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await seedMenu({
        'Middag': [dish('d1')],
      });

      expect(
        await service.deleteReportedContent(dishReport(dishId: null)),
        isFalse,
      );
      final snapshot =
          (await menuDoc())['menuSnapshot'] as Map<String, dynamic>;
      expect(snapshot['Middag'], hasLength(1));
    });

    test('menuDish on a missing shared menu returns false', () async {
      fakeAuth.setAuthState(userId: adminUid);

      expect(await service.deleteReportedContent(dishReport()), isFalse);
      expect(
        (await fakeFirestore
                .collection(FirestoreCollections.sharedContent)
                .doc('menu-1')
                .get())
            .exists,
        isFalse,
      );
      expect(await storedAction(), isNull);
    });

    test('recipe deletes /users/{ownerId}/recipes/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userRecipes)
          .doc('recipe-1')
          .set({'title': 'will-be-deleted'});

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.recipe,
          contentId: 'recipe-1',
        ),
      );

      expect(ok, isTrue);
      final after = await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userRecipes)
          .doc('recipe-1')
          .get();
      expect(after.exists, isFalse);
    });

    test(
      'recipe the owner already moved to trash: the trash copy is deleted too',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        final trashCopy = fakeFirestore
            .collection(FirestoreCollections.users)
            .doc(ownerUid)
            .collection(FirestoreCollections.userTrash)
            .doc('recipe-1');
        await trashCopy.set({'title': 'owner deleted it first'});

        final ok = await service.deleteReportedContent(
          sampleReport(type: ContentType.recipe, contentId: 'recipe-1'),
        );

        expect(ok, isTrue);
        expect((await trashCopy.get()).exists, isFalse);
      },
    );

    test('comment deletes nothing under the owner\'s trash', () async {
      fakeAuth.setAuthState(userId: adminUid);
      final unrelated = fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.userTrash)
          .doc('c-1');
      await unrelated.set({'title': 'a recipe that shares the id'});

      await service.deleteReportedContent(
        sampleReport(type: ContentType.comment, contentId: 'c-1'),
      );

      expect((await unrelated.get()).exists, isTrue);
    });

    test('comment deletes /recipe_comments/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-1')
          .set({'text': 'abuse'});

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.comment,
          contentId: 'c-1',
        ),
      );

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

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.message,
          contentId: 'm-1',
        ),
      );

      expect(ok, isTrue);
      expect(
        (await fakeFirestore
                .collection(FirestoreCollections.messages)
                .doc('m-1')
                .get())
            .exists,
        isFalse,
      );
    });

    test('cookSnap deletes /cook_snaps/{contentId}', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.cookSnaps)
          .doc('s-1')
          .set({'caption': 'abuse'});

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.cookSnap,
          contentId: 's-1',
        ),
      );

      expect(ok, isTrue);
      expect(
        (await fakeFirestore
                .collection(FirestoreCollections.cookSnaps)
                .doc('s-1')
                .get())
            .exists,
        isFalse,
      );
    });

    test(
      'group deletes /users/{ownerId}/friend_categories/{contentId}',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        await fakeFirestore
            .collection(FirestoreCollections.users)
            .doc(ownerUid)
            .collection(FirestoreCollections.userFriendCategories)
            .doc('g-1')
            .set({'name': 'abuse'});

        final ok = await service.deleteReportedContent(
          sampleReport(
            type: ContentType.group,
            contentId: 'g-1',
          ),
        );

        expect(ok, isTrue);
        expect(
          (await fakeFirestore
                  .collection(FirestoreCollections.users)
                  .doc(ownerUid)
                  .collection(FirestoreCollections.userFriendCategories)
                  .doc('g-1')
                  .get())
              .exists,
          isFalse,
        );
      },
    );

    /// recipe without ownerId cannot resolve a path safely → service must
    /// refuse rather than delete a wrong recipe at /users//recipes/{id}.
    test(
      'recipe without contentOwnerId returns false (refuses dispatch)',
      () async {
        fakeAuth.setAuthState(userId: adminUid);

        final ok = await service.deleteReportedContent(
          sampleReport(
            type: ContentType.recipe,
            contentId: 'recipe-1',
            owner: null,
          ),
        );

        expect(ok, isFalse);
      },
    );

    test(
      'group without contentOwnerId returns false (refuses dispatch)',
      () async {
        fakeAuth.setAuthState(userId: adminUid);

        final ok = await service.deleteReportedContent(
          sampleReport(
            type: ContentType.group,
            contentId: 'g-1',
            owner: null,
          ),
        );

        expect(ok, isFalse);
      },
    );

    /// profile must NOT be hard-deleted via this path — production routes
    /// it through suspendReportedProfile (reversible hide). If somebody
    /// adds a case for ContentType.profile here that hard-deletes the
    /// public_profile doc, this test breaks.
    test(
      'profile reports return false (must go through suspend path)',
      () async {
        fakeAuth.setAuthState(userId: adminUid);
        await fakeFirestore
            .collection(FirestoreCollections.publicProfiles)
            .doc(ownerUid)
            .set({'displayName': 'still-here'});

        final ok = await service.deleteReportedContent(
          sampleReport(
            type: ContentType.profile,
            contentId: ownerUid,
          ),
        );

        expect(
          ok,
          isFalse,
          reason:
              'profile deletes must be refused — suspendReportedProfile '
              'is the only legitimate primitive (reversible hide preserves '
              'auth + friendships).',
        );
        final profile = await fakeFirestore
            .collection(FirestoreCollections.publicProfiles)
            .doc(ownerUid)
            .get();
        expect(
          profile.exists,
          isTrue,
          reason: 'profile doc must remain — service refused the dispatch',
        );
      },
    );

    /// Unauth callers cannot delete reported content even if rules would
    /// also reject. Service-layer short-circuit is the cheap path.
    test('unauthenticated callers cannot delete reported content', () async {
      fakeAuth.setAuthState(userId: null);
      await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-keep')
          .set({'text': 'should-survive'});

      final ok = await service.deleteReportedContent(
        sampleReport(
          type: ContentType.comment,
          contentId: 'c-keep',
        ),
      );

      expect(ok, isFalse);
      final after = await fakeFirestore
          .collection(FirestoreCollections.recipeComments)
          .doc('c-keep')
          .get();
      expect(
        after.exists,
        isTrue,
        reason: 'unauth attempt must not delete the doc',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // suspendReportedProfile (existing coverage kept — wave-13 additions)
  // ──────────────────────────────────────────────────────────────────
  group('suspendReportedProfile (existing primitive)', () {
    // BUT-2330: the takedown stamps the report in the same batch, so the
    // report has to exist, as it always does in production.
    Future<void> seedSampleReport() => fakeFirestore
        .collection(FirestoreCollections.reports)
        .doc(sampleReport().id)
        .set(sampleReport().toFirestore());

    Future<Object?> storedAction() async =>
        (await fakeFirestore
                .collection(FirestoreCollections.reports)
                .doc(sampleReport().id)
                .get())
            .data()?['moderatorAction'];

    setUp(seedSampleReport);

    test('stamps profile_hidden on the report with the hide', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .set({'displayName': 'Anna', 'isHidden': false});

      final ok = await service.suspendReportedProfile(
        sampleReport(type: ContentType.profile, contentId: ownerUid),
      );

      expect(ok, isTrue);
      expect(await storedAction(), equals('profile_hidden'));
    });

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

      await service.suspendReportedProfile(
        sampleReport(
          type: ContentType.profile,
          contentId: ownerUid,
        ),
      );

      final after = await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .get();
      expect(after.data()?['isHidden'], isTrue);
      expect(
        after.data()?['displayName'],
        equals('Anna'),
        reason: 'must be a partial update — preserves the displayName',
      );
    });

    test('a closed report refuses the hide and is not stamped', () async {
      fakeAuth.setAuthState(userId: adminUid);
      await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .set({'displayName': 'Anna', 'isHidden': false});

      final ok = await service.suspendReportedProfile(
        sampleReport(
          type: ContentType.profile,
          contentId: ownerUid,
          status: ReportStatus.closed,
        ),
      );

      expect(ok, isFalse);
      final profile = await fakeFirestore
          .collection(FirestoreCollections.publicProfiles)
          .doc(ownerUid)
          .get();
      expect(profile.data()?['isHidden'], isFalse);
      expect(await storedAction(), isNull);
    });

    test('refuses non-profile contentType', () async {
      fakeAuth.setAuthState(userId: adminUid);

      final ok = await service.suspendReportedProfile(
        sampleReport(
          type: ContentType.recipe,
        ),
      );

      expect(ok, isFalse);
    });

    test('refuses when contentOwnerId is missing', () async {
      fakeAuth.setAuthState(userId: adminUid);

      final okNull = await service.suspendReportedProfile(
        sampleReport(
          type: ContentType.profile,
          owner: null,
        ),
      );
      final okEmpty = await service.suspendReportedProfile(
        sampleReport(
          type: ContentType.profile,
          owner: '',
        ),
      );

      expect(okNull, isFalse);
      expect(okEmpty, isFalse);
    });
  });
}
