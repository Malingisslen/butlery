import 'package:firebase_auth/firebase_auth.dart';

/// Repository responsible for authentication related operations
abstract class AuthRepository {
  /// Attempt to sign a user in with email and password
  Future<UserCredential> login(String email, String password);

  /// Sign out the currently authenticated user
  Future<void> logout();

  /// Retrieve the currently signed in user, if any
  User? getCurrentUser();

  /// Convenience getter for the currently authenticated user's id
  String? get currentUserId;

  /// Stream of auth state changes
  Stream<User?> authStateChanges();
}
