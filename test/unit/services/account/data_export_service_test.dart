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
import 'dart:convert';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Mocks
class MockFirestoreRepository extends Mock implements FirestoreRepository {}

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
    // ComplianceExportManager casts to Map<dynamic, dynamic>; widen to T.
    return _EmptyHttpsCallableResult<T>(
        <String, dynamic>{'rows': const [], 'nextCursor': null} as T);
  }
}

class _FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) =>
      _EmptyHttpsCallable();
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
  }) =>
      _TransientHttpsCallable();
}

void main() {
  group('DataExportService - GDPR Data Export', () {
    late DataExportService service;
    late MockAuthRepository mockAuthRepository;
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
      mockAuthRepository = MockAuthRepository();
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
            user: null, userId: null, isAuthenticated: false);
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

      test(
          'BUT-501: export-via-repo paths return real data (not error '
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
        await fakeFirestore
            .collection('activity_events')
            .doc('evt-1')
            .set({'actorId': testUserId, 'kind': 'cook'});
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

    group('BUT-864: transient per-section errors surface as top-level warnings',
        () {
      test(
          'audit-log unavailable produces export_metadata.warnings entry with '
          'error_code', () async {
        // Replace the default service with one whose audit-log call throws a
        // transient FirebaseFunctionsException. ComplianceExportManager will
        // catch + return the BUT-842 envelope; DataExportService should then
        // aggregate it into a top-level `warnings` array on export_metadata.
        final transientService = DataExportService(
          authRepository: mockAuthRepository,
          firestoreRepository: mockFirestoreRepository,
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
        final warnings = data['export_metadata']['warnings'] as List<dynamic>?;
        expect(warnings, isNotNull,
            reason: 'A transient section error must surface as a top-level '
                'warning entry so the consuming UI can flag the partial '
                'bundle without scanning every section.');
        expect(warnings, hasLength(1));
        final entry = warnings!.single as Map<String, dynamic>;
        expect(entry['section'], 'audit_logs');
        expect(entry['error_code'], 'unavailable');
        expect(entry['message'], isNotEmpty);
      });

      test(
          'no transient errors → no warnings array (avoids polluting '
          'happy-path bundles)', () async {
        // The default `service` (built in setUp) uses _FakeFirebaseFunctions
        // which returns empty audit-log pages — no error_code anywhere.
        final jsonString = await service.exportUserData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        expect(data['export_metadata'].containsKey('warnings'), isFalse,
            reason: 'warnings key is only set when at least one section '
                'reports an error_code; happy-path bundles must not carry '
                'an empty array.');
      });
    });

    group('FirebaseDataExportRepository — direct queries (BUT-748)', () {
      test('exportIncomingBlocks queries canonical `blockedId` field',
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

        expect(incoming, hasLength(2),
            reason: 'incoming blocks where blockedId == userId');
      });
    });
  });
}
