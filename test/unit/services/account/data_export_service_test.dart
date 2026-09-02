/// Comprehensive unit tests for DataExportService (GDPR Articles 15 & 20).
///
/// Tests data export functionality and GDPR compliance.
library;

import 'package:cloud_functions/cloud_functions.dart';
// `UserMetadata` only — `User` would clash with the project's own models.
import 'package:firebase_auth/firebase_auth.dart' show UserMetadata;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/export/compliance_export_manager.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/firebase/firebase_activity_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/firebase_feedback_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/models/household.dart';
import 'dart:convert';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Mocks
class MockFirestoreRepository extends Mock implements FirestoreRepository {}

/// BUT-1721: `MockUser` (production_mocks) stubs `uid` and `email` but NOT
/// `metadata`, and mocktail throws on an unstubbed non-nullable getter — so
/// `_exportUserProfile`'s `currentUser?.metadata.creationTime` threw and the
/// `profile` section of EVERY bundle in this file came back as
/// `{'error': 'Failed to export user profile'}`. That stayed invisible while
/// `export_metadata.warnings` keyed on `error_code` alone. It is a fixture
/// defect, not a production one (a real `User` always carries metadata), so the
/// fix is to stub it rather than to relax the warning contract.
class _FakeUserMetadata extends Fake implements UserMetadata {
  @override
  DateTime? get creationTime => DateTime.utc(2026, 1, 1);

  @override
  DateTime? get lastSignInTime => DateTime.utc(2026, 5, 1);
}

// BUT-1449: the GDPR export's family section (FamilyExportManager) resolves
// HouseholdRepository via the production ServiceLocator, which this test does
// not bridge. Inject a stub whose getForUser returns empty so exportFamily
// short-circuits to an empty section (no 'family-export-failed' warning)
// instead of throwing on an unregistered/unstubbed repo.
class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

HouseholdRepository _emptyFamilyHouseholdRepo() {
  final repo = _MockHouseholdRepository();
  when(
    () => repo.getForUser(any()),
  ).thenAnswer((_) async => const <Household>[]);
  return repo;
}

// FirebaseFunctions stub. ComplianceExportManager's constructor otherwise
// calls FirebaseFunctions.instanceFor() which throws
// "[core/no-app] No Firebase App '[DEFAULT]' has been created" in the
// unit-test runtime. BUT-842: the manager now re-throws unexpected
// exceptions from `httpsCallable(...).call(...)` (previously swallowed), so
// the fake must return a no-op callable that yields an empty audit-log
// page — otherwise every `exportUserData()` test in this file would abort
// on the audit-log slot.
class _EmptyHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _EmptyHttpsCallableResult(this.data);
  @override
  final T data;
}

class _EmptyHttpsCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    // BUT-866: production call site is always
    // `httpsCallable.call<Map<dynamic, dynamic>>(...)`
    // (compliance_export_manager.dart:108). The cast below assumes that exact
    // generic — if a future refactor changes it to a typed result, the cast
    // fails with an opaque `_TypeError`. The assert keeps the failure mode
    // loud + located.
    assert(
      T == Map<dynamic, dynamic>,
      '_EmptyHttpsCallable: production call site must use '
      'call<Map<dynamic, dynamic>>(); got T=$T. Update this fake when the '
      'production generic changes.',
    );
    return _EmptyHttpsCallableResult<T>(
      <String, dynamic>{'rows': const [], 'nextCursor': null} as T,
    );
  }
}

class _FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) => _EmptyHttpsCallable();
}

/// BUT-864: HttpsCallable stub that simulates a transient backend failure on
/// the audit-log call. ComplianceExportManager catches this and returns a
/// `{error_code: 'unavailable', ...}` envelope; DataExportService then has
/// to surface it as a top-level warning.
class _TransientHttpsCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Backend temporarily unavailable',
    );
  }
}

class _TransientFirebaseFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) => _TransientHttpsCallable();
}

/// BUT-865: HttpsCallable that succeeds on call #1 (returns one row + a
/// `nextCursor`, forcing the manager to loop) and throws a transient
/// `FirebaseFunctionsException` on call #2. Used to pin the contract for
/// mid-pagination-loop failures.
class _SuccessThenTransientHttpsCallable extends Fake implements HttpsCallable {
  int _callCount = 0;

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    _callCount++;
    if (_callCount == 1) {
      return _EmptyHttpsCallableResult<T>(
        <String, dynamic>{
              'rows': [
                <String, dynamic>{
                  'id': 'log-page1',
                  'operation': 'read',
                  'resourceType': 'recipes',
                  'resourceId': 'r1',
                  'timestamp': '2026-05-19T00:00:00Z',
                  'granted': true,
                },
              ],
              'nextCursor': 'cursor-after-page-1',
            }
            as T,
      );
    }
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'page #2 transient',
    );
  }
}

/// BUT-1721: a gateway whose conversation probe reports a CLIPPED conversation.
///
/// The flag it returns is exactly what the real probe sets when a conversation
/// holds more messages than the per-conversation cap. Seeding 1001 messages into
/// the fake would prove the same thing at a hundred times the runtime, and what
/// is under test here is the AGGREGATOR: whether a flag nested inside a LIST of
/// conversation maps reaches `export_metadata.truncated_collections`.
class _ClippedConversationsExportRepository
    extends FirebaseDataExportRepository {
  _ClippedConversationsExportRepository({
    required super.firestore,
    required super.authRepository,
  });

  @override
  Future<List<Map<String, dynamic>>> exportConversationsAndMessages(
    String userId, {
    int maxConversations = 100,
    int maxMessagesPerConversation = 500,
  }) async => [
    <String, dynamic>{
      'id': 'convo-1',
      'data': <String, dynamic>{
        'participantIds': [userId],
      },
      'messages': [
        <String, dynamic>{
          'id': 'msg-1',
          'data': <String, dynamic>{'senderId': userId, 'text': 'Hej'},
        },
      ],
      'messages_truncated': true,
    },
  ];
}

/// BUT-1721: a gateway whose profile read fails. `_exportUserProfile` catches it
/// and returns `{'error': ...}` with NO `error_code` — the shape most export
/// sections still use, and the one that was invisible in
/// `export_metadata.warnings`.
class _FailingProfileExportRepository extends FirebaseDataExportRepository {
  _FailingProfileExportRepository({
    required super.firestore,
    required super.authRepository,
  });

  @override
  Future<Map<String, dynamic>?> exportPrivateProfile(String userId) async =>
      throw StateError('profile read failed');
}

