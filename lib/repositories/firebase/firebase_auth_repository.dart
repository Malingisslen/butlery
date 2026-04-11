import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  // Cached auth state protection against Firebase NULL emissions
  User? _cachedUser;
  bool _ignoreInitialNull = false;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _initializeAuthStateProtection();
  }

  void _initializeAuthStateProtection() {
    _cachedUser = _firebaseAuth.currentUser;
    _ignoreInitialNull = (_cachedUser != null);

    if (_cachedUser != null) {
      AppLogger.info(
          'Auth protection enabled for user: ${_cachedUser!.uid.maskedUserId}',
          'AuthRepository');
    }
  }

  /// Stream of authentication state changes, deduplicated by UID.
  @override
  Stream<User?> authStateChanges() => _firebaseAuth
      .authStateChanges()
      .distinct((prev, next) => prev?.uid == next?.uid);

  @override
  User? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;

    // Critical Firebase initialization race condition guard
    if (_ignoreInitialNull && firebaseUser == null && _cachedUser != null) {
      AppLogger.info(
          'BLOCKING Firebase NULL emission - preserving cached user: ${_cachedUser!.uid}',
          'AuthRepository');
      _ignoreInitialNull = false;
      return _cachedUser;
    }

    _ignoreInitialNull = false;

    if (firebaseUser != null) {
      _cachedUser = firebaseUser;
    }

    return firebaseUser;
  }

  @override
  User? getCurrentUser() => currentUser;

  @override
  String? get currentUserId {
    final user = currentUser;
    return user?.uid;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await login(email, password);
  }

  @override
  Future<UserCredential> login(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    _cachedUser = credential.user;
    _ignoreInitialNull = false;
    AppLogger.success(
        'Login successful - cached user updated: ${_cachedUser!.uid}',
        'AuthRepository');

    return credential;
  }

  @override
  Future<UserCredential> createUser(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    _cachedUser = credential.user;
    _ignoreInitialNull = false;
    AppLogger.success(
        'Registration successful - cached user updated: ${_cachedUser!.uid}',
        'AuthRepository');

    return credential;
  }

  @override
  Future<void> updateDisplayName(User user, String displayName) {
    return user.updateDisplayName(displayName);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _cachedUser = null;
    _ignoreInitialNull = false;
  }

  @override
  Future<void> deleteCurrentUser() async {
    await _firebaseAuth.currentUser?.delete();
    _cachedUser = null;
    _ignoreInitialNull = false;
    AppLogger.success(
        'Account deleted - cached user cleared', 'AuthRepository');
  }

  @override
  Future<void> logout() => signOut();

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    if (user.email == null) throw Exception('User has no email address');

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    AppLogger.success(
        'Re-authentication successful for: ${user.email}', 'AuthRepository');
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.updatePassword(newPassword);
    AppLogger.success('Password updated successfully', 'AuthRepository');
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.sendEmailVerification();
    AppLogger.success('Verification email sent', 'AuthRepository');
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await user.reload();
    _cachedUser = _firebaseAuth.currentUser;
  }

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.verifyBeforeUpdateEmail(newEmail);
    AppLogger.success(
        'Verification email sent to: $newEmail', 'AuthRepository');
  }

  @override
  Future<void> verifyPhoneNumber({
    PhoneMultiFactorInfo? multiFactorInfo,
    MultiFactorSession? multiFactorSession,
    required String? phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      multiFactorInfo: multiFactorInfo,
      multiFactorSession: multiFactorSession,
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: timeout,
    );
  }
}
