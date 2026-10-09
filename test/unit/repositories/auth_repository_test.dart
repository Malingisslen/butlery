/// Unit tests for AuthRepository implementations
///
/// Tests authentication repository functionality including Firebase
/// integration and error handling scenarios.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Note: MockFirebaseAuth is now in production_mocks.dart for mocktail stubbing

// MockUser is now imported from production_mocks.dart

void main() {
  group('FirebaseAuthRepository', () {
    late FirebaseAuthRepository repository;
    late MockFirebaseAuth mockFirebaseAuth;

    setUpAll(() {
      registerFallbackValue(ActionCodeSettings(url: 'https://example.com'));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      mockFirebaseAuth = MockFirebaseAuth();
      repository = FirebaseAuthRepository(firebaseAuth: mockFirebaseAuth);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Authentication', () {
      test('should successfully login with email and password', () async {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'test123',
          email: 'test@example.com',
          displayName: 'Test User',
        );
        final mockCredential = FakeUserCredential(mockUser);

        when(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockCredential);

        // Act
        final result = await repository.login(
          'test@example.com',
          'password123',
        );

        // Assert
        expect(result, isNotNull);
        expect(result.user, mockUser);
        verify(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test(
        'should throw FirebaseAuthException on invalid credentials',
        () async {
          // Arrange
          when(
            () => mockFirebaseAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            FirebaseAuthException(
              code: 'wrong-password',
              message: 'Invalid password',
            ),
          );

          // Act & Assert
          expect(
            () => repository.login('test@example.com', 'wrongpass'),
            throwsA(isA<FirebaseAuthException>()),
          );
        },
      );
    });

    group('User Creation', () {
      test('should create new user account', () async {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'new_user_123',
          email: 'newuser@example.com',
        );
        final mockCredential = FakeUserCredential(mockUser);

        when(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockCredential);

        // Act
        final result = await repository.createUser(
          'newuser@example.com',
          'password123',
        );

        // Assert
        expect(result, isNotNull);
        expect(result.user?.email, 'newuser@example.com');
        verify(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'newuser@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('should handle email already in use error', () async {
        // Arrange
        when(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email already exists',
          ),
        );

        // Act & Assert
        expect(
          () => repository.createUser('existing@example.com', 'password'),
          throwsA(
            allOf(
              isA<FirebaseAuthException>(),
              predicate<FirebaseAuthException>(
                (e) => e.code == 'email-already-in-use',
              ),
            ),
          ),
        );
      });
    });

    group('Display Name Update', () {
      test('should update user display name', () async {
        // Arrange
        // Note: MockUser from firebase_auth_mocks doesn't allow stubbing
        // We just test that the method can be called without error
        final mockUser = auth_mocks.MockUser(
          uid: 'test_user',
          email: 'test@example.com',
        );

        // Act & Assert - should not throw
        await expectLater(
          () async => await repository.updateDisplayName(mockUser, 'New Name'),
          returnsNormally,
        );
      });
    });

    group('Sign Out', () {
      test('should successfully sign out user', () async {
        // Arrange
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

        // Act
        await repository.signOut();

        // Assert
        verify(() => mockFirebaseAuth.signOut()).called(1);
      });

      test('logout should also call signOut', () async {
        // Arrange
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

        // Act
        await repository.logout();

        // Assert
        verify(() => mockFirebaseAuth.signOut()).called(1);
      });
    });

    group('Registration display name', () {
      setUp(() {
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
      });
      tearDown(() => repository.signOut());

      test('a name held by one instance is read by another', () {
        // UserService and AuthService each build their own repository.
        repository.holdRegistrationDisplayName(
          email: 'a@example.se',
          displayName: 'Testperson Ett',
        );

        final other = FirebaseAuthRepository(firebaseAuth: mockFirebaseAuth);

        expect(
          other.registrationDisplayNameFor('a@example.se'),
          'Testperson Ett',
        );
      });

      test('the name is only handed to the address it was typed for', () {
        repository.holdRegistrationDisplayName(
          email: 'a@example.se',
          displayName: 'Testperson Ett',
        );

        expect(
          repository.registrationDisplayNameFor(' A@Example.se '),
          'Testperson Ett',
        );
        expect(repository.registrationDisplayNameFor('b@example.se'), isNull);
        expect(repository.registrationDisplayNameFor(null), isNull);
      });

      test('sign-out drops the held name', () async {
        repository.holdRegistrationDisplayName(
          email: 'a@example.se',
          displayName: 'Testperson Ett',
        );

        await repository.signOut();

        expect(repository.registrationDisplayNameFor('a@example.se'), isNull);
      });
    });

    group('Password Reset', () {
      test('should send password reset email', () async {
        // Arrange
        when(
          () => mockFirebaseAuth.sendPasswordResetEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await repository.sendPasswordResetEmail('test@example.com');

        // Assert
        verify(
          () => mockFirebaseAuth.sendPasswordResetEmail(
            email: 'test@example.com',
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).called(1);
      });

      // BUT-2170: the link must open the app (handleCodeInApp) through the
      // Hosting domain whose association files name this app; without these
      // settings Firebase's own page opens instead.
      test('sends the reset link so that it opens the app', () async {
        when(
          () => mockFirebaseAuth.sendPasswordResetEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer((_) async {});

        await repository.sendPasswordResetEmail('test@example.com');

        final settings =
            verify(
                  () => mockFirebaseAuth.sendPasswordResetEmail(
                    email: 'test@example.com',
                    actionCodeSettings: captureAny(
                      named: 'actionCodeSettings',
                    ),
                  ),
                ).captured.single
                as ActionCodeSettings;
        expect(settings.handleCodeInApp, isTrue);
        expect(settings.linkDomain, 'butlery-app-1.firebaseapp.com');
        expect(settings.androidPackageName, 'se.butlery.app');
        expect(settings.iOSBundleId, 'se.butlery.app');
        expect(Uri.parse(settings.url).host, 'butlery-app-1.firebaseapp.com');
      });

      test('passes a reset code and new password through', () async {
        when(
          () => mockFirebaseAuth.verifyPasswordResetCode('code-1'),
        ).thenAnswer((_) async => 'anna@example.com');
        when(
          () => mockFirebaseAuth.confirmPasswordReset(
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async {});

        expect(
          await repository.verifyPasswordResetCode('code-1'),
          'anna@example.com',
        );
        await repository.confirmPasswordReset(
          code: 'code-1',
          newPassword: 'nytt-losen-1',
        );
        verify(
          () => mockFirebaseAuth.confirmPasswordReset(
            code: 'code-1',
            newPassword: 'nytt-losen-1',
          ),
        ).called(1);
      });

      test('should handle user not found error', () async {
        // Arrange
        when(
          () => mockFirebaseAuth.sendPasswordResetEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer(
          (_) async => throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'User not found',
          ),
        );

        // Act & Assert
        expect(
          () => repository.sendPasswordResetEmail('unknown@example.com'),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('Delete User', () {
      test('should delete current user account', () async {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'user_to_delete',
          email: 'delete@example.com',
        );

        mockFirebaseAuth.setAuthState(currentUser: mockUser);

        // Act & Assert - should complete without error
        // Note: MockUser.delete() from firebase_auth_mocks handles deletion
        await expectLater(
          repository.deleteCurrentUser(),
          completes,
        );
      });

      test('should handle no user logged in', () async {
        // Arrange
        mockFirebaseAuth.setAuthState(currentUser: null);

        // Act & Assert - should complete without error (no-op)
        await expectLater(
          repository.deleteCurrentUser(),
          completes,
        );
      });

      test('should handle requires-recent-login error', () async {
        // Arrange
        // Create a mock User using centralized mock
        final mockUser = MockUser();

        mockUser.setUserState(
          uid: 'test_user',
          email: 'test@example.com',
        );
        mockFirebaseAuth.setAuthState(currentUser: mockUser);
        when(() => mockUser.delete()).thenAnswer(
          (_) async => throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'Recent login required',
          ),
        );

        // Act & Assert
        expect(
          () => repository.deleteCurrentUser(),
          throwsA(
            allOf(
              isA<FirebaseAuthException>(),
              predicate<FirebaseAuthException>(
                (e) => e.code == 'requires-recent-login',
              ),
            ),
          ),
        );
      });
    });

    group('Current User', () {
      test('should return current user when logged in', () {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'current_user',
          email: 'current@example.com',
        );

        mockFirebaseAuth.setAuthState(currentUser: mockUser);

        // Act
        final result = repository.currentUser;

        // Assert
        expect(result, mockUser);
      });

      test('should return null when not logged in', () {
        // Arrange
        mockFirebaseAuth.setAuthState(currentUser: null);

        // Act
        final result = repository.currentUser;

        // Assert
        expect(result, isNull);
      });

      test('getCurrentUser should return same as currentUser getter', () {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'test_user',
          email: 'test@example.com',
        );

        mockFirebaseAuth.setAuthState(currentUser: mockUser);

        // Act & Assert
        expect(repository.getCurrentUser(), repository.currentUser);
      });

      test('currentUserId should return uid of current user', () {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'user_123',
          email: 'test@example.com',
        );

        mockFirebaseAuth.setAuthState(currentUser: mockUser);

        // Act
        final result = repository.currentUserId;

        // Assert
        expect(result, 'user_123');
      });

      test('currentUserId should return null when no user', () {
        // Arrange
        mockFirebaseAuth.setAuthState(currentUser: null);

        // Act
        final result = repository.currentUserId;

        // Assert
        expect(result, isNull);
      });
    });

    group('Auth State Changes', () {
      test('should provide stream of auth state changes', () async {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'stream_user',
          email: 'stream@example.com',
        );

        final authStateStream = Stream<User?>.fromIterable([
          null,
          mockUser,
          null,
        ]);

        when(
          () => mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => authStateStream);

        // Act & Assert
        await expectLater(
          repository.authStateChanges(),
          emitsInOrder([null, mockUser, null]),
        );
      });
    });

    group('Alternative Sign In', () {
      test('should sign in with named parameters', () async {
        // Arrange
        final mockUser = auth_mocks.MockUser(
          uid: 'test123',
          email: 'test@example.com',
        );
        final mockCredential = FakeUserCredential(mockUser);

        when(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockCredential);

        // Act
        await repository.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });
    });
  });
}
