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

  /// Whether the last error came from the server, so trying again can help.
  /// A form error (an empty field, a short password) is fixed in the form,
  /// not by trying again.
  bool get canRetry => _canRetry;
  bool _canRetry = false;

  void _setServerFailure(String message) {
    _canRetry = true;
    setError(message);
  }

  /// The cause, when there is one. AuthService maps Firebase's codes to
  /// user text (auth_error_mapper.dart); the causeless fallback
  /// ("Ett oväntat fel uppstod") is not a cause (content-style-guide.md:95),
  /// so it is left out and the sentence says what did not happen.
  String? get _cause {
    final message = _authService.errorMessage?.trim();
    if (message == null ||
        message.isEmpty ||
        message == AppLocale.current.errorUnexpected) {
      return null;
    }
    return message;
  }

  String _passwordFailure() {
    final cause = _cause;
    return cause == null
        ? AppLocale.current.accountSecurityPasswordChangeFailed
        : AppLocale.current.accountSecurityPasswordChangeFailedBecause(cause);
  }

  String _emailFailure() {
    final cause = _cause;
    return cause == null
        ? AppLocale.current.accountSecurityEmailChangeFailed
        : AppLocale.current.accountSecurityEmailChangeFailedBecause(cause);
  }

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
      _setServerFailure(_passwordFailure());
      return false;
    }

    final success = await _authService.changePassword(newPassword);
    setLoading(false);

    if (!success) {
      _setServerFailure(_passwordFailure());
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
      _setServerFailure(_emailFailure());
      return false;
    }

    final success = await _authService.changeEmail(newEmail);
    setLoading(false);

    if (!success) {
      _setServerFailure(_emailFailure());
    }
    return success;
  }
}
