/// Unit tests for AuthService
///
/// Tests authentication operations including login, registration,
/// logout, and error handling using properly typed mocks.
library;

// Tests need to call clearError() which is @protected
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/auth_service.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockAuthRepository mockAuthRepository;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      mockAuthRepository = MockFactory.createAuthRepository();
      mockAnalyticsService = MockFactory.createAnalyticsService();

      // Stub analytics methods used during auth operations
      when(() => mockAnalyticsService.logSignUp(method: any(named: 'method')))
          .thenAnswer((_) async {});
      when(() => mockAnalyticsService.logLogin(method: any(named: 'method')))
          .thenAnswer((_) async {});
      when(() => mockAnalyticsService.logLogout()).thenAnswer((_) async {});
      when(() => mockAnalyticsService.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      // Stub the authStateChanges stream to return an empty stream by default
      when(() => mockAuthRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      authService = AuthService(
        authRepository: mockAuthRepository,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Authentication State', () {
      test('should initially be unauthenticated', () {
        expect(authService.isAuthenticated, false);
        expect(authService.currentUser, null);
        expect(authService.currentUserId, null);
      });

      test('should update authentication state when user signs in', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(
          uid: 'test123',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        mockAuthRepository.setAuthState(
          user: mockUser,
          isAuthenticated: true,
        );

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, true);
        verify(() => mockAuthRepository.signIn(
              email: 'test@example.com',
              password: 'password123',
            )).called(1);
      });
    });

    group('User Registration', () {
      test('should successfully register new user', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(
          uid: 'new_user_123',
          email: 'newuser@example.com',
          displayName: 'New User',
        );
        final mockCredential = FakeUserCredential(mockUser);

        when(() => mockAuthRepository.createUser(
              any(),
              any(),
            )).thenAnswer((_) async => mockCredential);

        when(() => mockAuthRepository.updateDisplayName(
              any(),
              any(),
            )).thenAnswer((_) async {});

        when(() => mockAuthRepository.sendEmailVerification())
            .thenAnswer((_) async {});

        // Act
        final result = await authService.registerWithEmail(
          email: 'newuser@example.com',
          password: 'securePassword123',
          displayName: 'New User',
        );

        // Assert
        expect(result, true);
        verify(() => mockAuthRepository.createUser(
              'newuser@example.com',
              'securePassword123',
            )).called(1);
        verify(() => mockAuthRepository.updateDisplayName(
              any(),
              'New User',
            )).called(1);
        verify(() => mockAuthRepository.sendEmailVerification()).called(1);
      });

      test('should handle registration errors gracefully', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(
              any(),
              any(),
            )).thenAnswer((_) async => throw FirebaseAuthException(
              code: 'email-already-in-use',
              message: 'Email already exists',
            ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'existing@example.com',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('används redan'));
      });
    });

    group('Sign Out', () {
      test('should successfully sign out user', () async {
        // Arrange
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

        // Act
        await authService.signOut();

        // Assert
        verify(() => mockAuthRepository.signOut()).called(1);
      });
    });

    group('Password Reset', () {
      test('should send password reset email', () async {
        // Arrange
        when(() => mockAuthRepository.sendPasswordResetEmail(any()))
            .thenAnswer((_) async {});

        // Act
        final result =
            await authService.sendPasswordResetEmail('test@example.com');

        // Assert
        expect(result, true);
        verify(() =>
                mockAuthRepository.sendPasswordResetEmail('test@example.com'))
            .called(1);
      });

      test('should handle password reset errors', () async {
        // Arrange
        when(() => mockAuthRepository.sendPasswordResetEmail(any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'user-not-found',
                  message: 'User not found',
                ));

        // Act
        final result =
            await authService.sendPasswordResetEmail('unknown@example.com');

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Fel email eller lösenord'));
      });
    });

    group('Error Handling', () {
      test('should translate Firebase error codes to Swedish messages',
          () async {
        // Test various error codes
        final errorTests = [
          ('weak-password', 'för svagt'),
          ('invalid-email', 'Ogiltig'),
          ('user-disabled', 'inaktiverats'),
          ('too-many-requests', 'många försök'),
        ];

        for (final (code, expectedMessage) in errorTests) {
          when(() => mockAuthRepository.signIn(
                    email: any(named: 'email'),
                    password: any(named: 'password'),
                  ))
              .thenAnswer((_) async => throw FirebaseAuthException(code: code));

          await authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          );

          expect(authService.errorMessage, contains(expectedMessage),
              reason: 'Error code $code should contain "$expectedMessage"');
        }
      });
    });

    group('Loading State', () {
      test('should manage loading state during operations', () async {
        // Arrange
        bool? loadingStateDuringOperation;

        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {
          // Capture loading state during the operation
          loadingStateDuringOperation = authService.isLoading;
        });

        // Listen for loading state changes
        final bool initialLoading = authService.isLoading;

        // Act
        await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert
        expect(initialLoading, false, reason: 'Should start not loading');
        expect(loadingStateDuringOperation, true,
            reason: 'Should be loading during operation');
        expect(authService.isLoading, false,
            reason: 'Should not be loading after operation');
      });
    });

    group('Delete Account', () {
      test('should successfully delete account', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(
          uid: 'user_to_delete',
          email: 'delete@example.com',
        );

        // Set up auth state with a user
        mockAuthRepository.setAuthState(
          user: mockUser,
          isAuthenticated: true,
        );

        // Override the auth state stream to provide the user
        when(() => mockAuthRepository.authStateChanges())
            .thenAnswer((_) => Stream.value(mockUser));

        // Re-create the service to pick up the new stream
        authService = AuthService(
          authRepository: mockAuthRepository,
          analyticsService: mockAnalyticsService,
        );

        // Give the stream time to emit
        await Future.delayed(Duration(milliseconds: 10));

        when(() => mockAuthRepository.deleteCurrentUser())
            .thenAnswer((_) async {});

        // Act
        final result = await authService.deleteAccount();

        // Assert
        expect(result, true);
        verify(() => mockAuthRepository.deleteCurrentUser()).called(1);
      });

      test('should handle requires-recent-login error', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(uid: 'test_user');
        mockAuthRepository.setAuthState(user: mockUser, isAuthenticated: true);

        // Override the auth state stream to provide the user
        when(() => mockAuthRepository.authStateChanges())
            .thenAnswer((_) => Stream.value(mockUser));

        // Re-create the service to pick up the new stream
        authService = AuthService(
          authRepository: mockAuthRepository,
          analyticsService: mockAnalyticsService,
        );

        // Give the stream time to emit
        await Future.delayed(Duration(milliseconds: 10));

        when(() => mockAuthRepository.deleteCurrentUser())
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'requires-recent-login',
                  message: 'Recent login required',
                ));

        // Act
        final result = await authService.deleteAccount();

        // Assert
        expect(result, false);
        // Should have the specific error message for requires-recent-login
        expect(authService.errorMessage, contains('logga in igen'));
      });
    });

    group('Clear Error', () {
      test('should clear error message', () async {
        // Arrange - Create an error state
        when(() => mockAuthRepository.signIn(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                ))
            .thenAnswer((_) async =>
                throw FirebaseAuthException(code: 'invalid-email'));

        await authService.signInWithEmail(
          email: 'bad-email',
          password: 'password',
        );

        expect(authService.errorMessage, isNotNull);

        // Act
        authService.clearError();

        // Assert
        expect(authService.errorMessage, '');
      });
    });

    // ============================================================================
    // COMPREHENSIVE ERROR TEST COVERAGE
    // ============================================================================

    group('Network Error Handling', () {
      test('should handle network timeout during sign in', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {
          await Future.delayed(Duration(seconds: 30));
          throw FirebaseAuthException(
            code: 'network-request-failed',
            message: 'Network timeout',
          );
        });

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Nätverksfel'));
        expect(authService.errorMessage, contains('internetanslutning'));
      });

      test('should handle no internet connection during sign up', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'network-request-failed',
                  message: 'No internet connection',
                ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Nätverksfel'));
      });

      test('should handle network errors during password reset', () async {
        // Arrange
        when(() => mockAuthRepository.sendPasswordResetEmail(any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'network-request-failed',
                  message: 'Network unavailable',
                ));

        // Act
        final result =
            await authService.sendPasswordResetEmail('test@example.com');

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Nätverksfel'));
      });
    });

    group('Firebase Auth Error Scenarios', () {
      test('should handle user-not-found with generic credentials error',
          () async {
        // Arrange — user-not-found now returns generic message (prevents enumeration)
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found',
            ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'nonexistent@example.com',
          password: 'password',
        );

        // Assert — same generic message as wrong-password
        expect(result, false);
        expect(authService.errorMessage, contains('Fel email eller lösenord'));
      });

      test('should handle wrong-password with generic credentials error',
          () async {
        // Arrange — wrong-password now returns generic message (prevents enumeration)
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => throw FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password',
            ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        // Assert — same generic message as user-not-found
        expect(result, false);
        expect(authService.errorMessage, contains('Fel email eller lösenord'));
      });

      test(
          'user-not-found, wrong-password, and invalid-credential all produce identical error',
          () async {
        final errorCodes = [
          'user-not-found',
          'wrong-password',
          'invalid-credential'
        ];
        final messages = <String>[];

        for (final code in errorCodes) {
          authService.clearError();
          when(() => mockAuthRepository.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(FirebaseAuthException(code: code));

          await authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          );

          messages.add(authService.errorMessage ?? '');
        }

        // All three should produce the exact same message
        expect(messages[0], equals(messages[1]));
        expect(messages[1], equals(messages[2]));
        expect(messages[0], contains('Fel email eller lösenord'));
      });

      test('should handle email-already-in-use error', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'email-already-in-use',
                  message: 'Email already registered',
                ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'existing@example.com',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage,
            equals('Email-adressen används redan av ett annat konto.'));
      });

      test('should handle weak-password error', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'weak-password',
                  message: 'Password too weak',
                ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'test@example.com',
          password: '123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage,
            equals('Lösenordet är för svagt. Använd minst 6 tecken.'));
      });

      test('should handle invalid-email error', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => throw FirebaseAuthException(
              code: 'invalid-email',
              message: 'Invalid email format',
            ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'notanemail',
          password: 'password',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, equals('Ogiltig email-adress.'));
      });

      test('should handle too-many-requests error', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => throw FirebaseAuthException(
              code: 'too-many-requests',
              message: 'Too many failed attempts',
            ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage,
            equals('För många försök. Vänta en stund och försök igen.'));
      });

      test('should handle operation-not-allowed error', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenAnswer((_) async => throw FirebaseAuthException(
                  code: 'operation-not-allowed',
                  message: 'Email/password accounts are not enabled',
                ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Autentiseringsfel'));
      });

      test('should handle user-disabled error', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(
          code: 'user-disabled',
          message: 'User account has been disabled',
        ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'disabled@example.com',
          password: 'password',
        );

        // Assert
        expect(result, false);
        expect(
            authService.errorMessage, equals('Detta konto har inaktiverats.'));
      });

      test('should handle unknown Firebase error codes gracefully', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(
          code: 'unknown-error-code',
          message: 'Something unexpected happened',
        ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Autentiseringsfel'));
        expect(authService.errorMessage,
            contains('Something unexpected happened'));
      });
    });

    group('Input Validation Errors', () {
      test('should handle empty email during sign in', () async {
        // Arrange - AuthService doesn't validate, Firebase will
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(
          code: 'invalid-email',
          message: 'Empty email',
        ));

        // Act
        final result = await authService.signInWithEmail(
          email: '',
          password: 'password123',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Ogiltig'));
        verify(() => mockAuthRepository.signIn(
              email: '',
              password: 'password123',
            )).called(1);
      });

      test('should handle empty password during sign in', () async {
        // Arrange - AuthService doesn't validate, Firebase will
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(
          code: 'wrong-password',
          message: 'Empty password',
        ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: '',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Fel email eller lösenord'));
        verify(() => mockAuthRepository.signIn(
              email: 'test@example.com',
              password: '',
            )).called(1);
      });

      test('should handle invalid email format during registration', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenThrow(FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email format',
        ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'notavalidemail',
          password: 'password123',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('Ogiltig'));
      });

      test('should handle password too short during registration', () async {
        // Arrange
        when(() => mockAuthRepository.createUser(any(), any()))
            .thenThrow(FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        ));

        // Act
        final result = await authService.registerWithEmail(
          email: 'test@example.com',
          password: '12345',
          displayName: 'Test User',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, contains('för svagt'));
        expect(authService.errorMessage, contains('6 tecken'));
      });

      test('should handle empty display name during registration', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(
          uid: 'test_user',
          email: 'test@example.com',
        );
        final mockCredential = FakeUserCredential(mockUser);

        when(() => mockAuthRepository.createUser(any(), any()))
            .thenAnswer((_) async => mockCredential);
        when(() => mockAuthRepository.updateDisplayName(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockAuthRepository.sendEmailVerification())
            .thenAnswer((_) async {});

        // Act - Test with empty string for display name
        final result = await authService.registerWithEmail(
          email: 'test@example.com',
          password: 'password123',
          displayName: '',
        );

        // Assert
        expect(result, true);
        // Should call updateDisplayName with empty string
        verify(() => mockAuthRepository.updateDisplayName(any(), '')).called(1);
      });
    });

    group('Concurrent Operation Errors', () {
      test('should handle multiple simultaneous sign-in attempts', () async {
        // Arrange
        var callCount = 0;
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {
          callCount++;
          // Simulate delay to test concurrent calls
          await Future.delayed(Duration(milliseconds: 100));
          // Both calls should throw the error
          throw FirebaseAuthException(
            code: 'too-many-requests',
            message: 'Too many concurrent attempts',
          );
        });

        // Act - Start multiple sign-in attempts
        final results = await Future.wait([
          authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          ),
          authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          ),
        ]);

        // Assert
        expect(results[0], false);
        expect(results[1], false);
        expect(authService.errorMessage, contains('många försök'));
        expect(callCount, equals(2)); // Both attempts should have been made
      });

      test('should handle sign out during sign in', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {
          // Simulate delay for concurrent operation
          await Future.delayed(Duration(milliseconds: 50));
          // Return successful sign in
        });

        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

        // Act - Start sign in, then immediately sign out
        final signInFuture = authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Sign out while sign in is in progress
        await Future.delayed(Duration(milliseconds: 10));
        await authService.signOut();

        final signInResult = await signInFuture;

        // Assert - Sign in completes successfully despite sign out
        expect(signInResult,
            true); // Sign in completes as it was already in progress
        verify(() => mockAuthRepository.signOut()).called(1);
        verify(() => mockAuthRepository.signIn(
              email: 'test@example.com',
              password: 'password',
            )).called(1);
      });

      test('should prevent concurrent delete operations', () async {
        // Arrange
        final mockUser = MockFactory.createMockUser(uid: 'test_user');
        mockAuthRepository.setAuthState(user: mockUser, isAuthenticated: true);

        when(() => mockAuthRepository.authStateChanges())
            .thenAnswer((_) => Stream.value(mockUser));

        authService = AuthService(
          authRepository: mockAuthRepository,
          analyticsService: mockAnalyticsService,
        );
        await Future.delayed(Duration(milliseconds: 10));

        var deleteCallCount = 0;
        when(() => mockAuthRepository.deleteCurrentUser())
            .thenAnswer((_) async {
          deleteCallCount++;
          await Future.delayed(Duration(milliseconds: 100));
          if (deleteCallCount > 1) {
            throw FirebaseAuthException(
              code: 'requires-recent-login',
              message: 'Concurrent delete not allowed',
            );
          }
        });

        // Act - Try to delete account twice concurrently
        final results = await Future.wait([
          authService.deleteAccount(),
          authService.deleteAccount(),
        ]);

        // Assert
        expect(deleteCallCount, greaterThanOrEqualTo(1));
        // At least one should fail
        expect(results.where((r) => r == false).length, greaterThan(0));
      });
    });

    group('Error Recovery', () {
      test('should clear error state after successful operation', () async {
        // Arrange - First create an error
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

        await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        expect(authService.errorMessage, isNotEmpty);

        // Now setup successful sign in
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'correctpassword',
        );

        // Assert
        expect(result, true);
        expect(authService.errorMessage ?? '', isEmpty);
      });

      test('should provide user-friendly error messages', () async {
        // Arrange
        final technicalErrors = [
          ('user-not-found', 'Fel email eller lösenord'),
          ('wrong-password', 'Fel email eller lösenord'),
          ('invalid-email', 'Ogiltig email'),
          ('weak-password', 'för svagt'),
          ('user-disabled', 'inaktiverats'),
          ('too-many-requests', 'många försök'),
          ('network-request-failed', 'Nätverksfel'),
        ];

        for (final (code, expectedPhrase) in technicalErrors) {
          // Reset error state
          authService.clearError();

          when(() => mockAuthRepository.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(FirebaseAuthException(code: code));

          // Act
          await authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          );

          // Assert - Error message should be user-friendly
          expect(authService.errorMessage, isNotEmpty,
              reason: 'Should have error message for $code');
          expect(authService.errorMessage, contains(expectedPhrase),
              reason: 'Error for $code should contain "$expectedPhrase"');
          // Should not expose technical details
          expect(authService.errorMessage?.toLowerCase(),
              isNot(contains('exception')),
              reason: 'Should not contain technical terms for $code');
        }
      });

      test('should preserve error message until explicitly cleared', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(code: 'user-not-found'));

        // Act
        await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        final errorBefore = authService.errorMessage;

        // Wait to ensure error persists
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(authService.errorMessage, equals(errorBefore));
        expect(authService.errorMessage, isNotEmpty);

        // Act - Clear error
        authService.clearError();

        // Assert
        expect(authService.errorMessage, isEmpty);
      });

      test('should handle error during error recovery', () async {
        // Arrange - First error
        when(() => mockAuthRepository.sendPasswordResetEmail(any()))
            .thenThrow(FirebaseAuthException(
          code: 'user-not-found',
          message: 'User not found',
        ));

        // Act
        final result1 =
            await authService.sendPasswordResetEmail('unknown@example.com');

        // Assert
        expect(result1, false);
        expect(authService.errorMessage, contains('Fel email eller lösenord'));

        // Arrange - Second error during recovery attempt
        when(() => mockAuthRepository.sendPasswordResetEmail(any()))
            .thenThrow(FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Network error',
        ));

        // Act
        final result2 =
            await authService.sendPasswordResetEmail('test@example.com');

        // Assert - Should update to new error
        expect(result2, false);
        expect(authService.errorMessage, contains('Nätverksfel'));
        expect(authService.errorMessage,
            isNot(contains('Fel email eller lösenord')));
      });
    });

    group('Special Edge Cases', () {
      test('should handle null user after successful sign in', () async {
        // Arrange - Repository signs in successfully but returns null user
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        // Keep auth state as null
        mockAuthRepository.setAuthState(user: null, isAuthenticated: false);

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert
        expect(result, true); // Sign in succeeded at repository level
        expect(authService.isAuthenticated, false); // But no user set
      });

      test('should handle error with null message', () async {
        // Arrange
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(FirebaseAuthException(
          code: 'unknown-error',
          message: null,
        ));

        // Act
        final result = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert
        expect(result, false);
        expect(authService.errorMessage, isNotEmpty);
        expect(authService.errorMessage, contains('Autentiseringsfel'));
      });

      test('should handle rapid error state changes', () async {
        // Arrange
        final errors = [
          FirebaseAuthException(code: 'user-not-found'),
          FirebaseAuthException(code: 'wrong-password'),
          FirebaseAuthException(code: 'invalid-email'),
        ];

        var errorIndex = 0;
        when(() => mockAuthRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {
          if (errorIndex < errors.length) {
            throw errors[errorIndex++];
          }
        });

        // Act - Rapid sign in attempts
        for (int i = 0; i < errors.length; i++) {
          await authService.signInWithEmail(
            email: 'test@example.com',
            password: 'password',
          );
        }

        // Assert - Should have the last error
        expect(authService.errorMessage, contains('Ogiltig'));
      });
    });
  });
}
