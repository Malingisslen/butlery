import 'package:firebase_auth/firebase_auth.dart';

/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Login with email and password.
  Future<UserCredential> login(String email, String password);

  /// Create new user account.
  Future<UserCredential> createUser(String email, String password);

  /// Update user display name.
  Future<void> updateDisplayName(User user, String displayName);

  /// Holds the name typed at registration for [email] until sign-out.
  /// `createUser` signs the account in before the name can be set, so the
  /// profile created on that sign-in reads the name from here.
  void holdRegistrationDisplayName({
    required String email,
    required String displayName,
  });

  /// The held name when [email] is the address it was typed for, else null.
  String? registrationDisplayNameFor(String? email);

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

  /// Send email verification to the current user.
  Future<void> sendEmailVerification();

  /// Reload current user data from Firebase (to check emailVerified status).
  Future<void> reloadCurrentUser();

  /// Send verification email to new address before updating (requires recent authentication).
  Future<void> verifyBeforeUpdateEmail(String newEmail);

  /// Verify a phone number (for MFA enrollment/sign-in).
  Future<void> verifyPhoneNumber({
    PhoneMultiFactorInfo? multiFactorInfo,
    MultiFactorSession? multiFactorSession,
    required String? phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  });
}
