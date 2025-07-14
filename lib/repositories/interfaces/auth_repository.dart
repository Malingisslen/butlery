import 'package:firebase_auth/firebase_auth.dart';

/// Repository responsible for authentication related operations
abstract class AuthRepository {
  /// Attempt to sign a user in with email and password
  Future<UserCredential> login(String email, String password);

  /// Register a new user with email and password
  Future<UserCredential> createUser(String email, String password);

  /// Update the currently signed in [user]'s display name
  Future<void> updateDisplayName(User user, String displayName);

  /// Sign in a user with the provided credentials
  Future<void> signIn({
    required String email,
    required String password,
  });

  /// Sign out the currently authenticated user
  Future<void> signOut();

  /// Send a password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Permanently delete the currently authenticated user
  Future<void> deleteCurrentUser();

  /// Convenience getter for the currently authenticated user
  User? get currentUser;

  /// Sign out the currently authenticated user
  Future<void> logout();

  /// Retrieve the currently signed in user, if any
  User? getCurrentUser();

  /// Convenience getter for the currently authenticated user's id
  String? get currentUserId;

  /// Stream of auth state changes
  Stream<User?> authStateChanges();
}
