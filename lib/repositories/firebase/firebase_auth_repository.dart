import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:butlery/models/auth/password_reset_link.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  // Cached auth state protection against Firebase NULL emissions
  User? _cachedUser;
  // Static: services build their own repository instances, and the one that
  // registers is not the one UserService reads.
  static ({String email, String displayName})? _registrationName;
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
        'AuthRepository',
      );
    }
  }

  /// Stream of authentication state changes, deduplicated by UID.
  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges().distinct(
    (prev, next) => prev?.uid == next?.uid,
  );

  @override
  User? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;

    // Critical Firebase initialization race condition guard
    if (_ignoreInitialNull && firebaseUser == null && _cachedUser != null) {
      AppLogger.info(
        'BLOCKING Firebase NULL emission - preserving cached user: ${_cachedUser!.uid}',
        'AuthRepository',
      );
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
      'AuthRepository',
    );

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
      'AuthRepository',
    );

    return credential;
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    final credential = await _firebaseAuth.signInAnonymously();
    _cachedUser = credential.user;
    _ignoreInitialNull = false;
    AppLogger.success(
      'Guest sign-in successful - cached user updated: '
          '${_cachedUser?.uid.maskedUserId}',
      'AuthRepository',
    );
    return credential;
  }

  @override
  Future<UserCredential> linkEmailPassword(
    String email,
    String password,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final credential = await user.linkWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    _cachedUser = credential.user ?? _firebaseAuth.currentUser;
    _ignoreInitialNull = false;
    AppLogger.success('E-mail and password linked', 'AuthRepository');
    return credential;
  }

  @override
  Future<void> updateDisplayName(User user, String displayName) {
    return user.updateDisplayName(displayName);
  }

  @override
  void holdRegistrationDisplayName({
    required String email,
    required String displayName,
  }) {
    _registrationName = (
      email: email.trim().toLowerCase(),
      displayName: displayName,
    );
  }

  @override
  String? registrationDisplayNameFor(String? email) {
    final held = _registrationName;
    if (held == null || email == null) return null;
    return email.trim().toLowerCase() == held.email ? held.displayName : null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: passwordResetActionCodeSettings,
    );
  }

  static final ActionCodeSettings passwordResetActionCodeSettings =
      ActionCodeSettings(
        url: PasswordResetLink.continueUrl,
        handleCodeInApp: true,
        linkDomain: PasswordResetLink.linkDomain,
        androidPackageName: PasswordResetLink.androidPackageName,
        iOSBundleId: PasswordResetLink.iOSBundleId,
      );

  @override
  Future<String> verifyPasswordResetCode(String code) =>
      _firebaseAuth.verifyPasswordResetCode(code);

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) => _firebaseAuth.confirmPasswordReset(
    code: code,
    newPassword: newPassword,
  );

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _cachedUser = null;
    _ignoreInitialNull = false;
    _registrationName = null;
  }

  @override
  Future<void> deleteCurrentUser() async {
    await _firebaseAuth.currentUser?.delete();
    _cachedUser = null;
    _ignoreInitialNull = false;
    AppLogger.success(
      'Account deleted - cached user cleared',
      'AuthRepository',
    );
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
      'Re-authentication successful for: ${user.email}',
      'AuthRepository',
    );
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
  List<String> get providerIds =>
      _firebaseAuth.currentUser?.providerData
          .map((info) => info.providerId)
          .toList() ??
      const [];

  @override
  AuthCredential providerCredential(ProviderTokens tokens) =>
      switch (tokens.provider) {
        SignInProvider.google => GoogleAuthProvider.credential(
          idToken: tokens.idToken,
        ),
        // The one-time code is not passed: it is spent only on the token
        // revocation before an account deletion.
        SignInProvider.apple => OAuthProvider('apple.com').credential(
          idToken: tokens.idToken,
          rawNonce: tokens.rawNonce,
        ),
      };

  /// Name and e-mail only: the photo is never asked for (Malin 2026-10-10).
  AuthProvider _firebaseProvider(SignInProvider provider) => switch (provider) {
    SignInProvider.google =>
      GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile'),
    SignInProvider.apple =>
      AppleAuthProvider()
        ..addScope('email')
        ..addScope('name'),
  };

  @override
  Future<UserCredential> signInWithProviderTokens(ProviderTokens tokens) =>
      _remember(
        _firebaseAuth.signInWithCredential(providerCredential(tokens)),
      );

  @override
  Future<UserCredential> signInWithProviderFlow(SignInProvider provider) {
    final authProvider = _firebaseProvider(provider);
    return _remember(
      kIsWeb
          ? _firebaseAuth.signInWithPopup(authProvider)
          : _firebaseAuth.signInWithProvider(authProvider),
    );
  }

  Future<UserCredential> _remember(Future<UserCredential> signIn) async {
    final credential = await signIn;
    _cachedUser = credential.user;
    _ignoreInitialNull = false;
    return credential;
  }

  @override
  Future<void> linkCredential(AuthCredential credential) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.linkWithCredential(credential);
    _cachedUser = _firebaseAuth.currentUser;
  }

  @override
  String? providerEmail(String providerId) {
    final infos = _firebaseAuth.currentUser?.providerData ?? const [];
    for (final info in infos) {
      if (info.providerId == providerId) return info.email;
    }
    return null;
  }

  @override
  Future<void> linkWithProviderFlow(SignInProvider provider) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final authProvider = _firebaseProvider(provider);
    if (kIsWeb) {
      await user.linkWithPopup(authProvider);
    } else {
      await user.linkWithProvider(authProvider);
    }
    _cachedUser = _firebaseAuth.currentUser;
  }

  @override
  Future<void> unlinkProvider(String providerId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.unlink(providerId);
    _cachedUser = _firebaseAuth.currentUser;
  }

  @override
  Future<void> reauthenticateWithProviderTokens(ProviderTokens tokens) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.reauthenticateWithCredential(providerCredential(tokens));
  }

  @override
  Future<void> reauthenticateWithProviderFlow(SignInProvider provider) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final authProvider = _firebaseProvider(provider);
    if (kIsWeb) {
      await user.reauthenticateWithPopup(authProvider);
    } else {
      await user.reauthenticateWithProvider(authProvider);
    }
  }

  @override
  Future<void> revokeAppleToken(String authorizationCode) =>
      _firebaseAuth.revokeTokenWithAuthorizationCode(authorizationCode);

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await user.verifyBeforeUpdateEmail(newEmail);
    AppLogger.success(
      'Verification email sent to: $newEmail',
      'AuthRepository',
    );
  }
}
