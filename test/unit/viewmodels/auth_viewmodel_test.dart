import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/services/auth_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('AuthViewModel - Ultrathink Enhanced Tests', () {
    late AuthViewModel viewModel;
    late MockAuthService mockAuthService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock auth service
      mockAuthService = MockFactory.createAuthService();

      // Register mock in test service locator
      TestServiceLocator.registerMock<AuthService>(mockAuthService);

      // Create view model with injected mock service
      viewModel = AuthViewModel(authService: mockAuthService);
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

    group('Initialization and Default State', () {
      test('should initialize with correct default state for all properties',
          () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.isLoginMode, isTrue,
            reason: 'Should start in login mode');
        expect(viewModel.isPasswordVisible, isFalse,
            reason: 'Password should be hidden by default');
        expect(viewModel.isLoading, isFalse,
            reason: 'Should not be loading initially');
        expect(viewModel.errorMessage, isNull,
            reason: 'Should have no error message initially');
        expect(viewModel.isAuthenticated, isFalse,
            reason: 'Should not be authenticated initially');
      });

      test('should properly initialize AuthService listener connection',
          () async {
        // Arrange
        final testViewModel = AuthViewModel(authService: mockAuthService);
        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        // Act - trigger service change and notify
        mockAuthService.setAuthState(isLoading: true);
        mockAuthService.notifyListeners();
        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(notificationCount, greaterThan(0),
            reason: 'Should be listening to AuthService changes');

        // Cleanup
        testViewModel.dispose();
      });
    });

    group('Authentication Mode Management', () {
      test('should toggle between login and register modes correctly', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act & Assert - first toggle to register
        expect(viewModel.isLoginMode, isTrue);
        viewModel.toggleAuthMode();
        expect(viewModel.isLoginMode, isFalse);
        expect(
            notificationCount,
            equals(
                3)); // toggleAuthMode() calls clearError() which triggers 3 notifications

        // Act & Assert - toggle back to login
        viewModel.toggleAuthMode();
        expect(viewModel.isLoginMode, isTrue);
        expect(notificationCount,
            equals(6)); // 3 more notifications from second toggle
      });

      test('should clear error messages when toggling authentication mode', () {
        // Arrange
        mockAuthService.setAuthState(error: 'Previous error');

        // Act
        viewModel.toggleAuthMode();

        // Assert - clearError() is now implemented in MockAuthService, verify behavior not call count
        expect(viewModel.errorMessage, isNull);
      });

      test('should maintain other state when toggling mode', () {
        // Arrange
        mockAuthService.setAuthState(isLoading: true, isAuthenticated: true);

        // Act
        viewModel.toggleAuthMode();

        // Assert
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.isPasswordVisible, isFalse);
      });
    });

    group('Password Visibility Management', () {
      test('should toggle password visibility state correctly', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act & Assert - show password
        expect(viewModel.isPasswordVisible, isFalse);
        viewModel.togglePasswordVisibility();
        expect(viewModel.isPasswordVisible, isTrue);
        expect(notificationCount, equals(1));

        // Act & Assert - hide password
        viewModel.togglePasswordVisibility();
        expect(viewModel.isPasswordVisible, isFalse);
        expect(notificationCount, equals(2));
      });

      test('should not affect other state when toggling password visibility',
          () {
        // Arrange
        mockAuthService.setAuthState(
            isLoading: true, isAuthenticated: true, error: 'Test error');

        // Act
        viewModel.togglePasswordVisibility();

        // Assert
        expect(viewModel.isLoginMode, isTrue);
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.errorMessage, equals('Test error'));
      });
    });

    group('Sign In Functionality', () {
      test('should successfully sign in with valid email and password',
          () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert - Verify behavior, not call count
        expect(result, isTrue);
      });

      test('should reject empty email during sign in', () async {
        // Arrange - no mocking needed for validation failure

        // Act
        final result = await viewModel.signIn(
          email: '',
          password: 'password123',
        );

        // Assert - Service should not be called due to validation failure
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('E-post kan inte vara tom'));
      });

      test('should reject invalid email format during sign in', () async {
        // Arrange - test emails that actually fail the production regex
        final invalidEmails = [
          'invalid-email', // No @ symbol
          'test@', // Missing domain
          '@example.com', // Missing local part
          'test@example', // Missing TLD
          'test @example.com', // Space in local part (not allowed by regex)
        ];

        // Act & Assert
        for (final email in invalidEmails) {
          final result = await viewModel.signIn(
            email: email,
            password: 'password123',
          );
          expect(result, isFalse, reason: 'Should reject email: $email');
          expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
        }
      });

      test('should accept valid email formats including Swedish characters',
          () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        final validEmails = [
          'test@example.com',
          'åsa.öberg@example.com',
          'erik_svensson@example.se',
          'anna-andersson@test.co.uk',
          'test123@subdomain.example.com',
        ];

        // Act & Assert
        for (final email in validEmails) {
          final result = await viewModel.signIn(
            email: email,
            password: 'password123',
          );
          expect(result, isTrue, reason: 'Should accept email: $email');
        }
      });

      test('should reject empty password during sign in', () async {
        // Arrange - no mocking needed for validation failure

        // Act
        final result = await viewModel.signIn(
          email: 'test@example.com',
          password: '',
        );

        // Assert - Service should not be called due to validation failure
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('Lösenord kan inte vara tomt'));
      });

      test('should reject password shorter than 6 characters', () async {
        // Arrange
        final shortPasswords = ['', '1', '12', '123', '1234', '12345'];

        // Act & Assert
        for (final password in shortPasswords) {
          final result = await viewModel.signIn(
            email: 'test@example.com',
            password: password,
          );
          expect(result, isFalse,
              reason: 'Should reject password length: ${password.length}');
          // Check appropriate error message based on length
          if (password.isEmpty) {
            expect(
                viewModel.errorMessage, equals('Lösenord kan inte vara tomt'));
          } else {
            expect(viewModel.errorMessage,
                equals('Lösenord måste vara minst 6 tecken'));
          }
        }
      });

      test('should accept password with exactly 6 characters', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.signIn(
          email: 'test@example.com',
          password: '123456',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should reject email with leading/trailing spaces during validation',
          () async {
        // Arrange - Production validates BEFORE trimming, so spaces cause rejection

        // Act
        final result = await viewModel.signIn(
          email: '  test@example.com  ',
          password: 'password123',
        );

        // Assert - Should fail validation due to spaces (production behavior)
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
      });

      test('should handle service failure during sign in', () async {
        // Arrange - Configure service to return false
        mockAuthService.setAuthState(
            isAuthenticated: false, error: 'Service failure');

        // Act
        final result = await viewModel.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Registration Functionality', () {
      test(
          'should successfully register with valid credentials and display name',
          () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.register(
          email: 'newuser@example.com',
          password: 'securePassword123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should validate all fields before registration', () async {
        // Arrange - test empty fields

        // Act & Assert - empty email
        var result = await viewModel.register(
          email: '',
          password: 'password123',
          displayName: 'Test User',
        );
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('E-post kan inte vara tom'));

        // Act & Assert - empty password
        result = await viewModel.register(
          email: 'test@example.com',
          password: '',
          displayName: 'Test User',
        );
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('Lösenord kan inte vara tomt'));

        // Act & Assert - empty display name
        result = await viewModel.register(
          email: 'test@example.com',
          password: 'password123',
          displayName: '',
        );
        expect(result, isFalse);
        expect(
            viewModel.errorMessage, equals('Visningsnamn kan inte vara tomt'));
      });

      test('should reject display name shorter than 2 characters', () async {
        // Arrange
        final shortNames = ['', 'A'];

        // Act & Assert
        for (final name in shortNames) {
          final result = await viewModel.register(
            email: 'test@example.com',
            password: 'password123',
            displayName: name,
          );
          expect(result, isFalse,
              reason: 'Should reject display name: "$name"');
          // Check appropriate error message based on length
          if (name.isEmpty) {
            expect(viewModel.errorMessage,
                equals('Visningsnamn kan inte vara tomt'));
          } else {
            expect(viewModel.errorMessage,
                equals('Visningsnamn måste vara minst 2 tecken'));
          }
        }
      });

      test('should accept display name with exactly 2 characters', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.register(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'AB',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should accept Swedish characters in display name', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        final swedishNames = [
          'Åsa Öberg',
          'Erik Svensson',
          'Anna-Lena Andersson',
          'Björn Ström',
        ];

        // Act & Assert
        for (final name in swedishNames) {
          final result = await viewModel.register(
            email: 'test@example.com',
            password: 'password123',
            displayName: name,
          );
          expect(result, isTrue, reason: 'Should accept display name: $name');
        }
      });

      test('should reject email with spaces during registration validation',
          () async {
        // Arrange - Production validates BEFORE trimming, so spaces cause rejection

        // Act
        final result = await viewModel.register(
          email: '  test@example.com  ',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert - Should fail validation due to spaces (production behavior)
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
      });

      test('should handle service failure during registration', () async {
        // Arrange - Configure service to return false
        mockAuthService.setAuthState(
            isAuthenticated: false, error: 'Service failure');

        // Act
        final result = await viewModel.register(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Sign Out Functionality', () {
      test('should delegate sign out to auth service', () async {
        // Arrange - Use default successful behavior

        // Act & Assert - Should complete without throwing
        await expectLater(viewModel.signOut(), completes);
      });

      test('should handle sign out errors gracefully', () async {
        // Arrange - Configure service to throw error
        mockAuthService.setAuthState(error: 'Sign out failed');

        // Act & Assert
        await expectLater(viewModel.signOut(), throwsA(isA<Exception>()));
      });
    });

    group('Password Reset Functionality', () {
      test('should send password reset email for valid email', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.sendPasswordReset('test@example.com');

        // Assert
        expect(result, isTrue);
      });

      test('should validate email before sending password reset', () async {
        // Arrange - test invalid emails
        final invalidEmails = ['', 'invalid-email', 'test@', '@example.com'];

        // Act & Assert
        for (final email in invalidEmails) {
          final result = await viewModel.sendPasswordReset(email);
          expect(result, isFalse, reason: 'Should reject email: $email');
          // Verify appropriate error message based on email
          if (email.isEmpty) {
            expect(viewModel.errorMessage, equals('E-post kan inte vara tom'));
          } else {
            expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
          }
        }
      });

      test('should reject email with spaces during password reset validation',
          () async {
        // Arrange - Production validates BEFORE trimming, so spaces cause rejection

        // Act
        final result =
            await viewModel.sendPasswordReset('  test@example.com  ');

        // Assert - Should fail validation due to spaces (production behavior)
        expect(result, isFalse);
        expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
      });

      test('should handle service failure during password reset', () async {
        // Arrange - Configure service to return false
        mockAuthService.setAuthState(
            isAuthenticated: false, error: 'Service failure');

        // Act
        final result = await viewModel.sendPasswordReset('test@example.com');

        // Assert
        expect(result, isFalse);
      });
    });

    group('Error Management', () {
      test('should clear error through auth service', () {
        // Arrange - Set an error first
        mockAuthService.setAuthState(error: 'Test error');

        // Act
        viewModel.clearError();

        // Assert - Verify behavior, not call count
        expect(viewModel.errorMessage, isNull);
      });

      test('should notify listeners when validation errors occur', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger validation error
        viewModel.signIn(email: '', password: 'password123');

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    group('State Synchronization with AuthService', () {
      test('should reflect auth service loading state', () {
        // Arrange & Act
        mockAuthService.setAuthState(isLoading: false);
        expect(viewModel.isLoading, isFalse);

        mockAuthService.setAuthState(isLoading: true);
        expect(viewModel.isLoading, isTrue);
      });

      test('should reflect auth service error messages', () {
        // Arrange & Act
        mockAuthService.setAuthState(error: null);
        expect(viewModel.errorMessage, isNull);

        mockAuthService.setAuthState(error: 'Test error message');
        expect(viewModel.errorMessage, equals('Test error message'));
      });

      test('should reflect auth service authentication state', () {
        // Arrange & Act
        mockAuthService.setAuthState(isAuthenticated: false);
        expect(viewModel.isAuthenticated, isFalse);

        mockAuthService.setAuthState(isAuthenticated: true);
        expect(viewModel.isAuthenticated, isTrue);
      });

      test('should notify listeners when auth service state changes', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        mockAuthService.setAuthState(isLoading: true);
        mockAuthService.notifyListeners();

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Lifecycle Management', () {
      test('should properly dispose resources and remove listeners', () {
        // Arrange
        final testViewModel = AuthViewModel(authService: mockAuthService);

        // Act & Assert - Should not throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test(
          'should handle multiple dispose calls as Flutter ChangeNotifier behavior',
          () {
        // Arrange
        final testViewModel = AuthViewModel(authService: mockAuthService);

        // Act - First dispose should work
        expect(() => testViewModel.dispose(), returnsNormally);

        // Act & Assert - Second dispose should throw FlutterError (correct ChangeNotifier behavior)
        expect(() => testViewModel.dispose(), throwsFlutterError);
      });

      test('should not notify listeners after disposal', () {
        // Arrange
        final testViewModel = AuthViewModel(authService: mockAuthService);
        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        // Act
        testViewModel.dispose();

        // Try to trigger notifications after disposal
        expect(() => testViewModel.toggleAuthMode(), throwsA(anything));

        // Assert
        expect(notificationCount, equals(0));
      });
    });

    group('Concurrent Operations', () {
      test('should handle rapid mode toggles correctly', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - rapid toggles
        for (int i = 0; i < 10; i++) {
          viewModel.toggleAuthMode();
        }

        // Assert
        expect(viewModel.isLoginMode, isTrue); // Even number of toggles
        expect(
            notificationCount,
            equals(
                30)); // 10 toggles × 3 notifications each (toggleAuthMode + clearError)
      });

      test('should handle concurrent sign in attempts', () async {
        // Arrange - Use default successful behavior with delay simulation

        // Act - start multiple sign ins
        final future1 = viewModel.signIn(
          email: 'test1@example.com',
          password: 'password123',
        );
        final future2 = viewModel.signIn(
          email: 'test2@example.com',
          password: 'password456',
        );

        final results = await Future.wait([future1, future2]);

        // Assert
        expect(results, everyElement(isTrue));
      });
    });

    group('Edge Cases and Boundary Conditions', () {
      test('should handle extremely long email addresses', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)
        final longEmail = '${'a' * 100}@${'b' * 100}.com';

        // Act
        final result = await viewModel.signIn(
          email: longEmail,
          password: 'password123',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle extremely long passwords', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)
        final longPassword = 'a' * 1000;

        // Act
        final result = await viewModel.signIn(
          email: 'test@example.com',
          password: longPassword,
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle special characters in display name', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)
        final specialNames = [
          "O'Connor",
          'Jean-Pierre',
          'María José',
          'François',
          'Müller',
        ];

        // Act & Assert
        for (final name in specialNames) {
          final result = await viewModel.register(
            email: 'test@example.com',
            password: 'password123',
            displayName: name,
          );
          expect(result, isTrue, reason: 'Should accept display name: $name');
        }
      });

      test('should handle email with multiple dots', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.signIn(
          email: 'first.last@sub.domain.example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle email with numbers', () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.signIn(
          email: 'user123@example456.com',
          password: 'password123',
        );

        // Assert
        expect(result, isTrue);
      });
    });

    group('Swedish Localization Validation', () {
      test('should accept Swedish special characters in all text fields',
          () async {
        // Arrange - Use default successful behavior (shouldSucceed = true)

        // Act
        final result = await viewModel.register(
          email: 'åäö@example.com',
          password: 'lösenordÅÄÖ',
          displayName: 'Åsa Öberg',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should reject Swedish domain names per email validation standards',
          () async {
        // Arrange - Production regex requires ASCII-only domain names (standard email validation)

        final swedishDomains = [
          'test@företag.se', // å, ö not allowed in domain part by production regex
          'test@skåne.se', // å not allowed in domain part
          'test@göteborg.se', // ö not allowed in domain part
        ];

        // Act & Assert - Should fail validation (production behavior)
        for (final email in swedishDomains) {
          final result = await viewModel.signIn(
            email: email,
            password: 'password123',
          );
          expect(result, isFalse,
              reason: 'Should reject email with non-ASCII domain: $email');
          expect(viewModel.errorMessage, equals('Ogiltig e-postadress'));
        }
      });
    });
  });
}
