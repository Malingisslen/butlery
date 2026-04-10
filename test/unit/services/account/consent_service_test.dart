/// Comprehensive unit tests for ConsentService (GDPR Article 7).
///
/// Tests consent management, consent validation, renewal checking, and audit trail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/firebase/firebase_consent_repository.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Mocks
class MockFirebaseConsentRepository extends Mock
    implements FirebaseConsentRepository {}

void main() {
  group('ConsentService - GDPR Consent Management', () {
    late ConsentService service;
    late MockAuthRepository mockAuthRepository;
    late MockFirebaseConsentRepository mockConsentRepository;

    // Test data
    const testUserId = 'user-123';
    const currentVersion = '1.1.0';

    final testConsentPurposes = ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: true,
      marketing: false,
      socialFeatures: true,
      pushNotifications: false,
    );

    final testUserConsent = UserConsent(
      userId: testUserId,
      purposes: testConsentPurposes,
      grantedAt: DateTime(2025, 1, 1),
      updatedAt: null,
      consentVersion: currentVersion,
      deviceInfo: 'Test Device',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Register fallback values for mocktail
      registerFallbackValue(UserConsent(
        userId: 'fallback',
        purposes: ConsentPurposes.defaults(),
        grantedAt: DateTime.now(),
        consentVersion: '1.0.0',
        deviceInfo: 'Test Device',
      ));
    });

    setUp(() {
      // Create mocks
      mockAuthRepository = MockAuthRepository();
      mockConsentRepository = MockFirebaseConsentRepository();

      // Configure mock auth
      mockAuthRepository.setAuthState(userId: testUserId);

      // Create service
      service = ConsentService(
        authRepository: mockAuthRepository,
        consentRepository: mockConsentRepository,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ===== CONSENT RETRIEVAL =====

    group('Consent Retrieval', () {
      test('should get user consent successfully', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.getUserConsent();

        // Assert
        expect(result, isNotNull);
        expect(result!.userId, testUserId);
        expect(result.purposes.analytics, isTrue);
        expect(result.consentVersion, currentVersion);
        verify(() => mockConsentRepository.getUserConsent(testUserId))
            .called(1);
      });

      test('should return null when no consent exists', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);

        // Act
        final result = await service.getUserConsent();

        // Assert
        expect(result, isNull);
      });

      test('should return null when user not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);

        // Act
        final result = await service.getUserConsent();

        // Assert
        expect(result, isNull);
        verifyNever(() => mockConsentRepository.getUserConsent(any()));
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenThrow(Exception('Firestore error'));

        // Act
        final result = await service.getUserConsent();

        // Assert
        expect(result, isNull); // BaseService error handling returns default
      });
    });

    // ===== CONSENT SAVING =====

    group('Consent Saving', () {
      test('should save new consent successfully', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null); // No existing consent
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.saveConsent(testConsentPurposes);

        // Assert
        expect(result, isTrue);
        verify(() => mockConsentRepository.saveConsent(testUserId, any()))
            .called(1);
      });

      test('should update existing consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        final updatedPurposes = testConsentPurposes.copyWith(
          marketing: true,
          pushNotifications: true,
        );

        // Act
        final result = await service.saveConsent(updatedPurposes);

        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockConsentRepository.saveConsent(
              testUserId,
              captureAny(),
            )).captured;
        final savedConsent = captured.first as UserConsent;
        expect(savedConsent.purposes.marketing, isTrue);
        expect(savedConsent.purposes.pushNotifications, isTrue);
        expect(savedConsent.updatedAt, isNotNull);
      });

      test('should set correct device info', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.saveConsent(testConsentPurposes);

        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockConsentRepository.saveConsent(
              testUserId,
              captureAny(),
            )).captured;
        final savedConsent = captured.first as UserConsent;
        expect(savedConsent.deviceInfo, isNotEmpty);
      });

      test('should return false when user not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);

        // Act
        final result = await service.saveConsent(testConsentPurposes);

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockConsentRepository.saveConsent(any(), any()));
      });

      test('should handle save failure', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await service.saveConsent(testConsentPurposes);

        // Assert
        expect(result, isFalse);
      });

      test('should handle repository errors during save', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.saveConsent(testConsentPurposes);

        // Assert
        expect(result, isFalse);
      });
    });

    // ===== CONSENT CHECKING =====

    group('Consent Checking', () {
      test('should check analytics consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.hasConsent(ConsentPurpose.analytics);

        // Assert
        expect(result, isTrue);
      });

      test('should check marketing consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.hasConsent(ConsentPurpose.marketing);

        // Assert
        expect(result, isFalse);
      });

      test('should check social features consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.hasConsent(ConsentPurpose.socialFeatures);

        // Assert
        expect(result, isTrue);
      });

      test('should check push notifications consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result =
            await service.hasConsent(ConsentPurpose.pushNotifications);

        // Assert
        expect(result, isFalse);
      });

      test('should check essential services consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result =
            await service.hasConsent(ConsentPurpose.essentialServices);

        // Assert
        expect(result, isTrue);
      });

      test('should check data processing consent', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.hasConsent(ConsentPurpose.dataProcessing);

        // Assert
        expect(result, isTrue);
      });

      test('should return false when no consent exists', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);

        // Act
        final result = await service.hasConsent(ConsentPurpose.analytics);

        // Assert
        expect(result, isFalse);
      });
    });

    // ===== CONSENT RENEWAL =====

    group('Consent Renewal', () {
      test('should detect when consent needs renewal', () async {
        // Arrange
        final outdatedConsent = testUserConsent.copyWith(
          consentVersion: '0.9.0', // Old version
        );
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => outdatedConsent);

        // Act
        final result = await service.needsConsentRenewal();

        // Assert
        expect(result, isTrue);
      });

      test('should detect when consent is current', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.needsConsentRenewal();

        // Assert
        expect(result, isFalse);
      });

      test('should require renewal when no consent exists', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);

        // Act
        final result = await service.needsConsentRenewal();

        // Assert
        expect(result, isTrue);
      });
    });

    // ===== REQUIRED CONSENTS =====

    group('Required Consents', () {
      test('should validate required consents are granted', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act
        final result = await service.hasRequiredConsents();

        // Assert
        expect(result, isTrue);
      });

      test('should detect missing essential services consent', () async {
        // Arrange
        final invalidConsent = testUserConsent.copyWith(
          purposes: testConsentPurposes.copyWith(essentialServices: false),
        );
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => invalidConsent);

        // Act
        final result = await service.hasRequiredConsents();

        // Assert
        expect(result, isFalse);
      });

      test('should detect missing data processing consent', () async {
        // Arrange
        final invalidConsent = testUserConsent.copyWith(
          purposes: testConsentPurposes.copyWith(dataProcessing: false),
        );
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => invalidConsent);

        // Act
        final result = await service.hasRequiredConsents();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when no consent exists', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);

        // Act
        final result = await service.hasRequiredConsents();

        // Assert
        expect(result, isFalse);
      });
    });

    // ===== CONSENT REVOCATION =====

    group('Consent Revocation', () {
      test('should revoke optional consents', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.revokeOptionalConsents();

        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockConsentRepository.saveConsent(
              testUserId,
              captureAny(),
            )).captured;
        final savedConsent = captured.first as UserConsent;
        expect(savedConsent.purposes.essentialServices, isTrue);
        expect(savedConsent.purposes.dataProcessing, isTrue);
        expect(savedConsent.purposes.analytics, isFalse);
        expect(savedConsent.purposes.marketing, isFalse);
        expect(savedConsent.purposes.socialFeatures, isFalse);
        expect(savedConsent.purposes.pushNotifications, isFalse);
      });

      test('should return false when user not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);

        // Act
        final result = await service.revokeOptionalConsents();

        // Assert
        expect(result, isFalse);
      });

      test('should handle revocation errors', () async {
        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await service.revokeOptionalConsents();

        // Assert
        expect(result, isFalse);
      });
    });

    // ===== CONSENT HISTORY =====

    group('Consent History', () {
      test('should get consent history', () async {
        // Arrange
        final history = [
          testUserConsent,
          testUserConsent.copyWith(
            grantedAt: DateTime(2025, 1, 15),
            consentVersion: '0.9.0',
          ),
        ];
        when(() => mockConsentRepository.getConsentHistory(testUserId))
            .thenAnswer((_) async => history);

        // Act
        final result = await service.getConsentHistory();

        // Assert
        expect(result.length, 2);
        expect(result.first.consentVersion, currentVersion);
        expect(result.last.consentVersion, '0.9.0');
      });

      test('should return empty list when no history', () async {
        // Arrange
        when(() => mockConsentRepository.getConsentHistory(testUserId))
            .thenAnswer((_) async => []);

        // Act
        final result = await service.getConsentHistory();

        // Assert
        expect(result, isEmpty);
      });

      test('should return empty list when user not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);

        // Act
        final result = await service.getConsentHistory();

        // Assert
        expect(result, isEmpty);
        verifyNever(() => mockConsentRepository.getConsentHistory(any()));
      });

      test('should handle history retrieval errors', () async {
        // Arrange
        when(() => mockConsentRepository.getConsentHistory(testUserId))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await service.getConsentHistory();

        // Assert
        expect(result, isEmpty);
      });
    });

    // ===== SERVICE INFO =====

    group('Service Info', () {
      test('should return current consent version', () {
        // Act
        final version = service.currentConsentVersion;

        // Assert
        expect(version, currentVersion);
      });

      test('should return service name', () {
        // Act
        final name = service.serviceName;

        // Assert
        expect(name, 'ConsentService');
      });
    });

    group('checkSafely — fail-closed consent gate', () {
      test('returns false when service is null', () async {
        final result = await ConsentService.checkSafely(
          null,
          ConsentPurpose.pushNotifications,
        );
        expect(result, isFalse);
      });

      test('returns true when consent is granted', () async {
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent.copyWith(
                  purposes:
                      testConsentPurposes.copyWith(pushNotifications: true),
                ));
        // Clear cache so fresh fetch happens
        service.clearConsentCache();

        final result = await ConsentService.checkSafely(
          service,
          ConsentPurpose.pushNotifications,
        );
        expect(result, isTrue);
      });

      test('returns false when consent is denied', () async {
        when(() => mockConsentRepository.getUserConsent(testUserId)).thenAnswer(
            (_) async => testUserConsent); // pushNotifications=false

        final result = await ConsentService.checkSafely(
          service,
          ConsentPurpose.pushNotifications,
        );
        expect(result, isFalse);
      });

      test('returns false when hasConsent throws (fail-closed)', () async {
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenThrow(Exception('Firestore unavailable'));

        final result = await ConsentService.checkSafely(
          service,
          ConsentPurpose.analytics,
          logTag: 'TestTag',
        );
        expect(result, isFalse);
      });
    });

    group('onConsentChanged callback', () {
      test('fires after successful save', () async {
        var callbackFired = false;
        service.onConsentChanged = () => callbackFired = true;

        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        await service.saveConsent(testConsentPurposes);

        expect(callbackFired, isTrue);
      });

      test('does not fire on failed save', () async {
        var callbackFired = false;
        service.onConsentChanged = () => callbackFired = true;

        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => false);

        await service.saveConsent(testConsentPurposes);

        expect(callbackFired, isFalse);
      });

      test('does not fire when no callback is set', () async {
        // No exception should be thrown
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        await service.saveConsent(testConsentPurposes);
        // If we get here without error, null callback was handled safely
      });
    });

    // ===== GDPR COMPLIANCE =====

    group('GDPR Compliance', () {
      test('should track all 6 consent purposes', () async {
        // This test verifies GDPR Article 7 requirements for specific consent

        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => testUserConsent);

        // Act & Assert - Check all 6 purposes
        expect(
            await service.hasConsent(ConsentPurpose.essentialServices), isTrue);
        expect(await service.hasConsent(ConsentPurpose.dataProcessing), isTrue);
        expect(await service.hasConsent(ConsentPurpose.analytics), isTrue);
        expect(await service.hasConsent(ConsentPurpose.marketing), isFalse);
        expect(await service.hasConsent(ConsentPurpose.socialFeatures), isTrue);
        expect(await service.hasConsent(ConsentPurpose.pushNotifications),
            isFalse);
      });

      test('should maintain audit trail via repository', () async {
        // GDPR Article 30: Records of Processing Activities
        // Audit logging is handled by FirebaseConsentRepository

        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        // Act
        await service.saveConsent(testConsentPurposes);

        // Assert - Verify repository was called (which handles audit logging)
        verify(() => mockConsentRepository.saveConsent(testUserId, any()))
            .called(1);
      });

      test('should allow consent withdrawal (revocation)', () async {
        // GDPR Article 7(3): Right to withdraw consent

        // Arrange
        when(() => mockConsentRepository.getUserConsent(testUserId))
            .thenAnswer((_) async => null);
        when(() => mockConsentRepository.saveConsent(testUserId, any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.revokeOptionalConsents();

        // Assert
        expect(result, isTrue);
      });

      test('should provide consent history for accountability', () async {
        // GDPR Article 30: Demonstration of compliance

        // Arrange
        final history = [testUserConsent];
        when(() => mockConsentRepository.getConsentHistory(testUserId))
            .thenAnswer((_) async => history);

        // Act
        final result = await service.getConsentHistory();

        // Assert
        expect(result, isNotEmpty);
        expect(result.first.grantedAt, isNotNull);
        expect(result.first.deviceInfo, isNotEmpty);
      });
    });
  });
}
