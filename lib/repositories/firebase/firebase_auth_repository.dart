import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Wrapper around [FirebaseAuth] to expose a minimal API used across services.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently signed in user.
  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  User? getCurrentUser() => _firebaseAuth.currentUser;

  /// Convenience getter for the current user id.
  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Sign in with email and password.
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> login(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register a new account with email and password.
  @override
  Future<UserCredential> createUser(String email, String password) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> updateDisplayName(User user, String displayName) {
    return user.updateDisplayName(displayName);
  }

  /// Send a password reset email to the given address.
  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Sign out the current user.
  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    await _firebaseAuth.currentUser?.delete();
  }

  @override
  Future<void> logout() => signOut();
}