/// BUT-1732: fails a section with backend text carrying exactly what must never
/// reach the bundle ROOT — ANOTHER data subject's uid inside a composite doc id,
/// plus a `create_composite` index URL naming a member field path and the
/// project id.
///
/// BUT-1760 repointed this from `preferences` to `audit_logs`. The original
/// fixture leaned on `PreferencesExportManager.exportPreferences` returning
/// `{'error': e.toString()}`; that manager (and the eleven sections in
/// `ContentExportManager`) now return authored sentences, so the premise it
/// asserted no longer exists there. `ComplianceExportManager`'s transient
/// branch still puts `e.message` — a string the BACKEND wrote — into the
/// section's `error`, which keeps this a REAL leak path rather than a contrived
/// one. The suppression under test is the aggregator's: the single place that
/// decides what gets promoted to `export_metadata.warnings[].message`.
class _LeakyAuditLogHttpsCallable extends Fake implements HttpsCallable {
  static const String foreignUid = 'uid-of-another-person-9f2e45';
  static const String indexUrl =
      'https://console.firebase.google.com/project/butlery-prod-42/firestore/'
      'indexes?create_composite=memberPermissions.$foreignUid';

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async => throw FirebaseFunctionsException(
    // Transient, so the manager returns an envelope instead of aborting the
    // whole bundle — the aggregator only ever sees sections that returned.
    code: 'unavailable',
    message:
        'PERMISSION_DENIED reading blocks/uid-alice_$foreignUid; $indexUrl',
  );
}

class _LeakyAuditLogFirebaseFunctions extends Fake
    implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) => _LeakyAuditLogHttpsCallable();
}

/// BUT-1760: fails the `preferences` read with an exception whose text names
/// another data subject. Proves the SECTION body — not just the bundle root —
/// is now authored, which is what stops the leak one level before the
/// aggregator ever sees it.
class _LeakySettingsExportRepository extends FirebaseDataExportRepository {
  _LeakySettingsExportRepository({
    required super.firestore,
    required super.authRepository,
  });

  static const String foreignUid = 'uid-of-another-person-9f2e45';

  @override
  Future<Map<String, dynamic>?> exportSettingsPreferences(
    String userId,
  ) async => throw StateError(
    'PERMISSION_DENIED reading blocks/${userId}_$foreignUid',
  );
}

/// BUT-1721 (fix round): the PARTIAL shape — a section that sets `error_code`
/// but NOT `error`.
///
/// `SharedShoppingListExport` is the one section that does this, deliberately:
/// its contributor probe is the only one a rules refusal can stop, so a
/// transient failure there leaves the owner and member probes' lists in the
/// section body along with an accurate note. The section WAS exported; one of
/// its three lookups was not.
///
/// A non-`permission-denied` exception is what makes it a warning rather than
/// the documented rules-refusal note, so the throw below is a `StateError`.
class _TransientContributorProbeRepository
    extends FirebaseDataExportRepository {
  _TransientContributorProbeRepository({
    required super.firestore,
    required super.authRepository,
  });

  @override
  Future<List<Map<String, dynamic>>> exportSharedShoppingListsAsContributor(
    String userId, {
    int maxDocuments = 500,
  }) async => throw StateError('deadline exceeded on the contributor probe');
}

class _SuccessThenTransientFirebaseFunctions extends Fake
    implements FirebaseFunctions {
  final _SuccessThenTransientHttpsCallable _callable =
      _SuccessThenTransientHttpsCallable();
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) => _callable;
}

