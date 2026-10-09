import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';

class AccountSecurityViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final AuthService _authService = ServiceLocator.get<AuthService>();

  String? get currentEmail => _authService.currentUser?.email;

  /// Whether trying the same change again can help.
  ///
  /// Only when the service gave no cause: a named cause is a wrong current
  /// password, a weak or taken address, too many attempts, an expired
  /// session or no network, and running the same change again with the same
  /// fields does not fix any of those (content-style-guide.md:93). Those get
  /// Stäng; the fields stay filled in, and the form's own button is there
  /// when the cause is gone. A form error (an empty field, a short password)
  /// is fixed in the form, so it gets Stäng too.
  bool get canRetry => _canRetry;
  bool _canRetry = false;

  void _setAuthFailure(String withoutCause, String Function(String) because) {
    final cause = _cause;
    _canRetry = cause == null;
    setError(cause == null ? withoutCause : because(cause));
  }

  /// The cause, when there is one. AuthService maps Firebase's codes to
  /// user text (auth_error_mapper.dart); the causeless fallback
  /// ("Ett oväntat fel uppstod") is not a cause (content-style-guide.md:95),
  /// so it is left out and the sentence says what did not happen.
  ///
  /// AuthService exposes only that text, not the Firebase code, so the
  /// fallback is recognised by comparing it with the same AppLocale string
  /// the service set it from.
  String? get _cause {
    final message = _authService.errorMessage?.trim();
    if (message == null ||
        message.isEmpty ||
        message == AppLocale.current.errorUnexpected) {
      return null;
    }
    return message;
  }

  void _setPasswordFailure() => _setAuthFailure(
    AppLocale.current.accountSecurityPasswordChangeFailed,
    AppLocale.current.accountSecurityPasswordChangeFailedBecause,
  );

  void _setEmailFailure() => _setAuthFailure(
    AppLocale.current.accountSecurityEmailChangeFailed,
    AppLocale.current.accountSecurityEmailChangeFailedBecause,
  );

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _canRetry = false;
    if (currentPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (newPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (confirmPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    if (newPassword.length < FormValidators.minPasswordLength) {
      setError(AppLocale.current.validationPasswordTooShort);
      return false;
    }
    if (newPassword != confirmPassword) {
      setError(AppLocale.current.accountSecurityPasswordMismatch);
      return false;
    }

    clearError();
    setLoading(true);

    // Reauthenticate first
    final reauthed = await _authService.reauthenticateWithPassword(
      currentPassword,
    );
    if (!reauthed) {
      setLoading(false);
      _setPasswordFailure();
      return false;
    }

    final success = await _authService.changePassword(newPassword);
    setLoading(false);

    if (!success) {
      _setPasswordFailure();
    }
    return success;
  }

  Future<bool> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    _canRetry = false;
    if (currentPassword.isEmpty) {
      setError(AppLocale.current.validationPasswordRequired);
      return false;
    }
    final emailError = ValidationUtils.validateEmail(newEmail);
    if (emailError != null) {
      setError(emailError);
      return false;
    }

    clearError();
    setLoading(true);

    // Reauthenticate first
    final reauthed = await _authService.reauthenticateWithPassword(
      currentPassword,
    );
    if (!reauthed) {
      setLoading(false);
      _setEmailFailure();
      return false;
    }

    final success = await _authService.changeEmail(newEmail);
    setLoading(false);

    if (!success) {
      _setEmailFailure();
    }
    return success;
  }
}
