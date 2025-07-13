// lib/repositories/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';

export 'package:firebase_auth/firebase_auth.dart'
    show User, UserCredential, FirebaseAuthException;

/// A thin wrapper around [FirebaseAuth] used by [AuthService].
class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently signed in user, or null if not signed in.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Currently signed in user's UID, or null if not signed in.
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Creates a new user with email and password.
  Future<UserCredential> createUser({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Updates the display name for the current user.
  Future<void> updateDisplayName(User user, String displayName) async {
    await user.updateDisplayName(displayName);
    await user.reload();
  }

  /// Signs in an existing user with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() => _firebaseAuth.signOut();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) =>
      _firebaseAuth.sendPasswordResetEmail(email: email);

  /// Deletes the currently signed-in user.
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