void main() {
  group('DataExportService - GDPR Data Export', () {
    late DataExportService service;
    late FakeAuthRepository mockAuthRepository;
    late MockUser mockUser;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirestoreRepository mockFirestoreRepository;

    const testUserId = 'user-123';
    const testEmail = 'test@example.com';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = FakeAuthRepository();
      mockUser = MockUser();
      mockFirestoreRepository = MockFirestoreRepository();

      mockUser.setUserState(uid: testUserId, email: testEmail);
      // See [_FakeUserMetadata]: without these two stubs the profile section
      // fails in every test in this file. `MockUser` covers `uid`, `email` and
      // `displayName` only, and mocktail throws on any other non-nullable
      // getter — `emailVerified` and `metadata` are both read by
      // `_exportUserProfile`.
      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockUser.metadata).thenReturn(_FakeUserMetadata());
      mockAuthRepository.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      when(() => mockFirestoreRepository.firestore).thenReturn(fakeFirestore);

      // BUT-501: wire fake-firestore-backed repos so the new export-via-repo
      // paths exercise end-to-end instead of falling through to ServiceLocator
      // and silently turning into `{'error': ...}` payloads.
      service = DataExportService(
        authRepository: mockAuthRepository,
        firestoreRepository: mockFirestoreRepository,
        householdRepository: _emptyFamilyHouseholdRepo(),
        // Inject a manager wired to the fake-functions stub so the
        // constructor doesn't hit FirebaseFunctions.instanceFor().
        // BUT-842: also inject a fake-firestore-backed dataExportRepository so
        // exportConsentRecords doesn't fall through to ServiceLocator (the
        // manager re-throws unknown errors instead of swallowing them).
        complianceExportManager: ComplianceExportManager(
          functions: _FakeFirebaseFunctions(),
          dataExportRepository: FirebaseDataExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        ),
        commentsRepository: FirebaseCommentsRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        ratingsRepository: FirebaseRatingsRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        feedbackRepository: FirebaseFeedbackRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        cookSnapRepository: FirebaseCookSnapRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        cookEventRepository: FirebaseCookEventRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
          recipeRepository: FirebaseRecipeRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        ),
        activityEventRepository: FirebaseActivityEventRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        weeklyMenuPlanRepository: FirebaseWeeklyMenuPlanRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        groupWeeklyMenuPlanRepository: FirebaseGroupWeeklyMenuPlanRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        pantryRepository: FirebasePantryRepository(
          firestore: fakeFirestore,
        ),
        recipeRepository: FirebaseRecipeRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        personalTagRepository: FirebasePersonalTagRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        personalTagGroupRepository: FirebasePersonalTagGroupRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
        dataExportRepository: FirebaseDataExportRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepository,
        ),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Authentication', () {
      test('should throw when user not authenticated', () async {
        mockAuthRepository.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );
        expect(() => service.exportUserData(), throwsA(isA<Exception>()));
      });
    });

    /// BUT-1773: the Art. 15 export wrote no Art. 30 record at all — neither
    /// for a bundle it produced nor for a request it refused. A right-of-access
    /// pipeline that leaves no trace of having run is unauditable: nothing can
    /// answer "did this user export their data, and when".
    ///
    /// Asserted through a spy rather than by reading `audit_logs` out of the
    /// fake: `AuditLog.toFirestore` embeds `FieldValue.serverTimestamp()`,
    /// which throws `MethodChannelFieldValue is not a subtype of
    /// MockFieldValuePlatform` under the test platform bindings, and
    /// `logPermissionCheck` swallows that by design (fire-and-forget). A
    /// fake-collection assertion would therefore be vacuous — it would read
    /// zero rows whether or not the call was made.
    group('Export audit trail (BUT-1773)', () {
      late _SpyAuditRepository spyAudit;
      late DataExportService auditedService;

      setUp(() {
        spyAudit = _SpyAuditRepository(fakeFirestore);
        auditedService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
          householdRepository: _emptyFamilyHouseholdRepo(),
          complianceExportManager: ComplianceExportManager(
            functions: _FakeFirebaseFunctions(),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          ),
          dataExportRepository: FirebaseDataExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
          auditRepository: spyAudit,
        );
      });

      test('a granted export writes exactly ONE row', () async {
        await auditedService.exportUserData();

        expect(
          spyAudit.calls,
          hasLength(1),
          reason:
              'One row per REQUEST, not per read. The gateway makes ~30 '
              'ownership-guarded reads per bundle, and firestore.rules caps '
              'audit_logs creates at rateLimitWrite(audit_logs, 2) — a row per '
              'read would be rejected from the third one on and leave an '
              'arbitrarily partial trail.',
        );
        final row = spyAudit.calls.single;
        expect(row['userId'], testUserId);
        expect(row['operation'], 'gdpr_export');
        expect(row['resourceType'], 'data_export');
        expect(row['granted'], isTrue);
        expect((row['metadata'] as Map)['outcome'], 'granted');
      });

      test('a REFUSED export writes a denied row', () async {
        mockAuthRepository.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        await expectLater(
          auditedService.exportUserData(),
          throwsA(isA<Exception>()),
        );

        expect(
          spyAudit.calls,
          hasLength(1),
          reason:
              'A refusal is a processing activity too, and it is the case a '
              'data subject later disputes.',
        );
        final row = spyAudit.calls.single;
        expect(row['operation'], 'gdpr_export');
        expect(row['granted'], isFalse);
        expect(
          (row['metadata'] as Map)['outcome'],
          'denied_unauthenticated',
        );
      });
    });

    group('Export Structure', () {
      test('should create valid JSON export', () async {
        final jsonString = await service.exportUserData();
        expect(jsonString, isNotEmpty);
        expect(() => json.decode(jsonString), returnsNormally);
      });

      // BUT-1957. The manager-layer suite proves which repository METHOD is
      // called; which Firestore COLLECTION that method reads is decided a layer
      // down and was pinned by nothing — repointing
      // `.collection(FirestoreCollections.userDeliveredNotifications)` at
      // `user_notifications` or `notification_history` left the whole repo
      // green. That is the BUT-1697 bug class: a wrong collection name matches
      // zero documents and silently empties a section of the export.
      //
      // This runs the REAL repository over the fake Firestore, and seeds both
      // sources with rows that disagree, so a read of the wrong one fails
      // rather than passing on its neighbour's data.
      test('delivered_notifications reads the subcollection, not the '
          'top-level user_notifications', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('notifications')
            .doc('sub-1')
            .set({
              'type': 'win_back',
              'message': 'Vi saknar dig',
              'bodyShown': 'Vi saknar dig',
              // Load-bearing, and this lane CANNOT prove why: the production
              // read is ordered by `createdAt`, and real Firestore drops a
              // document that lacks the orderBy field. `fake_cloud_firestore`
              // does not — measured: a row without `createdAt` comes back, and
              // comes back FIRST. So a future fixture that omits it passes
              // green here while production exports nothing. Seed it.
              'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
              'read': false,
            });
        // The decoy: same user, the OTHER collection.
        await fakeFirestore.collection('user_notifications').doc('top-1').set({
          'userId': testUserId,
          'type': 'social',
          'title': 'Decoy',
          'body': 'must not appear in delivered_notifications',
          'createdAt': Timestamp.fromDate(DateTime(2026, 8, 2)),
          'isRead': false,
        });

        final data =
            json.decode(await service.exportUserData()) as Map<String, dynamic>;
        final section = data['delivered_notifications'] as Map<String, dynamic>;
        final rows = (section['notifications'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        expect(
          section.containsKey('error'),
          isFalse,
          reason: 'a denied or mis-pathed read must not read as an empty week',
        );
        expect(rows.map((r) => r['notification_id']), contains('sub-1'));
        expect(rows.map((r) => r['notification_id']), isNot(contains('top-1')));
        // And the neighbour section still gets its own row, so this is a proof
        // about routing rather than about one of the two being empty.
        final neighbour = data['notifications'] as Map<String, dynamic>;
        expect(neighbour['total_count'], 1);
      });

      test('should include export metadata', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['export_metadata'], isNotNull);
        expect(data['export_metadata']['user_id'], testUserId);
        expect(data['export_metadata']['format'], 'JSON');
      });

      test('should include all required sections', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        // Core user data
        expect(data['profile'], isNotNull);
        expect(data['recipes'], isNotNull);
        expect(data['menus'], isNotNull);
        expect(data['shopping_lists'], isNotNull);
        // BUT-1732: `shopping_lists` is the PERSONAL subcollection only, and
        // the shared-list section is wired in as its own bundle key. That one
        // map entry is deletable with every section test still green — the
        // manager's own suite drives `exportSharedShoppingLists` directly and
        // never sees the bundle — so a household that shops from a shared list
        // could silently lose its whole shopping history from the Art. 15
        // export again. Assert the section is PRESENT and is not an error
        // envelope: "we could not give you this" is a different Art. 15
        // answer from "there is nothing".
        expect(data['shared_shopping_lists'], isNotNull);
        expect(data['shared_shopping_lists']['total_count'], 0);
        expect(
          (data['shared_shopping_lists'] as Map).containsKey('error'),
          isFalse,
        );
        expect(data['personal_tags'], isNotNull);
        // Social data
        expect(data['friends'], isNotNull);
        expect(data['messages'], isNotNull);
        expect(data['shared_content'], isNotNull);
        // Activity
        expect(data['comments_and_ratings'], isNotNull);
        // GDPR compliance
        expect(data['audit_logs'], isNotNull);
        expect(data['consent_records'], isNotNull);
        // Preferences
        expect(data['preferences'], isNotNull);
        expect(data['notifications'], isNotNull);
        // BUT-1957, and the same shape the shared-list comment above warns
        // about: `delivered_notifications` is one map entry in
        // `_buildExportBundle`, deletable with every other section test still
        // green, because the manager's own suite drives the method directly and
        // never sees the bundle. Measured — dropping the entry left the whole
        // suite passing. Present AND not an error envelope: "we could not give you
        // this" is a different Art. 15 answer from "there is nothing".
        expect(data['delivered_notifications'], isNotNull);
        expect(
          (data['delivered_notifications'] as Map).containsKey('error'),
          isFalse,
        );
        expect(data['notification_preferences'], isNotNull);
        // BUT-1396: erased-but-unexported PII collections + group menus must
        // each have a present (non-null) section so Art. 15 right-of-access is
        // satisfied even when the user has none of this data.
        expect(data['reports'], isNotNull);
        expect(data['pings'], isNotNull);
        expect(data['realtime_recipes'], isNotNull);
        expect(data['group_weekly_menu_plans'], isNotNull);
        // BUT-1450: notification-analytics sections the deletion cascade
        // erases must each be present for Art. 15 right-of-access.
        expect(data['notification_history'], isNotNull);
        expect(data['notification_batches'], isNotNull);
        expect(data['notification_engagement'], isNotNull);
        expect(data['notification_delivery'], isNotNull);
        // Increment 5 (pooled ratings, decision 12): the deletion cascade erases
        // canonical_rating_events, so the export must carry the section (export ⊇
        // erased) even when the user has no pooled votes.
        expect(data['pooled_rating_events'], isNotNull);
      });
    });

    group('Data Export', () {
      test('should export recipes', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('recipes')
            .doc('recipe-1')
            .set({'title': 'Test Recipe'});

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['recipes'], isNotNull);
        expect(data['recipes']['recipes'], isList);
      });

      test('should export friends', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friends')
            .doc('friend-1')
            .set({'friendId': 'friend-1'});

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['friends'], isNotNull);
        expect(data['friends']['friends'], isList);
      });

      test('should export shopping lists', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('shopping_lists')
            .doc('list-1')
            .set({'name': 'Weekly Shopping'});

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['shopping_lists'], isNotNull);
        expect(data['shopping_lists']['shopping_lists'], isList);
      });

      test('should export menus', () async {
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('menus')
            .doc('menu-1')
            .set({'name': 'Weekly Menu'});

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['menus'], isNotNull);
        expect(data['menus']['menus'], isList);
      });

      test('should export comments and ratings', () async {
        await fakeFirestore.collection('recipe_comments').doc('comment-1').set({
          'userId': testUserId,
          'text': 'Great!',
        });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['comments_and_ratings'], isNotNull);
      });

      test('Increment 5: seeded canonical_rating_events flows into the export '
          '(export ⊇ erased, real data not error payload)', () async {
        // Seed a frozen pool event at the user-scoped subcollection the deletion
        // cascade erases. If the export wiring regresses (wrong path, ownership
        // guard, or a stray error), the section falls back to {'error': ...} and
        // this fails — proving the real read path, not just section presence.
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('canonical_rating_events')
            .doc('v1:aaaabbbbccccdddd')
            .set({
              'poolKey': 'v1:aaaabbbbccccdddd',
              'ratingValue': 4,
              'recipeId': 'recipe-1',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['pooled_rating_events'] as Map<String, dynamic>;
        expect(section['error'], isNull);
        expect(section['events'], isList);
        expect(section['total_count'], 1);
        final events = section['events'] as List;
        expect(events.first['id'], 'v1:aaaabbbbccccdddd');
        expect((events.first['data'] as Map)['ratingValue'], 4);
      });

      test('BUT-501: export-via-repo paths return real data (not error '
          'payload) for cook_snaps, activity_events, weekly_menu_plans, '
          'and pantry', () async {
        // Seed a row in each migrated collection so the repo-backed
        // exporters return a populated list. If the validateOwnership
        // guard or the test-time wiring regresses, these collections
        // will fall back to `{'error': ...}` and the test fails.
        await fakeFirestore.collection('cook_snaps').doc('snap-1').set({
          'userId': testUserId,
          'recipeId': 'r1',
          'createdAt': DateTime.now(),
        });
        await fakeFirestore.collection('activity_events').doc('evt-1').set({
          'actorId': testUserId,
          'kind': 'cook',
        });
        await fakeFirestore
            .collection('weekly_menu_plans')
            .doc('${testUserId}_2026-W17')
            .set({'userId': testUserId, 'entries': []});
        await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('pantry')
            .doc('item-1')
            .set({'name': 'mjölk'});

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        // Each migrated section MUST surface its row, proving the repo
        // path is live (and the `validateOwnership` guard accepts the
        // self-export case).
        expect(data['cook_snaps']['total_count'], equals(1));
        expect(data['activity_events']['total_count'], equals(1));
        expect(data['weekly_menu_plans']['total_count'], equals(1));
        expect(data['pantry_items']['total_count'], equals(1));
      });

      test('BUT-1235: export bundle includes recipe_cook_events with the '
          'user\'s cook events as {event_id, data}', () async {
        // Seed directly (logCookEvent uses FieldValue.increment, which is
        // MethodChannel-backed after BaseUnitTest.setupUnit — see the cook
        // event integration test header for the freeze gotcha).
        await fakeFirestore
            .collection('recipe_cook_events')
            .doc(testUserId)
            .collection('events')
            .doc('evt-1')
            .set({
              'recipeId': 'r1',
              'cookedAt': DateTime(2026, 6, 1, 18, 30),
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['recipe_cook_events'] as Map<String, dynamic>;
        expect(
          section.containsKey('error'),
          isFalse,
          reason:
              'a repo-path or ownership-guard regression turns the '
              'section into an {error: ...} payload',
        );
        expect(section['total_count'], equals(1));
        final events = section['recipe_cook_events'] as List<dynamic>;
        final event = events.single as Map<String, dynamic>;
        expect(event['event_id'], 'evt-1');
        expect(event['data']['recipeId'], 'r1');
        expect(
          event['data']['cookedAt'],
          isA<String>(),
          reason: 'timestamps must be sanitized to ISO strings for JSON',
        );
      });

      test('BUT-1396: reports filed by the user export with the free-text '
          'description round-tripping (and total==1)', () async {
        // `description` is the genuine PII (the `reason` field is an enum);
        // the deletion cascade erases this doc, so Art. 15 requires it in the
        // export. A repo/ownership regression turns the section into an
        // {error: ...} payload or drops the free-text field.
        await fakeFirestore.collection('reports').doc('rep-1').set({
          'reporterId': testUserId,
          'reason': 'harassment',
          'description': 'Skickade hotfulla meddelanden i gruppchatten.',
        });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['reports'] as Map<String, dynamic>;
        expect(
          section.containsKey('error'),
          isFalse,
          reason: 'an ownership-guard/repo regression yields {error: ...}',
        );
        expect(section['total'], 1);
        final reports = section['reports'] as List<dynamic>;
        final report = reports.single as Map<String, dynamic>;
        expect(report['report_id'], 'rep-1');
        expect(
          report['data']['description'],
          'Skickade hotfulla meddelanden i gruppchatten.',
          reason: 'the free-text PII must survive the export verbatim',
        );
      });

      test('BUT-1396: a report filed by a DIFFERENT user is NOT in the '
          'calling user\'s export (ownership scoping)', () async {
        // The query filters on reporterId == uid; a foreign report must never
        // leak into this user\'s bundle. If the filter regresses to fetching
        // all reports, this fails.
        await fakeFirestore.collection('reports').doc('mine').set({
          'reporterId': testUserId,
          'reason': 'spam',
          'description': 'min anmälan',
        });
        await fakeFirestore.collection('reports').doc('theirs').set({
          'reporterId': 'someone-else',
          'reason': 'spam',
          'description': 'annans anmälan',
        });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['reports'] as Map<String, dynamic>;
        expect(section['total'], 1);
        final ids = (section['reports'] as List<dynamic>)
            .map((e) => (e as Map<String, dynamic>)['report_id'])
            .toList();
        expect(ids, ['mine']);
        expect(
          ids,
          isNot(contains('theirs')),
          reason: 'a foreign user\'s report must never appear in the export',
        );
      });

      test('BUT-1396: collaborative recipes the user owns export under '
          'realtime_recipes (total_count==1)', () async {
        // `realtime_recipes` is keyed on `ownerId` (the model\'s authoritative
        // field), not the cascade CF\'s no-op `userId`. The export queries
        // ownerId so the bundle ⊇ what deletion erases.
        await fakeFirestore.collection('realtime_recipes').doc('rt-1').set({
          'ownerId': testUserId,
          'title': 'Delat recept',
        });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['realtime_recipes'] as Map<String, dynamic>;
        expect(section.containsKey('error'), isFalse);
        expect(section['total_count'], 1);
        final recipes = section['realtime_recipes'] as List<dynamic>;
        final recipe = recipes.single as Map<String, dynamic>;
        expect(recipe['recipe_id'], 'rt-1');
        expect(recipe['data']['title'], 'Delat recept');
      });

      test('BUT-1396: group pings the user sent export via the pings '
          'collection-group (total==1)', () async {
        // Pings nest under pings/{groupId}/pings/{pingId}; the export uses a
        // collectionGroup('pings').where(fromUserId==uid) query. Confirmed
        // fake_cloud_firestore 4.x supports collectionGroup, so this is a real
        // end-to-end assertion (not a degraded presence-only check).
        await fakeFirestore
            .collection('pings')
            .doc('group-1')
            .collection('pings')
            .doc('ping-1')
            .set({
              'fromUserId': testUserId,
              'message': 'middag 18:00?',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['pings'] as Map<String, dynamic>;
        expect(
          section.containsKey('error'),
          isFalse,
          reason: 'a collectionGroup/ownership regression yields {error: ...}',
        );
        expect(section['total'], 1);
        final pings = section['pings'] as List<dynamic>;
        final ping = pings.single as Map<String, dynamic>;
        expect(ping['ping_id'], 'ping-1');
        expect(ping['data']['message'], 'middag 18:00?');
      });

      test('BUT-1396: a user with none of the new PII data still gets the '
          'sections present with no error (empty-safe Art. 15)', () async {
        // No reports/pings/realtime_recipes/group menus seeded — the export
        // must still surface every section as an empty, error-free shape so
        // the bundle is honest about "you have none of this" rather than
        // omitting the section or carrying a swallowed error.
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        for (final key in const [
          'reports',
          'pings',
          'realtime_recipes',
          'group_weekly_menu_plans',
        ]) {
          final section = data[key] as Map<String, dynamic>;
          expect(
            section.containsKey('error'),
            isFalse,
            reason: '$key must be empty-safe, not an {error: ...} payload',
          );
        }
        expect(data['reports']['total'], 0);
        expect(data['pings']['total'], 0);
        expect(data['realtime_recipes']['total_count'], 0);
        expect(data['group_weekly_menu_plans']['total_count'], 0);
      });
    });

    group('BUT-1450: notification analytics in GDPR export', () {
      test('notification_history the user received exports with title/body '
          'round-tripping (total_count==1)', () async {
        // The deletion cascade erases these; Art. 15 requires the export to
        // carry the friendly record the user actually saw. The repo query
        // orderBy('sentAt', descending) requires the field present — confirmed
        // fake_cloud_firestore honours orderBy on a present field.
        await fakeFirestore.collection('notification_history').doc('nh-1').set({
          'userId': testUserId,
          'sentAt': DateTime(2026, 6, 20, 9, 0),
          'title': 'Dags att handla',
          'body': 'Din inköpslista är redo inför helgen.',
          'type': 'shopping_reminder',
        });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['notification_history'] as Map<String, dynamic>;
        expect(
          section.containsKey('error'),
          isFalse,
          reason: 'a repo/ownership/orderBy regression yields {error: ...}',
        );
        expect(section['total_count'], 1);
        final entries = section['notification_history'] as List<dynamic>;
        final entry = entries.single as Map<String, dynamic>;
        expect(entry['id'], 'nh-1');
        expect(entry['data']['title'], 'Dags att handla');
        expect(
          entry['data']['body'],
          'Din inköpslista är redo inför helgen.',
          reason: 'the human-readable notification body must survive verbatim',
        );
      });

      test(
        'notification_batches the user owns export (total_count==1)',
        () async {
          await fakeFirestore
              .collection('notification_batches')
              .doc('nb-1')
              .set({
                'userId': testUserId,
                'kind': 'weekly_digest',
              });

          final jsonString = await service.exportUserData();
          final data = json.decode(jsonString) as Map<String, dynamic>;

          final section = data['notification_batches'] as Map<String, dynamic>;
          expect(section.containsKey('error'), isFalse);
          expect(section['total_count'], 1);
          final entries = section['notification_batches'] as List<dynamic>;
          expect((entries.single as Map<String, dynamic>)['id'], 'nb-1');
        },
      );

      test('notification_engagement (open/click events) export '
          '(total_count==1)', () async {
        await fakeFirestore
            .collection('notification_engagement')
            .doc('ne-1')
            .set({
              'userId': testUserId,
              'action': 'opened',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['notification_engagement'] as Map<String, dynamic>;
        expect(section.containsKey('error'), isFalse);
        expect(section['total_count'], 1);
        final entry =
            (section['notification_engagement'] as List<dynamic>).single
                as Map<String, dynamic>;
        expect(entry['id'], 'ne-1');
        expect(entry['data']['action'], 'opened');
      });

      test('notification_delivery merges sent + received, and the '
          'counterparty UID is INCLUDED, not anonymised', () async {
        // One row where the user SENT (target is someone else), one where the
        // user RECEIVED (sender is someone else). The union is two rows.
        await fakeFirestore
            .collection('notification_delivery')
            .doc('nd-sent')
            .set({
              'senderId': testUserId,
              'targetUserId': 'other-uid',
              'notificationId': 'n-sent',
            });
        await fakeFirestore
            .collection('notification_delivery')
            .doc('nd-recv')
            .set({
              'senderId': 'other-uid',
              'targetUserId': testUserId,
              'notificationId': 'n-recv',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['notification_delivery'] as Map<String, dynamic>;
        expect(section.containsKey('error'), isFalse);
        expect(section['total_count'], 2);
        expect(section['sent_count'], 1);
        expect(section['received_count'], 1);

        final rows = (section['notification_delivery'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final receivedRow = rows.firstWhere(
          (r) =>
              (r['data'] as Map<String, dynamic>)['targetUserId'] == testUserId,
        );
        // BUT-1450 decided behaviour (see accepted-deviations.md): on the row
        // where THIS user is the target, the counterparty senderId is exported
        // AS-IS — the real 'other-uid', NOT '[anonymised]'. This pins the
        // include-the-counterparty Art. 15(4) decision; a redaction regression
        // (replacing the UID) must fail here.
        expect(
          (receivedRow['data'] as Map<String, dynamic>)['senderId'],
          'other-uid',
          reason: 'counterparty UID is included, never anonymised (BUT-1450)',
        );
      });

      test('notification_delivery de-dupes a self-targeted row matched by '
          'both queries (appears once)', () async {
        // senderId == targetUserId == the user: both the sent query and the
        // received query match this single doc; the merged list must hold it
        // exactly once even though both counts see it.
        await fakeFirestore
            .collection('notification_delivery')
            .doc('nd-self')
            .set({
              'senderId': testUserId,
              'targetUserId': testUserId,
              'notificationId': 'n-self',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final section = data['notification_delivery'] as Map<String, dynamic>;
        expect(section['sent_count'], 1);
        expect(section['received_count'], 1);
        // De-duped by doc id: counted once in the merged list / total_count.
        expect(section['total_count'], 1);
        final rows = section['notification_delivery'] as List<dynamic>;
        expect(rows, hasLength(1));
        expect((rows.single as Map<String, dynamic>)['id'], 'nd-self');
      });

      test('ownership-negative: foreign notification_delivery and foreign '
          'notification_history never leak into the bundle', () async {
        // A delivery doc where neither side is the user.
        await fakeFirestore
            .collection('notification_delivery')
            .doc('nd-foreign')
            .set({
              'senderId': 'stranger-a',
              'targetUserId': 'stranger-b',
            });
        // A history doc owned by a different user.
        await fakeFirestore
            .collection('notification_history')
            .doc('nh-foreign')
            .set({
              'userId': 'other-uid',
              'sentAt': DateTime(2026, 6, 21, 9, 0),
              'title': 'Inte din',
              'body': 'Tillhör någon annan.',
            });

        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final delivery = data['notification_delivery'] as Map<String, dynamic>;
        expect(delivery['total_count'], 0);
        expect(delivery['notification_delivery'], isEmpty);

        final history = data['notification_history'] as Map<String, dynamic>;
        expect(history['total_count'], 0);
        final historyIds = (history['notification_history'] as List<dynamic>)
            .map((e) => (e as Map<String, dynamic>)['id'])
            .toList();
        expect(historyIds, isNot(contains('nh-foreign')));
      });

      test('empty-safe: a user with no notification analytics still gets all '
          'four sections present with no error', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        for (final key in const [
          'notification_history',
          'notification_batches',
          'notification_engagement',
          'notification_delivery',
        ]) {
          final section = data[key] as Map<String, dynamic>;
          expect(
            section.containsKey('error'),
            isFalse,
            reason: '$key must be empty-safe, not an {error: ...} payload',
          );
          expect(section['total_count'], 0);
        }
      });
    });

    group('GDPR Compliance', () {
      test('should include GDPR metadata', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        final metadata = data['export_metadata']['gdpr_compliance'];
        expect(metadata['article_15'], contains('Right of Access'));
        expect(metadata['article_20'], contains('Data Portability'));
        expect(metadata['article_30'], contains('Audit Logs'));
        expect(metadata['article_7'], contains('Consent'));
      });

      test('should mark export as including audit logs', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['export_metadata']['includes_audit_logs'], isTrue);
        expect(data['export_metadata']['includes_consent_history'], isTrue);
      });

      test('should export audit logs section', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['audit_logs'], isNotNull);
      });

      test('should export consent records section', () async {
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['consent_records'], isNotNull);
      });
    });

    group('Service Info', () {
      test('should return service name', () {
        expect(service.serviceName, 'DataExportService');
      });
    });

    group(
      'BUT-864: transient per-section errors surface as top-level warnings',
      () {
        test('audit-log unavailable produces export_metadata.warnings entry with '
            'error_code', () async {
          // Replace the default service with one whose audit-log call throws a
          // transient FirebaseFunctionsException. ComplianceExportManager will
          // catch + return the BUT-842 envelope; DataExportService should then
          // aggregate it into a top-level `warnings` array on export_metadata.
          final transientService = DataExportService(
            authRepository: mockAuthRepository,
            firestoreRepository: mockFirestoreRepository,
            householdRepository: _emptyFamilyHouseholdRepo(),
            complianceExportManager: ComplianceExportManager(
              functions: _TransientFirebaseFunctions(),
              dataExportRepository: FirebaseDataExportRepository(
                firestore: fakeFirestore,
                authRepository: mockAuthRepository,
              ),
            ),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          );

          final jsonString = await transientService.exportUserData();
          final data = json.decode(jsonString) as Map<String, dynamic>;
          // The audit_logs section itself still carries the transient envelope.
          expect(data['audit_logs']['error_code'], 'unavailable');

          // The aggregated top-level warnings array is the new contract.
          final warnings =
              data['export_metadata']['warnings'] as List<dynamic>?;
          expect(
            warnings,
            isNotNull,
            reason:
                'A transient section error must surface as a top-level '
                'warning entry so the consuming UI can flag the partial '
                'bundle without scanning every section.',
          );
          // Scoped to audit_logs rather than asserting the whole array's
          // length. This fixture wires ONLY the compliance manager and the
          // export gateway, so eleven other sections legitimately fail with
          // "ServiceLocator not initialized" — they always did, and BUT-1721
          // is precisely the change that stopped those failures being invisible
          // at bundle level. The over-warning direction is guarded by the
          // fully-wired happy-path test below, which asserts NO warnings key.
          final auditEntries = warnings!
              .cast<Map<String, dynamic>>()
              .where((w) => w['section'] == 'audit_logs')
              .toList();
          expect(auditEntries, hasLength(1));
          final entry = auditEntries.single;
          expect(entry['error_code'], 'unavailable');
          expect(entry['message'], isNotEmpty);
        });

        test('no transient errors → no warnings array (avoids polluting '
            'happy-path bundles)', () async {
          // The default `service` (built in setUp) uses _FakeFirebaseFunctions
          // which returns empty audit-log pages — no error_code anywhere.
          final jsonString = await service.exportUserData();
          final data = json.decode(jsonString) as Map<String, dynamic>;
          expect(
            data['export_metadata'].containsKey('warnings'),
            isFalse,
            reason:
                'warnings key is only set when at least one section '
                'reports an error_code; happy-path bundles must not carry '
                'an empty array.',
          );
          // BUT-1721, the OVER-claiming direction. `_declaresTruncation` walks
          // every nested map and list of a section, whole Firestore documents
          // included, and matches any key `truncated` / `*_truncated` whose
          // value is `true`. Its only remaining failure mode is therefore a
          // bundle that admits incompleteness it does not have — an Art. 15
          // artifact telling the data subject rows were dropped when none were.
          // The nested-flag test below covers the under-claiming direction; this
          // is the pair to it. Measured, not assumed: it kills a walk capped at
          // the section root, and a walk that lifted every section. It CANNOT
          // kill a lost `== true` test, because no emitter under
          // `lib/services/account/export/` ever writes the flag false — every
          // one sits behind an `if`. Don't restore that claim.
          expect(
            data['export_metadata'].containsKey('truncated_collections'),
            isFalse,
            reason:
                'nothing in a fully-wired happy-path bundle is truncated, so '
                'the deep walk must find no flag to lift',
          );
          expect(
            data['export_metadata'].containsKey('data_completeness'),
            isFalse,
          );
        });
      },
    );

    /// BUT-1721: the AGGREGATOR's own two lifts, which had zero coverage — every
    /// existing truncation test asserts a manager's section-root flag, and the
    /// warnings tests above only cover a section that already sets `error_code`.
    /// Both lifts are the only thing standing between a partial GDPR bundle and
    /// a bundle that silently claims to be complete.
    group('BUT-1721: bundle-level completeness metadata', () {
      test('a truncation flag nested inside a LIST reaches '
          'truncated_collections', () async {
        // `messages` states truncation per conversation, and `conversations` is
        // a LIST — so the pre-fix walk (`for (final nested in value.values)`
        // with an `is Map` test) could never see it: the list itself is not a
        // Map, and the flag is one level further down.
        final clippedService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
          householdRepository: _emptyFamilyHouseholdRepo(),
          complianceExportManager: ComplianceExportManager(
            functions: _FakeFirebaseFunctions(),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          ),
          dataExportRepository: _ClippedConversationsExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        );

        final data =
            json.decode(await clippedService.exportUserData())
                as Map<String, dynamic>;

        // Premise: the section really does carry the flag, nested in the list.
        final conversations =
            (data['messages'] as Map<String, dynamic>)['conversations']
                as List<dynamic>;
        expect(
          (conversations.single as Map<String, dynamic>)['messages_truncated'],
          isTrue,
          reason: 'fixture must stage the nested flag the walk has to find',
        );

        expect(
          data['export_metadata']['truncated_collections'],
          contains('messages'),
          reason:
              'a bundle that dropped messages must say so at bundle level; '
              'nobody reads 30 sections looking for a nested flag',
        );
        expect(
          data['export_metadata']['data_completeness'],
          contains('messages'),
        );
        // And ONLY messages. This is the falsifiable half of the over-claiming
        // direction: `contains` above stays green for a walk that lifted every
        // section (or that matched `truncated_collections` itself once the
        // metadata map grew a nested one), and a bundle claiming rows were
        // dropped from sections that shipped whole is as wrong an Art. 15
        // answer as one that hides a real gap. Every other manager emits
        // `'truncated': true` conditionally, so no section here can carry the
        // flag by accident.
        expect(
          (data['export_metadata']['truncated_collections'] as List<dynamic>)
              .cast<String>(),
          ['messages'],
        );
      });

      test('a section that fails WITHOUT an error_code still surfaces as a '
          'warning', () async {
        // Most export sections still fail with `{'error': ...}` alone; keying
        // the lift on `error_code` meant a whole Art. 15 section could be
        // missing while the metadata claimed the bundle was complete.
        final failingService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
          householdRepository: _emptyFamilyHouseholdRepo(),
          complianceExportManager: ComplianceExportManager(
            functions: _FakeFirebaseFunctions(),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          ),
          dataExportRepository: _FailingProfileExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        );

        final data =
            json.decode(await failingService.exportUserData())
                as Map<String, dynamic>;

        // Premise: the section failed, and it did so WITHOUT an error_code.
        expect((data['profile'] as Map<String, dynamic>)['error'], isNotNull);
        expect(
          (data['profile'] as Map<String, dynamic>).containsKey('error_code'),
          isFalse,
          reason:
              'this test is about the codeless shape; if the profile section '
              'starts setting its own token, point this at another one',
        );

        final warnings =
            data['export_metadata']['warnings'] as List<dynamic>? ??
            const <dynamic>[];
        final profileWarning = warnings
            .cast<Map<String, dynamic>>()
            .where((w) => w['section'] == 'profile')
            .toList();
        expect(
          profileWarning,
          hasLength(1),
          reason: 'a failed section is one top-level warning, named',
        );
        expect(profileWarning.single['error_code'], 'profile-export-failed');
        expect(profileWarning.single['message'], isNotEmpty);

        // The OUTRIGHT-failure arm of the message branch, and the higher-stakes
        // one. Its sibling test pins the partial shape; without this line the
        // branch could be inverted or dropped and the bundle root would tell the
        // data subject "may be incomplete — one of its lookups did not complete"
        // about a section that shipped NOTHING but an error envelope. That is an
        // Art. 15 UNDER-claim, and a reader who is told a lookup was slow does
        // not re-request.
        expect(
          profileWarning.single['message'],
          contains('could not be exported'),
        );

        // `data_completeness` has TWO arms and this fixture exercises only one
        // of them: a section failed, nothing was clipped. Without these the
        // warnings arm could be deleted outright and the whole suite would stay
        // green — which is the exact defect the aggregator was changed to close
        // (the field stayed ABSENT when sections failed, byte-identical to a
        // fully successful bundle).
        final completeness =
            data['export_metadata']['data_completeness'] as String;
        expect(
          completeness,
          contains('could not be exported or are incomplete'),
        );
        expect(
          completeness,
          isNot(contains('size limits')),
          reason: 'nothing was clipped — the two arms must not be confused',
        );
      });

      /// The mirror of the test above, and the one that was missing: a section
      /// that sets `error_code` but NOT `error` did not fail — it PARTIALLY
      /// succeeded. Lifting it with a flat "could not be exported" is the same
      /// class of defect BUT-1721 exists to close, with the sign flipped: an
      /// Art. 15 bundle telling the data subject a section is missing when it
      /// shipped whole. The subject may forward that artifact to a supervisory
      /// authority, so an over-claim costs as much as an under-claim.
      test('a section that sets error_code WITHOUT error is reported as '
          'incomplete, not as failed', () async {
        final partialService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
          householdRepository: _emptyFamilyHouseholdRepo(),
          complianceExportManager: ComplianceExportManager(
            functions: _FakeFirebaseFunctions(),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          ),
          dataExportRepository: _TransientContributorProbeRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        );

        final data =
            json.decode(await partialService.exportUserData())
                as Map<String, dynamic>;

        // Premise: the section really is in the partial shape. Without this the
        // assertions below would pass against any section that simply succeeded.
        final section =
            data['shared_shopping_lists'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        expect(
          section['error_code'],
          'shared-shopping-lists-contributor-probe-failed',
          reason: 'fixture must stage the error_code-without-error shape',
        );
        expect(
          section.containsKey('error'),
          isFalse,
          reason: 'the section did not fail outright — that is the whole point',
        );

        final warnings =
            data['export_metadata']['warnings'] as List<dynamic>? ??
            const <dynamic>[];
        final listWarning = warnings
            .cast<Map<String, dynamic>>()
            .where((w) => w['section'] == 'shared_shopping_lists')
            .toList();
        expect(listWarning, hasLength(1));
        expect(
          listWarning.single['message'],
          isNot(contains('could not be exported')),
          reason:
              'the section WAS exported; claiming otherwise at bundle root is '
              'the over-claiming half of this ticket',
        );
        expect(listWarning.single['message'], contains('may be incomplete'));
      });

      test(
        'BUT-1732: a lifted warning message is DERIVED, never the raw exception '
        '— no foreign uid and no index URL at the bundle root',
        () async {
          // Lifting a section field to bundle level changes its blast radius:
          // `export_metadata.warnings[].message` sits at the ROOT of the Art. 15
          // bundle the data subject downloads and may forward to a supervisory
          // authority. Copying `value['error']` through put raw Firestore text
          // there. Mutation test: restore
          // `'message': value['error'] ?? value['note'] ?? 'Unknown error'` in
          // `data_export_service.dart` and both isNot(contains(...)) assertions
          // below redden.
          final leakyService = DataExportService(
            authRepository: mockAuthRepository,
            firestoreRepository: mockFirestoreRepository,
            householdRepository: _emptyFamilyHouseholdRepo(),
            complianceExportManager: ComplianceExportManager(
              functions: _LeakyAuditLogFirebaseFunctions(),
              dataExportRepository: FirebaseDataExportRepository(
                firestore: fakeFirestore,
                authRepository: mockAuthRepository,
              ),
            ),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          );

          final data =
              json.decode(await leakyService.exportUserData())
                  as Map<String, dynamic>;

          // Premise: the section really did fail, and its own `error` field
          // really does carry the leaky text — so the assertions below are
          // about the aggregator suppressing it, not about an empty bundle.
          // (That buried section field is the pre-existing half of BUT-1732;
          // this test pins the ROOT, which is what this commit amplified.)
          final section = data['audit_logs'] as Map<String, dynamic>;
          expect(
            section['error'],
            contains(_LeakyAuditLogHttpsCallable.foreignUid),
            reason:
                'premise: audit_logs failed with backend-authored text. If this '
                'fails because ComplianceExportManager stopped putting '
                'e.message in `error`, point this test at another section '
                'whose `error` is not authored locally — or delete it once '
                'none are.',
          );

          final warnings =
              (data['export_metadata']['warnings'] as List<dynamic>? ??
                      const <dynamic>[])
                  .cast<Map<String, dynamic>>();
          final auditWarning = warnings
              .where((w) => w['section'] == 'audit_logs')
              .toList();
          expect(
            auditWarning,
            hasLength(1),
            reason: 'the failed section must still surface as one warning',
          );

          final message = auditWarning.single['message'] as String;
          expect(
            message,
            isNot(contains(_LeakyAuditLogHttpsCallable.foreignUid)),
            reason:
                'Art. 15(4): the requester\'s own bundle must not name another '
                'data subject at its root',
          );
          expect(
            message,
            isNot(contains('create_composite')),
            reason:
                'an index URL embeds the project id and a memberPermissions '
                'field path — internal topology, not the requester\'s data',
          );
          expect(
            message,
            contains('unavailable'),
            reason:
                'suppression must not cost the reader WHICH read failed; the '
                'derived message still names the section and its code',
          );
        },
      );

      // BUT-1760: the two managers this ticket touched are no longer a leak
      // path, and that is now a pinned property rather than an accident. A
      // section-level `error` reaches the bundle in full, so an authored
      // sentence there is the FIRST line of defence and the aggregator's
      // derivation is the second.
      test(
        'BUT-1760: a failed content/preferences section carries an authored '
        'sentence, so no raw exception text exists to suppress',
        () async {
          final service = DataExportService(
            authRepository: mockAuthRepository,
            firestoreRepository: mockFirestoreRepository,
            householdRepository: _emptyFamilyHouseholdRepo(),
            complianceExportManager: ComplianceExportManager(
              functions: _FakeFirebaseFunctions(),
              dataExportRepository: FirebaseDataExportRepository(
                firestore: fakeFirestore,
                authRepository: mockAuthRepository,
              ),
            ),
            dataExportRepository: _LeakySettingsExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          );

          final data =
              json.decode(await service.exportUserData())
                  as Map<String, dynamic>;

          final section = data['preferences'] as Map<String, dynamic>;
          expect(
            section['error'],
            'Could not export preferences.',
            reason: 'an authored sentence, not e.toString()',
          );
          expect(section['error_code'], 'preferences-export-failed');
          expect(
            json.encode(section),
            isNot(contains(_LeakySettingsExportRepository.foreignUid)),
            reason:
                'the section itself ships to the data subject — another '
                "person's uid must not survive even one level down",
          );
        },
      );
    });

    group('BUT-865: partial-recovery contract (page #1 success + page #2 '
        'transient throw)', () {
      test('partial rows from page #1 are discarded when page #2 throws — '
          'try/catch wraps the whole pagination loop', () async {
        final partialService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
          householdRepository: _emptyFamilyHouseholdRepo(),
          complianceExportManager: ComplianceExportManager(
            functions: _SuccessThenTransientFirebaseFunctions(),
            dataExportRepository: FirebaseDataExportRepository(
              firestore: fakeFirestore,
              authRepository: mockAuthRepository,
            ),
          ),
          dataExportRepository: FirebaseDataExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          ),
        );

        final jsonString = await partialService.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        // Section carries the transient envelope only — accumulated page-1
        // rows are NOT preserved. The `try` block in
        // compliance_export_manager.dart:92-178 wraps the entire pagination
        // loop, so any throw inside it discards `auditLogs` and returns the
        // bare {error, error_code, note} envelope.
        expect(
          data['audit_logs']['error_code'],
          'unavailable',
          reason: 'Section reports the transient backend code.',
        );
        expect(
          data['audit_logs'].containsKey('audit_logs'),
          isFalse,
          reason:
              'Current contract: partial rows from page #1 are '
              'discarded on mid-loop throw. If this fails because partial '
              'recovery has been implemented, update the assertion to '
              'verify the new shape (rows preserved + partial:true flag).',
        );

        // Top-level warnings still surface the section error so consumers
        // see the partial-bundle signal without scanning every section.
        final warnings = data['export_metadata']['warnings'] as List<dynamic>?;
        expect(warnings, isNotNull);
        // Scoped to audit_logs — same reason as the BUT-864 test above: this
        // fixture wires only the compliance manager, so the sections that fall
        // through to an uninitialised ServiceLocator now warn too (BUT-1721).
        final auditEntries = warnings!
            .cast<Map<String, dynamic>>()
            .where((w) => w['section'] == 'audit_logs')
            .toList();
        expect(auditEntries, hasLength(1));
        expect(auditEntries.single['error_code'], 'unavailable');
      });
    });

    group('FirebaseDataExportRepository — direct queries (BUT-748)', () {
      test(
        'exportIncomingBlocks queries canonical `blockedId` field',
        () async {
          // BUT-748: prior code queried `blockedUserId`, returning zero rows
          // because FirebaseBlockRepository writes `blockedId`. This test
          // would have failed under the old field name.
          final repo = FirebaseDataExportRepository(
            firestore: fakeFirestore,
            authRepository: mockAuthRepository,
          );

          await fakeFirestore.collection('blocks').doc('in1').set({
            'blockerId': 'other-user',
            'blockedId': testUserId,
          });
          await fakeFirestore.collection('blocks').doc('in2').set({
            'blockerId': 'another-user',
            'blockedId': testUserId,
          });
          // Outgoing — must NOT appear in incoming results.
          await fakeFirestore.collection('blocks').doc('out1').set({
            'blockerId': testUserId,
            'blockedId': 'someone-else',
          });

          final incoming = await repo.exportIncomingBlocks(testUserId);

          expect(
            incoming,
            hasLength(2),
            reason: 'incoming blocks where blockedId == userId',
          );
        },
      );
    });
  });
}

/// Records `logPermissionCheck` calls instead of writing them. See the
/// BUT-1773 group for why the fake collection cannot be asserted against.
class _SpyAuditRepository extends FirebaseAuditRepository {
  _SpyAuditRepository(super.firestore);

  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<void> logPermissionCheck({
    required String userId,
    required String operation,
    required String resourceType,
    String? resourceId,
    required bool granted,
    Map<String, dynamic>? metadata,
  }) async {
    calls.add(<String, dynamic>{
      'userId': userId,
      'operation': operation,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'granted': granted,
      'metadata': metadata,
    });
  }
}
