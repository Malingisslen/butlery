import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Why a reset step did not go through, in the terms the view answers.
enum PasswordResetFailure {
  /// Used, expired or unknown link, or the account is gone or disabled:
  /// only a new link helps.
  linkInvalid,

  /// Firebase's password policy refused the new password.
  weakPassword,

  /// No connection; the same link still works on a retry.
  network,

  /// Too many attempts from this device; a retry later works.
  tooManyAttempts,

  /// Anything else; a retry may work.
  unknown,
}

/// The result of checking a reset link: the account's address, or why not.
typedef PasswordResetCheck = ({String? email, PasswordResetFailure? failure});

/// Sets a new password from a "glömt lösenord" link (BUT-2170).
///
/// Not a `BaseService`: it runs signed OUT, which `executeServiceOperation`'s
/// auth pre-flight refuses, and its callers need the failure TYPE, not a
/// message. Neither the code nor the password is ever logged.
class PasswordResetService {
  PasswordResetService({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<PasswordResetCheck> check(String code) async {
    try {
      final email = await _authRepository.verifyPasswordResetCode(code);
      return (email: email, failure: null);
    } catch (e) {
      return (email: null, failure: _failure(e, 'check'));
    }
  }

  /// Null when the new password is saved.
  Future<PasswordResetFailure?> confirm({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _authRepository.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      return null;
    } catch (e) {
      return _failure(e, 'confirm');
    }
  }

  PasswordResetFailure _failure(Object error, String step) {
    final code = error is FirebaseAuthException ? error.code : null;
    AppLogger.warning(
      'Password reset $step failed: ${code ?? error.runtimeType}',
      'PasswordResetService',
    );
    return switch (code) {
      'expired-action-code' ||
      'invalid-action-code' ||
      'user-disabled' ||
      'user-not-found' => PasswordResetFailure.linkInvalid,
      'weak-password' || 'password-does-not-meet-requirements' =>
        PasswordResetFailure.weakPassword,
      'network-request-failed' => PasswordResetFailure.network,
      'too-many-requests' => PasswordResetFailure.tooManyAttempts,
      _ => PasswordResetFailure.unknown,
    };
  }
}

/// What the sign-in screen does next after the reset view hands over.
sealed class PasswordResetHandoff {
  const PasswordResetHandoff();

  static PasswordResetHandoff? _pending;

  /// The hand-over waiting for the sign-in screen, if any.
  static PasswordResetHandoff? get pending => _pending;

  static void record(PasswordResetHandoff handoff) => _pending = handoff;

  /// Cleared once the sign-in screen has acted on it, or on sign-in.
  static void clear() => _pending = null;
}

/// The password is saved: log in with it, address filled in (decision B1).
final class PasswordResetDone extends PasswordResetHandoff {
  const PasswordResetDone(this.email);
  final String email;
}

/// The link no longer works: open "Glömt lösenord" to send a new one.
final class PasswordResetRequestNewLink extends PasswordResetHandoff {
  const PasswordResetRequestNewLink();
}
