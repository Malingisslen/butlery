/// Comprehensive unit tests for AuthService following TDD and BDD patterns.
///
/// This test suite validates all authentication operations including login, logout,
/// registration, user state management, error handling, and Firebase auth integration
/// using MockFirebaseAuth and comprehensive test scenarios.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/auth_service.dart';

import '../../../helpers/test_service_locator.dart';

/// Mock UserCredential for testing
class MockUserCredential extends Mock implements UserCredential {
  @override
  final User? user;

  MockUserCredential(this.user);
}

void main() {
  group('AuthService', () {
    late AuthService sut; // System Under Test
    late MockFirebaseAuthRepository mockAuthRepository;
    late MockUser mockFirebaseUser;

    setUp(() {
      TestServiceLocator.initialize();
      mockAuthRepository = TestServiceLocator.mockAuthRepository;
      mockFirebaseUser = TestServiceLocator.mockFirebaseUser;

      // Setup basic auth repository behavior
      when(() => mockAuthRepository.currentUserId).thenReturn('test_user_123');
      when(() => mockAuthRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(mockFirebaseUser));

      sut = AuthService(authRepository: mockAuthRepository);
    });

    tearDown(() {
      TestServiceLocator.reset();
    });

    group('initialization', () {
      test('should initialize with authenticated state when user exists', () {
        // Given - setup in setUp()

        // Then
        expect(sut.isAuthenticated, isTrue);
        expect(sut.currentUserId, equals('test_user_123'));
      });

      test('should initialize with unauthenticated state when no user', () {
        // Given
        when(() => mockAuthRepository.currentUserId).thenReturn(null);
        when(() => mockAuthRepository.authStateChanges())
            .thenAnswer((_) => Stream.value(null));

        sut = AuthService(authRepository: mockAuthRepository);

        // Then
        expect(sut.isAuthenticated, isFalse);
        expect(sut.currentUserId, isNull);
      });
    });

    group('authentication state', () {
      test('should provide correct authentication status', () {
        // Then
        expect(sut.isAuthenticated, isTrue);
        // Don't verify the getter call since it might be called multiple times during initialization
      });

      test('should provide current user ID', () {
        // Given
        const userId = 'authenticated_user_456';
        when(() => mockAuthRepository.currentUserId).thenReturn(userId);

        // Then
        expect(sut.currentUserId, equals(userId));
      });

      test('should handle null user information gracefully', () {
        // Given
        when(() => mockAuthRepository.currentUserId).thenReturn(null);

        // Then
        expect(sut.currentUserId, isNull);
      });
    });

    group('registration operations', () {
      test('should register new user successfully', () async {
        // Given
        const email = 'newuser@example.com';
        const password = 'newPassword123';
        const displayName = 'New User';
        final mockUserCredential = MockUserCredential(mockFirebaseUser);

        when(() => mockAuthRepository.createUser(email, password))
            .thenAnswer((_) async => mockUserCredential);
        when(() => mockAuthRepository.updateDisplayName(any(), displayName))
            .thenAnswer((_) async {});
        when(() => mockAuthRepository.currentUser).thenReturn(mockFirebaseUser);

        // When
        final result = await sut.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );

        // Then
        expect(result, isTrue);
        verify(() => mockAuthRepository.createUser(email, password)).called(1);
        verify(() => mockAuthRepository.updateDisplayName(any(), displayName))
            .called(1);
      });

      test('should handle registration failure', () async {
        // Given
        const email = 'existing@example.com';
        const password = 'password123';
        const displayName = 'Test User';

        when(() => mockAuthRepository.createUser(email, password))
            .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

        // When
        final result = await sut.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );

        // Then
        expect(result, isFalse);
        expect(sut.error, isNotNull);
      });
    });

    group('login operations', () {
      test('should login with email and password successfully', () async {
        // Given
        const email = 'test@example.com';
        const password = 'securePassword123';

        when(() => mockAuthRepository.signIn(email: email, password: password))
            .thenAnswer((_) async {});

        // When
        final result =
            await sut.signInWithEmail(email: email, password: password);

        // Then
        expect(result, isTrue);
        verify(() =>
                mockAuthRepository.signIn(email: email, password: password))
            .called(1);
      });

      test('should handle login failure with invalid credentials', () async {
        // Given
        const email = 'invalid@example.com';
        const password = 'wrongPassword';

        when(() => mockAuthRepository.signIn(email: email, password: password))
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        // When
        final result =
            await sut.signInWithEmail(email: email, password: password);

        // Then
        expect(result, isFalse);
        expect(sut.error, isNotNull);
      });
    });

    group('logout operations', () {
      test('should logout successfully', () async {
        // Given
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

        // When
        await sut.signOut();

        // Then
        verify(() => mockAuthRepository.signOut()).called(1);
      });

      test('should handle logout errors gracefully', () async {
        // Given
        when(() => mockAuthRepository.signOut())
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        // When
        await sut.signOut();

        // Then
        expect(sut.error, isNotNull);
      });
    });

    group('password management', () {
      test('should send password reset email successfully', () async {
        // Given
        const email = 'reset@example.com';

        when(() => mockAuthRepository.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // When
        final result = await sut.sendPasswordResetEmail(email);

        // Then
        expect(result, isTrue);
        verify(() => mockAuthRepository.sendPasswordResetEmail(email))
            .called(1);
      });

      test('should handle password reset for non-existent email', () async {
        // Given
        const email = 'nonexistent@example.com';

        when(() => mockAuthRepository.sendPasswordResetEmail(email))
            .thenThrow(FirebaseAuthException(code: 'user-not-found'));

        // When
        final result = await sut.sendPasswordResetEmail(email);

        // Then
        expect(result, isFalse);
        expect(sut.error, isNotNull);
      });
    });

    group('account management', () {
      test('should delete account successfully', () async {
        // Given
        when(() => mockAuthRepository.deleteCurrentUser())
            .thenAnswer((_) async {});

        // When
        final result = await sut.deleteAccount();

        // Then
        expect(result, isTrue);
        verify(() => mockAuthRepository.deleteCurrentUser()).called(1);
      });

      test('should handle delete account for unauthenticated user', () async {
        // Given
        when(() => mockAuthRepository.authStateChanges())
            .thenAnswer((_) => Stream.value(null));
        sut = AuthService(authRepository: mockAuthRepository);

        // When
        final result = await sut.deleteAccount();

        // Then
        expect(result, isFalse);
        expect(sut.error, equals('Ingen användare är inloggad'));
      });

      test('should handle recent login requirement for account deletion',
          () async {
        // Given
        when(() => mockAuthRepository.deleteCurrentUser())
            .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

        // When
        final result = await sut.deleteAccount();

        // Then
        expect(result, isFalse);
        expect(sut.error, contains('logga in igen'));
      });
    });

    group('error handling', () {
      test('should handle network errors gracefully', () async {
        // Given
        const email = 'test@example.com';
        const password = 'password123';

        when(() => mockAuthRepository.signIn(email: email, password: password))
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        // When
        final result =
            await sut.signInWithEmail(email: email, password: password);

        // Then
        expect(result, isFalse);
        expect(sut.error, isNotNull);
      });

      test('should handle timeout errors', () async {
        // Given
        const email = 'test@example.com';
        const password = 'password123';

        when(() => mockAuthRepository.signIn(email: email, password: password))
            .thenThrow(FirebaseAuthException(code: 'timeout'));

        // When
        final result =
            await sut.signInWithEmail(email: email, password: password);

        // Then
        expect(result, isFalse);
        expect(sut.error, isNotNull);
      });
    });

    group('authentication state changes', () {
      test('should notify listeners on authentication state change', () async {
        // Given
        bool notificationReceived = false;
        sut.addListener(() {
          notificationReceived = true;
        });

        when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'))).thenAnswer((_) async {});

        // When
        await sut.signInWithEmail(
            email: 'test@example.com', password: 'password123');

        // Then
        expect(notificationReceived, isTrue);
      });
    });
  });
}
