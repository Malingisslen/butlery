/// Authentication test helper for consistent auth setup across tests
///
/// Provides standardized authentication setup and teardown for tests
/// to ensure proper auth context and prevent auth-related test failures.
library;

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart'
    as firebase_auth_mocks;
import 'package:mocktail/mocktail.dart';
import '../infrastructure/factories/mock_factory.dart';

/// Local mocktail subclass for tests that need to stub `signIn`, `signOut`,
/// `authStateChanges`, etc. The production `FakeAuthRepository` in
/// production_mocks.dart extends [Fake] and cannot be used with `when()`
/// (BUT-1074).
class _MockAuthRepository extends Mock implements AuthRepository {}

/// Helper class for standardized authentication setup in tests
class AuthTestHelper {
  AuthTestHelper._();

  /// Default test user ID
  static const String defaultUserId = 'test_user_123';

  /// Default test user email
  static const String defaultEmail = 'test@example.com';

  /// Default test user display name
  static const String defaultDisplayName = 'Test User';

  /// Default test user avatar URL
  static const String defaultAvatarUrl = 'https://example.com/avatar.jpg';

  /// Create a standard authenticated mock auth repository
  static AuthRepository createAuthenticatedAuthRepository({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool isEmailVerified = true,
  }) {
    final mockUser = MockFactory.createMockUser(
      uid: userId ?? defaultUserId,
      email: email ?? defaultEmail,
      displayName: displayName ?? defaultDisplayName,
      photoURL: avatarUrl ?? defaultAvatarUrl,
      emailVerified: isEmailVerified,
    );

    final mockAuthRepo = _MockAuthRepository();

    // Stub state-style getters via mocktail (no concrete overrides shadow
    // these on _MockAuthRepository, unlike the pre-BUT-1074 mock).
    when(() => mockAuthRepo.currentUser).thenReturn(mockUser);
    when(() => mockAuthRepo.currentUserId).thenReturn(userId ?? defaultUserId);
    when(() => mockAuthRepo.getCurrentUser()).thenReturn(mockUser);

    // Setup common auth methods
    when(() => mockAuthRepo.authStateChanges())
        .thenAnswer((_) => Stream.value(mockUser));

    when(() => mockAuthRepo.signOut()).thenAnswer((_) async {
      when(() => mockAuthRepo.currentUser).thenReturn(null);
      when(() => mockAuthRepo.currentUserId).thenReturn(null);
      when(() => mockAuthRepo.getCurrentUser()).thenReturn(null);
    });

    return mockAuthRepo;
  }

  /// Create an unauthenticated mock auth repository
  static AuthRepository createUnauthenticatedAuthRepository() {
    final mockAuthRepo = _MockAuthRepository();

    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockAuthRepo.currentUserId).thenReturn(null);
    when(() => mockAuthRepo.getCurrentUser()).thenReturn(null);

    // Setup auth state stream
    when(() => mockAuthRepo.authStateChanges())
        .thenAnswer((_) => Stream.value(null));

    return mockAuthRepo;
  }

  /// Create a MockFirebaseAuth instance for integration tests
  static firebase_auth_mocks.MockFirebaseAuth createMockFirebaseAuth({
    String? userId,
    String? email,
    String? displayName,
    bool signedIn = true,
  }) {
    if (signedIn) {
      return firebase_auth_mocks.MockFirebaseAuth(
        mockUser: firebase_auth_mocks.MockUser(
          uid: userId ?? defaultUserId,
          email: email ?? defaultEmail,
          displayName: displayName ?? defaultDisplayName,
        ),
        signedIn: true,
      );
    } else {
      return firebase_auth_mocks.MockFirebaseAuth(
        signedIn: false,
      );
    }
  }

  /// Setup standard authenticated user for a test
  static AuthTestContext setupAuthenticatedUser({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) {
    final mockUser = MockFactory.createMockUser(
      uid: userId ?? defaultUserId,
      email: email ?? defaultEmail,
      displayName: displayName ?? defaultDisplayName,
      photoURL: avatarUrl ?? defaultAvatarUrl,
    );

    final mockAuthRepo = createAuthenticatedAuthRepository(
      userId: userId,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    return AuthTestContext(
      user: mockUser,
      authRepository: mockAuthRepo,
      userId: userId ?? defaultUserId,
      email: email ?? defaultEmail,
      displayName: displayName ?? defaultDisplayName,
    );
  }

  /// Setup unauthenticated context for a test
  static AuthTestContext setupUnauthenticatedUser() {
    final mockAuthRepo = createUnauthenticatedAuthRepository();

    return AuthTestContext(
      user: null,
      authRepository: mockAuthRepo,
      userId: null,
      email: null,
      displayName: null,
    );
  }

  /// Setup auth error scenario
  static AuthRepository setupAuthError({
    required String errorCode,
    String? errorMessage,
  }) {
    final mockAuthRepo = _MockAuthRepository();

    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockAuthRepo.currentUserId).thenReturn(null);
    when(() => mockAuthRepo.getCurrentUser()).thenReturn(null);

    // Setup to throw error on sign in
    when(() => mockAuthRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(FirebaseAuthException(
      code: errorCode,
      message: errorMessage,
    ));

    // Setup to throw error on sign up
    when(() => mockAuthRepo.createUser(
          any(),
          any(),
        )).thenThrow(FirebaseAuthException(
      code: errorCode,
      message: errorMessage,
    ));

    return mockAuthRepo;
  }

  /// Verify common auth operations were called
  static void verifyAuthOperations({
    required AuthRepository authRepository,
    bool? signInCalled,
    bool? signOutCalled,
    bool? createUserCalled,
    bool? updateDisplayNameCalled,
    bool? deleteUserCalled,
  }) {
    if (signInCalled == true) {
      verify(() => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).called(1);
    }

    if (signOutCalled == true) {
      verify(() => authRepository.signOut()).called(1);
    }

    if (createUserCalled == true) {
      verify(() => authRepository.createUser(any(), any())).called(1);
    }

    if (updateDisplayNameCalled == true) {
      verify(() => authRepository.updateDisplayName(any(), any())).called(1);
    }

    if (deleteUserCalled == true) {
      verify(() => authRepository.deleteCurrentUser()).called(1);
    }
  }
}

/// Context object containing auth setup for a test
class AuthTestContext {
  final User? user;
  final AuthRepository authRepository;
  final String? userId;
  final String? email;
  final String? displayName;

  const AuthTestContext({
    required this.user,
    required this.authRepository,
    required this.userId,
    required this.email,
    required this.displayName,
  });

  /// Whether the user is authenticated
  bool get isAuthenticated => user != null;

  /// Get the current user ID or throw if not authenticated
  String get requireUserId {
    if (userId == null) {
      throw StateError('No authenticated user in test context');
    }
    return userId!;
  }

  /// Sign out the user
  Future<void> signOut() async {
    await authRepository.signOut();
  }
}

/// Extension to easily add auth context to tests
extension AuthTestExtensions on Object {
  /// Create authenticated context with default values
  AuthTestContext get withAuth => AuthTestHelper.setupAuthenticatedUser();

  /// Create unauthenticated context
  AuthTestContext get withoutAuth => AuthTestHelper.setupUnauthenticatedUser();
}
