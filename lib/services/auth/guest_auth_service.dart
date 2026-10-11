import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/account/terms_acceptance.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';

/// Why an upgrade from guest to account did not go through.
enum GuestUpgradeFailure {
  /// The address belongs to another account.
  emailInUse,

  /// The signed-in user is not a guest, so there is nothing to upgrade.
  notGuest,

  /// Anything else; [GuestUpgradeException.message] says what.
  other,
}

class GuestUpgradeException implements Exception {
  const GuestUpgradeException(this.reason, this.message);

  final GuestUpgradeFailure reason;
  final String message;

  @override
  String toString() => 'GuestUpgradeException(${reason.name})';
}

/// Signing in as a guest and turning the guest into an account (BUT-920).
///
/// Kept beside [AuthService] rather than in it, as [AuthMfaService] is, so
/// that file does not grow. [AuthService] still owns the signed-in user: the
/// guest sign-in reaches it through the auth stream, and the upgrade, which
/// keeps the uid and so never touches that stream, through
/// [AuthService.reloadUser].
///
/// Deliberately not a `BaseService`: the guest sign-in runs signed out, which
/// `executeServiceOperation`'s auth pre-flight refuses, and the upgrade's
/// caller needs the failure type ([GuestUpgradeException]).
class GuestAuthService {
  GuestAuthService({
    required AuthRepository authRepository,
    required AuthService authService,
    required AnalyticsService analyticsService,
    Future<void> Function()? pushUserScope,
    Future<void> Function(String uid)? recordTerms,
  }) : _authRepository = authRepository,
       _authService = authService,
       _analyticsService = analyticsService,
       _pushUserScope = pushUserScope ?? (() => DIContainer().pushUserScope()),
       _recordTerms = recordTerms ?? _recordTermsWithRepository;

  final AuthRepository _authRepository;
  final AuthService _authService;
  final AnalyticsService _analyticsService;
  final Future<void> Function() _pushUserScope;
  final Future<void> Function(String uid) _recordTerms;

  static Future<void> _recordTermsWithRepository(String uid) async {
    final users = ServiceLocator.tryGet<UserRepository>();
    if (users != null) await recordTermsAcceptance(users, uid);
  }

  /// Signs in as a new guest. Returns whether a guest is signed in.
  Future<bool> signInAsGuest() async {
    try {
      final credential = await _authRepository.signInAnonymously();
      if (credential.user == null) return false;
      // Same order as an e-mail sign-in: the user-scoped services exist
      // before anything reads them.
      await _pushUserScope();
      await _analyticsService.logSignUp(method: 'guest');
      return true;
    } catch (e) {
      AppLogger.error('Guest sign-in failed', e);
      return false;
    }
  }

  /// Adds [email] and [password] to the signed-in guest and names the account
  /// [displayName]. Everything the guest saved stays, because the uid does.
  ///
  /// Throws [GuestUpgradeException]. A failed verification e-mail does not
  /// fail the upgrade, as it does not fail a registration.
  Future<void> upgradeGuest({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null || !user.isAnonymous) {
      throw GuestUpgradeException(
        GuestUpgradeFailure.notGuest,
        AppLocale.current.errorUnexpected,
      );
    }
    final User? linked;
    try {
      final credential = await _authRepository.linkEmailPassword(
        email.trim(),
        password,
      );
      linked = credential.user ?? _authRepository.currentUser;
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Guest upgrade refused: ${e.code}');
      throw GuestUpgradeException(
        _failureFor(e.code),
        mapAuthErrorToMessage(e),
      );
    } catch (e) {
      AppLogger.error('Guest upgrade failed', e);
      throw GuestUpgradeException(
        GuestUpgradeFailure.other,
        AppLocale.current.errorUnexpected,
      );
    }

    // The link cannot be undone, so nothing after it fails the upgrade.
    if (linked != null) {
      try {
        await _authRepository.updateDisplayName(linked, displayName.trim());
      } catch (e) {
        AppLogger.warning('Guest upgrade: setting the name failed: $e');
      }
      try {
        // The terms record carries the moment the account was made, which
        // is now rather than the guest start.
        await _recordTerms(linked.uid);
      } catch (e) {
        AppLogger.warning('Guest upgrade: recording the terms failed: $e');
      }
    }
    try {
      await _authRepository.sendEmailVerification();
    } catch (e) {
      AppLogger.warning('Failed to send verification email: $e');
    }
    await _authService.reloadUser();
    try {
      await _analyticsService.logSignUp(method: 'guest_upgrade');
    } catch (e) {
      AppLogger.warning('Guest upgrade: logging the sign-up failed: $e');
    }
  }

  static GuestUpgradeFailure _failureFor(String code) => switch (code) {
    'email-already-in-use' ||
    'credential-already-in-use' => GuestUpgradeFailure.emailInUse,
    _ => GuestUpgradeFailure.other,
  };
}
