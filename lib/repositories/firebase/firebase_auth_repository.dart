import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/rate_limiting/rate_limiter.dart';

/// Firebase Authentication repository implementation providing secure user authentication.
///
/// This repository implements the [AuthRepository] interface using Firebase Authentication
/// as the backend service. It provides a clean, minimal API for authentication operations
/// while handling Firebase-specific implementation details and error handling.
///
/// **Firebase Integration:**
/// - Wraps Firebase Authentication SDK for secure user management
/// - Handles Firebase-specific authentication flows and errors
/// - Provides dependency injection support with optional Firebase instance
/// - Maintains authentication state through Firebase Auth state management
///
/// **Security Features:**
/// - Secure email/password authentication
/// - Automatic token management and refresh
/// - Session persistence across app restarts
/// - Password reset functionality via secure email links
/// - Account deletion with proper cleanup
///
/// **Architecture Benefits:**
/// - Clean separation between Firebase specifics and business logic
/// - Consistent error handling and authentication state management
/// - Testable through dependency injection of FirebaseAuth instance
/// - Minimal API surface reduces coupling to Firebase Authentication
///
/// **Usage in Dependency Injection:**
/// ```dart
/// // Register in service locator
/// ServiceLocator.registerLazySingleton<AuthRepository>(
///   () => FirebaseAuthRepository(),
/// );
///
/// // Use in ViewModels and services
/// final authRepo = ServiceLocator.get<AuthRepository>();
/// final user = await authRepo.login(email, password);
/// ```
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final RateLimiter _rateLimiter = RateLimiter();

  // ULTRATHINK: Cached auth state protection against Firebase NULL emissions
  User? _cachedUser;
  bool _ignoreInitialNull = false;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    // ULTRATHINK: Initialize cached state and setup protection
    _initializeAuthStateProtection();
  }

  /// Initialize authentication state protection against Firebase NULL emissions
  void _initializeAuthStateProtection() {
    _cachedUser = _firebaseAuth.currentUser;
    _ignoreInitialNull = (_cachedUser != null);

    if (_cachedUser != null) {
      AppLogger.info(
          'ULTRATHINK protection enabled for user: ${_cachedUser!.email}',
          'AuthRepository');
    }
  }

  /// Stream of authentication state changes.
  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently signed in user with ULTRATHINK protection against Firebase NULL emissions.
  @override
  User? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;

    // ULTRATHINK: Critical Firebase initialization race condition guard
    if (_ignoreInitialNull && firebaseUser == null && _cachedUser != null) {
      AppLogger.info(
          'BLOCKING Firebase NULL emission - preserving cached user: ${_cachedUser!.email}',
          'AuthRepository');
      _ignoreInitialNull = false; // Only ignore the first NULL
      return _cachedUser;
    }

    _ignoreInitialNull = false; // Reset flag after first real event

    // Update cached user with current state
    if (firebaseUser != null) {
      _cachedUser = firebaseUser;
    }

    return firebaseUser;
  }

  @override
  User? getCurrentUser() => currentUser;

  /// Convenience getter for the current user id with ULTRATHINK protection.
  @override
  String? get currentUserId {
    final user = currentUser; // Uses our protected currentUser getter
    return user?.uid;
  }

  /// Sign in with email and password.
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // Rate limit check for login operations (DoS prevention)
    return await _rateLimiter.executeWithLimit(
      RateLimitOperation.login,
      () async {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // ULTRATHINK: Update cached state immediately after successful login
        _cachedUser = credential.user;
        _ignoreInitialNull = false; // Reset protection flag
        AppLogger.success(
            'Login successful - cached user updated: ${_cachedUser!.email}',
            'AuthRepository');
      },
    );
  }

  @override
  Future<UserCredential> login(String email, String password) async {
    // Rate limit check for login operations (DoS prevention)
    return await _rateLimiter.executeWithLimit(
      RateLimitOperation.login,
      () async {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // ULTRATHINK: Update cached state immediately after successful login
        _cachedUser = credential.user;
        _ignoreInitialNull = false; // Reset protection flag
        AppLogger.success(
            'Login successful - cached user updated: ${_cachedUser!.email}',
            'AuthRepository');

        return credential;
      },
    );
  }

  /// Register a new account with email and password.
  @override
  Future<UserCredential> createUser(String email, String password) async {
    // Rate limit check for registration (prevents account spam/DoS)
    return await _rateLimiter.executeWithLimit(
      RateLimitOperation.register,
      () async {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // ULTRATHINK: Update cached state immediately after successful registration
        _cachedUser = credential.user;
        _ignoreInitialNull = false; // Reset protection flag
        AppLogger.success(
            'Registration successful - cached user updated: ${_cachedUser!.email}',
            'AuthRepository');

        return credential;
      },
    );
  }

  @override
  Future<void> updateDisplayName(User user, String displayName) {
    return user.updateDisplayName(displayName);
  }

  /// Send a password reset email to the given address.
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Rate limit check for password reset (prevents email spam/DoS)
    return await _rateLimiter.executeWithLimit(
      RateLimitOperation.passwordReset,
      () async {
        return await _firebaseAuth.sendPasswordResetEmail(email: email);
      },
    );
  }

  /// Sign out the current user.
  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();

    // ULTRATHINK: Clear cached state on logout
    _cachedUser = null;
    _ignoreInitialNull = false;
  }

  @override
  Future<void> deleteCurrentUser() async {
    await _firebaseAuth.currentUser?.delete();

    // ULTRATHINK: Clear cached state on account deletion
    _cachedUser = null;
    _ignoreInitialNull = false;
    AppLogger.success(
        'Account deleted - cached user cleared', 'AuthRepository');
  }

  @override
  Future<void> logout() => signOut();
}
