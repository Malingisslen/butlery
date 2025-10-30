/// Comprehensive unit tests for FirebaseConsentRepository (GDPR-critical)
///
/// Tests consent management functionality required for GDPR Article 7 compliance.
/// Validates secure storage, retrieval, and permission validation with audit logging.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseConsentRepository - GDPR Compliance', () {
    late FirebaseConsentRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'test-user-123'); // Match test user ID

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseConsentRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('getUserConsent - Read Operations', () {
      test('should retrieve user consent successfully', () async {
        // Arrange
        const userId = 'test-user-123';
        final consent = _createConsent(userId);
        await _seedConsent(fakeFirestore, userId, consent);

        // Act
        final result = await repository.getUserConsent(userId);

        // Assert
        expect(result, isNotNull);
        expect(result!.userId, equals(userId));
        expect(result.consentVersion, equals('1.0'));
        expect(result.purposes.essentialServices, isTrue);
        expect(result.purposes.dataProcessing, isTrue);
      });

      test('should return null when no consent exists', () async {
        // Arrange
        const userId = 'test-user-123';
        // No consent seeded

        // Act
        final result = await repository.getUserConsent(userId);

        // Assert
        expect(result, isNull);
      });

      test('should reject reading another user\'s consent', () async {
        // Arrange
        const otherUserId = 'other-user-456';
        mockAuthRepo.setAuthState(
          user: mockUser,
          userId: 'test-user-123',
          isAuthenticated: true,
        );

        // Act & Assert
        expect(
          () => repository.getUserConsent(otherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject when user is not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act & Assert
        expect(
          () => repository.getUserConsent('any-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('saveConsent - Write Operations', () {
      test('should save user consent successfully', () async {
        // Arrange
        const userId = 'test-user-123';
        final consent = _createConsent(userId);

        // Act
        final result = await repository.saveConsent(userId, consent);

        // Assert
        expect(result, isTrue);

        // Verify data was written
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('consent')
            .doc('current')
            .get();

        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['consentVersion'], equals('1.0'));
        expect(data['deviceInfo'], equals('test-device'));
      });

      test('should update existing consent', () async {
        // Arrange
        const userId = 'test-user-123';
        final initialConsent = _createConsent(userId);
        await _seedConsent(fakeFirestore, userId, initialConsent);

        final updatedConsent = initialConsent.copyWith(
          consentVersion: '2.0',
          updatedAt: DateTime.now(),
          purposes: const ConsentPurposes(
            essentialServices: true,
            dataProcessing: true,
            analytics: true, // Now enabled
          ),
        );

        // Act
        final result = await repository.saveConsent(userId, updatedConsent);

        // Assert
        expect(result, isTrue);

        // Verify updated data
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('consent')
            .doc('current')
            .get();

        final data = doc.data()!;
        expect(data['consentVersion'], equals('2.0'));
        expect(data['purposes']['analytics'], isTrue);
      });

      test('should reject saving consent for another user', () async {
        // Arrange
        const otherUserId = 'other-user-456';
        mockAuthRepo.setAuthState(
          user: mockUser,
          userId: 'test-user-123',
          isAuthenticated: true,
        );

        final consent = _createConsent(otherUserId);

        // Act & Assert
        expect(
          () => repository.saveConsent(otherUserId, consent),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject when consent userId mismatch', () async {
        // Arrange
        const userId = 'test-user-123';
        final consent = _createConsent('different-user');

        // Act
        final result = await repository.saveConsent(userId, consent);

        // Assert
        expect(result, isFalse); // Returns false for userId mismatch
      });

      test('should reject when user is not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);
        final consent = _createConsent('any-user');

        // Act & Assert
        expect(
          () => repository.saveConsent('any-user', consent),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('deleteConsent - Delete Operations (GDPR Article 17)', () {
      test('should delete user consent successfully', () async {
        // Arrange
        const userId = 'test-user-123';
        final consent = _createConsent(userId);
        await _seedConsent(fakeFirestore, userId, consent);

        // Verify consent exists before deletion
        var doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('consent')
            .doc('current')
            .get();
        expect(doc.exists, isTrue);

        // Act
        final result = await repository.deleteConsent(userId);

        // Assert
        expect(result, isTrue);

        // Verify consent was deleted
        doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('consent')
            .doc('current')
            .get();
        expect(doc.exists, isFalse);
      });

      test('should handle deleting non-existent consent', () async {
        // Arrange
        const userId = 'test-user-123';
        // No consent seeded

        // Act
        final result = await repository.deleteConsent(userId);

        // Assert
        expect(result, isTrue); // Should succeed even if nothing to delete
      });

      test('should reject deleting another user\'s consent', () async {
        // Arrange
        const otherUserId = 'other-user-456';
        mockAuthRepo.setAuthState(
          user: mockUser,
          userId: 'test-user-123',
          isAuthenticated: true,
        );

        // Act & Assert
        expect(
          () => repository.deleteConsent(otherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject when user is not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act & Assert
        expect(
          () => repository.deleteConsent('any-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('getConsentHistory - Audit Trail', () {
      test('should retrieve consent history successfully', () async {
        // Arrange
        const userId = 'test-user-123';
        final now = DateTime.now();

        // Seed multiple consent versions
        await _seedConsentHistory(fakeFirestore, userId, [
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 30))),
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 20)), consentVersion: '1.1'),
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 10)), consentVersion: '2.0'),
        ]);

        // Act
        final history = await repository.getConsentHistory(userId);

        // Assert
        expect(history.length, equals(3));
        expect(history[0].userId, equals(userId));
        // Should be ordered by most recent first
      });

      test('should return empty list when no history exists', () async {
        // Arrange
        const userId = 'test-user-123';

        // Act
        final history = await repository.getConsentHistory(userId);

        // Assert
        expect(history, isEmpty);
      });

      test('should respect limit parameter', () async {
        // Arrange
        const userId = 'test-user-123';
        final now = DateTime.now();

        // Seed multiple consent versions
        await _seedConsentHistory(fakeFirestore, userId, [
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 5))),
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 4))),
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 3))),
          _createConsent(userId, grantedAt: now.subtract(const Duration(days: 2))),
        ]);

        // Act
        final history = await repository.getConsentHistory(userId, limit: 2);

        // Assert
        expect(history.length, equals(2)); // Should only get 2 most recent
      });

      test('should reject reading another user\'s history', () async {
        // Arrange
        const otherUserId = 'other-user-456';
        mockAuthRepo.setAuthState(
          user: mockUser,
          userId: 'test-user-123',
          isAuthenticated: true,
        );

        // Act & Assert
        expect(
          () => repository.getConsentHistory(otherUserId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject when user is not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        // Act & Assert
        expect(
          () => repository.getConsentHistory('any-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('GDPR Compliance Verification', () {
      test('should support GDPR Article 7 - Explicit Consent', () async {
        // Arrange - User granting consent
        const userId = 'test-user-123';
        final consent = UserConsent(
          userId: userId,
          purposes: const ConsentPurposes(
            essentialServices: true,
            dataProcessing: true,
            analytics: true, // Explicitly granted
            marketing: false, // Explicitly denied
          ),
          grantedAt: DateTime.now(),
          consentVersion: '1.0',
          deviceInfo: 'iOS',
          ipAddress: '192.168.1.1', // Tracking for audit
        );

        // Act - Save explicit consent
        final result = await repository.saveConsent(userId, consent);

        // Assert - Consent is recorded with all details
        expect(result, isTrue);

        final saved = await repository.getUserConsent(userId);
        expect(saved!.purposes.analytics, isTrue);
        expect(saved.purposes.marketing, isFalse);
        expect(saved.ipAddress, equals('192.168.1.1'));
      });

      test('should support GDPR Article 17 - Right to Erasure', () async {
        // Arrange - User wants to withdraw consent
        const userId = 'test-user-123';
        final consent = _createConsent(userId);
        await _seedConsent(fakeFirestore, userId, consent);

        // Act - User exercises right to erasure
        final result = await repository.deleteConsent(userId);

        // Assert - Consent is completely removed
        expect(result, isTrue);

        final deleted = await repository.getUserConsent(userId);
        expect(deleted, isNull);
      });

      test('should track consent version changes', () async {
        // Arrange - Initial consent
        const userId = 'test-user-123';
        final initialConsent = _createConsent(userId, consentVersion: '1.0');
        await repository.saveConsent(userId, initialConsent);

        // Act - Policy updated, user consents to new version
        final updatedConsent = initialConsent.copyWith(
          consentVersion: '2.0',
          updatedAt: DateTime.now(),
        );
        await repository.saveConsent(userId, updatedConsent);

        // Assert - Version tracking is maintained
        final current = await repository.getUserConsent(userId);
        expect(current!.consentVersion, equals('2.0'));
        expect(current.updatedAt, isNotNull);
        expect(current.needsRenewal('2.0'), isFalse);
        expect(current.needsRenewal('3.0'), isTrue);
      });

      test('should validate required consents', () async {
        // Arrange
        const userId = 'test-user-123';

        // Test with required consents
        final validConsent = UserConsent(
          userId: userId,
          purposes: const ConsentPurposes(
            essentialServices: true,
            dataProcessing: true,
          ),
          grantedAt: DateTime.now(),
          consentVersion: '1.0',
          deviceInfo: 'test',
        );
        expect(validConsent.hasRequiredConsents, isTrue);

        // Test without required consents
        final invalidConsent = UserConsent(
          userId: userId,
          purposes: const ConsentPurposes(
            essentialServices: false,
            dataProcessing: true,
          ),
          grantedAt: DateTime.now(),
          consentVersion: '1.0',
          deviceInfo: 'test',
        );
        expect(invalidConsent.hasRequiredConsents, isFalse);
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test consent
UserConsent _createConsent(
  String userId, {
  DateTime? grantedAt,
  String consentVersion = '1.0',
}) {
  return UserConsent(
    userId: userId,
    purposes: const ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: false,
      marketing: false,
    ),
    grantedAt: grantedAt ?? DateTime.now(),
    consentVersion: consentVersion,
    deviceInfo: 'test-device',
  );
}

/// Seed consent into fake Firestore
Future<void> _seedConsent(
  FakeFirebaseFirestore firestore,
  String userId,
  UserConsent consent,
) async {
  final data = {
    'userId': userId, // Include userId for data integrity
    'purposes': consent.purposes.toMap(),
    'grantedAt': Timestamp.fromDate(consent.grantedAt),
    'updatedAt': consent.updatedAt != null
        ? Timestamp.fromDate(consent.updatedAt!)
        : null,
    'consentVersion': consent.consentVersion,
    'ipAddress': consent.ipAddress,
    'deviceInfo': consent.deviceInfo,
  };

  await firestore
      .collection('users')
      .doc(userId)
      .collection('consent')
      .doc('current')
      .set(data);
}

/// Seed consent history into fake Firestore
Future<void> _seedConsentHistory(
  FakeFirebaseFirestore firestore,
  String userId,
  List<UserConsent> consents,
) async {
  for (var i = 0; i < consents.length; i++) {
    final consent = consents[i];
    final data = {
      'userId': userId, // Include userId for data integrity
      'purposes': consent.purposes.toMap(),
      'grantedAt': Timestamp.fromDate(consent.grantedAt),
      'updatedAt': Timestamp.fromDate(consent.updatedAt ?? consent.grantedAt),
      'consentVersion': consent.consentVersion,
      'ipAddress': consent.ipAddress,
      'deviceInfo': consent.deviceInfo,
    };

    await firestore
        .collection('users')
        .doc(userId)
        .collection('consent')
        .doc('version_$i')
        .set(data);
  }
}
