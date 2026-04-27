/// Comprehensive unit tests for DataExportService (GDPR Articles 15 & 20).
///
/// Tests data export functionality and GDPR compliance.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/firebase/firebase_activity_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/firebase_feedback_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';
import 'dart:convert';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Mocks
class MockFirestoreRepository extends Mock implements FirestoreRepository {}

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
  });
}
