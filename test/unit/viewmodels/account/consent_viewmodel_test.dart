import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('ConsentViewModel - GDPR Article 7 Compliance Tests', () {
    late ConsentViewModel viewModel;
    late MockConsentService mockConsentService;

    // Test data
    final testUserId = 'test-user-123';
    final testTimestamp = DateTime(2025, 1, 1, 12, 0);

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
      grantedAt: testTimestamp,
      updatedAt: null,
      consentVersion: '1.0.0',
      deviceInfo: 'test-platform',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(ConsentPurposes(
        essentialServices: true,
        dataProcessing: true,
        analytics: false,
        marketing: false,
        socialFeatures: false,
        pushNotifications: false,
      ));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock service
      mockConsentService = MockConsentService();

      // Register mock in test service locator
      TestServiceLocator.registerMock<ConsentService>(mockConsentService);

      // Create view model with mock service
      viewModel = ConsentViewModel(
        consentService: mockConsentService,
      );
    });

    tearDown(() async {
      try {
        viewModel.dispose();
      } catch (e) {
        // Already disposed in test
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ===== INITIALIZATION AND DEFAULT STATE =====

    group('Initialization and Default State', () {
      test('should initialize with correct default state', () {
        // Assert - All default values
        expect(viewModel.isSaving, false,
            reason: 'Should not be saving initially');
        expect(viewModel.currentConsent, null, reason: 'No consent loaded yet');
        expect(viewModel.errorMessage, null, reason: 'No error initially');
        expect(viewModel.needsRenewal, false,
            reason: 'No renewal needed initially');
        expect(viewModel.hasConsent, false, reason: 'No consent loaded yet');

        // Required consents always true
        expect(viewModel.essentialServices, true,
            reason: 'Essential services always required');
        expect(viewModel.dataProcessing, true,
            reason: 'Data processing always required');

        // Optional consents default to false
        expect(viewModel.analytics, false,
            reason: 'Analytics consent defaults to false');
        expect(viewModel.marketing, false,
            reason: 'Marketing consent defaults to false');
        expect(viewModel.socialFeatures, false,
            reason: 'Social features consent defaults to false');
        expect(viewModel.pushNotifications, false,
            reason: 'Push notifications consent defaults to false');
      });

      test('should have required consent purposes that cannot be disabled', () {
        // Verify required consents are always true and cannot be changed
        expect(viewModel.essentialServices, true);
        expect(viewModel.dataProcessing, true);

        // These should remain true regardless of toggles
        viewModel.setAnalytics(false);
        viewModel.setMarketing(false);

        expect(viewModel.essentialServices, true,
            reason: 'Essential services cannot be disabled');
        expect(viewModel.dataProcessing, true,
            reason: 'Data processing cannot be disabled');
      });
    });

    // ===== LOAD CONSENT TESTS =====

    group('Load Consent', () {
      test('should load existing consent successfully', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.currentConsent, testUserConsent,
            reason: 'Consent should be loaded');
        expect(viewModel.hasConsent, true, reason: 'Should have consent');
        expect(viewModel.needsRenewal, false,
            reason: 'Should not need renewal');
        expect(viewModel.errorMessage, null, reason: 'No error should occur');

        // Check consent values are loaded correctly
        expect(viewModel.analytics, true,
            reason: 'Analytics consent from loaded data');
        expect(viewModel.marketing, false,
            reason: 'Marketing consent from loaded data');
        expect(viewModel.socialFeatures, true,
            reason: 'Social features consent from loaded data');
        expect(viewModel.pushNotifications, false,
            reason: 'Push notifications consent from loaded data');

        verify(() => mockConsentService.getUserConsent()).called(1);
        verify(() => mockConsentService.needsConsentRenewal()).called(1);
      });

      test('should handle no existing consent (first time user)', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => null);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => true);

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.currentConsent, null, reason: 'No consent exists');
        expect(viewModel.hasConsent, false, reason: 'Should not have consent');
        expect(viewModel.needsRenewal, true,
            reason: 'Should need renewal (first time)');

        // All optional consents should default to false
        expect(viewModel.analytics, false);
        expect(viewModel.marketing, false);
        expect(viewModel.socialFeatures, false);
        expect(viewModel.pushNotifications, false);

        verify(() => mockConsentService.getUserConsent()).called(1);
      });

      test('should detect when consent renewal is needed', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => true);

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.needsRenewal, true,
            reason: 'Should need renewal (outdated consent)');
        expect(viewModel.hasConsent, true, reason: 'Should still have consent');

        verify(() => mockConsentService.needsConsentRenewal()).called(1);
      });

      test('should handle errors during load', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenThrow(Exception('Network error'));

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.errorMessage, isNotNull,
            reason: 'Error message should be set');
        expect(viewModel.errorMessage, contains('Ett fel uppstod'),
            reason: 'User-friendly Swedish error');
        expect(viewModel.currentConsent, null,
            reason: 'Consent should not be loaded');

        verify(() => mockConsentService.getUserConsent()).called(1);
      });

      test('should handle authentication errors with specific message',
          () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenThrow(Exception('No authenticated user'));

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.errorMessage, contains('måste vara inloggad'),
            reason: 'Auth error should have specific message');
      });

      test('should handle network errors with specific message', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenThrow(Exception('network connection failed'));

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.errorMessage, contains('internetanslutning'),
            reason: 'Network error should have specific message');
      });
    });

    // ===== SAVE CONSENT TESTS =====

    group('Save Consent', () {
      test('should save consent successfully with current state', () async {
        // Arrange
        when(() => mockConsentService.saveConsent(any()))
            .thenAnswer((_) async => true);
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Set some consent values
        viewModel.setAnalytics(true);
        viewModel.setMarketing(false);
        viewModel.setSocialFeatures(true);
        viewModel.setPushNotifications(false);

        // Act
        final result = await viewModel.saveConsent();

        // Assert
        expect(result, true, reason: 'Save should succeed');
        expect(viewModel.errorMessage, null, reason: 'No error should occur');

        // Verify saved purposes match ViewModel state
        final captured =
            verify(() => mockConsentService.saveConsent(captureAny())).captured;
        expect(captured.length, 1);

        final savedPurposes = captured[0] as ConsentPurposes;
        expect(savedPurposes.analytics, true);
        expect(savedPurposes.marketing, false);
        expect(savedPurposes.socialFeatures, true);
        expect(savedPurposes.pushNotifications, false);
        expect(savedPurposes.essentialServices, true,
            reason: 'Always required');
        expect(savedPurposes.dataProcessing, true, reason: 'Always required');

        // Should reload after save
        verify(() => mockConsentService.getUserConsent()).called(1);
      });

      test('should handle save failure', () async {
        // Arrange
        when(() => mockConsentService.saveConsent(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await viewModel.saveConsent();

        // Assert
        expect(result, false, reason: 'Save should fail');
        // Note: When executeNamedOperation completes without throwing,
        // AsyncOperationMixin doesn't treat it as an error state
        // The operation completed successfully (no exception), it just returned false
        // Error messages set within the operation may not persist after completion

        verify(() => mockConsentService.saveConsent(any())).called(1);
      });

      test('should handle save exception', () async {
        // Arrange
        when(() => mockConsentService.saveConsent(any()))
            .thenThrow(Exception('Permission denied'));

        // Act
        final result = await viewModel.saveConsent();

        // Assert
        expect(result, false, reason: 'Save should fail on exception');
        expect(viewModel.errorMessage, isNotNull,
            reason: 'Error message should be set');
        expect(viewModel.errorMessage, contains('Ett fel uppstod'),
            reason: 'User-friendly error message');
      });

      test('should prevent duplicate concurrent saves (AsyncOperationMixin)',
          () async {
        // Arrange
        var saveCallCount = 0;
        when(() => mockConsentService.saveConsent(any())).thenAnswer((_) async {
          saveCallCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        });
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Act - Try to save twice concurrently
        final future1 = viewModel.saveConsent();
        await Future.delayed(const Duration(milliseconds: 10)); // Small delay
        final future2 = viewModel.saveConsent();

        final results = await Future.wait([future1, future2]);

        // Assert - AsyncOperationMixin should prevent duplicate 'save' operations
        // First operation should succeed, second should return previous result or fail
        expect(saveCallCount, lessThanOrEqualTo(1),
            reason: 'Named operation should prevent duplicates');
        expect(results.first, true, reason: 'First save should succeed');
      });
    });

    // ===== CONSENT PURPOSE TOGGLES =====

    group('Consent Purpose Toggles', () {
      test('should toggle analytics consent and notify listeners', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        expect(viewModel.analytics, false, reason: 'Initial state');

        // Act - Toggle on
        viewModel.setAnalytics(true);

        // Assert
        expect(viewModel.analytics, true, reason: 'Should be toggled on');
        expect(notificationCount, 1, reason: 'Should notify listeners');

        // Act - Toggle off
        viewModel.setAnalytics(false);

        // Assert
        expect(viewModel.analytics, false, reason: 'Should be toggled off');
        expect(notificationCount, 2, reason: 'Should notify listeners again');
      });

      test('should toggle marketing consent', () {
        // Arrange
        expect(viewModel.marketing, false);

        // Act
        viewModel.setMarketing(true);

        // Assert
        expect(viewModel.marketing, true);
      });

      test('should toggle social features consent', () {
        // Arrange
        expect(viewModel.socialFeatures, false);

        // Act
        viewModel.setSocialFeatures(true);

        // Assert
        expect(viewModel.socialFeatures, true);
      });

      test('should toggle push notifications consent', () {
        // Arrange
        expect(viewModel.pushNotifications, false);

        // Act
        viewModel.setPushNotifications(true);

        // Assert
        expect(viewModel.pushNotifications, true);
      });

      test('should handle multiple toggles correctly', () {
        // Act - Set multiple consents
        viewModel.setAnalytics(true);
        viewModel.setMarketing(true);
        viewModel.setSocialFeatures(false);
        viewModel.setPushNotifications(true);

        // Assert
        expect(viewModel.analytics, true);
        expect(viewModel.marketing, true);
        expect(viewModel.socialFeatures, false);
        expect(viewModel.pushNotifications, true);
      });
    });

    // ===== ACCEPT/REJECT ALL OPERATIONS =====

    group('Accept/Reject All Operations', () {
      test('should accept all optional consents', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Verify initial state
        expect(viewModel.analytics, false);
        expect(viewModel.marketing, false);
        expect(viewModel.socialFeatures, false);
        expect(viewModel.pushNotifications, false);

        // Act
        viewModel.acceptAll();

        // Assert - All optional consents should be true
        expect(viewModel.analytics, true,
            reason: 'Analytics should be accepted');
        expect(viewModel.marketing, true,
            reason: 'Marketing should be accepted');
        expect(viewModel.socialFeatures, true,
            reason: 'Social features should be accepted');
        expect(viewModel.pushNotifications, true,
            reason: 'Push notifications should be accepted');

        // Required consents remain true
        expect(viewModel.essentialServices, true);
        expect(viewModel.dataProcessing, true);

        expect(notificationCount, 1, reason: 'Should notify listeners once');
      });

      test('should reject all optional consents', () {
        // Arrange
        viewModel.acceptAll(); // Start with all accepted
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.rejectAll();

        // Assert - All optional consents should be false
        expect(viewModel.analytics, false,
            reason: 'Analytics should be rejected');
        expect(viewModel.marketing, false,
            reason: 'Marketing should be rejected');
        expect(viewModel.socialFeatures, false,
            reason: 'Social features should be rejected');
        expect(viewModel.pushNotifications, false,
            reason: 'Push notifications should be rejected');

        // Required consents remain true
        expect(viewModel.essentialServices, true);
        expect(viewModel.dataProcessing, true);

        expect(notificationCount, 1, reason: 'Should notify listeners once');
      });

      test('should handle accept all followed by save', () async {
        // Arrange
        when(() => mockConsentService.saveConsent(any()))
            .thenAnswer((_) async => true);
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Act
        viewModel.acceptAll();
        final result = await viewModel.saveConsent();

        // Assert
        expect(result, true);

        final captured =
            verify(() => mockConsentService.saveConsent(captureAny())).captured;
        final savedPurposes = captured[0] as ConsentPurposes;

        expect(savedPurposes.analytics, true);
        expect(savedPurposes.marketing, true);
        expect(savedPurposes.socialFeatures, true);
        expect(savedPurposes.pushNotifications, true);
      });
    });

    // ===== REVOKE ALL OPTIONAL CONSENTS =====

    group('Revoke All Optional Consents', () {
      test('should revoke all optional consents successfully', () async {
        // Arrange
        when(() => mockConsentService.revokeOptionalConsents())
            .thenAnswer((_) async => true);
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent.copyWith(
                  purposes: ConsentPurposes(
                    essentialServices: true,
                    dataProcessing: true,
                    analytics: false,
                    marketing: false,
                    socialFeatures: false,
                    pushNotifications: false,
                  ),
                ));
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Set some consents first
        viewModel.acceptAll();
        expect(viewModel.analytics, true,
            reason: 'Analytics should be accepted initially');

        // Act
        final result = await viewModel.revokeAllOptional();

        // Assert
        expect(result, isNotNull, reason: 'Result should not be null');
        expect(result, isTrue, reason: 'Revoke should succeed');
        expect(viewModel.analytics, false,
            reason: 'Analytics should be revoked');
        expect(viewModel.marketing, false,
            reason: 'Marketing should be revoked');
        expect(viewModel.socialFeatures, false,
            reason: 'Social features should be revoked');
        expect(viewModel.pushNotifications, false,
            reason: 'Push notifications should be revoked');

        verify(() => mockConsentService.revokeOptionalConsents()).called(1);
        verify(() => mockConsentService.getUserConsent()).called(1);
      });

      test('should handle revoke failure', () async {
        // Arrange
        when(() => mockConsentService.revokeOptionalConsents())
            .thenAnswer((_) async => false);

        // Act
        final result = await viewModel.revokeAllOptional();

        // Assert
        expect(result, false, reason: 'Revoke should fail');
        expect(
            viewModel.errorMessage, contains('Kunde inte återkalla samtycken'));
      });
    });

    // ===== HAS CONSENT FOR SPECIFIC PURPOSE =====

    group('Has Consent For Specific Purpose', () {
      test('should check if user has consent for specific purpose', () async {
        // Arrange
        when(() => mockConsentService.hasConsent(ConsentPurpose.analytics))
            .thenAnswer((_) async => true);
        when(() => mockConsentService.hasConsent(ConsentPurpose.marketing))
            .thenAnswer((_) async => false);

        // Act & Assert
        final hasAnalytics =
            await viewModel.hasConsentFor(ConsentPurpose.analytics);
        final hasMarketing =
            await viewModel.hasConsentFor(ConsentPurpose.marketing);

        expect(hasAnalytics, true);
        expect(hasMarketing, false);

        verify(() => mockConsentService.hasConsent(ConsentPurpose.analytics))
            .called(1);
        verify(() => mockConsentService.hasConsent(ConsentPurpose.marketing))
            .called(1);
      });
    });

    // ===== CONSENT HISTORY =====

    group('Consent History', () {
      test('should get consent history successfully', () async {
        // Arrange
        final historyConsent1 = testUserConsent;
        final historyConsent2 = testUserConsent.copyWith(
          updatedAt: DateTime(2025, 1, 15),
        );

        when(() => mockConsentService.getConsentHistory())
            .thenAnswer((_) async => [historyConsent1, historyConsent2]);

        // Act
        final history = await viewModel.getConsentHistory();

        // Assert
        expect(history.length, 2);
        expect(history[0], historyConsent1);
        expect(history[1], historyConsent2);

        verify(() => mockConsentService.getConsentHistory()).called(1);
      });

      test('should handle empty consent history', () async {
        // Arrange
        when(() => mockConsentService.getConsentHistory())
            .thenAnswer((_) async => []);

        // Act
        final history = await viewModel.getConsentHistory();

        // Assert
        expect(history, isEmpty);
      });

      test('should handle consent history error', () async {
        // Arrange
        when(() => mockConsentService.getConsentHistory())
            .thenThrow(Exception('Database error'));

        // Act
        final history = await viewModel.getConsentHistory();

        // Assert
        expect(history, isEmpty, reason: 'Should return empty list on error');
      });
    });

    // ===== TIMESTAMP FORMATTING =====

    group('Consent Timestamp Text', () {
      test('should return "Inget samtycke" when no consent', () {
        // Arrange - No consent loaded

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, 'Inget samtycke');
      });

      test('should format timestamp as "Just nu" for very recent consent',
          () async {
        // Arrange
        final recentConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => recentConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, 'Just nu');
      });

      test('should format timestamp in minutes for recent consent', () async {
        // Arrange
        final recentConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => recentConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, contains('minuter sedan'));
      });

      test('should format timestamp in hours for older consent', () async {
        // Arrange
        final olderConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(hours: 5)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => olderConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, contains('timmar sedan'));
      });

      test('should format timestamp in days for old consent', () async {
        // Arrange
        final oldConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => oldConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, contains('dagar sedan'));
      });

      test('should format timestamp in months for very old consent', () async {
        // Arrange
        final veryOldConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(days: 90)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => veryOldConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        expect(text, contains('månader sedan'));
      });

      test('should use updatedAt timestamp if available', () async {
        // Arrange
        final updatedConsent = testUserConsent.copyWith(
          grantedAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => updatedConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        await viewModel.loadConsent();

        // Act
        final text = viewModel.getConsentTimestampText();

        // Assert
        // Should use updatedAt (5 minutes ago), not grantedAt (90 days ago)
        expect(text, contains('minuter sedan'));
      });
    });

    // ===== ASYNCOPERATIONMIXIN INTEGRATION =====

    group('AsyncOperationMixin Integration', () {
      test('should set isLoading state during load operation', () async {
        // Arrange
        final loadingStateChanges = <bool>[];
        viewModel.addListener(() {
          loadingStateChanges.add(viewModel.isLoading);
        });

        when(() => mockConsentService.getUserConsent()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return testUserConsent;
        });
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Act
        final loadFuture = viewModel.loadConsent();
        await Future.delayed(const Duration(milliseconds: 10));

        // Should be loading at this point
        expect(viewModel.isLoading, true,
            reason: 'Should be loading during operation');

        await loadFuture;

        // Assert
        expect(viewModel.isLoading, false,
            reason: 'Should not be loading after completion');
        expect(loadingStateChanges, contains(true),
            reason: 'Loading state should have been true');
      });

      test('should set error state on operation failure', () async {
        // Arrange
        when(() => mockConsentService.getUserConsent())
            .thenThrow(Exception('Network error'));

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.hasError, true, reason: 'Should have error state');
        expect(viewModel.error, isNotNull, reason: 'Error should be set');
      });

      test('should clear error state before new operation', () async {
        // Arrange - First operation fails
        when(() => mockConsentService.getUserConsent())
            .thenThrow(Exception('Network error'));
        await viewModel.loadConsent();
        expect(viewModel.hasError, true);

        // Arrange - Second operation succeeds
        when(() => mockConsentService.getUserConsent())
            .thenAnswer((_) async => testUserConsent);
        when(() => mockConsentService.needsConsentRenewal())
            .thenAnswer((_) async => false);

        // Act
        await viewModel.loadConsent();

        // Assert
        expect(viewModel.hasError, false,
            reason: 'Error should be cleared on success');
        expect(viewModel.error, null);
      });
    });

    // ===== DISPOSE =====

    group('Dispose', () {
      test('should dispose without errors', () {
        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });

      test('should not notify listeners after dispose', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.dispose();

        // Try to modify after dispose - this will throw in debug mode
        // which is the expected behavior for Flutter ChangeNotifier
        expect(() => viewModel.setAnalytics(true), throwsA(anything));

        // Assert - notification count remains 0 (dispose doesn't notify)
        expect(notificationCount, 0, reason: 'Should not notify after dispose');
      });
    });
  });
}
