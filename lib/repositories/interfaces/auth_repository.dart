import 'package:firebase_auth/firebase_auth.dart';

/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Login with email and password.
  Future<UserCredential> login(String email, String password);

  /// Create new user account.
  Future<UserCredential> createUser(String email, String password);

  /// Update user display name.
  Future<void> updateDisplayName(User user, String displayName);

  /// Alternative sign in method with named parameters.
  Future<void> signIn({
    required String email,
    required String password,
  });

  /// Sign out current user.
  Future<void> signOut();

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email);

  /// Delete current user account permanently.
  Future<void> deleteCurrentUser();

  /// Get current authenticated user.
  User? get currentUser;

  /// Logout alias for signOut.
  Future<void> logout();

  /// Get current user (method form).
  User? getCurrentUser();

  /// Get current user ID.
  String? get currentUserId;

  /// Stream of authentication state changes.
  Stream<User?> authStateChanges();

  /// Re-authenticate user with password (required before sensitive operations).
  Future<void> reauthenticateWithPassword(String password);

  /// Update the current user's password (requires recent authentication).
  Future<void> updatePassword(String newPassword);

  /// Send verification email to new address before updating (requires recent authentication).
  Future<void> verifyBeforeUpdateEmail(String newEmail);
}
