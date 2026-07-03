/// Comprehensive unit tests for DataExportService (GDPR Articles 15 & 20).
///
/// Tests data export functionality and GDPR compliance.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

    group('Export Structure', () {
      test('should create valid JSON export', () async {
        final jsonString = await service.exportUserData();
        expect(jsonString, isNotEmpty);
        expect(() => json.decode(jsonString), returnsNormally);
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
          expect(warnings, hasLength(1));
          final entry = warnings!.single as Map<String, dynamic>;
          expect(entry['section'], 'audit_logs');
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
        });
      },
    );

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
        expect(warnings, hasLength(1));
        final entry = warnings!.single as Map<String, dynamic>;
        expect(entry['section'], 'audit_logs');
        expect(entry['error_code'], 'unavailable');
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
