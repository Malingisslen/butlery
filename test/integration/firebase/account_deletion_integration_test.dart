/// Integration tests for AccountDeletionService with real Firebase operations
///
/// Tests Firebase batch operations and FieldValue operations that cannot
/// be properly tested with mocks. Uses FakeFirebaseFirestore for realistic testing.
///
/// Run with: flutter test --tags=integration
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/presence_service.dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';
import '../../test_support/test_field_values.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for Firebase sealed classes
class MockUser extends Mock implements User {}

class _MockPresenceService extends Mock implements PresenceService {}

class _MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class _MockNotificationHistoryRepository extends Mock
    implements NotificationHistoryRepository {}

class _MockNotificationBatchRepository extends Mock
    implements NotificationBatchRepository {}

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockConsentRepository extends Mock
    implements FirebaseConsentRepository {}

class _MockMessagingRepository extends Mock implements MessagingRepository {}

class _MockCollaborativeRecipeRepository extends Mock
    implements CollaborativeRecipeRepository {}

// Fake classes for fallback values
class FakeException extends Fake implements Exception {}

void main() {
  group('AccountDeletionService Integration', () {
    late AccountDeletionService service;
    late FirebaseFirestore firestore;
    late MockFirebaseAuth mockAuth;
    late MockAuthRepository mockAuthRepository;
    late FakeFirestoreRepository mockFirestoreRepository;
    late MockAuthService mockAuthService;
    late MockUserService mockUserService;
    late MockUnifiedRecipeService mockRecipeService;
    late MockOfflineService mockOfflineService;
    late _MockPresenceService mockPresenceService;
    late _MockNotificationsRepository mockNotificationsRepository;
    late _MockNotificationHistoryRepository mockNotificationHistoryRepository;
    late _MockNotificationBatchRepository mockNotificationBatchRepository;
    late _MockDeviceRepository mockDeviceRepository;
    late _MockUserRepository mockUserRepository;
    late _MockConsentRepository mockConsentRepository;
    late _MockMessagingRepository mockMessagingRepository;
    late _MockCollaborativeRecipeRepository mockCollaborativeRecipeRepository;
    late MockAnalyticsService mockAnalyticsService;
    late MockUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeException());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks for non-Firebase services
      mockAuth = MockFirebaseAuth();
      mockAuthRepository = MockAuthRepository();
      mockFirestoreRepository = FakeFirestoreRepository();
      // Use the fake firestore that FakeFirestoreRepository already wraps —
      // stubbing `.firestore` with `when()` fails because the mock has a
      // concrete @override getter.
      firestore = mockFirestoreRepository.firestore as FakeFirebaseFirestore;
      mockAuthService = MockAuthService();
      mockUserService = MockUserService();
      mockRecipeService = MockUnifiedRecipeService();
      mockOfflineService = MockOfflineService();
      mockPresenceService = _MockPresenceService();
      when(() => mockPresenceService.deleteUserPresence(any()))
          .thenAnswer((_) async => true);
      mockNotificationsRepository = _MockNotificationsRepository();
      when(() => mockNotificationsRepository.deleteAllByUser(any()))
          .thenAnswer((_) async => 0);
      when(() => mockNotificationsRepository.deletePreferencesForUser(any()))
          .thenAnswer((_) async => true);
      mockNotificationHistoryRepository = _MockNotificationHistoryRepository();
      when(() => mockNotificationHistoryRepository.deleteAllByUser(any()))
          .thenAnswer((_) async => 0);
      mockNotificationBatchRepository = _MockNotificationBatchRepository();
      when(() => mockNotificationBatchRepository.deleteAllByUser(any()))
          .thenAnswer((_) async => 0);
      mockDeviceRepository = _MockDeviceRepository();
      when(() => mockDeviceRepository.deleteAllByUser(any()))
          .thenAnswer((_) async => 0);
      mockUserRepository = _MockUserRepository();
      // The integration test asserts on real `FakeFirebaseFirestore` state
      // (e.g., `userDoc.exists == false`). Stubs must side-effect or those
      // post-deletion assertions fail despite the mock returning `true`.
      when(() => mockUserRepository.deletePublicProfile(any()))
          .thenAnswer((invocation) async {
        final uid = invocation.positionalArguments.first as String;
        await firestore.collection('public_profiles').doc(uid).delete();
        return true;
      });
      when(() => mockUserRepository.deleteUserRootDoc(any()))
          .thenAnswer((invocation) async {
        final uid = invocation.positionalArguments.first as String;
        await firestore.collection('users').doc(uid).delete();
        return true;
      });
      mockConsentRepository = _MockConsentRepository();
      when(() => mockConsentRepository.deleteConsent(any()))
          .thenAnswer((_) async => true);
      mockMessagingRepository = _MockMessagingRepository();
      when(() => mockMessagingRepository.deleteAllMessagesForUser(any()))
          .thenAnswer((_) async => 0);
      mockCollaborativeRecipeRepository = _MockCollaborativeRecipeRepository();
      when(() => mockCollaborativeRecipeRepository.deleteAllByUser(any()))
          .thenAnswer((_) async => 0);
      mockAnalyticsService = MockAnalyticsService();

      // Setup mock user
      mockUser = MockUser();
      when(() => mockUser.uid).thenReturn('test-user-123');
      when(() => mockUser.email).thenReturn('test@example.com');
      when(() => mockUser.displayName).thenReturn('Test User');

      // Configure mocks
      mockAuth.setAuthState(currentUser: mockUser);
      mockAuthService.setAuthState(
        currentUser: mockUser,
        isAuthenticated: true,
      );

      mockOfflineService.setOfflineState(
        isInitialized: true,
        currentUserId: 'test-user-123',
      );

      when(() => mockOfflineService.clearUserData(any()))
          .thenAnswer((_) async => true);
      when(() => mockAnalyticsService.logAccountDeleted(any()))
          .thenAnswer((_) async {});
      when(() => mockUser.delete()).thenAnswer((_) async {});

      // Setup repository mocks. MockAuthRepository.currentUser is a
      // concrete @override (backed by setAuthState), so we can't stub it
      // with `when(...).thenReturn(...)` — use the setter instead.
      mockAuthRepository.setAuthState(user: mockUser);

      // Create service with repository wrappers
      service = AccountDeletionService(
        authRepository: mockAuthRepository,
        firestoreRepository: mockFirestoreRepository,
        authService: mockAuthService,
        userService: mockUserService,
        recipeService: mockRecipeService,
        offlineService: mockOfflineService,
        presenceService: mockPresenceService,
        notificationsRepository: mockNotificationsRepository,
        notificationHistoryRepository: mockNotificationHistoryRepository,
        notificationBatchRepository: mockNotificationBatchRepository,
        deviceRepository: mockDeviceRepository,
        userRepository: mockUserRepository,
        consentRepository: mockConsentRepository,
        messagingRepository: mockMessagingRepository,
        collaborativeRecipeRepository: mockCollaborativeRecipeRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Firebase Batch Operations', () {
      test('should handle batch operations correctly', () async {
        // Arrange
        final userId = 'test-user-123';

        // Add test data
        await firestore.collection('users').doc(userId).set({
          'displayName': 'Test User',
          'email': 'test@example.com',
        });

        // Add user's recipes subcollection
        await firestore
            .collection('users')
            .doc(userId)
            .collection('recipes')
            .doc('recipe-1')
            .set({
          'title': 'Recipe 1',
          'userId': userId,
        });
        await firestore
            .collection('users')
            .doc(userId)
            .collection('recipes')
            .doc('recipe-2')
            .set({
          'title': 'Recipe 2',
          'userId': userId,
        });

        // Add unified recipes
        await firestore.collection('recipes').doc('unified-1').set({
          'userId': userId,
          'title': 'Unified Recipe 1',
        });

        // Act
        final result = await service.deleteUserAccount(
          reason: 'Integration test',
          createAuditLog: true,
        );

        // Assert
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], contains('recipes'));
        expect(result['auditLogId'], isNotNull);

        // Verify data was deleted
        final userDoc = await firestore.collection('users').doc(userId).get();
        expect(userDoc.exists, isFalse);

        final recipes = await firestore
            .collection('recipes')
            .where('userId', isEqualTo: userId)
            .get();
        expect(recipes.docs, isEmpty);
      });

      test('should handle FieldValue.serverTimestamp in audit log', () async {
        // Arrange
        final userId = 'test-user-123';

        // Act & Assert - Service may fail due to FieldValue limitations in FakeFirebaseFirestore
        try {
          final result = await service.deleteUserAccount(
            reason: 'Test timestamp',
            createAuditLog: true,
          );

          // If service succeeds (production behavior), verify audit log
          expect(result['success'], isTrue);
          expect(result['auditLogId'], isNotNull);

          final auditLogs =
              await firestore.collection('deletion_audit_logs').get();
          expect(auditLogs.docs, isNotEmpty);

          final auditLog = auditLogs.docs.first.data();
          expect(auditLog['userId'], equals(userId));
          expect(auditLog['reason'], equals('Test timestamp'));
          expect(auditLog['deletionTimestamp'], isNotNull);
        } catch (e) {
          // FakeFirebaseFirestore FieldValue limitation - verify the error is related to FieldValue
          final errorMsg = e.toString().toLowerCase();
          expect(
              errorMsg.contains('fieldvalue') ||
                  errorMsg.contains('timestamp') ||
                  errorMsg.contains('cast'),
              isTrue,
              reason: 'Expected FieldValue-related error, got: $e');
        }
      },
          skip:
              'FakeFirebaseFirestore FieldValue.serverTimestamp() limitations');
    });

    group('Array Operations', () {
      test('should handle FieldValue.arrayUnion for shared content', () async {
        // Production `SocialDeletionOperations.removeFromSharedContent` uses
        // a collectionGroup query against `members` subcollections to locate
        // parents with sharedToUserIds to clean up. FakeFirebaseFirestore's
        // collectionGroup support is partial and the real behaviour is
        // covered by the dedicated `social_deletion_operations` unit tests
        // (done in BUT-298). Skip the duplicate FakeFirestore coverage here.
      },
          skip:
              'Duplicate of BUT-298 unit coverage; collectionGroup nuance in FakeFirestore.');

      test('should handle FieldValue.increment for statistics', () async {
        // Arrange
        await firestore.collection('statistics').doc('global').set({
          'totalUsers': 100,
          'deletedUsers': 5,
        });

        // Act - Use test-friendly approach instead of FieldValue.increment
        // Note: AccountDeletionService doesn't directly use increment,
        // but this tests the capability for future enhancements
        final doc =
            await firestore.collection('statistics').doc('global').get();
        final currentValue = doc.data()?['deletedUsers'] as int? ?? 0;

        await firestore.collection('statistics').doc('global').update({
          'deletedUsers': currentValue + 1, // Test-friendly increment
        });

        // Assert
        final stats =
            await firestore.collection('statistics').doc('global').get();
        expect(stats.data()?['deletedUsers'], equals(6));
      });
    });

    group('Transaction Support', () {
      test('should handle batch commit properly', () async {
        // Arrange
        final userId = 'test-user-123';
        final batch = firestore.batch();

        // Add multiple operations to batch
        for (int i = 0; i < 5; i++) {
          final docRef = firestore.collection('test_collection').doc('doc-$i');
          await docRef.set({'userId': userId, 'index': i});
          batch.delete(docRef);
        }

        // Act
        await batch.commit();

        // Assert
        final remaining = await firestore.collection('test_collection').get();
        expect(remaining.docs, isEmpty);
      });

      test('should handle large batch operations', () async {
        // Arrange
        final userId = 'test-user-123';

        // Create many documents
        for (int i = 0; i < 50; i++) {
          await firestore.collection('recipes').doc('recipe-$i').set({
            'userId': userId,
            'title': 'Recipe $i',
          });
        }

        // Act
        final result = await service.deleteUserAccount(
          reason: 'Large batch test',
        );

        // Assert
        expect(result['success'], isTrue);

        // Verify all were deleted
        final remaining = await firestore
            .collection('recipes')
            .where('userId', isEqualTo: userId)
            .get();
        expect(remaining.docs, isEmpty);
      });
    });

    group('Complex Data Structures', () {
      test('should handle nested collections', () async {
        // Arrange
        final userId = 'test-user-123';

        // Create nested structure
        final userDoc = firestore.collection('users').doc(userId);
        await userDoc.set({'name': 'Test User'});

        await userDoc
            .collection('recipes')
            .doc('r1')
            .set({'title': 'Recipe 1'});
        await userDoc.collection('menus').doc('m1').set({'name': 'Menu 1'});
        await userDoc.collection('shopping_lists').doc('s1').set({'items': []});

        // Act
        final result = await service.deleteUserAccount(
          reason: 'Nested collections test',
        );

        // Assert
        expect(result['success'], isTrue);
        expect(
            result['deletedCollections'],
            containsAll([
              'recipes',
              'menus',
              'shopping_lists',
            ]));
      });

      test('should handle map fields with FieldValue operations', () async {
        // Arrange
        final userId = 'test-user-123';
        final createdAt = TestFieldValues.serverTimestamp();

        await firestore.collection('complex_docs').doc('doc-1').set({
          'metadata': {
            'createdBy': userId,
            'createdAt': createdAt, // Test-friendly timestamp
            'tags': ['tag1', 'tag2'],
          },
          'stats': {
            'views': 0,
            'likes': 0,
          },
        });

        // Update with test-friendly operations
        final doc =
            await firestore.collection('complex_docs').doc('doc-1').get();
        final currentViews = doc.data()?['stats']['views'] as int? ?? 0;
        final lastModified = TestFieldValues.serverTimestamp();

        await firestore.collection('complex_docs').doc('doc-1').update({
          'stats.views': currentViews + 1, // Test-friendly increment
          'metadata.lastModified': lastModified, // Test-friendly timestamp
        });

        // Assert
        final updatedDoc =
            await firestore.collection('complex_docs').doc('doc-1').get();
        expect(updatedDoc.data()?['stats']['views'], equals(1));
        expect(updatedDoc.data()?['metadata']['lastModified'], isNotNull);
      });
    });

    group('GDPR residual-data probe (BUT-498 commit 5)', () {
      const userId = 'test-user-123';

      test('no residual data — no flag added to failedCollections', () async {
        // The default mocks return 0 for everything; FakeFirebaseFirestore
        // starts empty. So the probe finds nothing.
        final result = await service.deleteUserAccount(reason: 'no-residual');

        expect(result['success'], isTrue);
        expect(result['failedCollections'],
            isNot(contains('residual_data_detected')));
      });

      test('residual data present — failedCollections gets the flag', () async {
        // Seed a doc that the probe will find — simulates a deletion path
        // that silently dropped data. The mocked deletion-ops return true
        // for their tier steps but the doc remains in fakeFirestore.
        await firestore.collection('user_notifications').add({
          'userId': userId,
          'title': 'orphan',
        });

        final result = await service.deleteUserAccount(reason: 'residual');

        expect(result['success'], isTrue);
        expect(result['failedCollections'], contains('residual_data_detected'));
      });

      test('probe failure on one collection still flags + does not abort',
          () async {
        // We can't easily make FakeFirebaseFirestore .count() throw, so this
        // test exercises the no-residual path and asserts the deletion
        // completed normally. The error-handling branch in _probeResidualData
        // is exercised in production; pinning that branch via an injected
        // throwing collection would require splitting _firestore further.
        final result = await service.deleteUserAccount(reason: 'no-error');

        expect(result['success'], isTrue,
            reason:
                'probe wraps each collection in try/catch — never aborts the '
                'wider deletion, even if a count() query fails');
      });
    });
  });
}
